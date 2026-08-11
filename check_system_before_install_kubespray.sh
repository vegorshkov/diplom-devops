#!/usr/bin/env bash

set -Eeuo pipefail

umask 077
export LANG=C.UTF-8
export LC_ALL=C.UTF-8
export ANSIBLE_FORCE_COLOR=0
export ANSIBLE_NOCOLOR=1
export PIP_DISABLE_PIP_VERSION_CHECK=1

PROJECT_DIR="/home/vgorshkov/STUDENT1/PROJECT/diplom-devops"
EXPECTED_BRANCH="main"
KUBESPRAY_DIR="${PROJECT_DIR}/ansible_kubespray/kubespray"
INVENTORY_FILE="${PROJECT_DIR}/ansible_kubespray/inventory/hosts.yaml"
GROUP_VARS_DIR="${PROJECT_DIR}/ansible_kubespray/inventory/group_vars"
LOG_DIR="${PROJECT_DIR}/ansible_kubespray/logs"
VENV_DIR="/home/vgorshkov/venv-kubespray-2.31.0"
SSH_CONFIG_FILE="/home/vgorshkov/.ssh/config"
SSH_PRIVATE_KEY="/home/vgorshkov/.ssh/netology-ext-key"

EXPECTED_KUBESPRAY_VERSION="2.31.0"
EXPECTED_ANSIBLE_PACKAGE_VERSION="11.13.0"
EXPECTED_HOST_COUNT="6"
EXPECTED_KUBE_VERSION="v1.30.4"
EXPECTED_NODE_NETWORK="172.16.0.0/16"
EXPECTED_SERVICE_NETWORK="10.233.0.0/18"
EXPECTED_POD_NETWORK="10.233.64.0/18"
EXPECTED_DNS_DOMAIN="cluster.local"

CHECK_VALIDITY_SECONDS="3600"

STATE_FILE="${LOG_DIR}/kubespray-preflight-success.env"
INVENTORY_JSON=""
VALIDATOR_FILE=""
AUDIT_PLAYBOOK=""
NETWORK_PROBE_FILE=""
NETWORK_PLAYBOOK=""
LOG_FILE=""
REMOTE_NETWORK_PROBE_STARTED="0"

EXPECTED_HOSTS=(
    k8s-master-ru-central1-a
    k8s-master-ru-central1-b
    k8s-master-ru-central1-d
    k8s-worker-ru-central1-a
    k8s-worker-ru-central1-b
    k8s-worker-ru-central1-d
)

EXPECTED_CONTROL_PLANE_HOSTS=(
    k8s-master-ru-central1-a
    k8s-master-ru-central1-b
    k8s-master-ru-central1-d
)

EXPECTED_WORKER_HOSTS=(
    k8s-worker-ru-central1-a
    k8s-worker-ru-central1-b
    k8s-worker-ru-central1-d
)

declare -A EXPECTED_HOST_IPS=(
    [k8s-master-ru-central1-a]="172.16.1.10"
    [k8s-master-ru-central1-b]="172.16.2.10"
    [k8s-master-ru-central1-d]="172.16.3.10"
    [k8s-worker-ru-central1-a]="172.16.1.21"
    [k8s-worker-ru-central1-b]="172.16.2.21"
    [k8s-worker-ru-central1-d]="172.16.3.21"
)

cleanup()
{
    local temporary_file=""

    for temporary_file in \
        "${INVENTORY_JSON}" \
        "${VALIDATOR_FILE}" \
        "${AUDIT_PLAYBOOK}" \
        "${NETWORK_PROBE_FILE}" \
        "${NETWORK_PLAYBOOK}"
    do
        if [[ -n "${temporary_file}" ]] &&
           [[ -f "${temporary_file}" ]]
        then
            rm -f -- "${temporary_file}"
        fi
    done
}

fail()
{
    rm -f -- "${STATE_FILE}" 2>/dev/null || true
    printf 'ERROR: %s\n' "$1" >&2
    printf 'KUBESPRAY_PREFLIGHT_RESULT=FAILED\n' >&2
    exit 1
}

error_handler()
{
    local exit_code="$?"

    trap - ERR
    rm -f -- "${STATE_FILE}" 2>/dev/null || true

    printf '\nKUBESPRAY_PREFLIGHT_RESULT=FAILED\n' >&2
    printf 'FAILED_COMMAND=%s\n' "${BASH_COMMAND}" >&2
    printf 'EXIT_CODE=%s\n' "${exit_code}" >&2

    exit "${exit_code}"
}

calculate_configuration_digest()
{
    {
        printf 'PROJECT_HEAD=%s\n' "$(git -C "${PROJECT_DIR}" rev-parse HEAD)"
        printf 'KUBESPRAY_VERSION=%s\n' "${EXPECTED_KUBESPRAY_VERSION}"
        sha256sum -- "${INVENTORY_FILE}"

        find "${GROUP_VARS_DIR}" \
            -type f \
            -print0 |
            sort -z |
            xargs -0 -r sha256sum --

        sha256sum -- \
            "${KUBESPRAY_DIR}/galaxy.yml" \
            "${KUBESPRAY_DIR}/requirements.txt" \
            "${SSH_CONFIG_FILE}" \
            "${SSH_PRIVATE_KEY}"
    } | sha256sum | awk '{ print $1 }'
}

trap cleanup EXIT
trap error_handler ERR

if [[ "$(id -u)" -eq 0 ]]
then
    fail "сценарий нельзя выполнять от root"
fi

for required_command in \
    awk \
    bash \
    date \
    df \
    find \
    getent \
    git \
    grep \
    id \
    mktemp \
    python3 \
    rm \
    sed \
    sha256sum \
    sort \
    ssh \
    stat \
    tee \
    timeout \
    xargs
do
    command -v "${required_command}" >/dev/null 2>&1 ||
        fail "отсутствует обязательная команда ${required_command}"
done

[[ -d "${PROJECT_DIR}" ]] ||
    fail "каталог проекта отсутствует: ${PROJECT_DIR}"

[[ -d "${LOG_DIR}" ]] || mkdir -p -- "${LOG_DIR}"
[[ -w "${LOG_DIR}" ]] ||
    fail "каталог журналов недоступен для записи: ${LOG_DIR}"

LOG_FILE="${LOG_DIR}/kubespray-preflight-$(date -u +%Y%m%dT%H%M%SZ).log"
touch -- "${LOG_FILE}"
chmod 600 -- "${LOG_FILE}"
exec > >(tee -a "${LOG_FILE}") 2>&1

printf 'KUBESPRAY_PREFLIGHT_START=%s\n' "$(date --iso-8601=seconds)"
printf 'PROJECT_DIR=%s\n' "${PROJECT_DIR}"
printf 'LOG_FILE=%s\n' "${LOG_FILE}"
printf 'PERSISTENT_REMOTE_CHANGES=NONE\n'

rm -f -- "${STATE_FILE}"

printf '\n===== 01_LOCAL_REPOSITORY_AND_KUBESPRAY =====\n'

REPOSITORY_ROOT="$(git -C "${PROJECT_DIR}" rev-parse --show-toplevel)"
[[ "${REPOSITORY_ROOT}" == "${PROJECT_DIR}" ]] ||
    fail "выбран неверный Git-репозиторий: ${REPOSITORY_ROOT}"

CURRENT_BRANCH="$(git -C "${PROJECT_DIR}" branch --show-current)"
[[ "${CURRENT_BRANCH}" == "${EXPECTED_BRANCH}" ]] ||
    fail "выбрана неверная ветка Git: ${CURRENT_BRANCH:-DETACHED_HEAD}"

[[ -d "${KUBESPRAY_DIR}" ]] && [[ ! -L "${KUBESPRAY_DIR}" ]] ||
    fail "каталог Kubespray отсутствует или является символической ссылкой"

for required_path in \
    ansible.cfg \
    cluster.yml \
    galaxy.yml \
    requirements.txt \
    playbooks/cluster.yml \
    roles/kubespray-defaults \
    roles/kubernetes/preinstall \
    roles/container-engine \
    roles/network_plugin
do
    [[ -e "${KUBESPRAY_DIR}/${required_path}" ]] ||
        fail "в Kubespray отсутствует обязательный путь: ${required_path}"
done

ACTUAL_KUBESPRAY_VERSION="$(
    awk '
        $1 == "version:" {
            print $2
            found = 1
            exit
        }
        END { if (!found) exit 1 }
    ' "${KUBESPRAY_DIR}/galaxy.yml"
)"

[[ "${ACTUAL_KUBESPRAY_VERSION}" == "${EXPECTED_KUBESPRAY_VERSION}" ]] ||
    fail "версия Kubespray ${ACTUAL_KUBESPRAY_VERSION}; ожидалась ${EXPECTED_KUBESPRAY_VERSION}"

NESTED_GIT="$(find "${KUBESPRAY_DIR}" -name .git -print -quit)"
[[ -z "${NESTED_GIT}" ]] ||
    fail "в каталоге Kubespray обнаружены вложенные Git-метаданные"

if git -C "${PROJECT_DIR}" \
    ls-files --stage -- ansible_kubespray/kubespray |
    awk '$1 == "160000" { found = 1 } END { exit(found ? 0 : 1) }'
then
    fail "Kubespray по-прежнему зарегистрирован как submodule"
fi

KUBESPRAY_GIT_STATUS="$(
    git -C "${PROJECT_DIR}" status \
        --porcelain=v1 \
        --untracked-files=all \
        -- ansible_kubespray/kubespray
)"
[[ -z "${KUBESPRAY_GIT_STATUS}" ]] || {
    printf '%s\n' "${KUBESPRAY_GIT_STATUS}"
    fail "каталог Kubespray содержит незакоммиченные изменения"
}

REQUIRED_REQUIREMENTS=(
    "ansible==11.13.0"
    "cryptography==46.0.7"
    "jmespath==1.1.0"
    "netaddr==1.3.0"
)

for requirement in "${REQUIRED_REQUIREMENTS[@]}"
do
    grep -Fqx -- "${requirement}" "${KUBESPRAY_DIR}/requirements.txt" ||
        fail "requirements.txt не содержит ${requirement}"
done

printf 'REPOSITORY_ROOT=%s\n' "${REPOSITORY_ROOT}"
printf 'BRANCH=%s\n' "${CURRENT_BRANCH}"
printf 'KUBESPRAY_VERSION=%s\n' "${ACTUAL_KUBESPRAY_VERSION}"
printf 'KUBESPRAY_SOURCE_STATE=CLEAN\n'

printf '\n===== 02_CONTROLLER_ENVIRONMENT =====\n'

CONTROLLER_ROOT_FREE_KB="$(df -Pk "${PROJECT_DIR}" | awk 'NR == 2 { print $4 }')"
CONTROLLER_ROOT_FREE_INODES="$(df -Pi "${PROJECT_DIR}" | awk 'NR == 2 { print $4 }')"
(( CONTROLLER_ROOT_FREE_KB >= 2097152 )) ||
    fail "на управляющем компьютере доступно менее 2 GiB"
(( CONTROLLER_ROOT_FREE_INODES >= 50000 )) ||
    fail "на управляющем компьютере доступно менее 50000 inode"

for controller_dns_name in \
    github.com \
    dl.k8s.io \
    registry.k8s.io \
    mirror.yandex.ru
do
    getent ahostsv4 "${controller_dns_name}" >/dev/null 2>&1 ||
        fail "управляющий компьютер не разрешает DNS-имя ${controller_dns_name}"
done

printf 'CONTROLLER_ROOT_FREE_KB=%s\n' "${CONTROLLER_ROOT_FREE_KB}"
printf 'CONTROLLER_ROOT_FREE_INODES=%s\n' "${CONTROLLER_ROOT_FREE_INODES}"
printf 'CONTROLLER_DNS_RESULT=SUCCESS\n'

VENV_PYTHON="${VENV_DIR}/bin/python"
VENV_ANSIBLE="${VENV_DIR}/bin/ansible"
VENV_ANSIBLE_PLAYBOOK="${VENV_DIR}/bin/ansible-playbook"
VENV_ANSIBLE_INVENTORY="${VENV_DIR}/bin/ansible-inventory"
VENV_ANSIBLE_GALAXY="${VENV_DIR}/bin/ansible-galaxy"

for executable in \
    "${VENV_PYTHON}" \
    "${VENV_ANSIBLE}" \
    "${VENV_ANSIBLE_PLAYBOOK}" \
    "${VENV_ANSIBLE_INVENTORY}" \
    "${VENV_ANSIBLE_GALAXY}"
do
    [[ -x "${executable}" ]] ||
        fail "виртуальное окружение неполно: отсутствует ${executable}"
done

"${VENV_PYTHON}" - <<'PYTHON_PACKAGE_CHECK_EOF'
from importlib.metadata import version

expected = {
    "ansible": "11.13.0",
    "cryptography": "46.0.7",
    "jmespath": "1.1.0",
    "netaddr": "1.3.0",
}

for package, expected_version in expected.items():
    actual = version(package)
    if actual != expected_version:
        raise SystemExit(
            f"ERROR: package {package} has version {actual}; "
            f"expected {expected_version}"
        )
    print(f"PYTHON_PACKAGE_{package.upper()}={actual}")

core = tuple(int(part) for part in version("ansible-core").split(".")[:3])
if not ((2, 18, 12) <= core < (2, 19, 0)):
    raise SystemExit(f"ERROR: unsupported ansible-core version {version('ansible-core')}")
print(f"ANSIBLE_CORE_VERSION={version('ansible-core')}")
PYTHON_PACKAGE_CHECK_EOF

"${VENV_PYTHON}" -m pip check

export ANSIBLE_CONFIG="${KUBESPRAY_DIR}/ansible.cfg"
export ANSIBLE_LOCAL_TEMP="/tmp/ansible-kubespray-preflight-local-${UID}"
export ANSIBLE_REMOTE_TEMP="/tmp/ansible-kubespray-preflight-${UID}"

"${VENV_ANSIBLE}" --version

COLLECTION_LIST="$(${VENV_ANSIBLE_GALAXY} collection list)"
for collection in \
    ansible.utils \
    community.crypto \
    community.general \
    ansible.netcommon \
    ansible.posix \
    community.docker \
    kubernetes.core
do
    grep -Eq "^[[:space:]]*${collection//./\.}[[:space:]]" <<< "${COLLECTION_LIST}" ||
        fail "отсутствует обязательная Ansible collection ${collection}"
done

printf 'CONTROLLER_ENVIRONMENT_RESULT=SUCCESS\n'

printf '\n===== 03_INVENTORY_AND_PROJECT_VARIABLES =====\n'

[[ -f "${INVENTORY_FILE}" ]] && [[ ! -L "${INVENTORY_FILE}" ]] ||
    fail "inventory отсутствует или является символической ссылкой"
[[ -d "${GROUP_VARS_DIR}" ]] && [[ ! -L "${GROUP_VARS_DIR}" ]] ||
    fail "каталог group_vars отсутствует или является символической ссылкой"
[[ -r "${SSH_CONFIG_FILE}" ]] ||
    fail "SSH config недоступен: ${SSH_CONFIG_FILE}"
[[ -r "${SSH_PRIVATE_KEY}" ]] ||
    fail "закрытый SSH-ключ недоступен: ${SSH_PRIVATE_KEY}"

PRIVATE_KEY_MODE="$(stat -c '%a' "${SSH_PRIVATE_KEY}")"
case "${PRIVATE_KEY_MODE}" in
    400|600)
        ;;
    *)
        fail "закрытый SSH-ключ имеет небезопасный режим ${PRIVATE_KEY_MODE}"
        ;;
esac

if find "${GROUP_VARS_DIR}" -type l -print -quit | grep -q .
then
    fail "в group_vars обнаружена символическая ссылка"
fi

INVENTORY_JSON="$(mktemp /tmp/kubespray-inventory.XXXXXX.json)"
VALIDATOR_FILE="$(mktemp /tmp/kubespray-inventory-validator.XXXXXX.py)"

"${VENV_ANSIBLE_INVENTORY}" \
    -i "${INVENTORY_FILE}" \
    --list > "${INVENTORY_JSON}"

cat > "${VALIDATOR_FILE}" <<'PYTHON_INVENTORY_VALIDATOR_EOF'
#!/usr/bin/env python3

import ipaddress
import json
import sys

inventory_path = sys.argv[1]

with open(inventory_path, "r", encoding="utf-8") as source:
    data = json.load(source)

expected_hosts = {
    "k8s-master-ru-central1-a",
    "k8s-master-ru-central1-b",
    "k8s-master-ru-central1-d",
    "k8s-worker-ru-central1-a",
    "k8s-worker-ru-central1-b",
    "k8s-worker-ru-central1-d",
}
expected_control = {
    "k8s-master-ru-central1-a",
    "k8s-master-ru-central1-b",
    "k8s-master-ru-central1-d",
}
expected_workers = expected_hosts - expected_control

hostvars = data.get("_meta", {}).get("hostvars", {})

def group_hosts(group):
    return set(data.get(group, {}).get("hosts", []))

checks = {
    "all": set(hostvars),
    "kube_control_plane": group_hosts("kube_control_plane"),
    "etcd": group_hosts("etcd"),
    "kube_node": group_hosts("kube_node"),
}

if checks["all"] != expected_hosts:
    raise SystemExit(f"ERROR: invalid all hosts: {sorted(checks['all'])}")
if checks["kube_control_plane"] != expected_control:
    raise SystemExit("ERROR: invalid kube_control_plane group")
if checks["etcd"] != expected_control:
    raise SystemExit("ERROR: invalid etcd group")
if checks["kube_node"] != expected_workers:
    raise SystemExit("ERROR: invalid kube_node group")
if len(checks["etcd"]) % 2 != 1:
    raise SystemExit("ERROR: etcd member count must be odd")

for host in sorted(expected_hosts):
    values = hostvars[host]
    if values.get("ansible_user") != "ubuntu":
        raise SystemExit(f"ERROR: {host}: ansible_user must be ubuntu")
    if values.get("ansible_ssh_private_key_file") != "/home/vgorshkov/.ssh/netology-ext-key":
        raise SystemExit(f"ERROR: {host}: invalid SSH key path")
    if "-F /home/vgorshkov/.ssh/config" not in values.get("ansible_ssh_common_args", ""):
        raise SystemExit(f"ERROR: {host}: SSH config is not enabled")
    if values.get("ansible_become") not in (True, "yes", "true"):
        raise SystemExit(f"ERROR: {host}: ansible_become is not enabled")

reference = hostvars[sorted(expected_hosts)[0]]
expected_values = {
    "kube_version": "v1.30.4",
    "kube_network_plugin": "calico",
    "container_manager": "containerd",
    "kube_service_addresses": "10.233.0.0/18",
    "kube_pods_subnet": "10.233.64.0/18",
    "kube_network_node_prefix": 24,
}

for key, expected in expected_values.items():
    actual = reference.get(key)
    if str(actual) != str(expected):
        raise SystemExit(
            f"ERROR: {key}={actual!r}; expected {expected!r}. "
            "Check inventory/group_vars."
        )

cluster_name = reference.get("cluster_name", "cluster.local")
dns_domain = reference.get("dns_domain", cluster_name)
if dns_domain == "{{ cluster_name }}":
    dns_domain = cluster_name
if dns_domain != "cluster.local":
    raise SystemExit(
        f"ERROR: dns_domain={dns_domain!r}; expected 'cluster.local'"
    )

service_network = ipaddress.ip_network(reference["kube_service_addresses"])
pod_network = ipaddress.ip_network(reference["kube_pods_subnet"])
node_network = ipaddress.ip_network("172.16.0.0/16")

networks = [service_network, pod_network, node_network]
for index, first in enumerate(networks):
    for second in networks[index + 1:]:
        if first.overlaps(second):
            raise SystemExit(f"ERROR: network overlap: {first} and {second}")

if int(reference["kube_network_node_prefix"]) <= pod_network.prefixlen:
    raise SystemExit("ERROR: kube_network_node_prefix is invalid")

proxy_keys = ("http_proxy", "https_proxy", "HTTP_PROXY", "HTTPS_PROXY")
proxy_enabled = any(reference.get(key) for key in proxy_keys)
if proxy_enabled:
    no_proxy = str(reference.get("no_proxy") or reference.get("NO_PROXY") or "")
    required_no_proxy = (
        "127.0.0.1",
        "localhost",
        "172.16.",
        "10.233.",
        ".cluster.local",
    )
    missing = [value for value in required_no_proxy if value not in no_proxy]
    if missing:
        raise SystemExit(f"ERROR: no_proxy is incomplete: missing {missing}")

def normalized_bool(value):
    if isinstance(value, bool):
        return value
    return str(value).strip().lower() in {"1", "yes", "true", "on"}

resolved_defaults = {
    "kube_proxy_mode": reference.get("kube_proxy_mode", "ipvs"),
    "dns_mode": reference.get("dns_mode", "coredns"),
    "enable_nodelocaldns": normalized_bool(reference.get("enable_nodelocaldns", True)),
    "calico_network_backend": reference.get("calico_network_backend", "vxlan"),
    "calico_ipip_mode": reference.get("calico_ipip_mode", "Never"),
    "calico_vxlan_mode": reference.get("calico_vxlan_mode", "Always"),
    "containerd_use_systemd_cgroup": normalized_bool(
        reference.get("containerd_use_systemd_cgroup", True)
    ),
}

expected_resolved_defaults = {
    "kube_proxy_mode": "ipvs",
    "dns_mode": "coredns",
    "enable_nodelocaldns": True,
    "calico_network_backend": "vxlan",
    "calico_ipip_mode": "Never",
    "calico_vxlan_mode": "Always",
    "containerd_use_systemd_cgroup": True,
}

for key, expected in expected_resolved_defaults.items():
    actual = resolved_defaults[key]
    if str(actual).lower() != str(expected).lower():
        raise SystemExit(f"ERROR: effective {key}={actual!r}; expected {expected!r}")

for host in sorted(expected_control):
    etcd_type = hostvars[host].get("etcd_deployment_type", "host")
    if etcd_type != "host":
        raise SystemExit(
            f"ERROR: {host}: etcd_deployment_type={etcd_type!r}; expected 'host'"
        )

print(f"INVENTORY_HOST_COUNT={len(expected_hosts)}")
print("CONTROL_PLANE_HOSTS=" + ",".join(sorted(expected_control)))
print("ETCD_HOSTS=" + ",".join(sorted(expected_control)))
print("WORKER_HOSTS=" + ",".join(sorted(expected_workers)))
for key in expected_values:
    print(f"{key.upper()}={reference[key]}")
print(f"DNS_DOMAIN={dns_domain}")
for key, value in resolved_defaults.items():
    print(f"{key.upper()}={value}")
print("ETCD_DEPLOYMENT_TYPE=host")
print(f"PROXY_CONFIGURATION={'ENABLED' if proxy_enabled else 'NOT_DEFINED_IN_INVENTORY'}")
print("INVENTORY_AND_VARIABLES_RESULT=SUCCESS")
PYTHON_INVENTORY_VALIDATOR_EOF

chmod 700 -- "${VALIDATOR_FILE}"
"${VENV_PYTHON}" "${VALIDATOR_FILE}" "${INVENTORY_JSON}"

"${VENV_ANSIBLE_INVENTORY}" -i "${INVENTORY_FILE}" --graph

printf '\n===== 04_SSH_CONFIGURATION_AND_ACCESS =====\n'

for host in "${EXPECTED_HOSTS[@]}"
do
    SSH_EFFECTIVE_CONFIG="$(ssh -G -F "${SSH_CONFIG_FILE}" "${host}" 2>/dev/null)"
    SSH_HOSTNAME="$(awk '$1 == "hostname" { print $2; exit }' <<< "${SSH_EFFECTIVE_CONFIG}")"
    SSH_USER="$(awk '$1 == "user" { print $2; exit }' <<< "${SSH_EFFECTIVE_CONFIG}")"
    SSH_PROXYJUMP="$(awk '$1 == "proxyjump" { print $2; exit }' <<< "${SSH_EFFECTIVE_CONFIG}")"

    [[ "${SSH_HOSTNAME}" == "${EXPECTED_HOST_IPS[${host}]}" ]] ||
        fail "${host}: SSH HostName=${SSH_HOSTNAME}; ожидался ${EXPECTED_HOST_IPS[${host}]}"
    [[ "${SSH_USER}" == "ubuntu" ]] ||
        fail "${host}: SSH user=${SSH_USER}; ожидался ubuntu"
    [[ "${SSH_PROXYJUMP}" == "yc-nat-instance" ]] ||
        fail "${host}: ProxyJump=${SSH_PROXYJUMP:-NOT_SET}; ожидался yc-nat-instance"

    timeout 20 ssh \
        -F "${SSH_CONFIG_FILE}" \
        -o BatchMode=yes \
        -o ConnectTimeout=15 \
        -o ConnectionAttempts=1 \
        "${host}" \
        'test "$(id -u)" -ne 0 && sudo -n true' ||
        fail "${host}: SSH или sudo недоступны"

    printf 'SSH_ACCESS=SUCCESS host=%s ip=%s proxyjump=%s\n' \
        "${host}" "${SSH_HOSTNAME}" "${SSH_PROXYJUMP}"
done

printf 'SSH_CONFIGURATION_AND_ACCESS_RESULT=SUCCESS\n'

printf '\n===== 05_ANSIBLE_SYNTAX_AND_TARGETS =====\n'

"${VENV_ANSIBLE_PLAYBOOK}" \
    -i "${INVENTORY_FILE}" \
    "${KUBESPRAY_DIR}/cluster.yml" \
    --syntax-check

"${VENV_ANSIBLE_PLAYBOOK}" \
    -i "${INVENTORY_FILE}" \
    "${KUBESPRAY_DIR}/cluster.yml" \
    --list-hosts

printf 'KUBESPRAY_PLAYBOOK_STATIC_VALIDATION_RESULT=SUCCESS\n'

printf '\n===== 06_REMOTE_READ_ONLY_AUDIT =====\n'

AUDIT_PLAYBOOK="$(mktemp /tmp/kubespray-preflight-audit.XXXXXX.yml)"

cat > "${AUDIT_PLAYBOOK}" <<'ANSIBLE_AUDIT_PLAYBOOK_EOF'
---
- name: Perform complete read-only audit of Kubernetes target hosts
  hosts: all
  gather_facts: true
  become: true
  any_errors_fatal: true

  vars:
    expected_addresses:
      k8s-master-ru-central1-a: 172.16.1.10
      k8s-master-ru-central1-b: 172.16.2.10
      k8s-master-ru-central1-d: 172.16.3.10
      k8s-worker-ru-central1-a: 172.16.1.21
      k8s-worker-ru-central1-b: 172.16.2.21
      k8s-worker-ru-central1-d: 172.16.3.21

  tasks:
    - name: Verify the approved operating-system and hardware baseline
      ansible.builtin.assert:
        that:
          - ansible_distribution == 'Ubuntu'
          - ansible_distribution_release == 'jammy'
          - ansible_distribution_version is version('22.04', '>=')
          - ansible_architecture in ['x86_64', 'amd64']
          - ansible_hostname == inventory_hostname
          - ansible_default_ipv4.address == expected_addresses[inventory_hostname]
          - ansible_processor_vcpus | int >= 2
          - ansible_memtotal_mb | int >= (2000 if inventory_hostname in groups['kube_control_plane'] else 1000)
          - ansible_default_ipv4.mtu | int >= 1280
        fail_msg: >-
          Host platform, hostname, address, CPU, RAM or MTU differs from the
          approved topology.
        success_msg: HOST_PLATFORM_AND_RESOURCES=SUCCESS

    - name: Run comprehensive host audit without persistent changes
      ansible.builtin.shell: |
        set -Eeuo pipefail
        export LANG=C.UTF-8
        export LC_ALL=C.UTF-8

        errors=()
        warnings=()

        add_error()
        {
            errors+=("$1")
        }

        add_warning()
        {
            warnings+=("$1")
        }

        root_free_kb="$(df -Pk / | awk 'NR == 2 { print $4 }')"
        root_free_inodes="$(df -Pi / | awk 'NR == 2 { print $4 }')"
        root_inode_use="$(df -Pi / | awk 'NR == 2 { gsub(/%/, "", $5); print $5 }')"

        (( root_free_kb >= 10485760 )) || add_error "ROOT_FREE_SPACE_LT_10_GIB"
        (( root_free_inodes >= 100000 )) || add_error "ROOT_FREE_INODES_LT_100000"
        (( root_inode_use < 90 )) || add_error "ROOT_INODE_USAGE_GE_90_PERCENT"

        active_swap="$(swapon --noheadings --show=NAME 2>/dev/null || true)"
        [[ -z "${active_swap}" ]] || add_error "SWAP_ACTIVE"

        ipv4_forward="$(sysctl -n net.ipv4.ip_forward 2>/dev/null || true)"
        [[ "${ipv4_forward}" == "1" ]] || add_error "IPV4_FORWARDING_DISABLED"

        ntp_state="$(timedatectl show --property=NTPSynchronized --value 2>/dev/null || true)"
        [[ "${ntp_state}" == "yes" ]] || add_error "TIME_NOT_SYNCHRONIZED"

        if command -v cloud-init >/dev/null 2>&1
        then
            cloud_init_state="$(cloud-init status 2>/dev/null | awk '{ print $2; exit }')"
            [[ "${cloud_init_state}" == "done" ]] || add_error "CLOUD_INIT_NOT_DONE"
        else
            cloud_init_state="NOT_INSTALLED"
        fi

        [[ ! -e /var/run/reboot-required ]] || add_error "REBOOT_REQUIRED"

        dpkg_audit="$(dpkg --audit 2>&1 || true)"
        [[ -z "${dpkg_audit}" ]] || add_error "DPKG_AUDIT_NOT_CLEAN"

        if command -v ufw >/dev/null 2>&1
        then
            ufw_state="$(ufw status 2>/dev/null | head -n 1 || true)"
            grep -Fqi 'inactive' <<< "${ufw_state}" || add_error "UFW_ACTIVE"
        else
            ufw_state="NOT_INSTALLED"
        fi

        if systemctl list-unit-files firewalld.service >/dev/null 2>&1
        then
            firewalld_state="$(systemctl is-active firewalld 2>/dev/null || true)"
            [[ "${firewalld_state}" != "active" ]] || add_error "FIREWALLD_ACTIVE"
        else
            firewalld_state="NOT_INSTALLED"
        fi

        if command -v iptables-save >/dev/null 2>&1
        then
            filter_policies="$(iptables-save -t filter 2>/dev/null | awk '$1 ~ /^:/ { print $1, $2 }')"
            grep -Eq '^:INPUT DROP$|^:FORWARD DROP$' <<< "${filter_policies}" &&
                add_error "IPTABLES_DEFAULT_DROP_POLICY" || true

            if iptables-save 2>/dev/null | grep -Eq '(^|[[:space:]])(KUBE-|cali-|CNI-|FLANNEL)'
            then
                add_error "KUBERNETES_OR_CNI_IPTABLES_RESIDUE"
            fi
        fi

        for module in overlay br_netfilter nf_conntrack ip_vs ip_vs_rr ip_vs_wrr ip_vs_sh
        do
            modinfo "${module}" >/dev/null 2>&1 || add_error "KERNEL_MODULE_UNAVAILABLE_${module}"
        done

        for service in kubelet etcd
        do
            if systemctl is-active --quiet "${service}" 2>/dev/null ||
               systemctl is-enabled --quiet "${service}" 2>/dev/null
            then
                add_error "STALE_SERVICE_${service}"
            fi
        done

        for package_name in kubeadm kubelet kubectl kubernetes-cni
        do
            package_state="$(dpkg-query -W -f='${db:Status-Abbrev}' "${package_name}" 2>/dev/null || true)"
            [[ "${package_state}" != "ii " ]] || add_error "STALE_PACKAGE_${package_name}"
        done

        for binary in kubeadm kubelet kubectl
        do
            command -v "${binary}" >/dev/null 2>&1 && add_error "STALE_BINARY_${binary}" || true
        done

        for directory in \
            /etc/kubernetes \
            /var/lib/kubelet \
            /var/lib/etcd \
            /etc/cni/net.d \
            /var/lib/cni \
            /opt/cni/bin
        do
            if [[ -d "${directory}" ]] &&
               find "${directory}" -mindepth 1 -print -quit 2>/dev/null | grep -q .
            then
                add_error "STALE_DIRECTORY_${directory//\//_}"
            fi
        done

        if ip -o link show 2>/dev/null |
            grep -Eq '^[0-9]+: (cni0|flannel\.|cali|tunl0|vxlan\.calico|kube-ipvs0)'
        then
            add_error "STALE_KUBERNETES_NETWORK_INTERFACE"
        fi

        if ip -4 route show 2>/dev/null |
            grep -Eq '(^|[[:space:]])10\.233\.(0|[1-9]|[1-9][0-9]|1[01][0-9]|12[0-7])\.'
        then
            add_error "STALE_KUBERNETES_ROUTE"
        fi

        role_ports=(10250)
        if [[ "{{ inventory_hostname }}" == k8s-master-* ]]
        then
            role_ports+=(2379 2380 6443 10257 10259)
        else
            role_ports+=(10256)
        fi

        listening_sockets="$(ss -H -lntup 2>/dev/null || true)"
        for port in "${role_ports[@]}"
        do
            if awk -v port=":${port}" '$5 ~ port "$" { found=1 } END { exit(found ? 0 : 1) }' \
                <<< "${listening_sockets}"
            then
                add_error "REQUIRED_PORT_ALREADY_IN_USE_${port}"
            fi
        done

        default_route_count="$(ip -4 route show default | awk 'END { print NR + 0 }')"
        (( default_route_count >= 1 )) || add_error "DEFAULT_ROUTE_MISSING"

        route_overlap="$({
            ip -4 route show |
                awk '$1 != "default" && $1 ~ /^[0-9]+\./ { print $1 }' |
                python3 -c '
        import ipaddress
        import sys

        service = ipaddress.ip_network("10.233.0.0/18")
        pods = ipaddress.ip_network("10.233.64.0/18")

        for text in sys.stdin:
            text = text.strip()
            if not text:
                continue
            try:
                route = ipaddress.ip_network(text, strict=False)
            except ValueError:
                continue
            if route.overlaps(service) or route.overlaps(pods):
                print(route)
        ' || true
        })"
        [[ -z "${route_overlap}" ]] || add_error "POD_OR_SERVICE_NETWORK_ROUTE_OVERLAP"

        for peer_ip in \
            172.16.1.10 172.16.2.10 172.16.3.10 \
            172.16.1.21 172.16.2.21 172.16.3.21
        do
            timeout 5 bash -c "exec 3<>/dev/tcp/${peer_ip}/22" 2>/dev/null ||
                add_error "PEER_SSH_UNREACHABLE_${peer_ip}"
        done

        for dns_name in \
            mirror.yandex.ru \
            dl.k8s.io \
            registry.k8s.io \
            quay.io \
            registry-1.docker.io \
            github.com \
            ghcr.io
        do
            getent ahostsv4 "${dns_name}" >/dev/null 2>&1 ||
                add_error "DNS_RESOLUTION_FAILED_${dns_name}"
        done

        apt_temp="$(mktemp -d /tmp/kubespray-apt-preflight.XXXXXX)"
        cleanup_apt_temp()
        {
            rm -rf -- "${apt_temp}"
        }
        trap cleanup_apt_temp EXIT

        mkdir -p -- \
            "${apt_temp}/lists/partial" \
            "${apt_temp}/cache/archives/partial"
        chmod 755 -- "${apt_temp}" "${apt_temp}/lists" "${apt_temp}/lists/partial"

        apt_options=(
            -o "Dir::State::lists=${apt_temp}/lists"
            -o "Dir::Cache=${apt_temp}/cache"
            -o Acquire::Retries=2
            -o Acquire::http::Timeout=30
            -o Acquire::https::Timeout=30
            -o APT::Get::List-Cleanup=0
        )

        if ! apt-get "${apt_options[@]}" update >/tmp/kubespray-apt-preflight-output.$$ 2>&1
        then
            sed -E \
                -e 's#(https?://)[^/@[:space:]]+:[^/@[:space:]]+@#\1***:***@#g' \
                -e 's#([Aa]uthorization:).*#\1 ***#g' \
                /tmp/kubespray-apt-preflight-output.$$ >&2 || true
            rm -f -- /tmp/kubespray-apt-preflight-output.$$
            add_error "APT_SIGNED_METADATA_CHECK_FAILED"
        else
            rm -f -- /tmp/kubespray-apt-preflight-output.$$
        fi

        required_packages=(
            ca-certificates conntrack curl ebtables ethtool iproute2 ipset
            iptables ipvsadm kmod libseccomp2 openssl python3 python3-apt
            rsync socat sudo tar util-linux
        )

        if ! apt-get "${apt_options[@]}" --simulate install "${required_packages[@]}" \
            >/dev/null 2>&1
        then
            add_error "APT_PACKAGE_RESOLUTION_FAILED"
        fi

        check_http()
        {
            local name="$1"
            local url="$2"
            local accepted="$3"
            local code=""

            code="$(
                curl \
                    --location \
                    --silent \
                    --show-error \
                    --output /dev/null \
                    --connect-timeout 15 \
                    --max-time 45 \
                    --write-out '%{http_code}' \
                    "${url}" || true
            )"

            grep -Eq "^(${accepted})$" <<< "${code}" ||
                add_error "HTTPS_ENDPOINT_FAILED_${name}_${code:-NO_CODE}"
        }

        check_http "APT_INRELEASE" \
            "https://mirror.yandex.ru/ubuntu/dists/jammy/InRelease" "200"
        check_http "KUBEADM_BINARY" \
            "https://dl.k8s.io/release/{{ kube_version }}/bin/linux/amd64/kubeadm" "200"
        check_http "KUBERNETES_REGISTRY" \
            "https://registry.k8s.io/v2/" "200|401|404"
        check_http "QUAY_REGISTRY" \
            "https://quay.io/v2/" "200|401"
        check_http "DOCKER_REGISTRY" \
            "https://registry-1.docker.io/v2/" "200|401"
        check_http "GHCR_REGISTRY" \
            "https://ghcr.io/v2/" "200|401"
        check_http "GITHUB" "https://github.com/" "200"

        proxy_environment="NOT_SET"
        if env | awk -F= 'tolower($1) ~ /^(http|https|all|no)_proxy$/ { found=1 } END { exit(found ? 0 : 1) }'
        then
            proxy_environment="PRESENT"
        fi

        containerd_state="$(systemctl is-active containerd 2>/dev/null || true)"
        containerd_package="$(dpkg-query -W -f='${db:Status-Abbrev}' containerd.io 2>/dev/null || true)"

        printf 'HOST=%s\n' "{{ inventory_hostname }}"
        printf 'PRIMARY_IPV4=%s\n' "{{ ansible_default_ipv4.address }}"
        printf 'PRIMARY_INTERFACE=%s\n' "{{ ansible_default_ipv4.interface }}"
        printf 'PRIMARY_MTU=%s\n' "{{ ansible_default_ipv4.mtu }}"
        printf 'CPU_VCPU=%s\n' "{{ ansible_processor_vcpus }}"
        printf 'MEMORY_MB=%s\n' "{{ ansible_memtotal_mb }}"
        printf 'ROOT_FREE_KB=%s\n' "${root_free_kb}"
        printf 'ROOT_FREE_INODES=%s\n' "${root_free_inodes}"
        printf 'IPV4_FORWARDING=%s\n' "${ipv4_forward}"
        printf 'SWAP=%s\n' "$([[ -z "${active_swap}" ]] && printf DISABLED || printf ACTIVE)"
        printf 'NTP_SYNCHRONIZED=%s\n' "${ntp_state}"
        printf 'CLOUD_INIT=%s\n' "${cloud_init_state}"
        printf 'UFW=%s\n' "${ufw_state}"
        printf 'FIREWALLD=%s\n' "${firewalld_state}"
        printf 'PROXY_ENVIRONMENT=%s\n' "${proxy_environment}"
        printf 'CONTAINERD_SERVICE=%s\n' "${containerd_state:-NOT_INSTALLED}"
        printf 'CONTAINERD_PACKAGE=%s\n' "${containerd_package:-NOT_INSTALLED}"

        if (( ${#warnings[@]} > 0 ))
        then
            printf 'WARNINGS=%s\n' "${warnings[*]}"
        else
            printf 'WARNINGS=NONE\n'
        fi

        if (( ${#errors[@]} > 0 ))
        then
            printf 'HOST_AUDIT_ERRORS=%s\n' "${errors[*]}" >&2
            exit 50
        fi

        printf 'HOST_AUDIT_RESULT=SUCCESS\n'
      args:
        executable: /bin/bash
      register: host_audit
      changed_when: false

    - name: Display host audit report
      ansible.builtin.debug:
        var: host_audit.stdout_lines

- name: Verify uniqueness of node identifiers
  hosts: localhost
  gather_facts: false
  become: false

  tasks:
    - name: Assert unique addresses, machine identifiers, UUIDs and MAC addresses
      ansible.builtin.assert:
        that:
          - groups['all'] | length == 6
          - groups['all'] | map('extract', hostvars, ['ansible_default_ipv4', 'address']) | list | unique | length == 6
          - groups['all'] | map('extract', hostvars, 'ansible_machine_id') | list | unique | length == 6
          - groups['all'] | map('extract', hostvars, 'ansible_product_uuid') | list | unique | length == 6
          - groups['all'] | map('extract', hostvars, ['ansible_default_ipv4', 'macaddress']) | list | unique | length == 6
        fail_msg: Duplicate node identity detected.
        success_msg: NODE_IDENTITY_UNIQUENESS=SUCCESS
ANSIBLE_AUDIT_PLAYBOOK_EOF

"${VENV_ANSIBLE_PLAYBOOK}" \
    -i "${INVENTORY_FILE}" \
    "${AUDIT_PLAYBOOK}" \
    --syntax-check

"${VENV_ANSIBLE_PLAYBOOK}" \
    -i "${INVENTORY_FILE}" \
    "${AUDIT_PLAYBOOK}"

printf 'REMOTE_READ_ONLY_AUDIT_RESULT=SUCCESS\n'

printf '\n===== 07_INTER_NODE_SECURITY_GROUP_AND_PORT_AUDIT =====\n'

NETWORK_PROBE_FILE="$(mktemp /tmp/kubespray-network-probe.XXXXXX.py)"
NETWORK_PLAYBOOK="$(mktemp /tmp/kubespray-network-playbook.XXXXXX.yml)"
RUN_TOKEN="kubespray-preflight-$(date -u +%Y%m%dT%H%M%SZ)-$$"
REMOTE_PROBE_PATH="/tmp/${RUN_TOKEN}.py"
REMOTE_PID_PATH="/tmp/${RUN_TOKEN}.pid"
REMOTE_LOG_PATH="/tmp/${RUN_TOKEN}.log"

cat > "${NETWORK_PROBE_FILE}" <<'PYTHON_NETWORK_PROBE_EOF'
#!/usr/bin/env python3

import argparse
import concurrent.futures
import selectors
import socket
import sys
import time

HOST_IPS = {
    "k8s-master-ru-central1-a": "172.16.1.10",
    "k8s-master-ru-central1-b": "172.16.2.10",
    "k8s-master-ru-central1-d": "172.16.3.10",
    "k8s-worker-ru-central1-a": "172.16.1.21",
    "k8s-worker-ru-central1-b": "172.16.2.21",
    "k8s-worker-ru-central1-d": "172.16.3.21",
}
CONTROL_HOSTS = {
    "k8s-master-ru-central1-a",
    "k8s-master-ru-central1-b",
    "k8s-master-ru-central1-d",
}

def short_hostname():
    return socket.gethostname().split(".", 1)[0]

def server(token, duration):
    hostname = short_hostname()
    if hostname not in HOST_IPS:
        raise RuntimeError(f"unknown host {hostname}")

    tcp_ports = [10250]
    if hostname in CONTROL_HOSTS:
        tcp_ports.extend([2379, 2380, 6443, 10257, 10259])
    else:
        tcp_ports.append(10256)

    selector = selectors.DefaultSelector()
    sockets = []

    for port in tcp_ports:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        sock.bind(("0.0.0.0", port))
        sock.listen(128)
        sock.setblocking(False)
        selector.register(sock, selectors.EVENT_READ, ("tcp", port))
        sockets.append(sock)

    udp = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    udp.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    udp.bind(("0.0.0.0", 4789))
    udp.setblocking(False)
    selector.register(udp, selectors.EVENT_READ, ("udp", 4789))
    sockets.append(udp)

    print(f"SERVER_READY host={hostname} tcp={tcp_ports} udp=[4789]", flush=True)
    deadline = time.monotonic() + duration
    expected = token.encode("utf-8")

    try:
        while time.monotonic() < deadline:
            for key, _ in selector.select(timeout=0.5):
                kind, _port = key.data
                sock = key.fileobj
                if kind == "tcp":
                    conn, _address = sock.accept()
                    with conn:
                        conn.settimeout(2)
                        data = conn.recv(4096)
                        conn.sendall(b"OK" if data == expected else b"BAD")
                else:
                    data, address = sock.recvfrom(4096)
                    sock.sendto(b"OK" if data == expected else b"BAD", address)
    finally:
        for sock in sockets:
            try:
                selector.unregister(sock)
            except Exception:
                pass
            sock.close()

def tcp_check(source, target, port, token):
    with socket.create_connection((target, port), timeout=4) as sock:
        sock.settimeout(4)
        sock.sendall(token.encode("utf-8"))
        reply = sock.recv(16)
        if reply != b"OK":
            raise RuntimeError(f"invalid TCP reply {reply!r}")
    return f"TCP_OK source={source} target={target} port={port}"

def udp_check(source, target, token):
    last_error = None
    for _attempt in range(3):
        try:
            with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
                sock.settimeout(3)
                sock.sendto(token.encode("utf-8"), (target, 4789))
                reply, _address = sock.recvfrom(16)
                if reply != b"OK":
                    raise RuntimeError(f"invalid UDP reply {reply!r}")
                return f"UDP_OK source={source} target={target} port=4789"
        except Exception as exc:
            last_error = exc
            time.sleep(0.5)
    raise RuntimeError(str(last_error))

def client(token):
    source = short_hostname()
    if source not in HOST_IPS:
        raise RuntimeError(f"unknown host {source}")

    tests = []

    for control_host in sorted(CONTROL_HOSTS):
        tests.append(("tcp", HOST_IPS[control_host], 6443))

    if source in CONTROL_HOSTS:
        for control_host in sorted(CONTROL_HOSTS):
            tests.append(("tcp", HOST_IPS[control_host], 2379))
            tests.append(("tcp", HOST_IPS[control_host], 2380))
        for target in HOST_IPS.values():
            tests.append(("tcp", target, 10250))

    for target in HOST_IPS.values():
        tests.append(("udp", target, 4789))

    failures = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=32) as pool:
        futures = {}
        for kind, target, port in tests:
            if kind == "tcp":
                future = pool.submit(tcp_check, source, target, port, token)
            else:
                future = pool.submit(udp_check, source, target, token)
            futures[future] = (kind, target, port)

        for future in concurrent.futures.as_completed(futures):
            kind, target, port = futures[future]
            try:
                print(future.result(), flush=True)
            except Exception as exc:
                failures.append(f"{kind.upper()} source={source} target={target} port={port}: {exc}")

    if failures:
        for failure in failures:
            print(f"PORT_CHECK_FAILED {failure}", file=sys.stderr)
        raise SystemExit(60)

    print(f"NETWORK_POLICY_PATHS=SUCCESS source={source}")

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("mode", choices=("server", "client"))
    parser.add_argument("--token", required=True)
    parser.add_argument("--duration", type=int, default=90)
    args = parser.parse_args()

    if args.mode == "server":
        server(args.token, args.duration)
    else:
        client(args.token)

if __name__ == "__main__":
    main()
PYTHON_NETWORK_PROBE_EOF

chmod 700 -- "${NETWORK_PROBE_FILE}"
"${VENV_PYTHON}" -m py_compile "${NETWORK_PROBE_FILE}"

cat > "${NETWORK_PLAYBOOK}" <<'ANSIBLE_NETWORK_PLAYBOOK_EOF'
---
- name: Verify required inter-node ports without persistent changes
  hosts: all
  gather_facts: false
  become: true
  any_errors_fatal: true

  tasks:
    - name: Run temporary network validation and guarantee cleanup
      block:
        - name: Copy temporary network probe
          ansible.builtin.copy:
            src: "{{ local_probe_path }}"
            dest: "{{ remote_probe_path }}"
            owner: root
            group: root
            mode: '0700'

        - name: Start temporary network listeners
          ansible.builtin.shell: |
            set -Eeuo pipefail
            nohup setsid /usr/bin/python3 \
                "{{ remote_probe_path }}" \
                server \
                --token "{{ run_token }}" \
                --duration 90 \
                > "{{ remote_log_path }}" 2>&1 \
                < /dev/null &
            probe_pid="$!"
            printf '%s\n' "${probe_pid}" > "{{ remote_pid_path }}"
            sleep 1
            kill -0 "${probe_pid}"
          args:
            executable: /bin/bash
          changed_when: false

        - name: Wait for all temporary listeners
          ansible.builtin.pause:
            seconds: 2
          run_once: true

        - name: Probe role-specific TCP paths and Calico UDP paths
          ansible.builtin.command:
            argv:
              - /usr/bin/python3
              - "{{ remote_probe_path }}"
              - client
              - --token
              - "{{ run_token }}"
          register: network_probe
          changed_when: false

        - name: Display network probe result
          ansible.builtin.debug:
            var: network_probe.stdout_lines

      always:
        - name: Stop and remove temporary network probe
          ansible.builtin.shell: |
            set -u
            if [[ -r "{{ remote_pid_path }}" ]]
            then
                probe_pid="$(cat "{{ remote_pid_path }}")"
                if [[ "${probe_pid}" =~ ^[0-9]+$ ]]
                then
                    kill "${probe_pid}" 2>/dev/null || true
                fi
            fi
            rm -f -- \
                "{{ remote_probe_path }}" \
                "{{ remote_pid_path }}" \
                "{{ remote_log_path }}"
          args:
            executable: /bin/bash
          changed_when: false
ANSIBLE_NETWORK_PLAYBOOK_EOF

"${VENV_ANSIBLE_PLAYBOOK}" \
    -i "${INVENTORY_FILE}" \
    "${NETWORK_PLAYBOOK}" \
    --syntax-check \
    -e "local_probe_path=${NETWORK_PROBE_FILE}" \
    -e "remote_probe_path=${REMOTE_PROBE_PATH}" \
    -e "remote_pid_path=${REMOTE_PID_PATH}" \
    -e "remote_log_path=${REMOTE_LOG_PATH}" \
    -e "run_token=${RUN_TOKEN}"

"${VENV_ANSIBLE_PLAYBOOK}" \
    -i "${INVENTORY_FILE}" \
    "${NETWORK_PLAYBOOK}" \
    -e "local_probe_path=${NETWORK_PROBE_FILE}" \
    -e "remote_probe_path=${REMOTE_PROBE_PATH}" \
    -e "remote_pid_path=${REMOTE_PID_PATH}" \
    -e "remote_log_path=${REMOTE_LOG_PATH}" \
    -e "run_token=${RUN_TOKEN}"

printf 'INTER_NODE_SECURITY_GROUP_AND_PORT_AUDIT_RESULT=SUCCESS\n'

printf '\n===== 08_PREFLIGHT_ATTESTATION =====\n'

CONFIGURATION_DIGEST="$(calculate_configuration_digest)"
PREFLIGHT_EPOCH="$(date +%s)"
PREFLIGHT_EXPIRES_EPOCH="$((PREFLIGHT_EPOCH + CHECK_VALIDITY_SECONDS))"
STATE_FILE_TEMP="${STATE_FILE}.tmp.$$"

{
    printf 'PREFLIGHT_RESULT=SUCCESS\n'
    printf 'PREFLIGHT_EPOCH=%s\n' "${PREFLIGHT_EPOCH}"
    printf 'PREFLIGHT_EXPIRES_EPOCH=%s\n' "${PREFLIGHT_EXPIRES_EPOCH}"
    printf 'CONFIGURATION_DIGEST=%s\n' "${CONFIGURATION_DIGEST}"
    printf 'PROJECT_HEAD=%s\n' "$(git -C "${PROJECT_DIR}" rev-parse HEAD)"
    printf 'KUBESPRAY_VERSION=%s\n' "${EXPECTED_KUBESPRAY_VERSION}"
    printf 'INVENTORY_FILE=%s\n' "${INVENTORY_FILE}"
    printf 'PREFLIGHT_LOG=%s\n' "${LOG_FILE}"
} > "${STATE_FILE_TEMP}"

chmod 600 -- "${STATE_FILE_TEMP}"
mv -f -- "${STATE_FILE_TEMP}" "${STATE_FILE}"

printf 'CONFIGURATION_DIGEST=%s\n' "${CONFIGURATION_DIGEST}"
printf 'PREFLIGHT_STATE_FILE=%s\n' "${STATE_FILE}"
printf 'PREFLIGHT_VALID_UNTIL_EPOCH=%s\n' "${PREFLIGHT_EXPIRES_EPOCH}"

printf '\nCONTROLLER_ENVIRONMENT_RESULT=SUCCESS\n'
printf 'INVENTORY_AND_VARIABLES_RESULT=SUCCESS\n'
printf 'SSH_CONFIGURATION_AND_ACCESS_RESULT=SUCCESS\n'
printf 'KUBESPRAY_PLAYBOOK_STATIC_VALIDATION_RESULT=SUCCESS\n'
printf 'REMOTE_READ_ONLY_AUDIT_RESULT=SUCCESS\n'
printf 'INTER_NODE_SECURITY_GROUP_AND_PORT_AUDIT_RESULT=SUCCESS\n'
printf 'KUBESPRAY_PREFLIGHT_RESULT=SUCCESS\n'
printf 'PERSISTENT_REMOTE_CHANGES=NONE\n'
printf 'KUBESPRAY_PREFLIGHT_END=%s\n' "$(date --iso-8601=seconds)"
