cd /home/vgorshkov/STUDENT1/PROJECT/diplom-devops || exit 1

bash << 'MIGRATION_EOF'
set -Eeuo pipefail
umask 027

PROJECT_DIR="/home/vgorshkov/STUDENT1/PROJECT/diplom-devops"
ANSIBLE_ROOT="${PROJECT_DIR}/ansible_kubespray"
KUBESPRAY_DIR="${ANSIBLE_ROOT}/kubespray"
INVENTORY_FILE="${ANSIBLE_ROOT}/inventory/hosts.yaml"
PROJECT_VARS_FILE="${ANSIBLE_ROOT}/inventory/group_vars/k8s_cluster/z2026-diplom.yml"
NEW_VENV_DIR="${ANSIBLE_ROOT}/venv-kubespray-v2.31.0"
LOG_DIR="${ANSIBLE_ROOT}/logs"
PRIMARY_CONTROL_PLANE="k8s-master-ru-central1-a"

KUBESPRAY_REPOSITORY="https://github.com/kubernetes-sigs/kubespray.git"
KUBESPRAY_TAG="v2.31.0"
KUBESPRAY_COMMIT_PREFIX="1c9add4"
KUBERNETES_VERSION="1.35.4"
APT_MIRROR="https://mirror.yandex.ru/ubuntu"

CHANGE_ID="$(date '+%Y%m%dT%H%M%S')"
MIRROR_PLAYBOOK="$(mktemp /tmp/configure-yandex-mirror.XXXXXX.yml)"
HOST_VARS_JSON="$(mktemp /tmp/kubespray-host-vars.XXXXXX.json)"
STAGING_DIR=""

die()
{
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

cleanup()
{
    rm -f -- "${MIRROR_PLAYBOOK}" "${HOST_VARS_JSON}"

    if [[ -n "${STAGING_DIR}" && -d "${STAGING_DIR}" ]]
    then
        rm -rf -- "${STAGING_DIR}"
    fi
}

trap cleanup EXIT

[[ -d "${PROJECT_DIR}" ]] ||
    die "Не найден каталог проекта: ${PROJECT_DIR}"

[[ -d "${ANSIBLE_ROOT}" ]] ||
    die "Не найден каталог Ansible: ${ANSIBLE_ROOT}"

[[ -d "${KUBESPRAY_DIR}" ]] ||
    die "Не найден текущий каталог Kubespray: ${KUBESPRAY_DIR}"

[[ -f "${INVENTORY_FILE}" ]] ||
    die "Не найден inventory: ${INVENTORY_FILE}"

[[ -f "${PROJECT_VARS_FILE}" ]] ||
    die "Не найден файл переменных: ${PROJECT_VARS_FILE}"

[[ -x /usr/bin/python3 ]] ||
    die "Не найден /usr/bin/python3"

command -v ansible-playbook >/dev/null 2>&1 ||
    die "В текущем окружении отсутствует ansible-playbook"

command -v git >/dev/null 2>&1 ||
    die "Не найдена команда git"

PYTHON_VERSION_OK="$(
    /usr/bin/python3 - << 'PYTHON_EOF'
import sys

if (3, 11) <= sys.version_info[:2] <= (3, 13):
    print("YES")
else:
    print("NO")
PYTHON_EOF
)"

[[ "${PYTHON_VERSION_OK}" == "YES" ]] ||
    die "Для Ansible 11 требуется Python 3.11–3.13"

printf 'MIGRATION_START=%s\n' "$(date --iso-8601=seconds)"
printf 'CHANGE_ID=%s\n' "${CHANGE_ID}"

printf '\nЭтап 1. Настройка российского APT-зеркала\n'

export ANSIBLE_CONFIG="${KUBESPRAY_DIR}/ansible.cfg"
export ANSIBLE_PIPELINING=True
export ANSIBLE_FORKS=12
export PYTHONUNBUFFERED=1

cat > "${MIRROR_PLAYBOOK}" << 'PLAYBOOK_EOF'
---
- name: Configure Yandex Ubuntu mirror
  hosts: k8s_cluster
  become: true
  gather_facts: true

  vars:
    apt_mirror_base: "https://mirror.yandex.ru/ubuntu"
    apt_backup_dir: "/var/backups/apt-before-yandex-{{ mirror_change_id }}"

  tasks:
    - name: Verify operating system
      ansible.builtin.assert:
        that:
          - ansible_distribution == "Ubuntu"
          - ansible_distribution_version is version("22.04", ">=")
          - ansible_distribution_version is version("24.04", "<")
        fail_msg: >-
          Поддерживаются только узлы Ubuntu 22.04.
          Обнаружено: {{ ansible_distribution }}
          {{ ansible_distribution_version }}

    - name: Verify Yandex mirror through HTTPS
      ansible.builtin.uri:
        url: "https://mirror.yandex.ru/ubuntu/dists/jammy/InRelease"
        method: GET
        return_content: false
        status_code: 200
        timeout: 30
        validate_certs: true

    - name: Create APT configuration backup
      ansible.builtin.shell: |
        set -Eeuo pipefail

        install -d -m 0700 -- "{{ apt_backup_dir }}"

        if [[ -f /etc/apt/sources.list ]]
        then
            cp -a -- \
                /etc/apt/sources.list \
                "{{ apt_backup_dir }}/sources.list"
        fi

        if [[ -d /etc/apt/sources.list.d ]]
        then
            cp -a -- \
                /etc/apt/sources.list.d \
                "{{ apt_backup_dir }}/sources.list.d"
        fi

        touch -- "{{ apt_backup_dir }}/.complete"
      args:
        executable: /bin/bash
        creates: "{{ apt_backup_dir }}/.complete"

    - name: Find APT source files
      ansible.builtin.find:
        paths:
          - /etc/apt
        recurse: true
        file_type: file
        patterns:
          - "*.list"
          - "*.sources"
      register: apt_source_files

    - name: Replace Ubuntu repository addresses
      ansible.builtin.replace:
        path: "{{ item.path }}"
        regexp: >-
          https?://(?:(?:[a-z]{2}\.)?archive\.ubuntu\.com|security\.ubuntu\.com|mirror\.yandex\.ru)/ubuntu
        replace: "{{ apt_mirror_base }}"
      loop: "{{ apt_source_files.files }}"
      loop_control:
        label: "{{ item.path }}"

    - name: Update APT cache
      ansible.builtin.apt:
        update_cache: true
        cache_valid_time: 0
        force_apt_get: true
        update_cache_retries: 3
        update_cache_retry_max_delay: 5

    - name: Read active Ubuntu sources
      ansible.builtin.shell: |
        set -o pipefail

        grep \
            -RhsE \
            '^[[:space:]]*(deb|URIs:)' \
            /etc/apt/sources.list \
            /etc/apt/sources.list.d/*.list \
            /etc/apt/sources.list.d/*.sources \
            2>/dev/null |
            grep -vE '^[[:space:]]*#' ||
            true
      args:
        executable: /bin/bash
      changed_when: false
      register: active_ubuntu_sources

    - name: Report mirror configuration
      ansible.builtin.debug:
        msg:
          - "NODE={{ inventory_hostname }}"
          - "APT_BACKUP={{ apt_backup_dir }}"
          - "APT_SOURCES={{ active_ubuntu_sources.stdout_lines }}"
          - "APT_MIRROR_RESULT=SUCCESS"
PLAYBOOK_EOF

ansible-playbook \
    -i "${INVENTORY_FILE}" \
    "${MIRROR_PLAYBOOK}" \
    --extra-vars "mirror_change_id=${CHANGE_ID}" \
    --forks 12

printf '\nAPT_MIRROR_CONFIGURATION=SUCCESS\n'

printf '\nЭтап 2. Получение официального Kubespray %s\n' \
    "${KUBESPRAY_TAG}"

CURRENT_IS_TARGET="NO"

if [[ -d "${KUBESPRAY_DIR}/.git" ]]
then
    CURRENT_TAG="$(
        git \
            -C "${KUBESPRAY_DIR}" \
            describe \
            --tags \
            --exact-match \
            HEAD \
            2>/dev/null ||
        true
    )"

    CURRENT_COMMIT="$(
        git \
            -C "${KUBESPRAY_DIR}" \
            rev-parse \
            HEAD \
            2>/dev/null ||
        true
    )"

    if [[ "${CURRENT_TAG}" == "${KUBESPRAY_TAG}" &&
          "${CURRENT_COMMIT}" == "${KUBESPRAY_COMMIT_PREFIX}"* ]]
    then
        CURRENT_IS_TARGET="YES"
    fi
fi

if [[ "${CURRENT_IS_TARGET}" == "YES" ]]
then
    printf 'KUBESPRAY_SOURCE=ALREADY_INSTALLED\n'
else
    STAGING_DIR="$(
        mktemp \
            -d \
            "${ANSIBLE_ROOT}/.kubespray-v2.31.0.XXXXXX"
    )"

    NEW_SOURCE_DIR="${STAGING_DIR}/kubespray"

    git clone \
        --branch "${KUBESPRAY_TAG}" \
        --depth 1 \
        "${KUBESPRAY_REPOSITORY}" \
        "${NEW_SOURCE_DIR}"

    NEW_TAG="$(
        git \
            -C "${NEW_SOURCE_DIR}" \
            describe \
            --tags \
            --exact-match \
            HEAD
    )"

    NEW_COMMIT="$(
        git \
            -C "${NEW_SOURCE_DIR}" \
            rev-parse \
            HEAD
    )"

    [[ "${NEW_TAG}" == "${KUBESPRAY_TAG}" ]] ||
        die "Получен неверный тег: ${NEW_TAG}"

    [[ "${NEW_COMMIT}" == "${KUBESPRAY_COMMIT_PREFIX}"* ]] ||
        die "Получена неверная ревизия: ${NEW_COMMIT}"

    KUBESPRAY_BACKUP_DIR="$(
        printf '%s/kubespray-before-v2.31.0-%s' \
            "${ANSIBLE_ROOT}" \
            "${CHANGE_ID}"
    )"

    [[ ! -e "${KUBESPRAY_BACKUP_DIR}" ]] ||
        die "Каталог резервной копии уже существует: ${KUBESPRAY_BACKUP_DIR}"

    mv -- \
        "${KUBESPRAY_DIR}" \
        "${KUBESPRAY_BACKUP_DIR}"

    mv -- \
        "${NEW_SOURCE_DIR}" \
        "${KUBESPRAY_DIR}"

    printf 'OLD_KUBESPRAY_BACKUP=%s\n' \
        "${KUBESPRAY_BACKUP_DIR}"
fi

INSTALLED_TAG="$(
    git \
        -C "${KUBESPRAY_DIR}" \
        describe \
        --tags \
        --exact-match \
        HEAD
)"

INSTALLED_COMMIT="$(
    git \
        -C "${KUBESPRAY_DIR}" \
        rev-parse \
        HEAD
)"

[[ "${INSTALLED_TAG}" == "${KUBESPRAY_TAG}" ]] ||
    die "После установки обнаружен неверный тег: ${INSTALLED_TAG}"

[[ "${INSTALLED_COMMIT}" == "${KUBESPRAY_COMMIT_PREFIX}"* ]] ||
    die "После установки обнаружена неверная ревизия: ${INSTALLED_COMMIT}"

printf 'KUBESPRAY_TAG=%s\n' "${INSTALLED_TAG}"
printf 'KUBESPRAY_COMMIT=%s\n' "${INSTALLED_COMMIT}"

printf '\nЭтап 3. Создание изолированного окружения Ansible\n'

if [[ ! -x "${NEW_VENV_DIR}/bin/python" ]]
then
    /usr/bin/python3 \
        -m venv \
        "${NEW_VENV_DIR}"
fi

"${NEW_VENV_DIR}/bin/python" \
    -m pip \
    install \
    --upgrade \
    pip \
    setuptools \
    wheel

"${NEW_VENV_DIR}/bin/python" \
    -m pip \
    install \
    --requirement "${KUBESPRAY_DIR}/requirements.txt"

"${NEW_VENV_DIR}/bin/ansible" --version

ANSIBLE_VERSION="$(
    "${NEW_VENV_DIR}/bin/ansible" \
        --version |
        sed -n '1p'
)"

printf 'ANSIBLE_VERSION=%s\n' "${ANSIBLE_VERSION}"

printf '\nЭтап 4. Установка Kubernetes %s в проектных переменных\n' \
    "${KUBERNETES_VERSION}"

PROJECT_VARS_BACKUP="${PROJECT_VARS_FILE}.bak-${CHANGE_ID}"

cp -a -- \
    "${PROJECT_VARS_FILE}" \
    "${PROJECT_VARS_BACKUP}"

KUBE_VERSION_COUNT="$(
    grep \
        -Ec \
        '^[[:space:]]*kube_version[[:space:]]*:' \
        "${PROJECT_VARS_FILE}" ||
    true
)"

case "${KUBE_VERSION_COUNT}" in
    0)
        printf '\nkube_version: "%s"\n' \
            "${KUBERNETES_VERSION}" \
            >> "${PROJECT_VARS_FILE}"
        ;;
    1)
        sed \
            -E \
            -i \
            's/^[[:space:]]*kube_version[[:space:]]*:.*$/kube_version: "1.35.4"/' \
            "${PROJECT_VARS_FILE}"
        ;;
    *)
        die "В ${PROJECT_VARS_FILE} найдено несколько параметров kube_version"
        ;;
esac

FINAL_KUBE_VERSION_COUNT="$(
    grep \
        -Ec \
        '^kube_version:[[:space:]]*"1\.35\.4"[[:space:]]*$' \
        "${PROJECT_VARS_FILE}" ||
    true
)"

[[ "${FINAL_KUBE_VERSION_COUNT}" -eq 1 ]] ||
    die "Параметр kube_version установлен некорректно"

printf 'PROJECT_VARS_BACKUP=%s\n' \
    "${PROJECT_VARS_BACKUP}"

printf 'PROJECT_KUBE_VERSION=%s\n' \
    "${KUBERNETES_VERSION}"

printf '\nЭтап 5. Проверка inventory и playbook\n'

export PATH="${NEW_VENV_DIR}/bin:${PATH}"
export ANSIBLE_CONFIG="${KUBESPRAY_DIR}/ansible.cfg"
export ANSIBLE_PIPELINING=True
export ANSIBLE_FORKS=12
export PYTHONUNBUFFERED=1

hash -r

ansible-inventory \
    -i "${INVENTORY_FILE}" \
    --host "${PRIMARY_CONTROL_PLANE}" \
    > "${HOST_VARS_JSON}"

"${NEW_VENV_DIR}/bin/python" \
    - "${HOST_VARS_JSON}" << 'PYTHON_EOF'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as source:
    variables = json.load(source)

expected = {
    "kube_version": "1.35.4",
    "container_manager": "containerd",
    "kube_network_plugin": "calico",
    "cluster_name": "cluster.local",
    "dns_domain": "cluster.local",
}

errors = []

for variable_name, expected_value in expected.items():
    actual_value = variables.get(variable_name)
    print(f"{variable_name}={actual_value}")

    if actual_value != expected_value:
        errors.append(
            f"{variable_name}: ожидается {expected_value!r}, "
            f"получено {actual_value!r}"
        )

if errors:
    for error in errors:
        print(f"ERROR: {error}", file=sys.stderr)

    raise SystemExit(1)

print("INVENTORY_VARIABLES_CHECK=SUCCESS")
PYTHON_EOF

cd "${KUBESPRAY_DIR}"

ansible-playbook \
    -i "${INVENTORY_FILE}" \
    cluster.yml \
    --syntax-check

printf 'KUBESPRAY_SYNTAX_CHECK=SUCCESS\n'

printf '\nЭтап 6. Развёртывание Kubernetes\n'

mkdir -p -- "${LOG_DIR}"

DEPLOY_LOG="${LOG_DIR}/kubespray-v2.31.0-${CHANGE_ID}.log"

printf 'DEPLOY_LOG=%s\n' "${DEPLOY_LOG}"
printf 'DEPLOY_START=%s\n' "$(date --iso-8601=seconds)"

set +e

ansible-playbook \
    -i "${INVENTORY_FILE}" \
    cluster.yml \
    --become \
    --forks 12 \
    2>&1 |
    tee "${DEPLOY_LOG}"

DEPLOY_RC="${PIPESTATUS[0]}"

set -e

printf 'DEPLOY_RC=%s\n' "${DEPLOY_RC}"

if [[ "${DEPLOY_RC}" -ne 0 ]]
then
    printf 'DEPLOY_RESULT=FAILED\n'
    printf 'DEPLOY_LOG=%s\n' "${DEPLOY_LOG}"
    exit "${DEPLOY_RC}"
fi

printf 'DEPLOY_RESULT=SUCCESS\n'

printf '\nЭтап 7. Проверка состояния кластера\n'

ansible \
    "${PRIMARY_CONTROL_PLANE}" \
    -i "${INVENTORY_FILE}" \
    --become \
    --forks 1 \
    -m ansible.builtin.shell \
    -a \
    'kubectl --kubeconfig=/etc/kubernetes/admin.conf get nodes -o wide && kubectl --kubeconfig=/etc/kubernetes/admin.conf get pods -A -o wide'

printf '\nCLUSTER_VERIFICATION=SUCCESS\n'
printf 'MIGRATION_END=%s\n' "$(date --iso-8601=seconds)"
printf 'DEPLOY_LOG=%s\n' "${DEPLOY_LOG}"
MIGRATION_EOF

