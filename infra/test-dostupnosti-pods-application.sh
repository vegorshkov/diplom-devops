ssh k8s-master-ru-central1-a 'bash -s' <<'REMOTE'
set -u
set -o pipefail

KUBECTL=(sudo kubectl --kubeconfig=/etc/kubernetes/admin.conf --namespace=default)
TARGET_NODE="k8s-worker-ru-central1-d"

echo "===== ИСХОДНОЕ РАСПРЕДЕЛЕНИЕ ====="

"${KUBECTL[@]}" get deployment infra -o wide

"${KUBECTL[@]}" get pods -l app=infra \
  -o custom-columns=POD:.metadata.name,NODE:.spec.nodeName,IP:.status.podIP,READY:.status.containerStatuses[0].ready,STATUS:.status.phase

TARGET_POD="$(
  "${KUBECTL[@]}" get pods \
    -l app=infra \
    --field-selector="spec.nodeName=${TARGET_NODE}" \
    -o jsonpath='{.items[0].metadata.name}'
)"

if [[ -z "$TARGET_POD" ]]; then
  echo "ОШИБКА: pod на узле ${TARGET_NODE} не найден"
  exit 1
fi

echo
echo "Удаляем pod: ${TARGET_POD}"
echo "Узел: ${TARGET_NODE}"

"${KUBECTL[@]}" delete pod "$TARGET_POD" --wait=false

echo
echo "===== НАБЛЮДЕНИЕ ЗА ВОССТАНОВЛЕНИЕМ ====="

RECOVERED=0

for attempt in {1..60}; do
  echo
  echo "Проверка ${attempt}/60, время: $(date '+%H:%M:%S')"

  "${KUBECTL[@]}" get pods -l app=infra \
    -o custom-columns=POD:.metadata.name,NODE:.spec.nodeName,IP:.status.podIP,READY:.status.containerStatuses[0].ready,STATUS:.status.phase

  TOTAL_COUNT="$("${KUBECTL[@]}" get pods -l app=infra --no-headers | wc -l)"

  READY_COUNT="$(
    "${KUBECTL[@]}" get pods -l app=infra \
      -o jsonpath='{range .items[*]}{.status.containerStatuses[0].ready}{"\n"}{end}' |
    awk '$1 == "true" { count++ } END { print count + 0 }'
  )"

  OLD_POD="$("${KUBECTL[@]}" get pod "$TARGET_POD" --ignore-not-found -o name)"

  if [[ "$TOTAL_COUNT" -eq 3 && "$READY_COUNT" -eq 3 && -z "$OLD_POD" ]]; then
    RECOVERED=1
    break
  fi

  sleep 2
done

echo
echo "===== ИТОГОВОЕ РАСПРЕДЕЛЕНИЕ ====="

"${KUBECTL[@]}" get deployment infra -o wide

"${KUBECTL[@]}" get pods -l app=infra \
  -o custom-columns=POD:.metadata.name,NODE:.spec.nodeName,IP:.status.podIP,READY:.status.containerStatuses[0].ready,STATUS:.status.phase

echo
echo "===== СОБЫТИЯ ====="

"${KUBECTL[@]}" get events --sort-by=.lastTimestamp | tail -n 25

if [[ "$RECOVERED" -ne 1 ]]; then
  echo
  echo "ОШИБКА: три готовые реплики не восстановились за 120 секунд"
  exit 1
fi

echo
echo "РЕЗУЛЬТАТ: Deployment автоматически восстановил три готовые реплики."
REMOTE

