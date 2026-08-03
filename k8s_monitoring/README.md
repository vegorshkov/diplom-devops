# Kubernetes Monitoring

## Назначение
Развёртывание стека мониторинга в кластере Kubernetes с помощью kube-prometheus.

## Компоненты
- Prometheus (сбор метрик)
- Grafana (визуализация, дашборды)
- Alertmanager (оповещения)
- Node Exporter (метрики узлов)

## Установка (из репозитория kube-prometheus)

```bash
# Клонируем kube-prometheus
git clone https://github.com/prometheus-operator/kube-prometheus.git /tmp/kube-prometheus
cd /tmp/kube-prometheus

# Шаг 1: CRDs и операторы
kubectl apply --server-side -f manifests/setup/

# Шаг 2: Основные компоненты
kubectl apply -f manifests/

# Проверка
kubectl get pods -n monitoring
