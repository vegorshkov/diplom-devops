# Активируем venv
source ~/venv-ansible/bin/activate

# Переходим в kubespray
cd /home/vgorshkov/STUDENT1/PROJECT/diplom-devops/ansible_kubespray/kubespray

# Проверяем что инвентарь на месте
ls inventory/diplom/hosts.yaml

# Запускаем с явной версией
ansible-playbook -i inventory/diplom/hosts.yaml cluster.yml -e kube_version=v1.30.6
