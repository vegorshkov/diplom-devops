#!/usr/bin/env bash

set -Eeuo pipefail

umask 077
export LANG=C.UTF-8
export LC_ALL=C.UTF-8
export ANSIBLE_FORCE_COLOR=0
export ANSIBLE_NOCOLOR=1

PROJECT_DIR="/home/vgorshkov/STUDENT1/PROJECT/diplom-devops"
KUBESPRAY_DIR="${PROJECT_DIR}/ansible_kubespray/kubespray"
INVENTORY_FILE="${PROJECT_DIR}/ansible_kubespray/inventory/hosts.yaml"
GROUP_VARS_DIR="${PROJECT_DIR}/ansible_kubespray/inventory/group_vars"
LOG_DIR="${PROJECT_DIR}/ansible_kubespray/logs"
VENV_DIR="/home/vgorshkov/venv-kubespray-2.31.0"
SSH_CONFIG_FILE="/home/vgorshkov/.ssh/config"
SSH_PRIVATE_KEY="/home/vgorshkov/.ssh/netology-ext-key"

CHECK_SCRIPT="${PROJECT_DIR}/check_system_before_install_kubespray.sh"
STATE_FILE="${LOG_DIR}/kubespray-preflight-success.env"
LOCK_FILE="${LOG_DIR}/kubespray-install.lock"
LOCAL_KUBECONFIG="${PROJECT_DIR}/ansible_kubespray/inventory/artifacts/admin.conf"

EXPECTED_KUBESPRAY_VERSION="2.31.0"
EXPECTED_HOST_COUNT="6"
CONFIRMATION_PHRASE="INSTALL_KUBESPRAY"

POSTINSTALL_PLAYBOOK=""
LOG_FILE=""
INSTALL_SUCCESS_FILE=""

cleanup()
{
    if [[ -n "${POSTINSTALL_PLAYBOOK}" ]] &&
       [[ -f "${POSTINSTALL_PLAYBOOK}" ]]
    then
        rm -f -- "${POSTINSTALL_PLAYBOOK}"
    fi
}

fail()
{
    printf 'ERROR: %s\n' "$1" >&2
    printf 'KUBESPRAY_INSTALL_RESULT=FAILED\n' >&2
    exit 1
}

error_handler()
{
    local exit_code="$?"

    trap - ERR

    printf '\nKUBESPRAY_INSTALL_RESULT=FAILED\n' >&2
    printf 'FAILED_COMMAND=%s\n' "${BASH_COMMAND}" >&2
    printf 'EXIT_CODE=%s\n' "${exit_code}" >&2

    exit "${exit_code}"
}

read_state_value()
{
    local key="$1"

    awk -F= -v requested_key="${key}" '
        $1 == requested_key {
            sub(/^[^=]*=/, "")
            print
            found = 1
            exit
        }
        END { if (!found) exit 1 }
    ' "${STATE_FILE}"
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
    chmod \
    date \
    find \
    flock \
    git \
    mkdir \
    mktemp \
    mv \
    sha256sum \
    sort \
    stat \
    tee \
    xargs
do
    command -v "${required_command}" >/dev/null 2>&1 ||
        fail "отсутствует обязательная команда ${required_command}"
done

[[ -d "${PROJECT_DIR}" ]] ||
    fail "каталог проекта отсутствует: ${PROJECT_DIR}"
[[ -x "${CHECK_SCRIPT}" ]] ||
    fail "первый сценарий отсутствует или не является исполняемым: ${CHECK_SCRIPT}"

[[ -d "${LOG_DIR}" ]] || mkdir -p -- "${LOG_DIR}"
[[ -w "${LOG_DIR}" ]] ||
    fail "каталог журналов недоступен для записи: ${LOG_DIR}"

exec 9>"${LOCK_FILE}"
flock -n 9 ||
    fail "уже выполняется другой процесс установки Kubespray"

printf 'Сценарий выполнит полное развертывание Kubernetes на шести узлах.\n'
printf 'Целевой inventory: %s\n' "${INVENTORY_FILE}"
printf 'Для продолжения введите: %s\n' "${CONFIRMATION_PHRASE}"

if [[ -t 0 ]]
then
    read -r -p '> ' USER_CONFIRMATION
else
    USER_CONFIRMATION="${KUBESPRAY_INSTALL_CONFIRMATION:-}"
fi

[[ "${USER_CONFIRMATION}" == "${CONFIRMATION_PHRASE}" ]] ||
    fail "установка не подтверждена"

printf '\n===== MANDATORY_PREFLIGHT_RECHECK =====\n'

"${CHECK_SCRIPT}"

[[ -f "${STATE_FILE}" ]] && [[ ! -L "${STATE_FILE}" ]] ||
    fail "первый сценарий не создал подтверждение успешной проверки"

STATE_MODE="$(stat -c '%a' "${STATE_FILE}")"
[[ "${STATE_MODE}" == "600" ]] ||
    fail "файл подтверждения имеет небезопасный режим ${STATE_MODE}"

PREFLIGHT_RESULT="$(read_state_value PREFLIGHT_RESULT)"
PREFLIGHT_EXPIRES_EPOCH="$(read_state_value PREFLIGHT_EXPIRES_EPOCH)"
PREFLIGHT_CONFIGURATION_DIGEST="$(read_state_value CONFIGURATION_DIGEST)"
PREFLIGHT_PROJECT_HEAD="$(read_state_value PROJECT_HEAD)"
PREFLIGHT_KUBESPRAY_VERSION="$(read_state_value KUBESPRAY_VERSION)"
PREFLIGHT_LOG="$(read_state_value PREFLIGHT_LOG)"

[[ "${PREFLIGHT_RESULT}" == "SUCCESS" ]] ||
    fail "предустановочная проверка не завершилась успешно"
[[ "${PREFLIGHT_EXPIRES_EPOCH}" =~ ^[0-9]+$ ]] ||
    fail "некорректный срок действия предустановочной проверки"
(( $(date +%s) <= PREFLIGHT_EXPIRES_EPOCH )) ||
    fail "срок действия предустановочной проверки истёк"

CURRENT_CONFIGURATION_DIGEST="$(calculate_configuration_digest)"
[[ "${CURRENT_CONFIGURATION_DIGEST}" == "${PREFLIGHT_CONFIGURATION_DIGEST}" ]] ||
    fail "конфигурация изменилась после предустановочной проверки"

CURRENT_PROJECT_HEAD="$(git -C "${PROJECT_DIR}" rev-parse HEAD)"
[[ "${CURRENT_PROJECT_HEAD}" == "${PREFLIGHT_PROJECT_HEAD}" ]] ||
    fail "Git HEAD изменился после предустановочной проверки"
[[ "${PREFLIGHT_KUBESPRAY_VERSION}" == "${EXPECTED_KUBESPRAY_VERSION}" ]] ||
    fail "версия Kubespray изменилась после предустановочной проверки"

LOG_FILE="${LOG_DIR}/kubespray-install-$(date -u +%Y%m%dT%H%M%SZ).log"
INSTALL_SUCCESS_FILE="${LOG_DIR}/kubespray-install-success.env"
touch -- "${LOG_FILE}"
chmod 600 -- "${LOG_FILE}"
exec > >(tee -a "${LOG_FILE}") 2>&1

printf 'KUBESPRAY_INSTALL_START=%s\n' "$(date --iso-8601=seconds)"
printf 'PROJECT_DIR=%s\n' "${PROJECT_DIR}"
printf 'KUBESPRAY_DIR=%s\n' "${KUBESPRAY_DIR}"
printf 'INVENTORY_FILE=%s\n' "${INVENTORY_FILE}"
printf 'PREFLIGHT_LOG=%s\n' "${PREFLIGHT_LOG}"
printf 'INSTALL_LOG=%s\n' "${LOG_FILE}"
printf 'CONFIGURATION_DIGEST=%s\n' "${CURRENT_CONFIGURATION_DIGEST}"

VENV_PYTHON="${VENV_DIR}/bin/python"
VENV_ANSIBLE="${VENV_DIR}/bin/ansible"
VENV_ANSIBLE_PLAYBOOK="${VENV_DIR}/bin/ansible-playbook"

for executable in \
    "${VENV_PYTHON}" \
    "${VENV_ANSIBLE}" \
    "${VENV_ANSIBLE_PLAYBOOK}"
do
    [[ -x "${executable}" ]] ||
        fail "виртуальное окружение неполно: отсутствует ${executable}"
done

export ANSIBLE_CONFIG="${KUBESPRAY_DIR}/ansible.cfg"
export ANSIBLE_LOCAL_TEMP="/tmp/ansible-kubespray-install-local-${UID}"
export ANSIBLE_REMOTE_TEMP="/tmp/ansible-kubespray-install-${UID}"

printf '\n===== KUBESPRAY_FINAL_STATIC_CHECK =====\n'

"${VENV_ANSIBLE_PLAYBOOK}" \
    -i "${INVENTORY_FILE}" \
    "${KUBESPRAY_DIR}/cluster.yml" \
    --syntax-check

printf 'KUBESPRAY_FINAL_STATIC_CHECK_RESULT=SUCCESS\n'

printf '\n===== KUBESPRAY_CLUSTER_DEPLOYMENT =====\n'

cd "${KUBESPRAY_DIR}"

"${VENV_ANSIBLE_PLAYBOOK}" \
    -i "${INVENTORY_FILE}" \
    --become \
    --forks 6 \
    -v \
    cluster.yml

printf 'KUBESPRAY_CLUSTER_DEPLOYMENT_RESULT=SUCCESS\n'

printf '\n===== POSTINSTALL_SERVICE_AND_CLUSTER_VALIDATION =====\n'

POSTINSTALL_PLAYBOOK="$(mktemp /tmp/kubespray-postinstall.XXXXXX.yml)"
SMOKE_NAMESPACE="kubespray-smoke-$(date -u +%Y%m%d%H%M%S)"

cat > "${POSTINSTALL_PLAYBOOK}" <<'ANSIBLE_POSTINSTALL_PLAYBOOK_EOF'
---
- name: Verify node services after Kubespray deployment
  hosts: all
  gather_facts: false
  become: true
  any_errors_fatal: true

  tasks:
    - name: Read containerd state
      ansible.builtin.command:
        argv:
          - systemctl
          - is-active
          - containerd
      register: containerd_state
      changed_when: false

    - name: Read kubelet state
      ansible.builtin.command:
        argv:
          - systemctl
          - is-active
          - kubelet
      register: kubelet_state
      changed_when: false

    - name: Verify CRI operation
      ansible.builtin.command:
        argv:
          - crictl
          - info
      register: crictl_info
      changed_when: false

    - name: Assert node service health
      ansible.builtin.assert:
        that:
          - containerd_state.stdout | trim == 'active'
          - kubelet_state.stdout | trim == 'active'
          - crictl_info.rc == 0
        fail_msg: containerd, kubelet or CRI is not healthy.
        success_msg: NODE_SERVICES=SUCCESS

- name: Verify etcd services
  hosts: etcd
  gather_facts: false
  become: true
  any_errors_fatal: true

  tasks:
    - name: Read etcd state
      ansible.builtin.command:
        argv:
          - systemctl
          - is-active
          - etcd
      register: etcd_state
      changed_when: false

    - name: Assert etcd service health
      ansible.builtin.assert:
        that:
          - etcd_state.stdout | trim == 'active'
        fail_msg: etcd service is not active.
        success_msg: ETCD_SERVICE=SUCCESS

- name: Verify Kubernetes API, workloads, DNS and inter-node pod network
  hosts: k8s-master-ru-central1-a
  gather_facts: false
  become: true
  any_errors_fatal: true

  vars:
    kubeconfig_path: /etc/kubernetes/admin.conf

  tasks:
    - name: Wait for the Kubernetes API ready endpoint
      ansible.builtin.command:
        argv:
          - kubectl
          - --kubeconfig
          - "{{ kubeconfig_path }}"
          - get
          - --raw=/readyz
      register: api_ready
      changed_when: false
      retries: 60
      delay: 10
      until:
        - api_ready.rc == 0
        - api_ready.stdout | trim == 'ok'

    - name: Wait for all nodes to become Ready
      ansible.builtin.command:
        argv:
          - kubectl
          - --kubeconfig
          - "{{ kubeconfig_path }}"
          - wait
          - --for=condition=Ready
          - nodes
          - --all
          - --timeout=900s
      register: nodes_ready
      changed_when: false

    - name: Wait for all kube-system deployments
      ansible.builtin.command:
        argv:
          - kubectl
          - --kubeconfig
          - "{{ kubeconfig_path }}"
          - --namespace=kube-system
          - wait
          - --for=condition=Available
          - deployments
          - --all
          - --timeout=900s
      register: deployments_ready
      changed_when: false

    - name: Validate Kubernetes objects by JSON state
      ansible.builtin.shell: |
        set -Eeuo pipefail
        export KUBECONFIG="{{ kubeconfig_path }}"

        kubectl get --raw=/livez | grep -Fx ok
        kubectl get --raw=/readyz | grep -Fx ok

        kubectl get nodes -o json |
            python3 -c '
        import json
        import sys

        data = json.load(sys.stdin)
        items = data.get("items", [])
        if len(items) != 6:
            raise SystemExit(f"expected 6 nodes, found {len(items)}")

        control = 0
        workers = 0
        for node in items:
            name = node["metadata"]["name"]
            labels = node["metadata"].get("labels", {})
            conditions = {
                item["type"]: item["status"]
                for item in node.get("status", {}).get("conditions", [])
            }
            if conditions.get("Ready") != "True":
                raise SystemExit(f"node {name} is not Ready")
            if "node-role.kubernetes.io/control-plane" in labels:
                control += 1
            else:
                workers += 1

        if (control, workers) != (3, 3):
            raise SystemExit(
                f"expected 3 control-plane and 3 worker nodes; "
                f"found {control} and {workers}"
            )
        print("NODE_TOPOLOGY_AND_READINESS=SUCCESS")
        '

        kubectl --namespace=kube-system get pods -o json |
            python3 -c '
        import json
        import sys

        data = json.load(sys.stdin)
        failures = []
        for pod in data.get("items", []):
            name = pod["metadata"]["name"]
            phase = pod.get("status", {}).get("phase")
            if phase not in {"Running", "Succeeded"}:
                failures.append(f"{name}:{phase}")
                continue
            if phase == "Running":
                statuses = pod.get("status", {}).get("containerStatuses", [])
                if not statuses or not all(item.get("ready") for item in statuses):
                    failures.append(f"{name}:containers-not-ready")

        if failures:
            raise SystemExit("unhealthy kube-system pods: " + ",".join(failures))
        print("KUBE_SYSTEM_PODS=SUCCESS")
        '

        kubectl --namespace=kube-system get daemonsets -o json |
            python3 -c '
        import json
        import sys

        data = json.load(sys.stdin)
        failures = []
        for daemonset in data.get("items", []):
            name = daemonset["metadata"]["name"]
            status = daemonset.get("status", {})
            desired = int(status.get("desiredNumberScheduled", 0))
            ready = int(status.get("numberReady", 0))
            unavailable = int(status.get("numberUnavailable", 0))
            if desired == 0 or ready != desired or unavailable != 0:
                failures.append(f"{name}:{ready}/{desired}")

        if failures:
            raise SystemExit("unhealthy daemonsets: " + ",".join(failures))
        print("KUBE_SYSTEM_DAEMONSETS=SUCCESS")
        '

        kubectl get nodes -o wide
        kubectl --namespace=kube-system get pods -o wide
      args:
        executable: /bin/bash
      register: cluster_json_validation
      changed_when: false

    - name: Display cluster validation report
      ansible.builtin.debug:
        var: cluster_json_validation.stdout_lines

    - name: Run temporary DNS, Service and cross-zone pod-network test
      ansible.builtin.shell: |
        set -Eeuo pipefail
        export KUBECONFIG="{{ kubeconfig_path }}"
        namespace="{{ smoke_namespace }}"

        cleanup_smoke_test()
        {
            kubectl delete namespace "${namespace}" \
                --ignore-not-found=true \
                --wait=false \
                >/dev/null 2>&1 || true
        }

        trap cleanup_smoke_test EXIT

        kubectl create namespace "${namespace}"

        kubectl --namespace "${namespace}" apply -f - <<'SMOKE_SERVER_EOF'
        apiVersion: v1
        kind: Pod
        metadata:
          name: server
          labels:
            app: kubespray-smoke-server
        spec:
          nodeName: k8s-worker-ru-central1-a
          restartPolicy: Never
          containers:
            - name: server
              image: busybox:1.36.1
              imagePullPolicy: IfNotPresent
              command:
                - /bin/sh
                - -ec
                - mkdir -p /www; echo KUBESPRAY_NETWORK_OK > /www/index.html; httpd -f -p 8080 -h /www
              readinessProbe:
                httpGet:
                  path: /
                  port: 8080
                initialDelaySeconds: 1
                periodSeconds: 2
        ---
        apiVersion: v1
        kind: Service
        metadata:
          name: server
        spec:
          selector:
            app: kubespray-smoke-server
          ports:
            - name: http
              port: 8080
              targetPort: 8080
        SMOKE_SERVER_EOF

        kubectl --namespace "${namespace}" wait \
            --for=condition=Ready \
            pod/server \
            --timeout=600s

        kubectl --namespace "${namespace}" apply -f - <<'SMOKE_CLIENT_EOF'
        apiVersion: v1
        kind: Pod
        metadata:
          name: client
        spec:
          nodeName: k8s-worker-ru-central1-d
          restartPolicy: Never
          containers:
            - name: client
              image: busybox:1.36.1
              imagePullPolicy: IfNotPresent
              command:
                - /bin/sh
                - -ec
                - |
                  nslookup kubernetes.default.svc.cluster.local
                  nslookup server
                  response="$(wget -qO- http://server:8080/)"
                  test "${response}" = "KUBESPRAY_NETWORK_OK"
                  echo DNS_SERVICE_AND_CROSS_ZONE_POD_NETWORK=SUCCESS
        SMOKE_CLIENT_EOF

        for attempt in $(seq 1 120)
        do
            phase="$(
                kubectl --namespace "${namespace}" get pod client \
                    -o jsonpath='{.status.phase}'
            )"

            case "${phase}" in
                Succeeded)
                    break
                    ;;
                Failed)
                    kubectl --namespace "${namespace}" describe pod client
                    kubectl --namespace "${namespace}" logs client || true
                    exit 70
                    ;;
            esac

            sleep 5
        done

        final_phase="$(
            kubectl --namespace "${namespace}" get pod client \
                -o jsonpath='{.status.phase}'
        )"
        [[ "${final_phase}" == "Succeeded" ]]

        kubectl --namespace "${namespace}" logs client
        kubectl delete namespace "${namespace}" --wait=true --timeout=300s
        trap - EXIT

        printf 'POSTINSTALL_SMOKE_TEST_RESULT=SUCCESS\n'
      args:
        executable: /bin/bash
      environment:
        SMOKE_NAMESPACE: "{{ smoke_namespace }}"
      register: smoke_test
      changed_when: false

    - name: Display smoke-test report
      ansible.builtin.debug:
        var: smoke_test.stdout_lines
ANSIBLE_POSTINSTALL_PLAYBOOK_EOF

"${VENV_ANSIBLE_PLAYBOOK}" \
    -i "${INVENTORY_FILE}" \
    "${POSTINSTALL_PLAYBOOK}" \
    --syntax-check \
    -e "smoke_namespace=${SMOKE_NAMESPACE}"

"${VENV_ANSIBLE_PLAYBOOK}" \
    -i "${INVENTORY_FILE}" \
    "${POSTINSTALL_PLAYBOOK}" \
    -e "smoke_namespace=${SMOKE_NAMESPACE}"

printf 'POSTINSTALL_SERVICE_AND_CLUSTER_VALIDATION_RESULT=SUCCESS\n'

printf '\n===== SAVE_ADMIN_KUBECONFIG =====\n'

mkdir -p -- "$(dirname "${LOCAL_KUBECONFIG}")"

"${VENV_ANSIBLE}" \
    -i "${INVENTORY_FILE}" \
    k8s-master-ru-central1-a \
    --become \
    --module-name ansible.builtin.fetch \
    --args "src=/etc/kubernetes/admin.conf dest=${LOCAL_KUBECONFIG} flat=true"

[[ -s "${LOCAL_KUBECONFIG}" ]] ||
    fail "локальная копия admin.conf не создана"
chmod 600 -- "${LOCAL_KUBECONFIG}"

printf 'LOCAL_KUBECONFIG=%s\n' "${LOCAL_KUBECONFIG}"
printf 'LOCAL_KUBECONFIG_MODE=600\n'
printf 'LOCAL_KUBECONFIG_RESULT=SUCCESS\n'

printf '\n===== INSTALLATION_ATTESTATION =====\n'

INSTALL_SUCCESS_TEMP="${INSTALL_SUCCESS_FILE}.tmp.$$"
{
    printf 'KUBESPRAY_INSTALL_RESULT=SUCCESS\n'
    printf 'INSTALL_EPOCH=%s\n' "$(date +%s)"
    printf 'CONFIGURATION_DIGEST=%s\n' "${CURRENT_CONFIGURATION_DIGEST}"
    printf 'PROJECT_HEAD=%s\n' "${CURRENT_PROJECT_HEAD}"
    printf 'KUBESPRAY_VERSION=%s\n' "${EXPECTED_KUBESPRAY_VERSION}"
    printf 'INSTALL_LOG=%s\n' "${LOG_FILE}"
    printf 'LOCAL_KUBECONFIG=%s\n' "${LOCAL_KUBECONFIG}"
} > "${INSTALL_SUCCESS_TEMP}"

chmod 600 -- "${INSTALL_SUCCESS_TEMP}"
mv -f -- "${INSTALL_SUCCESS_TEMP}" "${INSTALL_SUCCESS_FILE}"

printf 'KUBESPRAY_FINAL_STATIC_CHECK_RESULT=SUCCESS\n'
printf 'KUBESPRAY_CLUSTER_DEPLOYMENT_RESULT=SUCCESS\n'
printf 'POSTINSTALL_SERVICE_AND_CLUSTER_VALIDATION_RESULT=SUCCESS\n'
printf 'LOCAL_KUBECONFIG_RESULT=SUCCESS\n'
printf 'GIT_COMMIT=NOT_EXECUTED\n'
printf 'GIT_PUSH=NOT_EXECUTED\n'
printf 'KUBESPRAY_INSTALL_RESULT=SUCCESS\n'
printf 'KUBESPRAY_INSTALL_END=%s\n' "$(date --iso-8601=seconds)"
