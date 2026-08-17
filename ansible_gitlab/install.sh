PROJECT_DIR="/home/vgorshkov/STUDENT1/PROJECT/diplom-devops"
TERRAFORM_DIR="$PROJECT_DIR/terraform_infra"
ANSIBLE_DIR="$PROJECT_DIR/ansible_gitlab"


printf '\n===== 1. КОНФИГУРАЦИЯ ANSIBLE ДЛЯ GITLAB =====\n'

mkdir -p "$ANSIBLE_DIR"
cd "$ANSIBLE_DIR"


printf '\n===== 2. ПРОВЕРКА СОЗДАННЫХ ФАЙЛОВ =====\n'

ls -la ansible.cfg hosts.yml install-gitlab.yml

printf '\n===== 3. ПРОВЕРКА INVENTORY =====\n'

ansible-inventory --graph
INVENTORY_RC=$?

printf 'Код проверки inventory: %s\n' "$INVENTORY_RC"

printf '\n===== 4. ПРОВЕРКА СИНТАКСИСА PLAYBOOK =====\n'

ansible-playbook --syntax-check install-gitlab.yml
SYNTAX_RC=$?

printf 'Код проверки синтаксиса: %s\n' "$SYNTAX_RC"

printf '\n===== 5. ПРОВЕРКА СОЕДИНЕНИЯ =====\n'

ansible gitlab -m ansible.builtin.ping
PING_RC=$?

printf 'Код проверки соединения: %s\n' "$PING_RC"

if [[ "$INVENTORY_RC" -eq 0 && "$SYNTAX_RC" -eq 0 && "$PING_RC" -eq 0 ]]; then
    printf '\n===== 6. УСТАНОВКА И ПРОВЕРКА GITLAB CE =====\n'

    ansible-playbook install-gitlab.yml
    INSTALL_RC=$?

    printf '\nКод выполнения playbook: %s\n' "$INSTALL_RC"
else
    INSTALL_RC=1
    printf '\nУстановка не запускалась: предварительная проверка завершилась с ошибкой.\n'
fi

ls -la "$ANSIBLE_DIR"

if [[ -f "$ANSIBLE_DIR/secrets/initial_root_password" ]]; then
    ls -la "$ANSIBLE_DIR/secrets/initial_root_password"
    printf 'Пароль сохранён, но его значение не выводилось.\n'
else
    printf 'Файл initial_root_password пока отсутствует.\n'
fi

printf '\nТекущий каталог:\n'
pwd

