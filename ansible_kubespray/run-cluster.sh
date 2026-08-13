#!/usr/bin/env bash
set -uo pipefail

PROJECT_DIR="/home/vgorshkov/STUDENT1/PROJECT/diplom-devops"
ANSIBLE_ROOT="${PROJECT_DIR}/ansible_kubespray"
KUBESPRAY_DIR="${ANSIBLE_ROOT}/kubespray"
INVENTORY_FILE="${ANSIBLE_ROOT}/inventory/hosts.yaml"
VENV_DIR="/home/vgorshkov/venv-kubespray-2.31.0"
LOG_DIR="${ANSIBLE_ROOT}/logs"
LOG_FILE="${LOG_DIR}/kubespray-cluster-$(date -u '+%Y%m%dT%H%M%SZ').log"

mkdir -p "${LOG_DIR}"

if [[ ! -d "${VENV_DIR}" ]]; then
    echo "ERROR: venv не найден: ${VENV_DIR}" >&2
    exit 1
fi

# shellcheck disable=SC1091
source "${VENV_DIR}/bin/activate"

export ANSIBLE_CONFIG="${KUBESPRAY_DIR}/ansible.cfg"

echo "=== KUBESPRAY CLUSTER RUN ==="
echo "START_TIME=$(date --iso-8601=seconds)"
echo "KUBESPRAY_DIR=${KUBESPRAY_DIR}"
echo "INVENTORY_FILE=${INVENTORY_FILE}"
echo "VIRTUAL_ENV=${VIRTUAL_ENV}"
echo "ANSIBLE_CONFIG=${ANSIBLE_CONFIG}"
echo "LOG_FILE=${LOG_FILE}"
echo

ansible --version | head -n 5

echo
echo "=== INVENTORY GRAPH ==="
ansible-inventory -i "${INVENTORY_FILE}" --graph

echo
echo "=== START PLAYBOOK ==="
cd "${KUBESPRAY_DIR}"

set -o pipefail

ansible-playbook \
    -i "${INVENTORY_FILE}" \
    --become \
    --become-user=root \
    cluster.yml \
    2>&1 | tee -a "${LOG_FILE}"

PLAYBOOK_EXIT_CODE="${PIPESTATUS[0]}"

echo
echo "=== RESULT ==="
echo "EXIT_CODE=${PLAYBOOK_EXIT_CODE}"
echo "LOG_FILE=${LOG_FILE}"
echo "END_TIME=$(date --iso-8601=seconds)"

exit "${PLAYBOOK_EXIT_CODE}"
