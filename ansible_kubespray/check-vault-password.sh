
echo "===== ПРОВЕРКА ANSIBLE VAULT ====="
echo "Файл: $(pwd)/group_vars/vault-monitoring.yml"
echo

echo "Заголовок зашифрованного файла:"
head -n 1 group_vars/vault-monitoring.yml
echo

VAULT_CONTENT=$(ansible-vault view \
    group_vars/vault-monitoring.yml \
    --ask-vault-pass)

VAULT_RC=$?
echo

if [ "$VAULT_RC" -eq 0 ]; then
    echo "Результат: Ansible Vault успешно расшифрован."
    echo
    echo "===== СОХРАНЁННЫЕ ПЕРЕМЕННЫЕ ====="

    printf '%s\n' "$VAULT_CONTENT" |
        sed -E 's/^([[:space:]]*vault_grafana_admin_password:).*/\1 "********"/'
else
    echo "Результат: ошибка расшифровки Ansible Vault."
fi

unset VAULT_CONTENT VAULT_RC

echo
echo "===== ПРОВЕРКА ЗАВЕРШЕНА ====="


