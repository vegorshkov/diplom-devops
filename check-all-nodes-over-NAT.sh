# Проверяем доступность нод через NAT-инстанс
for host in k8s-master-ru-central1-a k8s-master-ru-central1-e k8s-master-ru-central1-d k8s-worker-ru-central1-a k8s-worker-ru-central1-e k8s-worker-ru-central1-d gitlab-server; do
  echo -n "$host: "
  ssh -o ConnectTimeout=5 $host "hostname -I" 2>/dev/null || echo "недоступен"
done

