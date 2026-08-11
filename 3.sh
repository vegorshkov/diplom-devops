#!/usr/bin/env bash

set -Eeuo pipefail

umask 077
export LANG=C.UTF-8
export LC_ALL=C.UTF-8
export PIP_DISABLE_PIP_VERSION_CHECK=1
export PIP_NO_INPUT=1
export ANSIBLE_FORCE_COLOR=0

EXPECTED_REPO_ROOT="/home/vgorshkov/STUDENT1/PROJECT/diplom-devops"
EXPECTED_BRANCH="main"
KUBESPRAY_DIR="${EXPECTED_REPO_ROOT}/ansible_kubespray/kubespray"
INVENTORY_FILE="${EXPECTED_REPO_ROOT}/ansible_kubespray/inventory/hosts.yaml"
VENV_DIR="/home/vgorshkov/venv-kubespray-2.31.0"
SYSTEM_PYTHON="/usr/bin/python3"

EXPECTED_KUBESPRAY_VERSION="2.31.0"
EXPECTED_ANSIBLE_PACKAGE_VERSION="11.13.0"
EXPECTED_HOST_COUNT="6"

SSH_PRIVATE_KEY="/home/vgorshkov/.ssh/netology-ext-key"
SSH_CONFIG_FILE="/home/vgorshkov/.ssh/config"

INVENTORY_JSON=""
REMOTE_CHECK_PLAYBOOK=""

cleanup()
{
    if [[ -n "${INVENTORY_JSON}" ]] &&
       [[ -f "${INVENTORY_JSON}" ]]
    then
        rm -f -- "${INVENTORY_JSON}"
    fi

    if [[ -n "${REMOTE_CHECK_PLAYBOOK}" ]] &&
       [[ -f "${REMOTE_CHECK_PLAYBOOK}" ]]
    then
        rm -f -- "${REMOTE_CHECK_PLAYBOOK}"
    fi
}

fail()
{
    printf 'ERROR: %s\n' "$1" >&2
    printf 'KUBESPRAY_CONTROLLER_CHECK_RESULT=FAILED\n' >&2
    exit 1
}

error_handler()
{
    local exit_code="$?"

    trap - ERR

    printf '\nKUBESPRAY_CONTROLLER_CHECK_RESULT=FAILED\n' >&2
    printf 'FAILED_COMMAND=%s\n' "${BASH_COMMAND}" >&2
    printf 'EXIT_CODE=%s\n' "${exit_code}" >&2

    exit "${exit_code}"
}

trap cleanup EXIT
trap error_handler ERR

printf 'KUBESPRAY_CONTROLLER_CHECK_START=%s\n' \
    "$(date --iso-8601=seconds)"

if [[ "$(id -u)" -eq 0 ]]
then
    fail "сценарий нельзя выполнять от root"
fi

for required_command in \
    awk \
    date \
    dpkg-query \
    find \
    git \
    grep \
    id \
    mktemp \
    rm \
    sed \
    sort
do
    if ! command -v "${required_command}" >/dev/null 2>&1
    then
        fail "отсутствует обязательная команда ${required_command}"
    fi
done

if [[ ! -x "${SYSTEM_PYTHON}" ]]
then
    fail "системный Python не найден: ${SYSTEM_PYTHON}"
fi

REPO_ROOT="$(git rev-parse --show-toplevel)"

if [[ "${REPO_ROOT}" != "${EXPECTED_REPO_ROOT}" ]]
then
    fail "выбран неверный Git-репозиторий: ${REPO_ROOT}"
fi

cd "${REPO_ROOT}"

CURRENT_BRANCH="$(git branch --show-current)"

if [[ "${CURRENT_BRANCH}" != "${EXPECTED_BRANCH}" ]]
then
    fail "выбрана неверная ветка Git: ${CURRENT_BRANCH:-DETACHED_HEAD}"
fi

if [[ ! -d "${KUBESPRAY_DIR}" ]] ||
   [[ -L "${KUBESPRAY_DIR}" ]]
then
    fail "каталог Kubespray отсутствует или является символической ссылкой"
fi

REQUIRED_KUBESPRAY_PATHS=(
    ansible.cfg
    cluster.yml
    galaxy.yml
    requirements.txt
    inventory/sample
    roles/kubespray-defaults
    roles/kubernetes/preinstall
)

for required_path in "${REQUIRED_KUBESPRAY_PATHS[@]}"
do
    if [[ ! -e "${KUBESPRAY_DIR}/${required_path}" ]]
    then
        fail "в Kubespray отсутствует обязательный путь: ${required_path}"
    fi
done

NESTED_GIT="$({
    find "${KUBESPRAY_DIR}" \
        -name .git \
        -print \
        -quit
})"

if [[ -n "${NESTED_GIT}" ]]
then
    fail "обнаружены вложенные Git-метаданные: ${NESTED_GIT}"
fi

ACTUAL_KUBESPRAY_VERSION="$({
    awk '
        $1 == "version:" {
            print $2
            found = 1
            exit
        }

        END {
            if (!found) {
                exit 1
            }
        }
    ' "${KUBESPRAY_DIR}/galaxy.yml"
})"

if [[ "${ACTUAL_KUBESPRAY_VERSION}" != "${EXPECTED_KUBESPRAY_VERSION}" ]]
then
    fail "версия Kubespray ${ACTUAL_KUBESPRAY_VERSION}; ожидалась ${EXPECTED_KUBESPRAY_VERSION}"
fi

TARGET_GIT_STATUS="$({
    git status \
        --porcelain=v1 \
        --untracked-files=all \
        -- "${KUBESPRAY_DIR#${REPO_ROOT}/}"
})"

if [[ -n "${TARGET_GIT_STATUS}" ]]
then
    printf '%s\n' "${TARGET_GIT_STATUS}" >&2
    fail "каталог Kubespray содержит незакоммиченные изменения"
fi

REQUIRED_REQUIREMENTS=(
    "ansible==11.13.0"
    "cryptography==46.0.7"
    "jmespath==1.1.0"
    "netaddr==1.3.0"
)

for required_requirement in "${REQUIRED_REQUIREMENTS[@]}"
do
    if ! grep \
        -Fqx \
        -- "${required_requirement}" \
        "${KUBESPRAY_DIR}/requirements.txt"
    then
        fail "requirements.txt не содержит ${required_requirement}"
    fi
done

if [[ ! -r "${INVENTORY_FILE}" ]] ||
   [[ -L "${INVENTORY_FILE}" ]]
then
    fail "inventory отсутствует, недоступен или является символической ссылкой"
fi

if [[ ! -r "${SSH_PRIVATE_KEY}" ]]
then
    fail "закрытый SSH-ключ недоступен: ${SSH_PRIVATE_KEY}"
fi

if [[ ! -r "${SSH_CONFIG_FILE}" ]]
then
    fail "конфигурация SSH недоступна: ${SSH_CONFIG_FILE}"
fi

SYSTEM_PYTHON_VERSION="$({
    "${SYSTEM_PYTHON}" -c \
        'import sys; print(".".join(map(str, sys.version_info[:3])))'
})"

if ! "${SYSTEM_PYTHON}" -c '
import sys
raise SystemExit(0 if sys.version_info >= (3, 11) else 1)
'
then
    fail "для Ansible 11 требуется Python 3.11 или новее; найден ${SYSTEM_PYTHON_VERSION}"
fi

printf 'REPOSITORY_ROOT=%s\n' "${REPO_ROOT}"
printf 'BRANCH=%s\n' "${CURRENT_BRANCH}"
printf 'KUBESPRAY_DIR=%s\n' "${KUBESPRAY_DIR}"
printf 'KUBESPRAY_VERSION=%s\n' "${ACTUAL_KUBESPRAY_VERSION}"
printf 'INVENTORY_FILE=%s\n' "${INVENTORY_FILE}"
printf 'SYSTEM_PYTHON=%s\n' "${SYSTEM_PYTHON}"
printf 'SYSTEM_PYTHON_VERSION=%s\n' "${SYSTEM_PYTHON_VERSION}"
printf 'CURRENT_VIRTUAL_ENV=%s\n' "${VIRTUAL_ENV:-NOT_ACTIVE}"

printf '\n===== PREPARE_ISOLATED_PYTHON_ENVIRONMENT =====\n'

VENV_PYTHON="${VENV_DIR}/bin/python"
VENV_ANSIBLE="${VENV_DIR}/bin/ansible"
VENV_ANSIBLE_INVENTORY="${VENV_DIR}/bin/ansible-inventory"
VENV_ANSIBLE_PLAYBOOK="${VENV_DIR}/bin/ansible-playbook"

if [[ -e "${VENV_DIR}" ]] &&
   [[ -L "${VENV_DIR}" ]]
then
    fail "каталог виртуального окружения является символической ссылкой: ${VENV_DIR}"
fi

if [[ -e "${VENV_DIR}" ]] &&
   [[ ! -x "${VENV_PYTHON}" ]]
then
    fail "существующий каталог не является исправным venv: ${VENV_DIR}"
fi

if [[ ! -x "${VENV_PYTHON}" ]]
then
    PYTHON_VENV_PACKAGE_STATUS="$({
        dpkg-query \
            -W \
            -f='${db:Status-Abbrev}' \
            python3-venv \
            2>/dev/null ||
            true
    })"

    if [[ "${PYTHON_VENV_PACKAGE_STATUS}" != "ii " ]]
    then
        if ! command -v sudo >/dev/null 2>&1
        then
            fail "пакет python3-venv отсутствует, а команда sudo не найдена"
        fi

        printf 'PYTHON_VENV_PACKAGE=INSTALLING\n'

        sudo apt-get update
        sudo env \
            DEBIAN_FRONTEND=noninteractive \
            apt-get install \
                --yes \
                --no-install-recommends \
                python3-venv
    fi

    "${SYSTEM_PYTHON}" -m venv "${VENV_DIR}"
    printf 'VIRTUAL_ENVIRONMENT=CREATED\n'
else
    printf 'VIRTUAL_ENVIRONMENT=REUSED\n'
fi

if [[ ! -x "${VENV_PYTHON}" ]]
then
    fail "Python в виртуальном окружении не создан"
fi

"${VENV_PYTHON}" -m pip --version

printf '\n===== INSTALL_OFFICIAL_KUBESPRAY_REQUIREMENTS =====\n'

"${VENV_PYTHON}" -m pip install \
    --upgrade \
    --requirement "${KUBESPRAY_DIR}/requirements.txt"

"${VENV_PYTHON}" -m pip check

for venv_command in \
    "${VENV_ANSIBLE}" \
    "${VENV_ANSIBLE_INVENTORY}" \
    "${VENV_ANSIBLE_PLAYBOOK}"
do
    if [[ ! -x "${venv_command}" ]]
    then
        fail "после установки отсутствует команда ${venv_command}"
    fi
done

ACTUAL_ANSIBLE_PACKAGE_VERSION="$({
    "${VENV_PYTHON}" -c \
        'from importlib.metadata import version; print(version("ansible"))'
})"

if [[ "${ACTUAL_ANSIBLE_PACKAGE_VERSION}" != "${EXPECTED_ANSIBLE_PACKAGE_VERSION}" ]]
then
    fail "установлена версия ansible ${ACTUAL_ANSIBLE_PACKAGE_VERSION}; ожидалась ${EXPECTED_ANSIBLE_PACKAGE_VERSION}"
fi

"${VENV_PYTHON}" - <<'PYTHON_DEPENDENCY_CHECK_EOF'
from importlib.metadata import version

expected = {
    "ansible": "11.13.0",
    "cryptography": "46.0.7",
    "jmespath": "1.1.0",
    "netaddr": "1.3.0",
}

for package_name, expected_version in expected.items():
    actual_version = version(package_name)
    if actual_version != expected_version:
        raise SystemExit(
            f"{package_name}: installed {actual_version}, expected {expected_version}"
        )
    print(f"PYTHON_PACKAGE_{package_name.upper()}={actual_version}")
PYTHON_DEPENDENCY_CHECK_EOF

unset ANSIBLE_INVENTORY || true
unset ANSIBLE_LIBRARY || true
unset ANSIBLE_ROLES_PATH || true
unset ANSIBLE_CALLBACK_PLUGINS || true
unset ANSIBLE_FILTER_PLUGINS || true

export VIRTUAL_ENV="${VENV_DIR}"
export PATH="${VENV_DIR}/bin:${PATH}"
export ANSIBLE_CONFIG="${KUBESPRAY_DIR}/ansible.cfg"

hash -r

printf 'VIRTUAL_ENV=%s\n' "${VIRTUAL_ENV}"
printf 'ANSIBLE_PACKAGE_VERSION=%s\n' "${ACTUAL_ANSIBLE_PACKAGE_VERSION}"
printf 'DEPENDENCY_INSTALLATION_RESULT=SUCCESS\n'

printf '\n===== ANSIBLE_VERSION =====\n'

"${VENV_ANSIBLE}" --version

printf '\n===== BUILD_AND_VALIDATE_INVENTORY =====\n'

INVENTORY_JSON="$(mktemp /tmp/kubespray-inventory.XXXXXX.json)"

cd "${KUBESPRAY_DIR}"

"${VENV_ANSIBLE_INVENTORY}" \
    -i "${INVENTORY_FILE}" \
    --list \
    > "${INVENTORY_JSON}"

"${VENV_PYTHON}" \
    - "${INVENTORY_JSON}" "${EXPECTED_HOST_COUNT}" <<'PYTHON_INVENTORY_CHECK_EOF'
import json
import sys

inventory_path = sys.argv[1]
expected_host_count = int(sys.argv[2])

expected_hosts = {
    "k8s-master-ru-central1-a",
    "k8s-master-ru-central1-b",
    "k8s-master-ru-central1-d",
    "k8s-worker-ru-central1-a",
    "k8s-worker-ru-central1-b",
    "k8s-worker-ru-central1-d",
}

expected_control_plane_hosts = {
    "k8s-master-ru-central1-a",
    "k8s-master-ru-central1-b",
    "k8s-master-ru-central1-d",
}

expected_worker_hosts = {
    "k8s-worker-ru-central1-a",
    "k8s-worker-ru-central1-b",
    "k8s-worker-ru-central1-d",
}

with open(inventory_path, encoding="utf-8") as inventory_file:
    inventory = json.load(inventory_file)

hostvars = inventory.get("_meta", {}).get("hostvars", {})
actual_hosts = set(hostvars)

if len(actual_hosts) != expected_host_count:
    raise SystemExit(
        f"inventory host count is {len(actual_hosts)}, expected {expected_host_count}"
    )

if actual_hosts != expected_hosts:
    raise SystemExit(
        "inventory hosts differ: " + ", ".join(sorted(actual_hosts))
    )

def group_hosts(group_name):
    return set(inventory.get(group_name, {}).get("hosts", []))

if group_hosts("kube_control_plane") != expected_control_plane_hosts:
    raise SystemExit("kube_control_plane membership differs from approved topology")

if group_hosts("etcd") != expected_control_plane_hosts:
    raise SystemExit("etcd membership differs from approved topology")

if group_hosts("kube_node") != expected_worker_hosts:
    raise SystemExit("kube_node membership differs from approved topology")

for host_name in sorted(expected_hosts):
    variables = hostvars[host_name]

    if variables.get("ansible_user") != "ubuntu":
        raise SystemExit(f"{host_name}: ansible_user must be ubuntu")

    if variables.get("ansible_ssh_private_key_file") != "/home/vgorshkov/.ssh/netology-ext-key":
        raise SystemExit(f"{host_name}: unexpected SSH private key path")

    become_value = variables.get("ansible_become")
    if become_value not in (True, "yes", "true", 1):
        raise SystemExit(f"{host_name}: ansible_become is not enabled")

print(f"INVENTORY_HOST_COUNT={len(actual_hosts)}")
print("INVENTORY_HOSTS=" + ",".join(sorted(actual_hosts)))
print("INVENTORY_TOPOLOGY=VALID")
PYTHON_INVENTORY_CHECK_EOF

printf '\n===== INVENTORY_GRAPH =====\n'

"${VENV_ANSIBLE_INVENTORY}" \
    -i "${INVENTORY_FILE}" \
    --graph

printf 'INVENTORY_VALIDATION_RESULT=SUCCESS\n'

printf '\n===== SSH_CONNECTIVITY_WITHOUT_PRIVILEGE_ESCALATION =====\n'

"${VENV_ANSIBLE}" \
    all \
    -i "${INVENTORY_FILE}" \
    --module-name ansible.builtin.ping \
    --extra-vars ansible_become=false \
    --forks "${EXPECTED_HOST_COUNT}" \
    --one-line

printf 'SSH_CONNECTIVITY_RESULT=SUCCESS\n'

REMOTE_CHECK_PLAYBOOK="$(mktemp /tmp/kubespray-remote-check.XXXXXX.yml)"

"${VENV_PYTHON}" \
    - "${REMOTE_CHECK_PLAYBOOK}" <<'PYTHON_PLAYBOOK_EOF'
from pathlib import Path
import sys

playbook_path = Path(sys.argv[1])
playbook_path.write_text(
    """---
- name: Validate access and inspect the Kubernetes hosts
  hosts: all
  gather_facts: true
  any_errors_fatal: true
  become: true

  tasks:
    - name: Read effective user identifier
      ansible.builtin.command:
        argv:
          - id
          - -u
      register: effective_uid
      changed_when: false

    - name: Validate supported host platform
      ansible.builtin.assert:
        that:
          - effective_uid.stdout == '0'
          - ansible_distribution == 'Ubuntu'
          - ansible_distribution_release in ['jammy', 'noble']
          - ansible_architecture in ['x86_64', 'amd64']
          - ansible_service_mgr == 'systemd'
          - ansible_python_version is version('3.8', '>=')
          - ansible_hostname == inventory_hostname
          - >-
            (ansible_memtotal_mb | int) >=
            (1900 if inventory_hostname in groups['kube_control_plane'] else 900)
        fail_msg: >-
          Host does not meet the approved Kubespray platform, naming,
          privilege-escalation or memory requirements.
        success_msg: HOST_PLATFORM=VALID

    - name: Read IPv4 forwarding state
      ansible.builtin.command:
        argv:
          - sysctl
          - -n
          - net.ipv4.ip_forward
      register: ipv4_forwarding
      changed_when: false

    - name: Read active swap devices
      ansible.builtin.command:
        argv:
          - swapon
          - --noheadings
          - --show=NAME
      register: active_swap
      changed_when: false

    - name: Read time synchronization state
      ansible.builtin.command:
        argv:
          - timedatectl
          - show
          - --property=NTPSynchronized
          - --value
      register: time_synchronization
      changed_when: false

    - name: Read UFW state
      ansible.builtin.shell: |
        set -Eeuo pipefail

        if command -v ufw >/dev/null 2>&1
        then
            ufw status
        else
            printf 'UFW_NOT_INSTALLED\\n'
        fi
      args:
        executable: /bin/bash
      register: ufw_state
      changed_when: false

    - name: Report the inspected host state
      ansible.builtin.debug:
        msg:
          - "HOST={{ inventory_hostname }}"
          - "OS={{ ansible_distribution }} {{ ansible_distribution_version }}"
          - "KERNEL={{ ansible_kernel }}"
          - "ARCHITECTURE={{ ansible_architecture }}"
          - "REMOTE_PYTHON={{ ansible_python_version }}"
          - "MEMORY_MB={{ ansible_memtotal_mb }}"
          - "IPV4_FORWARDING={{ ipv4_forwarding.stdout | trim }}"
          - "SWAP={{ 'DISABLED' if (active_swap.stdout | trim == '') else active_swap.stdout | trim }}"
          - "NTP_SYNCHRONIZED={{ time_synchronization.stdout | trim }}"
          - "UFW={{ ufw_state.stdout | trim }}"
          - REMOTE_PERSISTENT_CHANGES=NONE
""",
    encoding="utf-8",
)
PYTHON_PLAYBOOK_EOF

printf '\n===== REMOTE_CHECK_SYNTAX =====\n'

"${VENV_ANSIBLE_PLAYBOOK}" \
    -i "${INVENTORY_FILE}" \
    "${REMOTE_CHECK_PLAYBOOK}" \
    --syntax-check

printf '\n===== REMOTE_CHECK_TARGETS =====\n'

"${VENV_ANSIBLE_PLAYBOOK}" \
    -i "${INVENTORY_FILE}" \
    "${REMOTE_CHECK_PLAYBOOK}" \
    --list-hosts

printf '\n===== REMOTE_OS_INSPECTION =====\n'

"${VENV_ANSIBLE_PLAYBOOK}" \
    -i "${INVENTORY_FILE}" \
    "${REMOTE_CHECK_PLAYBOOK}" \
    --forks "${EXPECTED_HOST_COUNT}"

printf '\nDEPENDENCY_INSTALLATION_RESULT=SUCCESS\n'
printf 'INVENTORY_VALIDATION_RESULT=SUCCESS\n'
printf 'SSH_CONNECTIVITY_RESULT=SUCCESS\n'
printf 'REMOTE_OS_INSPECTION_RESULT=SUCCESS\n'
printf 'REMOTE_PERSISTENT_CHANGES=NONE\n'
printf 'PREPARE_KUBESPRAY_HOSTS=NOT_EXECUTED\n'
printf 'CLUSTER_PLAYBOOK=NOT_EXECUTED\n'
printf 'GIT_COMMIT=NOT_EXECUTED\n'
printf 'GIT_PUSH=NOT_EXECUTED\n'
printf 'KUBESPRAY_CONTROLLER_CHECK_RESULT=SUCCESS\n'
printf 'KUBESPRAY_CONTROLLER_CHECK_END=%s\n' \
    "$(date --iso-8601=seconds)"
