# Ansible Kubespray

## Назначение
Развёртывание отказоустойчивого кластера Kubernetes (3 master + 3 worker) с помощью Kubespray.

## Отказоустойчивость
- **kube‑vip** обеспечивает виртуальный IP (`172.16.2.100`), который автоматически переключается между мастер‑нодами.
- Клиенты (kubectl, worker‑ноды) обращаются к API-серверу через этот VIP.
- При отказе одного мастера остальные продолжают обслуживать запросы.

## Структура
- `inventory/hosts.yml` — хосты и группы
- `group_vars/` — конфигурация кластера, CNI, kube‑vip

## Развертывание
```bash
# Клонируем Kubespray
git clone https://github.com/kubernetes-sigs/kubespray.git /tmp/kubespray
cd /tmp/kubespray

# Копируем наш инвентарь
cp -r /home/vgorshkov/STUDENT1/PROJECT/diplom-devops/ansible_kubespray/inventory ./inventory/diplo
cp -r /home/vgorshkov/STUDENT1/PROJECT/diplom-devops/ansible_kubespray/group_vars ./inventory/diplo/

# Запускаем развёртывание
ansible-playbook -i inventory/diplo/hosts.yml cluster.yml




