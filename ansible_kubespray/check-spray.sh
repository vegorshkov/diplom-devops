#!/usr/bin/env bash

set -uo pipefail

umask 077

export LANG=C.UTF-8
export LC_ALL=C.UTF-8
export ANSIBLE_FORCE_COLOR=0
export ANSIBLE_NOCOLOR=1
export ANSIBLE_TIMEOUT=10
export PYTHONUNBUFFERED=1

PROJECT_DIR="/home/vgorshkov/STUDENT1/PROJECT/diplom-devops"
ANSIBLE_ROOT="${PROJECT_DIR}/ansible_kubespray"
KUBESPRAY_OLD_DIR="${ANSIBLE_ROOT}/kubespray"
KUBESPRAY_NEW_DIR="${ANSIBLE_ROOT}/kubespray-new"
INVENTORY_FILE="${ANSIBLE_ROOT}/inventory/hosts.yaml"
GROUP_VARS_DIR="${ANSIBLE_ROOT}/inventory/group_vars"
TARGET_VENV="/home/vgorshkov/venv-kubespray-2.31.0"
SSH_CONFIG_FILE="/home/vgorshkov/.ssh/config"
SSH_PRIVATE_KEY_FILE="/home/vgorshkov/.ssh/netology-ext-key"
LOG_DIR="${ANSIBLE_ROOT}/logs"

EXPECTED_HOSTS=(
    "k8s-master-ru-central1-a"
    "k8s-master-ru-central1-d"
    "k8s-master-ru-central1-e"
    "k8s-worker-ru-central1-a"
    "k8s-worker-ru-central1-d"
    "k8s-worker-ru-central1-e"
)

EXPECTED_CONTROL_PLANE=(
    "k8s-master-ru-central1-a"
    "k8s-master-ru-central1-d"
    "k8s-master-ru-central1-e"
)

EXPECTED_WORKERS=(
    "k8s-worker-ru-central1-a"
    "k8s-worker-ru-central1-d"
    "k8s-worker-ru-central1-e"
)

declare -A EXPECTED_IP=(
    [k8s-master-ru-central1-a]="172.16.1.10"
    [k8s-master-ru-central1-d]="172.16.3.10"
    [k8s-master-ru-central1-e]="172.16.4.10"
    [k8s-worker-ru-central1-a]="172.16.1.21"
    [k8s-worker-ru-central1-d]="172.16.3.21"
    [k8s-worker-ru-central1-e]="172.16.4.21"
)

TEMP_FILES=()
AUDIT_STATUS=0

cleanup()
{
    local file_path

    for file_path in "${TEMP_FILES[@]}"
    do
        if [[ -n "${file_path}" && -e "${file_path}" ]]
        then
            rm -f -- "${file_path}"
        fi
    done
}

section()
{
    printf '\n===== %s =====\n' "$1"
}

record_error()
{
    printf 'AUDIT_ERROR=%s\n' "$1" >&2
    AUDIT_STATUS=1
}

record_warning()
{
    printf 'AUDIT_WARNING=%s\n' "$1" >&2
}

command_exists()
{
    command -v "$1" >/dev/null 2>&1
}

print_proxy_environment_state()
{
    local variable_name
    local variable_value

    for variable_name in \
        http_proxy \
        https_proxy \
        all_proxy \
        no_proxy \
        HTTP_PROXY \
        HTTPS_PROXY \
        ALL_PROXY \
        NO_PROXY
    do
        if [[ -v "${variable_name}" ]]
        then
            variable_value="${!variable_name}"

            if [[ -n "${variable_value}" ]]
            then
                printf '%s=SET length=%s\n' \
                    "${variable_name}" \
                    "${#variable_value}"
            else
                printf '%s=EMPTY\n' "${variable_name}"
            fi
        else
            printf '%s=UNSET\n' "${variable_name}"
        fi
    done
}

audit_kubespray_directory()
{
    local directory_path="$1"
    local directory_name="$2"
    local galaxy_version="NOT_FOUND"
    local ansible_requirement="NOT_FOUND"
    local default_kubernetes_version="NOT_FOUND"

    printf '\n--- %s ---\n' "${directory_name}"
    printf 'PATH=%s\n' "${directory_path}"

    if [[ ! -d "${directory_path}" ]]
    then
        printf 'STATE=ABSENT\n'
        return
    fi

    printf 'STATE=PRESENT\n'
    printf 'PATH_TYPE=%s\n' "$([[ -L "${directory_path}" ]] && printf SYMLINK || printf DIRECTORY)"
    du -sh -- "${directory_path}" 2>/dev/null || true

    if [[ -f "${directory_path}/galaxy.yml" ]]
    then
        galaxy_version="$(
            awk '
                $1 == "version:" {
                    gsub(/"/, "", $2)
                    print $2
                    exit
                }
            ' "${directory_path}/galaxy.yml"
        )"
    fi

    if [[ -f "${directory_path}/requirements.txt" ]]
    then
        ansible_requirement="$(
            sed -nE 's/^ansible==([^[:space:]]+).*/\1/p' \
                "${directory_path}/requirements.txt" |
                head -n 1
        )"
    fi

    for version_file in \
        "${directory_path}/roles/kubespray-defaults/defaults/main/main.yml" \
        "${directory_path}/roles/kubespray_defaults/defaults/main/main.yml" \
        "${directory_path}/roles/kubespray_defaults/defaults/main/download.yml"
    do
        if [[ -f "${version_file}" ]]
        then
            default_kubernetes_version="$(
                awk '
                    /^[[:space:]]*kube_version:[[:space:]]*/ {
                        value=$0
                        sub(/^[[:space:]]*kube_version:[[:space:]]*/, "", value)
                        print value
                        exit
                    }
                ' "${version_file}"
            )"

            if [[ -n "${default_kubernetes_version}" ]]
            then
                break
            fi
        fi
    done

    printf 'GALAXY_VERSION=%s\n' "${galaxy_version:-NOT_FOUND}"
    printf 'ANSIBLE_REQUIREMENT=%s\n' "${ansible_requirement:-NOT_FOUND}"
    printf 'DEFAULT_KUBERNETES_VERSION=%s\n' "${default_kubernetes_version:-NOT_FOUND}"

    for required_path in \
        ansible.cfg \
        cluster.yml \
        galaxy.yml \
        requirements.txt \
        inventory/sample
    do
        if [[ -e "${directory_path}/${required_path}" ]]
        then
            printf 'REQUIRED_PATH=%s state=PRESENT\n' "${required_path}"
        else
            printf 'REQUIRED_PATH=%s state=ABSENT\n' "${required_path}"
            record_warning "${directory_name}: Ð¾Ñ‚Ñ�ÑƒÑ‚Ñ�Ñ‚Ð²ÑƒÐµÑ‚ ${required_path}"
        fi
    done

    sha256sum \
        "${directory_path}/galaxy.yml" \
        "${directory_path}/requirements.txt" \
        "${directory_path}/ansible.cfg" \
        2>/dev/null || true
}

trap cleanup EXIT

if [[ ! -d "${ANSIBLE_ROOT}" ]]
then
    printf 'ERROR: ÐºÐ°Ñ‚Ð°Ð»Ð¾Ð³ %s Ð½Ðµ Ð½Ð°Ð¹Ð´ÐµÐ½\n' "${ANSIBLE_ROOT}" >&2
    exit 1
fi

mkdir -p -- "${LOG_DIR}"
LOG_TIMESTAMP="$(date -u '+%Y%m%dT%H%M%SZ')"
LOG_FILE="${LOG_DIR}/check-spray-${LOG_TIMESTAMP}.log"
exec > >(tee -a "${LOG_FILE}") 2>&1

section "ÐŸÐ�Ð Ð�ÐœÐ•Ð¢Ð Ð« Ð�Ð£Ð”Ð˜Ð¢Ð�"

printf 'START_TIME=%s\n' "$(date --iso-8601=seconds)"
printf 'PROJECT_DIR=%s\n' "${PROJECT_DIR}"
printf 'ANSIBLE_ROOT=%s\n' "${ANSIBLE_ROOT}"
printf 'INVENTORY_FILE=%s\n' "${INVENTORY_FILE}"
printf 'GROUP_VARS_DIR=%s\n' "${GROUP_VARS_DIR}"
printf 'TARGET_VENV=%s\n' "${TARGET_VENV}"
printf 'SSH_CONFIG_FILE=%s\n' "${SSH_CONFIG_FILE}"
printf 'LOG_FILE=%s\n' "${LOG_FILE}"
printf 'MODE=READ_ONLY_REMOTE_AUDIT\n'

section "Ð›ÐžÐšÐ�Ð›Ð¬Ð�Ð«Ð• ÐšÐžÐœÐ�Ð�Ð”Ð«"

for required_command in \
    ansible \
    ansible-inventory \
    git \
    python3 \
    sed \
    sha256sum \
    ssh \
    tee
do
    if command_exists "${required_command}"
    then
        printf 'COMMAND=%s state=PRESENT path=%s\n' \
            "${required_command}" \
            "$(command -v "${required_command}")"
    else
        printf 'COMMAND=%s state=ABSENT\n' "${required_command}"
        record_error "Ð½Ðµ Ð½Ð°Ð¹Ð´ÐµÐ½Ð° ÐºÐ¾Ð¼Ð°Ð½Ð´Ð° ${required_command}"
    fi
done

section "Ð Ð•ÐŸÐžÐ—Ð˜Ð¢ÐžÐ Ð˜Ð™ ÐŸÐ ÐžÐ•ÐšÐ¢Ð�"

git -C "${PROJECT_DIR}" rev-parse --show-toplevel 2>/dev/null || \
    record_error "${PROJECT_DIR} Ð½Ðµ Ñ�Ð²Ð»Ñ�ÐµÑ‚Ñ�Ñ� Git-Ñ€ÐµÐ¿Ð¾Ð·Ð¸Ñ‚Ð¾Ñ€Ð¸ÐµÐ¼"
git -C "${PROJECT_DIR}" branch --show-current 2>/dev/null || true
git -C "${PROJECT_DIR}" log -1 --format='COMMIT=%H%nCOMMIT_DATE=%aI%nCOMMIT_SUBJECT=%s' 2>/dev/null || true
git -C "${PROJECT_DIR}" status --short 2>/dev/null || true

section "Ð”Ð’Ð� ÐšÐ�Ð¢Ð�Ð›ÐžÐ“Ð� KUBESPRAY"

audit_kubespray_directory "${KUBESPRAY_OLD_DIR}" "kubespray"
audit_kubespray_directory "${KUBESPRAY_NEW_DIR}" "kubespray-new"

section "Ð¡Ð¡Ð«Ð›ÐšÐ˜ Ð�Ð� KUBESPRAY Ð’ Ð Ð�Ð‘ÐžÐ§Ð˜Ð¥ Ð¤Ð�Ð™Ð›Ð�Ð¥"

if command_exists rg
then
    rg -n \
        --glob '*.sh' \
        --glob '*.yml' \
        --glob '*.yaml' \
        --glob '!kubespray/**' \
        --glob '!kubespray-new/**' \
        --glob '!logs/**' \
        'kubespray-new|ansible_kubespray/kubespray|KUBESPRAY_DIR|central1-[b]|central1-e' \
        "${ANSIBLE_ROOT}" || true
else
    grep -RInE \
        'kubespray-new|ansible_kubespray/kubespray|KUBESPRAY_DIR|central1-[b]|central1-e' \
        "${ANSIBLE_ROOT}" \
        --exclude-dir=kubespray \
        --exclude-dir=kubespray-new \
        --exclude-dir=logs || true
fi

section "Ð˜Ð¡Ð¢ÐžÐ Ð˜Ð§Ð•Ð¡ÐšÐ˜Ð• Ð–Ð£Ð Ð�Ð�Ð›Ð« Ð—Ð�ÐŸÐ£Ð¡ÐšÐ�"

if compgen -G "${LOG_DIR}/*.log" >/dev/null
then
    grep -HnE \
        '^START_TIME=|^KUBESPRAY_DIR=|^VIRTUAL_ENV=|^ansible \[core|^RESULT=|PLAY RECAP' \
        "${LOG_DIR}"/*.log 2>/dev/null |
        tail -n 160 || true
else
    printf 'LOG_STATE=ABSENT\n'
fi

section "Ð’Ð˜Ð Ð¢Ð£Ð�Ð›Ð¬Ð�ÐžÐ• ÐžÐšÐ Ð£Ð–Ð•Ð�Ð˜Ð• Ð˜ ANSIBLE"

printf 'CALLER_VIRTUAL_ENV=%s\n' "${VIRTUAL_ENV:-UNSET}"

if [[ -r "${TARGET_VENV}/bin/activate" ]]
then
    # shellcheck disable=SC1091
    source "${TARGET_VENV}/bin/activate"
    printf 'ACTIVATED_VIRTUAL_ENV=%s\n' "${VIRTUAL_ENV:-UNSET}"
else
    record_error "Ð½Ðµ Ð½Ð°Ð¹Ð´ÐµÐ½Ð¾ Ð²Ð¸Ñ€Ñ‚ÑƒÐ°Ð»ÑŒÐ½Ð¾Ðµ Ð¾ÐºÑ€ÑƒÐ¶ÐµÐ½Ð¸Ðµ ${TARGET_VENV}"
fi

if command_exists python
then
    python --version
    python -m pip --version 2>/dev/null || true
    python -m pip check || record_error "pip check Ð·Ð°Ð²ÐµÑ€ÑˆÐ¸Ð»Ñ�Ñ� Ñ� Ð¾ÑˆÐ¸Ð±ÐºÐ¾Ð¹"
    python - <<'PYTHON_PACKAGE_AUDIT'
from importlib import metadata

for package_name in (
    "ansible",
    "ansible-core",
    "cryptography",
    "jmespath",
    "netaddr",
):
    try:
        version = metadata.version(package_name)
    except metadata.PackageNotFoundError:
        version = "NOT_INSTALLED"
    print(f"PYTHON_PACKAGE={package_name} version={version}")
PYTHON_PACKAGE_AUDIT
fi

if command_exists ansible
then
    ansible --version | sed -n '1,10p'
fi

section "ÐŸÐ�Ð Ð�ÐœÐ•Ð¢Ð Ð« ENVIRONMENT"

print_proxy_environment_state

export ANSIBLE_CONFIG="${KUBESPRAY_NEW_DIR}/ansible.cfg"

printf 'LANG=%s\n' "${LANG}"
printf 'LC_ALL=%s\n' "${LC_ALL}"
printf 'ANSIBLE_CONFIG=%s\n' "${ANSIBLE_CONFIG}"
printf 'ANSIBLE_FORCE_COLOR=%s\n' "${ANSIBLE_FORCE_COLOR}"
printf 'ANSIBLE_NOCOLOR=%s\n' "${ANSIBLE_NOCOLOR}"
printf 'ANSIBLE_TIMEOUT=%s\n' "${ANSIBLE_TIMEOUT}"
printf 'PYTHONUNBUFFERED=%s\n' "${PYTHONUNBUFFERED}"

section "SSH-ÐŸÐ¡Ð•Ð’Ð”ÐžÐ�Ð˜ÐœÐ« Ð¤Ð�ÐšÐ¢Ð˜Ð§Ð•Ð¡ÐšÐ˜Ð¥ Ð£Ð—Ð›ÐžÐ’"

if [[ ! -r "${SSH_CONFIG_FILE}" ]]
then
    record_error "Ð½Ðµ Ð½Ð°Ð¹Ð´ÐµÐ½ SSH config ${SSH_CONFIG_FILE}"
fi

if [[ ! -r "${SSH_PRIVATE_KEY_FILE}" ]]
then
    record_error "Ð½Ðµ Ð½Ð°Ð¹Ð´ÐµÐ½ SSH-ÐºÐ»ÑŽÑ‡ ${SSH_PRIVATE_KEY_FILE}"
fi

for host_name in "${EXPECTED_HOSTS[@]}"
do
    resolved_ssh="$(
        ssh -G -F "${SSH_CONFIG_FILE}" "${host_name}" 2>/dev/null |
            awk '
                $1 == "hostname" ||
                $1 == "user" ||
                $1 == "identityfile" ||
                $1 == "proxyjump" {
                    print
                }
            '
    )"

    printf '\nHOST_ALIAS=%s EXPECTED_IP=%s\n' \
        "${host_name}" \
        "${EXPECTED_IP[${host_name}]}"
    printf '%s\n' "${resolved_ssh:-SSH_ALIAS_NOT_RESOLVED}"

    resolved_ip="$(
        awk '$1 == "hostname" { print $2; exit }' <<< "${resolved_ssh}"
    )"

    if [[ "${resolved_ip}" != "${EXPECTED_IP[${host_name}]}" ]]
    then
        record_error "${host_name}: HostName=${resolved_ip:-UNSET}, Ð¾Ð¶Ð¸Ð´Ð°Ð»Ñ�Ñ� ${EXPECTED_IP[${host_name}]}"
    fi
done

section "Ð¢Ð•ÐšÐ£Ð©Ð˜Ð™ INVENTORY"

if [[ ! -r "${INVENTORY_FILE}" ]]
then
    record_error "Ð½Ðµ Ð½Ð°Ð¹Ð´ÐµÐ½ inventory ${INVENTORY_FILE}"
else
    sed -n '1,260p' "${INVENTORY_FILE}"

    ansible-inventory \
        -i "${INVENTORY_FILE}" \
        --graph || record_error "ansible-inventory --graph Ð·Ð°Ð²ÐµÑ€ÑˆÐ¸Ð»Ñ�Ñ� Ñ� Ð¾ÑˆÐ¸Ð±ÐºÐ¾Ð¹"

    INVENTORY_JSON="$(mktemp /tmp/check-spray-inventory.XXXXXX.json)"
    TEMP_FILES+=("${INVENTORY_JSON}")

    if ansible-inventory \
        -i "${INVENTORY_FILE}" \
        --list \
        > "${INVENTORY_JSON}"
    then
        if ! python - "${INVENTORY_JSON}" <<'PYTHON_INVENTORY_AUDIT'
import json
import sys

inventory_path = sys.argv[1]

with open(inventory_path, encoding="utf-8") as source:
    inventory = json.load(source)

expected_control_plane = {
    "k8s-master-ru-central1-a",
    "k8s-master-ru-central1-d",
    "k8s-master-ru-central1-e",
}

expected_workers = {
    "k8s-worker-ru-central1-a",
    "k8s-worker-ru-central1-d",
    "k8s-worker-ru-central1-e",
}


def group_hosts(group_name):
    visited = set()

    def walk(current_group):
        if current_group in visited:
            return set()

        visited.add(current_group)
        group_data = inventory.get(current_group, {})
        result = set(group_data.get("hosts", []))

        for child_group in group_data.get("children", []):
            result.update(walk(child_group))

        return result

    return walk(group_name)


checks = (
    ("kube_control_plane", group_hosts("kube_control_plane"), expected_control_plane),
    ("etcd", group_hosts("etcd"), expected_control_plane),
    ("kube_node", group_hosts("kube_node"), expected_workers),
    (
        "k8s_cluster",
        group_hosts("k8s_cluster"),
        expected_control_plane | expected_workers,
    ),
)

errors = []

for group_name, actual, expected in checks:
    print(f"GROUP={group_name}")
    print(f"ACTUAL={','.join(sorted(actual))}")
    print(f"EXPECTED={','.join(sorted(expected))}")

    if actual != expected:
        errors.append(group_name)

if errors:
    print("INVENTORY_TOPOLOGY=MISMATCH")
    raise SystemExit(20)

print("INVENTORY_TOPOLOGY=VALID")
PYTHON_INVENTORY_AUDIT
        then
            record_error "inventory Ñ�Ð¾Ð´ÐµÑ€Ð¶Ð¸Ñ‚ Ñ‚Ð¾Ð¿Ð¾Ð»Ð¾Ð³Ð¸ÑŽ, Ð¾Ñ‚Ð»Ð¸Ñ‡Ð½ÑƒÑŽ Ð¾Ñ‚ a/d/e"
        fi
    else
        record_error "ansible-inventory --list Ð·Ð°Ð²ÐµÑ€ÑˆÐ¸Ð»Ñ�Ñ� Ñ� Ð¾ÑˆÐ¸Ð±ÐºÐ¾Ð¹"
    fi
fi

section "GROUP_VARS Ð˜ Ð Ð•Ð—Ð•Ð Ð’Ð�Ð«Ð• Ð¤Ð�Ð™Ð›Ð«"

if [[ -d "${GROUP_VARS_DIR}" ]]
then
    find "${GROUP_VARS_DIR}" \
        -maxdepth 4 \
        -type f \
        -printf '%P\n' |
        sort

    printf '\nACTIVE_CLUSTER_PARAMETERS\n'

    if command_exists rg
    then
        rg -n \
            --glob '*.yml' \
            --glob '*.yaml' \
            '^(kube_version|cluster_name|dns_domain|kube_network_plugin|container_manager|kube_service_addresses|kube_pods_subnet|kube_network_node_prefix|kube_proxy_mode|calico_network_backend|calico_ipip_mode):' \
            "${GROUP_VARS_DIR}" || true
    else
        grep -RInE \
            '^(kube_version|cluster_name|dns_domain|kube_network_plugin|container_manager|kube_service_addresses|kube_pods_subnet|kube_network_node_prefix|kube_proxy_mode|calico_network_backend|calico_ipip_mode):' \
            "${GROUP_VARS_DIR}" || true
    fi

    printf '\nBACKUP_OR_TEMPORARY_FILES\n'
    find "${GROUP_VARS_DIR}" \
        -type f \
        \( \
            -name '*.bak' -o \
            -name '*.bak-*' -o \
            -name '*.before-*' -o \
            -name '*.orig' -o \
            -name '*~' \
        \) \
        -printf '%P\n' |
        sort
else
    record_error "Ð½Ðµ Ð½Ð°Ð¹Ð´ÐµÐ½ ÐºÐ°Ñ‚Ð°Ð»Ð¾Ð³ ${GROUP_VARS_DIR}"
fi

section "Ð’Ð Ð•ÐœÐ•Ð�Ð�Ð«Ð™ INVENTORY Ð”Ð›Ð¯ Ð�Ð£Ð”Ð˜Ð¢Ð� Ð’Ðœ"

AUDIT_INVENTORY="$(mktemp /tmp/check-spray-hosts.XXXXXX.yml)"
TEMP_FILES+=("${AUDIT_INVENTORY}")

cat > "${AUDIT_INVENTORY}" <<EOF_AUDIT_INVENTORY
all:
  hosts:
    k8s-master-ru-central1-a:
    k8s-master-ru-central1-d:
    k8s-master-ru-central1-e:
    k8s-worker-ru-central1-a:
    k8s-worker-ru-central1-d:
    k8s-worker-ru-central1-e:
  vars:
    ansible_user: ubuntu
    ansible_ssh_private_key_file: ${SSH_PRIVATE_KEY_FILE}
    ansible_ssh_common_args: '-F ${SSH_CONFIG_FILE}'
    ansible_become: true
    ansible_become_method: sudo
    ansible_become_user: root
EOF_AUDIT_INVENTORY

ansible-inventory -i "${AUDIT_INVENTORY}" --graph || \
    record_error "Ð²Ñ€ÐµÐ¼ÐµÐ½Ð½Ñ‹Ð¹ audit inventory Ð½Ðµ Ð¿Ñ€Ð¾ÑˆÑ‘Ð» Ð¿Ñ€Ð¾Ð²ÐµÑ€ÐºÑƒ"

section "ANSIBLE PING Ð˜ SUDO"

ansible \
    -i "${AUDIT_INVENTORY}" \
    all \
    -m ansible.builtin.ping || record_error "Ð½Ðµ Ð²Ñ�Ðµ ÑƒÐ·Ð»Ñ‹ Ð²ÐµÑ€Ð½ÑƒÐ»Ð¸ pong"

ansible \
    -i "${AUDIT_INVENTORY}" \
    all \
    --become \
    -m ansible.builtin.command \
    -a 'id -u' || record_error "Ð½Ðµ Ð½Ð° Ð²Ñ�ÐµÑ… ÑƒÐ·Ð»Ð°Ñ… Ñ€Ð°Ð±Ð¾Ñ‚Ð°ÐµÑ‚ sudo"

section "Ð¡ÐžÐ¡Ð¢ÐžÐ¯Ð�Ð˜Ð• Ð¨Ð•Ð¡Ð¢Ð˜ Ð’Ð˜Ð Ð¢Ð£Ð�Ð›Ð¬Ð�Ð«Ð¥ ÐœÐ�Ð¨Ð˜Ð�"

REMOTE_AUDIT_SCRIPT="$(cat <<'REMOTE_AUDIT_EOF'
set -uo pipefail

export LANG=C.UTF-8
export LC_ALL=C.UTF-8

print_command_version()
{
    local command_name="$1"

    if command -v "${command_name}" >/dev/null 2>&1
    then
        printf 'BINARY=%s path=%s\n' \
            "${command_name}" \
            "$(command -v "${command_name}")"

        case "${command_name}" in
            kubeadm|kubectl|kubelet|containerd|crictl|etcdctl)
                timeout 10 "${command_name}" version 2>&1 |
                    sed -n '1,5p' || true
                ;;
        esac
    else
        printf 'BINARY=%s state=ABSENT\n' "${command_name}"
    fi
}

print_service_state()
{
    local service_name="$1"
    local load_state
    local active_state
    local enabled_state

    load_state="$(systemctl show "${service_name}" -p LoadState --value 2>/dev/null || true)"
    active_state="$(systemctl is-active "${service_name}" 2>/dev/null || true)"
    enabled_state="$(systemctl is-enabled "${service_name}" 2>/dev/null || true)"

    printf 'SERVICE=%s load=%s active=%s enabled=%s\n' \
        "${service_name}" \
        "${load_state:-NOT_FOUND}" \
        "${active_state:-NOT_FOUND}" \
        "${enabled_state:-NOT_FOUND}"
}

print_directory_state()
{
    local directory_path="$1"
    local object_count="0"
    local size="0"

    if [[ -e "${directory_path}" ]]
    then
        object_count="$(
            find "${directory_path}" \
                -xdev \
                -mindepth 1 \
                -maxdepth 2 \
                -print 2>/dev/null |
                wc -l
        )"
        size="$(du -sh -- "${directory_path}" 2>/dev/null | awk '{ print $1 }')"

        printf 'PATH=%s state=PRESENT objects_to_depth_2=%s size=%s\n' \
            "${directory_path}" \
            "${object_count}" \
            "${size:-UNKNOWN}"
    else
        printf 'PATH=%s state=ABSENT\n' "${directory_path}"
    fi
}

printf 'HOST=%s\n' "$(hostname)"
printf 'FQDN=%s\n' "$(hostname -f 2>/dev/null || hostname)"
printf 'DATE=%s\n' "$(date --iso-8601=seconds)"
printf 'UPTIME=%s\n' "$(uptime -p 2>/dev/null || true)"

if [[ -r /etc/os-release ]]
then
    . /etc/os-release
    printf 'OS=%s\n' "${PRETTY_NAME:-UNKNOWN}"
fi

printf 'KERNEL=%s\n' "$(uname -srmo)"
printf 'CPU_COUNT=%s\n' "$(nproc)"
printf 'MEMORY_MB=%s\n' "$(awk '/^MemTotal:/ { printf "%d", $2 / 1024 }' /proc/meminfo)"
df -hT /
df -ih /

printf '\nNETWORK\n'
ip -br -4 address show
ip -4 route show
printf 'DEFAULT_ROUTE_COUNT=%s\n' "$(ip -4 route show default | wc -l)"
ping -c 1 -W 2 8.8.8.8 || true
getent ahostsv4 mirror.yandex.ru | sed -n '1,3p' || true

if command -v curl >/dev/null 2>&1
then
    http_code="$(
        env \
            -u http_proxy \
            -u https_proxy \
            -u all_proxy \
            -u no_proxy \
            -u HTTP_PROXY \
            -u HTTPS_PROXY \
            -u ALL_PROXY \
            -u NO_PROXY \
            curl \
                --silent \
                --show-error \
                --output /dev/null \
                --connect-timeout 10 \
                --max-time 20 \
                --write-out '%{http_code}' \
                https://mirror.yandex.ru/ubuntu/dists/jammy/InRelease 2>/dev/null || true
    )"
    printf 'DIRECT_HTTPS_MIRROR_CODE=%s\n' "${http_code:-FAILED}"
fi

printf '\nTIME_AND_SWAP\n'
timedatectl show \
    --property=Timezone \
    --property=NTPSynchronized \
    --property=NTP \
    2>/dev/null || true
swapon --show --noheadings 2>/dev/null || true
printf 'SWAP_STATE=%s\n' "$([[ -n "$(swapon --show --noheadings 2>/dev/null)" ]] && printf ACTIVE || printf DISABLED)"
printf 'REBOOT_REQUIRED=%s\n' "$([[ -e /var/run/reboot-required ]] && printf YES || printf NO)"

printf '\nKERNEL_MODULES_AND_SYSCTL\n'
for module_name in overlay br_netfilter nf_conntrack ip_vs ip_vs_rr ip_vs_wrr ip_vs_sh
do
    printf 'MODULE=%s available=%s loaded=%s\n' \
        "${module_name}" \
        "$([[ -n "$(modinfo -n "${module_name}" 2>/dev/null)" ]] && printf YES || printf NO)" \
        "$(lsmod | awk -v module="${module_name}" '$1 == module { found=1 } END { print(found ? "YES" : "NO") }')"
done

for sysctl_name in \
    net.ipv4.ip_forward \
    net.bridge.bridge-nf-call-iptables \
    net.bridge.bridge-nf-call-ip6tables
do
    printf 'SYSCTL=%s value=%s\n' \
        "${sysctl_name}" \
        "$(sysctl -n "${sysctl_name}" 2>/dev/null || printf UNAVAILABLE)"
done

printf '\nPROXY_CONFIGURATION\n'
env |
    awk -F= '
        tolower($1) ~ /^(http|https|all|no)_proxy$/ {
            print "ENV_PROXY=" $1 " state=" (length($2) ? "SET" : "EMPTY")
        }
    ' |
    sort

if command -v apt-config >/dev/null 2>&1
then
    apt-config dump 2>/dev/null |
        awk '
            tolower($0) ~ /acquire::(http|https).*proxy/ {
                line=$0
                sub(/"[^"]*"/, "\"<REDACTED>\"", line)
                print "APT_PROXY_DIRECTIVE=" line
            }
        ' || true
fi

grep -RIlE \
    '(http|https|socks5|socks5h)://|Acquire::(http|https)::[Pp]roxy' \
    /etc/apt/apt.conf \
    /etc/apt/apt.conf.d \
    /etc/environment \
    /etc/systemd/system/containerd.service.d \
    /etc/systemd/system/kubelet.service.d \
    2>/dev/null |
    sed 's/^/PROXY_REFERENCE_FILE=/' || true

grep -RIlE \
    '172\.16\.2\.254:1080' \
    /etc/apt \
    /etc/environment \
    /etc/systemd/system \
    2>/dev/null |
    sed 's/^/OLD_SOCKS_REFERENCE_FILE=/' || true

printf '\nAPT_SOURCES\n'
grep -RhsE \
    '^[[:space:]]*(deb|Types:|URIs:|Suites:|Components:)' \
    /etc/apt/sources.list \
    /etc/apt/sources.list.d 2>/dev/null || true
dpkg --audit 2>/dev/null || true

printf '\nKUBERNETES_AND_RUNTIME_PACKAGES\n'
dpkg-query -W \
    -f='${binary:Package}\t${Version}\t${db:Status-Abbrev}\n' \
    kubeadm \
    kubelet \
    kubectl \
    kubernetes-cni \
    cri-tools \
    containerd \
    containerd.io \
    docker-ce \
    docker.io \
    2>/dev/null || true

printf '\nBINARIES\n'
for binary_name in kubeadm kubelet kubectl containerd crictl etcdctl
do
    print_command_version "${binary_name}"
done

printf '\nSERVICES\n'
for service_name in kubelet containerd docker crio etcd
do
    print_service_state "${service_name}"
done

printf '\nKUBERNETES_PATHS\n'
for kubernetes_path in \
    /etc/kubernetes \
    /etc/systemd/system/kubelet.service.d \
    /var/lib/kubelet \
    /var/lib/etcd \
    /etc/containerd \
    /var/lib/containerd \
    /run/containerd \
    /etc/cni/net.d \
    /var/lib/cni \
    /opt/cni/bin \
    /var/lib/calico \
    /etc/calico \
    /var/run/calico
do
    print_directory_state "${kubernetes_path}"
done

printf '\nKUBERNETES_INTERFACES_AND_ROUTES\n'
ip -o link show 2>/dev/null |
    grep -E 'cni0|flannel|cali|tunl0|vxlan\.calico|kube-ipvs0' || true
ip -4 route show 2>/dev/null |
    grep -E '10\.233\.|blackhole|cali|cni|flannel' || true

printf '\nKUBERNETES_FIREWALL_CHAINS\n'
if command -v iptables-save >/dev/null 2>&1
then
    printf 'KUBE_OR_CALI_IPTABLES_LINES=%s\n' "$(
        iptables-save 2>/dev/null |
            grep -Ec 'KUBE-|cali-|CNI-|FLANNEL' || true
    )"
fi

if command -v nft >/dev/null 2>&1
then
    printf 'KUBE_OR_CALI_NFT_LINES=%s\n' "$(
        nft list ruleset 2>/dev/null |
            grep -Eci 'KUBE-|cali-|CNI-|FLANNEL' || true
    )"
fi

printf '\nLISTENING_KUBERNETES_PORTS\n'
ss -H -lntup 2>/dev/null |
    awk '
        $5 ~ /:(2379|2380|6443|10250|10256|10257|10259)$/ {
            print
        }
    ' || true

printf '\nCONTAINERS\n'
if command -v crictl >/dev/null 2>&1
then
    timeout 15 crictl ps -a 2>/dev/null | sed -n '1,80p' || true
elif command -v ctr >/dev/null 2>&1
then
    timeout 15 ctr -n k8s.io containers list 2>/dev/null | sed -n '1,80p' || true
fi

printf '\nEXISTING_CLUSTER_STATE\n'
if [[ -r /etc/kubernetes/admin.conf ]] && command -v kubectl >/dev/null 2>&1
then
    timeout 20 kubectl \
        --kubeconfig=/etc/kubernetes/admin.conf \
        get nodes \
        -o wide 2>&1 || true

    timeout 20 kubectl \
        --kubeconfig=/etc/kubernetes/admin.conf \
        get pods \
        --all-namespaces \
        -o wide 2>&1 |
        sed -n '1,120p' || true
else
    printf 'ADMIN_KUBECONFIG_OR_KUBECTL=ABSENT\n'
fi

printf 'REMOTE_AUDIT_RESULT=COMPLETED\n'
REMOTE_AUDIT_EOF
)"

ansible \
    -i "${AUDIT_INVENTORY}" \
    all \
    --become \
    -m ansible.builtin.shell \
    -a "${REMOTE_AUDIT_SCRIPT}" || record_error "ÑƒÐ´Ð°Ð»Ñ‘Ð½Ð½Ñ‹Ð¹ Ð°ÑƒÐ´Ð¸Ñ‚ Ð·Ð°Ð²ÐµÑ€ÑˆÐ¸Ð»Ñ�Ñ� Ñ� Ð¾ÑˆÐ¸Ð±ÐºÐ¾Ð¹"

section "Ð˜Ð¢ÐžÐ“"

printf 'END_TIME=%s\n' "$(date --iso-8601=seconds)"
printf 'LOG_FILE=%s\n' "${LOG_FILE}"

if (( AUDIT_STATUS == 0 ))
then
    printf 'AUDIT_RESULT=COMPLETED_WITHOUT_TRANSPORT_ERRORS\n'
else
    printf 'AUDIT_RESULT=COMPLETED_WITH_ERRORS\n'
fi

printf 'CHANGES_ON_REMOTE_HOSTS=NONE\n'
printf 'KUBESPRAY_CLUSTER_PLAYBOOK_STARTED=NO\n'
printf 'FILES_OR_PACKAGES_REMOVED=NONE\n'

exit "${AUDIT_STATUS}"


