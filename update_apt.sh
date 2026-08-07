#Update зеркало дистрибутивов на всех нодах
for host in k8s-master-ru-central1-a k8s-master-ru-central1-b k8s-master-ru-central1-d k8s-worker-ru-central1-a k8s-worker-ru-central1-b k8s-worker-ru-central1-d; do
  echo "=== $host ==="
  ssh $host "sudo sed -i 's/mirror\.yandex\.ru/archive.ubuntu.com/g' /etc/apt/sources.list"
done
