#!/usr/bin/env bash

set -Eeuo pipefail

CONTROL_PLANE_HOST="${CONTROL_PLANE_HOST:-k8s-master-ru-central1-a}"

CONTROL_PLANE_NODES=(
  k8s-master-ru-central1-a
  k8s-master-ru-central1-d
  k8s-master-ru-central1-e
)

echo "============================================================"
echo "ПРОВЕРКА HELM И METRICS SERVER"
echo "Управляющий узел: ${CONTROL_PLANE_HOST}"
echo "Время запуска: $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo "============================================================"

echo
echo "===== 1. ПРОВЕРКА ДОСТУПНОСТИ УПРАВЛЯЮЩИХ УЗЛОВ ====="

for host in "${CONTROL_PLANE_NODES[@]}"; do
  if ssh -o BatchMode=yes -o ConnectTimeout=10 "${host}" "true"; then
    echo "${host}: доступен"
  else
    echo "${host}: недоступен"
    exit 1
  fi
done

echo
echo "===== 2. ВЕРСИЯ HELM НА УПРАВЛЯЮЩИХ УЗЛАХ ====="

for host in "${CONTROL_PLANE_NODES[@]}"; do
  echo
  echo "--- ${host} ---"

  if ssh "${host}" "command -v helm >/dev/null 2>&1"; then
    ssh "${host}" "helm version --short"
  else
    echo "ОШИБКА: Helm не установлен"
    exit 1
  fi
done

ssh "${CONTROL_PLANE_HOST}" 'bash -s' <<'REMOTE'
set -Eeuo pipefail

KUBECTL=(sudo kubectl --kubeconfig=/etc/kubernetes/admin.conf)

echo
echo "===== 3. ВЕРСИЯ KUBERNETES ====="
"${KUBECTL[@]}" version

echo
echo "===== 4. СОСТОЯНИЕ УЗЛОВ ====="
"${KUBECTL[@]}" get nodes -o wide

NOT_READY_NODES="$(
  "${KUBECTL[@]}" get nodes \
    --no-headers \
    -o custom-columns='NAME:.metadata.name,READY:.status.conditions[?(@.type=="Ready")].status' |
  awk '$2 != "True" {print $1}'
)"

if [[ -n "${NOT_READY_NODES}" ]]; then
  echo
  echo "ОШИБКА: обнаружены неготовые узлы:"
  echo "${NOT_READY_NODES}"
  exit 1
fi

echo
echo "Все узлы Kubernetes находятся в состоянии Ready."

echo
echo "===== 5. ОБЪЕКТЫ METRICS SERVER ====="
"${KUBECTL[@]}" get deployment metrics-server -n kube-system -o wide
"${KUBECTL[@]}" get pods -n kube-system -l k8s-app=metrics-server -o wide
"${KUBECTL[@]}" get service metrics-server -n kube-system -o wide

echo
echo "===== 6. ОЖИДАНИЕ ГОТОВНОСТИ METRICS SERVER ====="

if ! "${KUBECTL[@]}" rollout status \
  deployment/metrics-server \
  -n kube-system \
  --timeout=180s; then

  echo
  echo "ОШИБКА: Deployment metrics-server не перешёл в готовое состояние."

  echo
  echo "===== ОПИСАНИЕ DEPLOYMENT ====="
  "${KUBECTL[@]}" describe deployment metrics-server -n kube-system || true

  echo
  echo "===== СОСТОЯНИЕ POD ====="
  "${KUBECTL[@]}" get pods -n kube-system -l k8s-app=metrics-server -o wide || true

  echo
  echo "===== ЛОГИ METRICS SERVER ====="
  "${KUBECTL[@]}" logs \
    -n kube-system \
    deployment/metrics-server \
    --all-containers=true \
    --tail=100 || true

  echo
  echo "===== ПОСЛЕДНИЕ СОБЫТИЯ ====="
  "${KUBECTL[@]}" get events \
    -n kube-system \
    --sort-by=.lastTimestamp |
  tail -n 30 || true

  exit 1
fi

echo
echo "===== 7. СОСТОЯНИЕ METRICS API ====="
"${KUBECTL[@]}" get apiservice v1beta1.metrics.k8s.io -o wide

echo
echo "Ожидание доступности Metrics API..."

if ! "${KUBECTL[@]}" wait \
  --for=condition=Available \
  apiservice/v1beta1.metrics.k8s.io \
  --timeout=180s; then

  echo
  echo "ОШИБКА: Metrics API не перешёл в состояние Available."
  "${KUBECTL[@]}" describe apiservice v1beta1.metrics.k8s.io || true
  exit 1
fi

echo
echo "===== 8. МЕТРИКИ УЗЛОВ ====="
"${KUBECTL[@]}" top nodes

echo
echo "===== 9. МЕТРИКИ POD ====="
"${KUBECTL[@]}" top pods -A

echo
echo "===== 10. СОСТОЯНИЕ ПРИЛОЖЕНИЯ INFRA ====="

if "${KUBECTL[@]}" get deployment infra -n default >/dev/null 2>&1; then
  "${KUBECTL[@]}" get deployment infra -n default -o wide

  echo
  echo "--- Распределение реплик по узлам ---"
  "${KUBECTL[@]}" get pods \
    -n default \
    -l app=infra \
    -o custom-columns='POD:.metadata.name,NODE:.spec.nodeName,IP:.status.podIP,READY:.status.containerStatuses[0].ready,STATUS:.status.phase'

  echo
  echo "--- Service ---"
  "${KUBECTL[@]}" get service infra -n default -o wide

  echo
  echo "--- EndpointSlice ---"
  "${KUBECTL[@]}" get endpointslices.discovery.k8s.io \
    -n default \
    -l kubernetes.io/service-name=infra \
    -o wide

  echo
  echo "--- Проверка /api/health через Service ---"
  "${KUBECTL[@]}" get \
    --raw '/api/v1/namespaces/default/services/infra:http/proxy/api/health'

  echo
else
  echo "ПРЕДУПРЕЖДЕНИЕ: Deployment infra в namespace default не найден."
fi

echo
echo "============================================================"
echo "РЕЗУЛЬТАТ: HELM И METRICS SERVER РАБОТАЮТ ШТАТНО"
echo "УЗЛЫ КЛАСТЕРА ДОСТУПНЫ, METRICS API ОТВЕЧАЕТ"
echo "============================================================"
REMOTE
