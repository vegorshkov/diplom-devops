# diplom-devops
Дипломная работа (graduate work)

git@github.com:vegorshkov/diplom-devops.git

## Исправленная структура диплома (чистовик):

---

### ВВЕДЕНИЕ
- Актуальность автоматизации развёртывания инфраструктуры.
- Цель: создание отказоустойчивой платформы для CI/CD и мониторинга.
- Задачи.
- Экономическое обоснование (стоимость ресурсов, окупаемость).
- Технические риски при планировании.
---

### I. ПРОЕКТИРОВАНИЕ ОБЛАЧНОЙ ИНФРАСТРУКТУРЫ
1.1. Анализ требований и выбор облачного провайдера
1.2. Экономическое обоснование выбора ресурсов
1.3. Архитектура облачной инфраструктуры (схема)
1.4. Проектирование сетевой топологии (VPC, подсети, NAT)
1.5. Проектирование системы безопасности (IAM, Security Groups, Basic Auth)
1.6. Проектирование хранения состояния (S3 backend)

---

### II. РАЗВЁРТЫВАНИЕ ИНФРАСТРУКТУРЫ КАК КОД
2.1. Подготовка bootstrap-конфигурации Terraform
2.2. Создание сервисного аккаунта и S3-бакета
2.3. Развёртывание VPC и подсетей в разных зонах доступности
2.4. Развёртывание виртуальных машин (с обоснованием типов)
2.5. Настройка NAT-инстанса и Security Groups
2.6. Настройка Basic Auth (NGINX + HTTPS)

---

### III. РАЗВЁРТЫВАНИЕ KUBERNETES КЛАСТЕРА
3.1. Обоснование выбора метода установки (Kubespray)
3.2. Подготовка инвентаря и конфигурации Ansible
3.3. Развёртывание отказоустойчивого кластера (3 master + N worker)
3.4. Настройка CNI (Calico)
3.5. Проверка работоспособности и настройка ~/.kube/config

---

### IV. НАСТРОЙКА СИСТЕМЫ МОНИТОРИНГА
4.1. Выбор стека мониторинга (kube-prometheus)
4.2. Развёртывание Prometheus + Grafana + Alertmanager
4.3. Настройка дашбордов Grafana
4.4. Настройка доступа к Grafana через HTTPS (порт 443)
4.5. Проверка сбора метрик и алертов

---

### V. РАЗРАБОТКА И ДЕПЛОЙ ТЕСТОВОГО ПРИЛОЖЕНИЯ
5.1. Создание тестового приложения (nginx + статика)
5.2. Создание Dockerfile и сборка образа
5.3. Публикация образа в GitLab Container Registry
5.4. Деплой приложения в Kubernetes (Deployment, Service, Ingress)
5.5. Настройка доступа к приложению через HTTP

---

### VI. НАСТРОЙКА CI/CD И TERRAFORM PIPELINE
6.1. Развёртывание GitLab Server и GitLab Runner
6.2. Создание Terraform pipeline (автоприменение при коммите в main)
6.3. Создание пайплайна сборки Docker-образа
6.4. Создание пайплайна деплоя по тегу
6.5. Демонстрация работы CI/CD (скриншоты пайплайнов)

---

### VII. ТЕСТИРОВАНИЕ И ДЕМОНСТРАЦИЯ
7.1. Проверка отказоустойчивости кластера
7.2. Проверка автоматической сборки и деплоя
7.3. Предоставление доступа для проверки (преподавателям)

---

### VIII. ЭКОНОМИЧЕСКАЯ ЭФФЕКТИВНОСТЬ
8.1. Фактические затраты на развёртывание
8.2. Сравнение с альтернативными решениями
8.3. Расчёт окупаемости и экономического эффекта

---

### ЗАКЛЮЧЕНИЕ
- Итоги работы
- Достигнутые результаты
- Перспективы развития

---

### ПРИЛОЖЕНИЯ
- А. Листинги Terraform-конфигураций (bootstrap + main)
- Б. Листинги Ansible-плейбуков (Kubespray + Basic Auth)
- В. Листинги Kubernetes-манифестов (мониторинг + приложение)
- Г. Листинги GitLab CI/CD пайплайнов
- Д. Схема архитектуры
- Е. Скриншоты работающей системы

---


## Структура репозиториев:

```
gitlab.internal/
├── terraform-bootstrap/    # Сервисный аккаунт + S3
├── terraform-main/         # Вся инфраструктура
├── ansible-kubespray/      # Kubespray конфиги
├── ansible-basicauth/      # Basic Auth настройка
├── k8s-monitoring/         # kube-prometheus манифесты
├── k8s-test-app/           # Манифесты тестового приложения
├── test-app/               # Dockerfile + код приложения
└── docs/                   # Документация, схемы, скриншоты
```







--->
## ВВЕДЕНИЕ

В современных условиях стремительного развития информационных технологий ключевым фактором успешной разработки программного обеспечения является скорость и надёжность доставки изменений до конечного пользователя. Традиционные подходы к управлению инфраструктурой, основанные на ручном развёртывании серверов и настройке окружений, уже не отвечают требованиям бизнеса по времени вывода продукта на рынок. Автоматизация процессов развёртывания инфраструктуры с использованием подхода «инфраструктура как код» (Infrastructure as Code, IaC) позволяет сократить время подготовки среды с недель до минут, исключить человеческий фактор и обеспечить воспроизводимость результатов. Практика непрерывной интеграции и доставки (CI/CD) в сочетании с контейнеризацией и оркестрацией обеспечивает автоматическую сборку, тестирование и деплой приложений при каждом изменении кода, что является стандартом современной индустрии.

**Целью дипломной работы** является создание отказоустойчивой облачной платформы на базе Yandex Cloud, обеспечивающей автоматическую сборку, тестирование и развёртывание приложений с использованием Kubernetes, системы мониторинга на основе Prometheus и Grafana, а также полного цикла CI/CD.

**Для достижения поставленной цели необходимо решить следующие задачи:**
1. Спроектировать и развернуть облачную инфраструктуру с использованием Terraform
2. Развернуть отказоустойчивый кластер Kubernetes с помощью Kubespray
3. Настроить систему мониторинга на базе Prometheus, Grafana и Alertmanager
4. Разработать тестовое приложение и контейнеризировать его с помощью Docker
5. Развернуть GitLab Server и настроить пайплайны CI/CD
6. Реализовать автоматическое применение изменений инфраструктуры через Terraform pipeline
7. Обеспечить безопасный доступ ко всем сервисам через HTTPS с аутентификацией

**Экономическое обоснование.** Стоимость облачных ресурсов для развёртывания инфраструктуры, согласно проведённому тендерному анализу, составляет 3 650 рублей в месяц при использовании прерываемых виртуальных машин для рабочих узлов Kubernetes. Внешний статический IP-адрес резервируется на облачном аккаунте и сохраняется при остановке и повторном запуске виртуальных машин, что исключает необходимость изменения сетевых конфигураций при выключении ресурсов. Внедрение автоматизированной платформы CI/CD позволяет сократить время развёртывания новых версий приложения с нескольких часов до 5–10 минут, что эквивалентно экономии не менее 40 человеко-часов в месяц. При средней стоимости часа DevOps-инженера в 2 000 рублей, ежемесячная экономия составляет от 80 000 рублей. Таким образом, окупаемость платформы достигается в первый месяц эксплуатации.

**Дополнительная "Экономия на выключении ресурсов".**
Если выключать ресурсы на ночь (16 часов простоя), экономия составит ~60% от месячной стоимости:

NAT-инстанс — можно не выключать (внешний IP сохраняется, ~1500 руб/мес)
K8s worker nodes — прерываемые, можно выключать все (~1000 руб/мес экономии)
K8s master nodes — выключать, но не все сразу (для сохранения кворума etcd)
GitLab Server — выключать (~800 руб/мес экономии)
При таком режиме месячная стоимость снижается до 2000-2500 рублей.

![Тендер](image.png)

Анализ показывает ([LibreOffice-Анализ](<Анализ облачных провайдеров.ods>)), что Yandex Cloud предоставляет наиболее экономичное решение среди рассмотренных провайдеров.

Итоги тендерного отбора: Yandex Cloud предоставляет наиболее экономичное решение (3 650 руб/мес), что в 2,2 раза дешевле ближайшего конкурента Selectel и в 3,6 раза экономичнее AWS. Ключевыми преимуществами являются: отсутствие платы за управляющий слой Kubernetes, встроенная система мониторинга, наличие сертификации 152-ФЗ для государственных информационных систем. Китайские провайдеры предлагают конкурентоспособные цены, но имеют повышенный порог входа из-за языкового барьера и требований к верификации. В качестве резервной площадки рекомендуется Selectel, имеющий собственные центры обработки данных на территории Российской Федерации.

**Технические риски при планировании.** 
При проектировании отказоустойчивой инфраструктуры необходимо учитывать следующие технические риски, связанные с географическим распределением ресурсов:

Сетевая задержка между зонами доступности. Yandex Cloud использует как собственные, так и арендуемые центры обработки данных, расположенные в разных географических точках (Владимирская область, Московская область, Калужская область). Задержка между зонами может достигать 10-15 мс, что критично для работы распределённого key-value хранилища etcd, используемого Kubernetes для хранения состояния кластера. Согласно официальным рекомендациям, задержка между узлами etcd не должна превышать 5 мс для стабильной работы алгоритма консенсуса Raft.

Размещение мастер-нод Kubernetes. Для обеспечения кворума etcd и стабильной работы управляющего слоя принято решение разместить мастер-ноды в зонах ru-central1-a и ru-central1-b (собственные ЦОДы Яндекса с минимальной задержкой), в то время как рабочие узлы будут распределены по всем доступным зонам для демонстрации географической отказоустойчивости приложения.

Прерываемые виртуальные машины. Использование прерываемых ВМ для рабочих узлов снижает стоимость инфраструктуры на 60%, однако вносит риск принудительной остановки с уведомлением за 30 секунд. Для минимизации данного риска в кластере предусмотрено не менее трёх рабочих узлов с автоматическим перераспределением нагрузки при остановке одного из них.

Сетевые ограничения. В условиях нестабильной работы API Yandex Cloud возможно нарушение автоматического применения конфигураций Terraform из CI/CD пайплайна. Для снижения данного риска все критически важные артефакты (Docker-образы, конфигурации) хранятся локально в GitLab Container Registry, а Terraform-состояние реплицируется в S3-бакет с возможностью ручного восстановления.

Безопасность доступа. Размещение всех сервисов в приватных подсетях с единственной точкой входа через NAT-инстанс создаёт единую точку отказа. Для снижения риска на NAT-инстансе настроен автоматический перезапуск сервисов и мониторинг доступности, а критически важные порты зарезервированы в конфигурации Security Groups.

Учёт перечисленных рисков на этапе проектирования позволяет создать устойчивую инфраструктуру, сохраняющую работоспособность при отказе отдельных компонентов и обеспечивающую заявленные показатели доступности.
--->



diplom-devops/
├── authorized_key.json                        # Основной СА (для ресурсов)
├── authorized_key_terraform_state.json        # Новый СА (только для S3)
├── terraform_state/
│   └── main.tf                                # Создаёт СА + бакет
└── terraform_infra/
    └── backend.tf                             # Использует authorized_key_terraform_state.json


# 1. Применяем terraform_state
cd terraform_state/
terraform apply

# 2. Сохраняем output в JSON-файл
terraform output -json terraform_state_key_file > ../authorized_key_terraform_state.json

# 3. Используем в terraform_infra
cd ../terraform_infra/
terraform init -backend-config="access_key=$(jq -r .access_key ../authorized_key_terraform_state.json)" \
               -backend-config="secret_key=$(jq -r .secret_key ../authorized_key_terraform_state.json)"




Инструкция по использованию (для диплома):
```
# 1. Применяем terraform_state
cd terraform_state/
terraform apply

# 2. Сохраняем output в JSON-файл
terraform output -json terraform_state_key_file > ../authorized_key_terraform_state.json

# 3. Используем в terraform_infra
cd ../terraform_infra/
terraform init -backend-config="access_key=$(jq -r .access_key ../authorized_key_terraform_state.json)" \
               -backend-config="secret_key=$(jq -r .secret_key ../authorized_key_terraform_state.json)"
```

Производим проверки
cd /home/vgorshkov/STUDENT1/PROJECT/diplom-devops/terraform_state
terraform init
terraform validate

![alt text](image-1.png)


Выполняем проверку Инфры в локально
![alt text](image-2.png)

Выполняем проверку terraform-state
![alt text](image-3.png)
![alt text](image-4.png)

Проверяем ключи
![alt text](image-5.png)

Тераформ план прошел, яндекс cloud API доступен, должны быть созданы ресурсы:

1. Сервисный аккаунт terraform-state-sa
2. Статический ключ доступа
3. Роль storage.admin
4. S3-minio бакет terraform-state

Запускаем создание 
![alt text](image-6.png)
![alt text](image-7.png)

Сервисный аккаунт terraform-state-sa создан (aje1an77bngre1qdfa8g)
Статический ключ создан (ajeorc20mbsskl76mlhs)

Так как я запускал из под другого сервисного аккаунта terraform-sa, то у него не хватило прав
![alt text](image-9.png)
![alt text](image-8.png)

Корректируем. Добавим роль iam.admin для сервисного аккаунта под которым создается аккаунт для Terraform State   

Матрица прав доступа:
admin      -	Полный доступ ко всем ресурсам и управление доступом
iam.admin  -	Управление доступом (не может создавать ВМ, бакеты)
editor	   -    Создание и изменение ресурсов, он не может назначать роли

![IAM admin на УЗ](image-10.png)
![IAM admin на Каталог](image-11.png)

Бакет создаётся от имени terraform-sa (у которого storage.admin назначен ранее), и сгенерированы ключи для terraform-state-sa

![Бакет создан](image-12.png)

Итоговые права доступа:
![alt text](image-13.png)

После выполнения сохраняем ключи в локальные переменные системы, согласно рекомендаций best-practice terraform и yandex cloud  https://yandex.cloud/en/docs/tutorials/infrastructure-management/terraform-state-storage#linux_1

![Безопасная передача ключей в RAM](image-14.png)

Проведен краткий анализ используемого нами метода передачи ключей, в сравнении с рекомендациями Yandex, сохранен: [text](<Сравнение метода безопасного хранения токенов.ods>)
![Таблица 1](image-15.png)

Официальная инструкция передаёт ключи через -backend-config, что может сохранить их в .terraform/ и plan-файлах.

Наша схема использует стандартные переменные окружения AWS_ACCESS_KEY_ID и AWS_SECRET_ACCESS_KEY, которые S3 backend читает автоматически — это рекомендация HashiCorp для безопасной работы.


Переходим к созданию Infra-окружения
![Инфраструктура](image-16.png)

![alt text](image-17.png)
![alt text](image-18.png)
![alt text](image-19.png)
![alt text](image-20.png)
![alt text](image-21.png)
![alt text](image-22.png)
![alt text](image-23.png)
![alt text](image-24.png)
![alt text](image-25.png)
![alt text](image-26.png)
![alt text](image-27.png)
![alt text](image-28.png)
![alt text](image-29.png)
![alt text](image-30.png)
![alt text](image-31.png)
![alt text](image-32.png)

Зафиксируем первоначальное состояние бакета с терраформ состоянием:
![alt text](image-33.png)

Применим конфигурацию:
![alt text](image-36.png)
![alt text](image-37.png)
![alt text](image-38.png)

Машины созданы:
![Консоль Яндекса](image-35.png)

Локальный ~/.ssh/config скорректирован
![Подключение по ssh](image-34.png)

Outputs:
![Infrastructure](image-39.png)

Инфраструктура развертнута


Переходим на "Kubernetes через Kubespray"
![KubeSpray](image-41.png)

Склонировали из github Kubespray и поправили файл inventory согласно нашего конфига
![Kubespray_inventory](image-40.png)

Проверяем связь с хостами через Ansible:
![Success](image-42.png)

Установим модули kubespray
![alt text](image-43.png)

Блок команд:
```
set -euo pipefail

if [ -z "${VIRTUAL_ENV:-}" ]; then
    echo "Ошибка: виртуальное окружение не активировано."
    exit 1
fi

if [ ! -f requirements.txt ]; then
    echo "Ошибка: requirements.txt не найден. Перейдите в корневой каталог kubespray."
    exit 1
fi

PROXY_URL="socks5h://127.0.0.1:7777"
PYSOCKS_METADATA="/tmp/pysocks-pypi.json"

echo "Проверка SOCKS5-прокси"

curl \
    --fail \
    --show-error \
    --silent \
    --proxy "${PROXY_URL}" \
    --output /dev/null \
    https://pypi.org/simple/

echo "Получение метаданных PySocks"

curl \
    --fail \
    --show-error \
    --silent \
    --proxy "${PROXY_URL}" \
    --output "${PYSOCKS_METADATA}" \
    https://pypi.org/pypi/PySocks/json

PYSOCKS_WHEEL_URL="$(
    "${VIRTUAL_ENV}/bin/python" - "${PYSOCKS_METADATA}" <<'PY'
import json
import sys

metadata_file = sys.argv[1]

with open(metadata_file, encoding="utf-8") as file:
    metadata = json.load(file)

wheels = [
    item
    for item in metadata["urls"]
    if item["packagetype"] == "bdist_wheel"
    and item["filename"].endswith("py3-none-any.whl")
]

if not wheels:
    raise SystemExit("Подходящий wheel-файл PySocks не найден")

print(wheels[0]["url"])
PY
)"

PYSOCKS_WHEEL_NAME="${PYSOCKS_WHEEL_URL##*/}"
PYSOCKS_WHEEL_PATH="/tmp/${PYSOCKS_WHEEL_NAME}"

echo "Загрузка ${PYSOCKS_WHEEL_NAME}"

curl \
    --fail \
    --show-error \
    --location \
    --proxy "${PROXY_URL}" \
    --output "${PYSOCKS_WHEEL_PATH}" \
    "${PYSOCKS_WHEEL_URL}"

echo "Локальная установка PySocks"

"${VIRTUAL_ENV}/bin/python" -m pip install \
    --no-index \
    --no-deps \
    "${PYSOCKS_WHEEL_PATH}"

"${VIRTUAL_ENV}/bin/python" -c \
    'import socks; print("PySocks установлен:", socks.__version__)'

export ALL_PROXY="${PROXY_URL}"
export HTTPS_PROXY="${PROXY_URL}"
export HTTP_PROXY="${PROXY_URL}"

export all_proxy="${ALL_PROXY}"
export https_proxy="${HTTPS_PROXY}"
export http_proxy="${HTTP_PROXY}"

export NO_PROXY="${NO_PROXY:+${NO_PROXY},}127.0.0.1,localhost,::1"
export no_proxy="${NO_PROXY}"

echo "Установка зависимостей Kubespray"

"${VIRTUAL_ENV}/bin/python" -m pip install \
    --proxy "${PROXY_URL}" \
    --disable-pip-version-check \
    --requirement requirements.txt

if [ -f requirements.yml ]; then
    echo "Установка Ansible Collections"

    "${VIRTUAL_ENV}/bin/ansible-galaxy" collection install \
        --requirements-file requirements.yml
fi

echo "Проверка зависимостей Python"

"${VIRTUAL_ENV}/bin/python" -m pip check

echo "Проверка Ansible"

"${VIRTUAL_ENV}/bin/ansible" --version

echo "Проверка коллекции ansible.utils"

"${VIRTUAL_ENV}/bin/ansible-galaxy" collection list ansible.utils

echo "Проверка модуля ansible.utils.validate"

"${VIRTUAL_ENV}/bin/ansible-doc" \
    --type module \
    ansible.utils.validate \
    >/dev/null

echo "Синтаксическая проверка Kubespray"

"${VIRTUAL_ENV}/bin/ansible-playbook" \
    cluster.yml \
    --syntax-check

echo "Проверка завершена успешно"
```

Запускаем развертывание:
![alt text](image-44.png)
![alt text](image-45.png)
![alt text](image-46.png)
![alt text](image-47.png)
![alt text](image-48.png)
![alt text](image-49.png)

Провожу проверку/разбор ошибок.
Добавлен sudo доступ при выполнения команд
![alt text](image-50.png)
![alt text](image-51.png)

![Проверка перед установкой](image-52.png)
Проверки пройдены полностью. Установка управляющих зависимостей завершена.

Запускаем повторно:
![alt text](image-53.png)
![alt text](image-54.png)
![alt text](image-55.png)
![alt text](image-56.png)
![alt text](image-57.png)
![alt text](image-58.png)
![alt text](image-59.png)
![alt text](image-60.png)
![alt text](image-61.png)
![alt text](image-62.png)
![alt text](image-63.png)

Дозапускаем для двух отвалившихся нод.
Ansible идемпотентен - это свойство Ansible и его модулей, при котором многократное выполнение одной и той же задачи приводит к одному и тому же результату, не вызывая повторных изменений в системе.


Модернизирован код, в соответствии с документацией Яндекса, nat-instance разнесен с воркером, иначе образуется петля маршрутизации.
![alt text](image-64.png)

![Переразвертывание Destroy=0](image-65.png)
![alt text](image-66.png)
![alt text](image-67.png)

После правок, развернут Кластер k8s
![alt text](image-68.png)

Проверим состояние кластера
![alt text](image-69.png)


![alt text](image-70.png)
![alt text](image-71.png)
![alt text](image-72.png)

Все pods  стартовали
![alt text](image-73.png)

Кластер готов через KubeSpray
![alt text](image-74.png)
![alt text](image-75.png)


Далее, перейдем к деплою приложения котрое должно в графике мониторить состояние кластера и себя так же.

Деплоим приложение Infra:
Обновим приложение, для того, чтобы оно работало реальными данными из Kubernetes API. 
Создаём RBAC и деплой:
![alt text](image-76.png)

Обновление Deployment:
![alt text](image-77.png)

Собираем образ приложения изагружаем в Conteinerd

![alt text](image-78.png)

Загружаю приложение на мастер:
![alt text](image-79.png)

Загружаю с мастера на все ноды:
```
for host in k8s-master-ru-central1-d k8s-master-ru-central1-e \
            k8s-worker-ru-central1-a k8s-worker-ru-central1-d k8s-worker-ru-central1-e; do
  echo "=== $host ==="
  docker save infra:latest | ssh $host "sudo ctr -n k8s.io images import -" &
done
wait
```
![alt text](image-80.png)

Применяем RBAC:
![alt text](image-81.png)

RBAC применён успешно:

ServiceAccount infra-viewer создан;
ClusterRole infra-viewer создан;
ClusterRoleBinding infra-viewer создан.

Ошибок нет. Повторное применение этих объектов будет идемпотентным.

Применяю Deployment
![alt text](image-82.png)

Приложение развернуто:
```
NAME                     READY   STATUS    NODE
infra-6df498986f-dvqxg   1/1     Running   k8s-worker-ru-central1-d

Лог: Infra server starting on :8080

```

![alt text](image-83.png)

POD_NAME=infra-6df498986f-dvqxg
{"status":"ok"}  -  приложение работает.


Произведем маштабирование приложения  replicas = 3

Каждое приложение будет мониторить состояние кубернетис кластера и отображать в консоли.
Конфликтовать они медлу собой не должны.

При маштабировании приложение распределяется по разным воркерам, и они размещаются по разным зонам (topology spread constraint и maxSkew: 1).

Допуск: если позднее появится еще несколько worker-узлов в одной зоне, kubernetes.io/hostname не сможет точно распределять приложение по разным зонам.

![alt text](image-84.png)

Проведем тестирование [Скрипт тестирования](infra/test-dostupnosti-pods-application.sh) доступности и переразвертывания aplication pods силами приложения:
![alt text](image-85.png)
![alt text](image-86.png)

Проверка самовосстановления приложения:

Приложение развёрнуто в трёх репликах, распределённых по worker-узлам в зонах `ru-central1-a`, `ru-central1-d` и `ru-central1-e`. При ручном удалении pod на узле `k8s-worker-ru-central1-d` контроллер Deployment автоматически создал новую реплику. Новый pod был запущен на освободившемся узле и перешёл в состояние `Ready` примерно за 10 секунд. Во время восстановления две остальные реплики продолжали работать. Проверка подтвердила самовосстановление приложения, сохранение заданного количества реплик и межзональное распределение.

Перейдем к настройке конфигурации Мониторинга:

1. Service — опубликовать приложение внутри кластера

2. Проверить доступность — через ClusterIP/NodePort

3. Запустить Мониторинг — kube-prometheus + Grafana

4. далее настройка CI/CD

Создаём Service: [text](infra/k8s/service.yaml)

Применяем
ssh k8s-master-ru-central1-a "sudo kubectl --kubeconfig=/etc/kubernetes/admin.conf apply -f -" < k8s/service.yaml

Проверяем
ssh k8s-master-ru-central1-a "sudo kubectl --kubeconfig=/etc/kubernetes/admin.conf get svc infra -o wide"

Проверяем эндпоинты
ssh k8s-master-ru-central1-a "sudo kubectl --kubeconfig=/etc/kubernetes/admin.conf get endpoints infra"

Проверяем доступность через Service
ssh k8s-master-ru-central1-a "sudo kubectl --kubeconfig=/etc/kubernetes/admin.conf run test-curl --rm -i --restart=Never --image=curlimages/curl -- curl -s http://infra:8080/api/health"
service/infra created
NAME    TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE   SELECTOR
infra   ClusterIP   10.233.22.136   <none>        8080/TCP   1s    app=infra
Warning: v1 Endpoints is deprecated in v1.33+; use discovery.k8s.io/v1 EndpointSlice
NAME    ENDPOINTS                                                  AGE
infra   10.233.108.68:8080,10.233.110.133:8080,10.233.88.70:8080   2s
All commands and output from this session will be recorded in container logs, including credentials and sensitive information passed through the command prompt.
If you don't see a command prompt, try pressing enter.
pod "test-curl" deleted from default namespace

Тест-под выполнил curl —  доступ через Service работает (вывод pod "test-curl" deleted —  тест завершился).

Выводы:
Компонент	             Статус
Deployment	             3 реплики по зонам
Service	ClusterIP        10.233.22.136:8080
Endpoints	             3 пода доступны
Health	                 curl http://infra:8080/api/health работает


### Настройка Мониторинга:

## Подготовка Kubernetes к установке системы мониторинга

Система мониторинга разворачивается непосредственно внутри Kubernetes-кластера. Для последующей установки компонентов мониторинга необходимо включить Helm и Metrics Server.

Helm используется для управления Kubernetes-пакетами. 
Metrics Server предоставляет API `metrics.k8s.io`, необходимый для получения текущих показателей использования CPU и памяти командами `kubectl top`, а также для работы механизмов автоматического масштабирования.


В файле `ansible_kubespray/inventory/group_vars/k8s_cluster/addons.yml` устанавливаются следующие параметры:

```yaml
helm_enabled: true
metrics_server_enabled: true
```

Обновлённая конфигурация применяется к существующему кластеру с помощью Kubespray:

```bash
cd /home/vgorshkov/STUDENT1/PROJECT/diplom-devops/ansible_kubespray/kubespray
source /home/vgorshkov/venv-kubespray-2.31.0/bin/activate

ansible-playbook \
  -i ../inventory/hosts.yaml \
  --become \
  --become-user=root \
  cluster.yml
```

Повторный запуск `cluster.yml` не создаёт новый кластер, а приводит его компоненты к состоянию, определённому в inventory Kubespray.

После завершения необходимо проверить доступность Helm и Metrics API:

```bash
ssh k8s-master-ru-central1-a "helm version --short"

ssh k8s-master-ru-central1-a \
  "sudo kubectl --kubeconfig=/etc/kubernetes/admin.conf get apiservice v1beta1.metrics.k8s.io"

ssh k8s-master-ru-central1-a \
  "sudo kubectl --kubeconfig=/etc/kubernetes/admin.conf top nodes"

ssh k8s-master-ru-central1-a \
  "sudo kubectl --kubeconfig=/etc/kubernetes/admin.conf top pods --all-namespaces"
```

Вывод Playbook:
![alt text](image-87.png)
![alt text](image-88.png)
![alt text](image-89.png)
![alt text](image-90.png)
![alt text](image-91.png)
![alt text](image-92.png)
![alt text](image-93.png)
![alt text](image-94.png)
![alt text](image-95.png)
![alt text](image-96.png)



Успешное выполнение подтверждает готовность Kubernetes-кластера к развёртыванию Prometheus, Grafana, Alertmanager, Node Exporter и kube-state-metrics.

Kubespray завершился успешно:

![alt text](image-97.png)
![alt text](image-98.png)

все 6 узлов: failed=0, unreachable=0;
продолжительность — около 14 минут 47 секунд;
Helm v3.18.4 установлен на трёх управляющих узлах;
образ Metrics Server v0.8.1 загружен;
манифесты Metrics Server сформированы и применены;
ошибок конфигурации Calico не обнаружено.

Количество changed ожидаемо: был выполнен полный cluster.yml, который повторно синхронизировал конфигурацию кластера и установил новые компоненты.

![alt text](image-99.png)
![alt text](image-100.png)
![alt text](image-101.png)

Добавим ресурсов для развертывания:
![alt text](image-102.png)

Установим kube-prometheus-stack для мониторинга [playbook](ansible_kubespray/playbooks/install-monitoring.yml)

![alt text](image-104.png)
![alt text](image-105.png)
![alt text](image-106.png)
![alt text](image-107.png)
![alt text](image-108.png)

При установке возникли технические тонкости, по результатам составлен PostMorten.

```
## Постмортем установки kube-prometheus-stack

Дата инцидента: 15.08.2026

Статус: устранён

### 1. Краткое описание

При первоначальной установке kube-prometheus-stack Helm одновременно запускался на трёх control-plane узлах. Один узел успешно создал release, два других завершились с ошибкой `release: already exists`.

После установки Grafana перешла в состояние `CrashLoopBackOff`. Prometheus и Alertmanager продолжали работать, однако заданные для них ограничения ресурсов и параметры хранения метрик не применились.

Первая попытка исправления не изменила release, поскольку в playbook была указана отсутствующая в Helm-репозитории версия chart `91.4.0`.

### 2. Воздействие

В период инцидента:

- Grafana была недоступна;
- контейнер Grafana регулярно завершался с кодом 137;
- Prometheus работал без заданных requests и limits;
- срок хранения метрик Prometheus составлял стандартные 10 суток вместо 24 часов;
- ограничение размера хранилища метрик не применилось;
- Alertmanager использовал стандартный request памяти 200 MiБ;
- Kubernetes и прикладные компоненты кластера не пострадали;
- Prometheus, Alertmanager, Node Exporter и kube-state-metrics продолжали работать.

### 3. Основные причины

1. Helm install выполнялся одновременно на всех control-plane узлах.

2. Использовалась операция `helm install`, не обеспечивающая безопасный повторный запуск при существующем release.

3. Часть Helm values была указана по неправильным путям:

   - `prometheus.resources`;
   - `prometheus.retention`;
   - `prometheus.retentionSize`;
   - `alertmanager.resources`.

4. Для Grafana был установлен недостаточный лимит памяти 128 MiБ.

5. Версия Helm chart первоначально не была зафиксирована.

6. При первой попытке исправления была указана несуществующая версия chart `91.4.0`.

7. Перед применением отсутствовала автоматическая проверка доступности указанной версии chart.

### 4. Подтверждение причины отказа Grafana

Контейнер Grafana завершался со следующими параметрами:

- состояние: `OOMKilled`;
- код завершения: 137;
- request памяти: 64 MiБ;
- limit памяти: 128 MiБ;
- количество перезапусков: 7.

Фактическое потребление памяти исправленной Grafana составляет 319 MiБ. Следовательно, лимит 128 MiБ объективно не соответствовал используемой версии Grafana 13.1.3.

### 5. Выполненные корректирующие действия

1. Версия kube-prometheus-stack зафиксирована на `88.3.0`.

2. Helm values вынесены в отдельный файл.

3. Исправлены пути параметров Prometheus и Alertmanager.

4. Операция установки заменена на `helm upgrade --install`.

5. Выполнение Helm ограничено первым control-plane узлом.

6. Добавлены параметры:

   - `--reset-values`;
   - `--atomic`;
   - `--wait`;
   - `--timeout 10m`;
   - `--history-max 5`.

7. Добавлены предварительные проверки:

   - наличия kubeconfig;
   - наличия Helm;
   - готовности Kubernetes API;
   - доступности зафиксированной версии chart;
   - наличия namespace.

8. Добавлено ожидание готовности Prometheus, Alertmanager и Grafana.

9. Добавлена итоговая проверка фактически применённых значений.

### 6. Применённые ограничения ресурсов

| Компонент | Request CPU | Limit CPU | Request memory | Limit memory |
|---|---:|---:|---:|---:|
| Prometheus | 100m | 500m | 256 MiБ | 768 MiБ |
| Grafana | 50m | 200m | 256 MiБ | 512 MiБ |
| Grafana sidecar | 10m | 100m | 64 MiБ | 128 MiБ |
| Alertmanager | 10m | 100m | 32 MiБ | 128 MiБ |

### 7. Результат восстановления

Helm release:

- namespace: `monitoring`;
- status: `deployed`;
- revision: 3;
- chart: `kube-prometheus-stack-88.3.0`;
- Prometheus Operator: `v0.93.0`.

Состояние компонентов:

- Grafana: 3/3 Running, 0 перезапусков;
- Prometheus: 2/2 Running, 0 перезапусков;
- Alertmanager: 2/2 Running, 0 перезапусков;
- Prometheus Operator: Running;
- kube-state-metrics: Running;
- Node Exporter: Running на всех шести узлах.

Фактическое потребление памяти:

- Grafana: 319 MiБ;
- Grafana dashboard sidecar: 78 MiБ;
- Grafana datasource sidecar: 76 MiБ;
- Prometheus: 316 MiБ;
- Alertmanager: 13 MiБ.

Параметры хранения Prometheus:

- retention: 24 часа;
- retentionSize: 1 GB.

### 8. Остаточные ограничения

StorageClass и PVC в кластере отсутствуют. Prometheus, Alertmanager и Grafana временно используют EmptyDir.

При пересоздании соответствующего pod локальные данные будут потеряны. Это принято как временное ограничение до отдельного этапа настройки постоянного хранилища.

Playbook допускает безопасный повторный запуск, однако каждый вызов `helm upgrade` может создавать новую ревизию Helm даже при отсутствии фактических изменений.

### 9. Предупреждающие мероприятия

Для последующих установок необходимо:

1. Фиксировать версию каждого Helm chart.
2. Проверять доступность версии до установки.
3. Хранить параметры Helm в отдельном values-файле.
4. Выполнять Helm только с одного управляющего узла.
5. Использовать `upgrade --install`, `atomic` и `wait`.
6. Проверять созданные Custom Resources, а не только пользовательские Helm values.
7. Определять requests и limits по фактическому потреблению компонентов.
8. Проверять установку повторным запуском playbook.
9. Добавить проверку YAML и Helm values в CI.
10. Настроить постоянное хранилище до перехода к длительному хранению метрик.
```

Выполняю проброс портов через Jump-хост и проверяю доступность через браузер:

Grafana: http://127.0.0.1:3000
![Графана](image-109.png)

Prometheus: http://127.0.0.1:9090
![Прометеус](image-110.png)

Alertmanager: http://127.0.0.1:9093
![Алерт-manager](image-111.png)

В Grafana использовал пользователя admin и текущий пароль из вывода:
```
ssh k8s-master-ru-central1-a \
  "sudo kubectl --kubeconfig=/etc/kubernetes/admin.conf \
  get secret kube-prometheus-stack-grafana \
  -n monitoring \
  -o jsonpath='{.data.admin-password}'" \
| base64 --decode

echo

```
!Пароль скомпрометирован специально и будет сразу изменен.

Используем  Ansible Vault, Kubernetes Secret и ссылку из Grafana на этот Secret. 
Старый Helm Secret не будет удаляеться, при ошибке --atomic и выполнит откат.

![Vault позволяет скрывать пароли](image-112.png)

Порядок применения:

1.Применяем парль через ansible

```
cd /home/vgorshkov/STUDENT1/PROJECT/diplom-devops/ansible_kubespray
source /home/vgorshkov/venv-kubespray-2.31.0/bin/activate

echo "===== ПРОВЕРКА КОНФИГУРАЦИИ ====="

CONFIG_READY="yes"

grep -q 'vault-monitoring.yml' playbooks/install-monitoring.yml || CONFIG_READY="no"
grep -q 'grafana-admin-credentials' playbooks/install-monitoring.yml || CONFIG_READY="no"
grep -q 'existingSecret.*grafana-admin-credentials' playbooks/kube-prometheus-stack-values.yml || CONFIG_READY="no"

if [ "$CONFIG_READY" = "yes" ]; then
    echo "Конфигурация готова. Запускаем Ansible."
    echo

    ansible-playbook \
        -i inventory/hosts.yaml \
        --become \
        --become-user=root \
        --ask-vault-pass \
        playbooks/install-monitoring.yml
else
    echo "Установка не запущена: в playbook или values отсутствуют настройки нового Secret."
fi

unset CONFIG_READY

```

2.Вводишь пароль Ansible Vault. Успешный итог должен содержать: failed=0

3.Проверяем Secret и Grafana

```
ssh k8s-master-ru-central1-a '
KUBECTL="sudo kubectl --kubeconfig=/etc/kubernetes/admin.conf"

echo "===== SECRET GRAFANA ====="
$KUBECTL get secret grafana-admin-credentials \
    -n monitoring \
    -o custom-columns="NAME:.metadata.name,TYPE:.type,CREATED:.metadata.creationTimestamp"

echo
echo "===== SECRET В DEPLOYMENT ====="
$KUBECTL get deployment kube-prometheus-stack-grafana \
    -n monitoring \
    -o jsonpath="{.spec.template.spec.containers[?(@.name==\"grafana\")].env[?(@.name==\"GF_SECURITY_ADMIN_PASSWORD\")].valueFrom.secretKeyRef.name}"
echo

echo
echo "===== СОСТОЯНИЕ GRAFANA ====="
$KUBECTL rollout status \
    deployment/kube-prometheus-stack-grafana \
    -n monitoring \
    --timeout=180s

$KUBECTL get pods \
    -n monitoring \
    -l app.kubernetes.io/name=grafana \
    -o wide
'

```

4. В разделе SECRET В DEPLOYMENT должно появиться: grafana-admin-credentials


5. Поднимаем или проверяем SSH-туннель
```
MASTER_HOST="k8s-master-ru-central1-a"
KUBECONFIG_PATH="/etc/kubernetes/admin.conf"
TUNNEL_SOCKET="/tmp/diplom-monitoring-tunnel-$(id -u).sock"

GRAFANA_IP=$(ssh "$MASTER_HOST" \
    "sudo kubectl --kubeconfig=$KUBECONFIG_PATH get service kube-prometheus-stack-grafana -n monitoring -o jsonpath='{.spec.clusterIP}'")

if ssh -S "$TUNNEL_SOCKET" -O check "$MASTER_HOST" >/dev/null 2>&1; then
    echo "SSH-туннель уже работает."
else
    rm -f -- "$TUNNEL_SOCKET"

    ssh \
        -M \
        -S "$TUNNEL_SOCKET" \
        -fNT \
        -o ExitOnForwardFailure=yes \
        -o ServerAliveInterval=30 \
        -o ServerAliveCountMax=3 \
        -L "127.0.0.1:3000:${GRAFANA_IP}:80" \
        "$MASTER_HOST"
fi

echo
echo "Grafana доступна по адресу:"
echo "http://127.0.0.1:3000"
```



6. Открывай в браузере:
или проверить авторизацию без сохранения пароля в истории:
```
curl \
    --fail \
    --silent \
    --show-error \
    --user admin \
    http://127.0.0.1:3000/api/user

echo
```
Производим перегенерацию паролей
![alt text](image-113.png)

Проверка vault пароля
![alt text](image-114.png)

Обновляем пароль для Grafana через Ansible Vault
```
cd /home/vgorshkov/STUDENT1/PROJECT/diplom-devops/ansible_kubespray
source /home/vgorshkov/venv-kubespray-2.31.0/bin/activate

ansible-playbook \
    -i /home/vgorshkov/STUDENT1/PROJECT/diplom-devops/ansible_kubespray/inventory/hosts.yaml \
    --become \
    --become-user=root \
    --ask-vault-pass \
    /home/vgorshkov/STUDENT1/PROJECT/diplom-devops/ansible_kubespray/playbooks/install-monitoring.yml
```
![Обновление пароля](image-116.png)

Передеплой Мониторинга:
![alt text](image-117.png)
![alt text](image-118.png)
![alt text](image-119.png)
![alt text](image-120.png)
![alt text](image-121.png)

Посмотрим дашборд:
![alt text](image-122.png)
![alt text](image-123.png)
![alt text](image-124.png)
![alt text](image-125.png)
![alt text](image-126.png)


Grafana - доступна, пароль работает, версия 13.1.3
Prometheus - 42 из 48 целей здоровы
Alertmanager - работает
Все поды - в статусе Running
ServiceMonitors - 13 штук
PrometheusRules - 35 штук

![alt text](image-127.png)


Перейдем к настройке балансированного доступа к нашим сервисам из сети интернет, позащищенному каналу связи.
Используем возможности (существующие) облачного провайдера Yandex Cloud.

### Схема организации доступов к нашим ресурсам:
![Listeners-Schemas](image-128.png)

Таблица №1 Ingress by New External Domain

| Уровень | Средство | Назначение |
|---|---|---|
| **Yandex Cloud** | Terraform Provider | ALB, статический IP, target/backend группы, HTTPS listener, security groups |
| **Сертификат** | Existing Certificate Manager ID | Подключение к ALB без выпуска нового сертификата |
| **Kubernetes** | Helm | Traefik в режиме DaemonSet для маршрутизации |
| **Маршрутизация** | Kubernetes Ingress | Приложение (/, /api, /ws) и Grafana (/grafana) через один домен |
| **Применение** | Terraform + kubectl/Helm | Полное управление без использования yc CLI (отключено провайдером) |


Архитектура доступа (IP-based, HTTP, без домена):

Таблица №2 Ingress External IP
| Уровень | Средство | Назначение |
|---|---|---|
| **Клиент** | Браузер / curl | Доступ по HTTP на IP worker-узла: `http://<IP>:30080/grafana` |
| **Kubernetes** | Service (NodePort) | Traefik слушает на порту `30080` на всех worker-узлах |
| **Kubernetes** | Ingress (Traefik) | Маршрутизация запросов по пути `/grafana` → Service Grafana (порт 80) |
| **Приложение** | Grafana Pod | Раздача интерфейса, авторизация через admin-секрет |
| **Конфигурация** | `k8s_monitoring/ingress/grafana.yaml` | Временный Ingress для теста, без TLS |

Таблица №3 Ingreass  Architecture access
| Компонент | Описание |
|---|---|
| **Клиент** | `http://<IP_worker>:30080/grafana` |
| **NodePort** | 30080 на всех worker-узлах |
| **Ingress Controller** | Traefik, маршрут `/grafana` |
| **Service** | `kube-prometheus-stack-grafana:80` |
| **Pod** | Grafana v13.1.3 |

Таблица №4 Ingress Route Map
| Уровень | Средство | Назначение |
|---|---|---|
| **Клиент** | Браузер / curl | Доступ по HTTP на IP worker-узла: `http://<IP>:30080/grafana` |
| **Kubernetes** | Service (NodePort) | Traefik слушает на порту `30080` на всех worker-узлах |
| **Kubernetes** | Ingress (Traefik) | Маршрутизация запросов по пути `/grafana` → Service Grafana (порт 80) |
| **Приложение** | Grafana Pod | Раздача интерфейса, авторизация через admin-секрет |
| **Конфигурация** | `k8s_monitoring/ingress/grafana.yaml` | Временный Ingress для теста, без TLS |


Проверям окружение.

| Компонент | Статус | Подробности |
|---|---|---|
| **Kubernetes кластер** | Работает | 6 нод (3 master + 3 worker), все системы готовы |
| **Traefik Ingress** | Установлен | DaemonSet на 3 worker-узлах, NodePort 30080 |
| **Grafana** | +Работает | Версия 13.1.3, доступ по HTTP через Traefik |
| **Prometheus** | +Работает | 48/48 targets healthy, retention 24h |
| **Alertmanager** | +Работает | Только Watchdog firing (нормально) |
| **kube-proxy метрики** | +Исправлены | Все 6 нод публикуют метрики на 0.0.0.0:10249 |
| **Ingress для приложения** | +Применён | `infra-public` на `/` → Service infra:8080 |
| **Ingress для Grafana** | =>Готов, не применён | `grafana-public` на `/grafana` → Grafana:80 |
| **Yandex ALB** | =>В плане | Будет добавлен через Terraform с HTTPS и сертификатом |
| **Persistent Storage** | =>В плане | Нужно добавить PVC для Prometheus и Grafana |


Произведем развертывание балансировщика с помощью терраформ:

![alt text](image-130.png)
![alt text](image-131.png)
![alt text](image-132.png)
![alt text](image-133.png)
![alt text](image-134.png)
![alt text](image-135.png)
![alt text](image-136.png)

Балансировщик развернут:

![Балансировщик-Доступа](image-129.png)

![alt text](image-137.png)

![alt text](image-138.png)

![alt text](image-139.png)

Доступ открыт:
![Access_by_Ext_IP](image-140.png)


Произведем открытие доступа к приложению:
Блок кода: Развёртывание приложения. 
Блок идемпотентен: сначала импортирует образ на все три worker-узла и только после этого обновляет Kubernetes.
```
PROJECT_DIR="/home/vgorshkov/STUDENT1/PROJECT/diplom-devops"
ANSIBLE_DIR="$PROJECT_DIR/ansible_kubespray"
TERRAFORM_DIR="$PROJECT_DIR/terraform_infra"

DEPLOYMENT_FILE="$PROJECT_DIR/infra/k8s/deployment.yaml"
IMAGE_ARCHIVE="/tmp/diplom-infra-prometheus.tar"
IMAGE_REF_FILE="/tmp/diplom-infra-image-reference.txt"

PLAYBOOK_FILE="$ANSIBLE_DIR/playbooks/deploy-infra-monitoring.yml"
PLAYBOOK_BACKUP="$PLAYBOOK_FILE.before-infra-monitoring"

APPLICATION_URL_FILE="/tmp/diplom-application-url-monitoring.txt"
GRAFANA_URL_FILE="/tmp/diplom-grafana-url-monitoring.txt"
PUBLIC_HEALTH_FILE="/tmp/diplom-infra-public-health.json"
GRAFANA_HEALTH_FILE="/tmp/diplom-grafana-public-health.json"

cd "$PROJECT_DIR"

printf '\n===== 1. ПОЛУЧЕНИЕ IMAGE ИЗ DEPLOYMENT =====\n'

python3 - "$DEPLOYMENT_FILE" "$IMAGE_REF_FILE" <<'PY'
import sys
import yaml

deployment_path = sys.argv[1]
output_path = sys.argv[2]

with open(deployment_path, encoding="utf-8") as stream:
    deployment = yaml.safe_load(stream)

containers = deployment["spec"]["template"]["spec"]["containers"]
images = [
    container["image"]
    for container in containers
    if container.get("name") == "infra"
]

if len(images) != 1:
    raise RuntimeError(
        f"Ожидался один контейнер infra, обнаружено: {len(images)}"
    )

with open(output_path, "w", encoding="utf-8") as stream:
    stream.write(images[0] + "\n")

print(f"Image из Deployment: {images[0]}")
PY

IMAGE_READ_RC=$?

read -r IMAGE_REF < "$IMAGE_REF_FILE"

printf 'Image reference: %s\n' "$IMAGE_REF"
printf 'Код чтения Deployment: %s\n' "$IMAGE_READ_RC"

printf '\n===== 2. ПРОВЕРКА ЛОКАЛЬНОГО ОБРАЗА И АРХИВА =====\n'

DEPLOY_READY=1

if [[ "$IMAGE_READ_RC" -ne 0 ]]; then
    DEPLOY_READY=0
fi

if [[ "$IMAGE_REF" != docker.io/library/infra:metrics-* ]]; then
    printf 'ОШИБКА: неожиданный image reference: %s\n' "$IMAGE_REF"
    DEPLOY_READY=0
fi

if [[ -f "$IMAGE_ARCHIVE" ]]; then
    ls -lh "$IMAGE_ARCHIVE"
else
    printf 'ОШИБКА: архив образа не найден: %s\n' "$IMAGE_ARCHIVE"
    DEPLOY_READY=0
fi

docker image inspect \
    --format 'IMAGE={{index .RepoTags 0}} ID={{.Id}} SIZE={{.Size}}' \
    "$IMAGE_REF"

IMAGE_INSPECT_RC=$?

if [[ "$IMAGE_INSPECT_RC" -ne 0 ]]; then
    printf 'ОШИБКА: локальный Docker image не найден.\n'
    DEPLOY_READY=0
fi

printf 'Готовность к развёртыванию: %s\n' "$DEPLOY_READY"

if [[ "$DEPLOY_READY" -eq 1 ]]; then

    printf '\n===== 3. РЕЗЕРВНАЯ КОПИЯ PLAYBOOK =====\n'

    if [[ -f "$PLAYBOOK_FILE" && ! -e "$PLAYBOOK_BACKUP" ]]; then
        cp -a "$PLAYBOOK_FILE" "$PLAYBOOK_BACKUP"
        printf 'Создана копия: %s\n' "$PLAYBOOK_BACKUP"
    elif [[ -e "$PLAYBOOK_BACKUP" ]]; then
        printf 'Копия уже существует: %s\n' "$PLAYBOOK_BACKUP"
    else
        printf 'Новый playbook будет создан без замены существующего файла.\n'
    fi

    printf '\n===== 4. СОЗДАНИЕ PLAYBOOK =====\n'

    cat > "$PLAYBOOK_FILE" <<'EOF'
---
- name: Размещение образа infra на Kubernetes worker-узлах
  hosts: kube_node
  gather_facts: false
  become: true
  serial: 1
  any_errors_fatal: true

  vars:
    containerd_namespace: k8s.io
    image_archive_remote: /var/tmp/diplom-infra-prometheus.tar

  tasks:
    - name: Проверить входные параметры образа
      ansible.builtin.assert:
        that:
          - infra_image_reference is defined
          - infra_image_reference | length > 0
          - infra_image_archive is defined
          - infra_image_archive | length > 0
        fail_msg: Не переданы infra_image_reference или infra_image_archive.

    - name: Получить список образов containerd до импорта
      ansible.builtin.command:
        argv:
          - ctr
          - --namespace
          - "{{ containerd_namespace }}"
          - images
          - list
          - --quiet
      register: containerd_images_before
      changed_when: false

    - name: Скопировать архив образа на worker
      ansible.builtin.copy:
        src: "{{ infra_image_archive }}"
        dest: "{{ image_archive_remote }}"
        owner: root
        group: root
        mode: "0644"
      when: infra_image_reference not in containerd_images_before.stdout_lines

    - name: Импортировать образ в containerd
      ansible.builtin.command:
        argv:
          - ctr
          - --namespace
          - "{{ containerd_namespace }}"
          - images
          - import
          - "{{ image_archive_remote }}"
      register: containerd_import
      changed_when: true
      when: infra_image_reference not in containerd_images_before.stdout_lines

    - name: Получить список образов containerd после импорта
      ansible.builtin.command:
        argv:
          - ctr
          - --namespace
          - "{{ containerd_namespace }}"
          - images
          - list
          - --quiet
      register: containerd_images_after
      changed_when: false

    - name: Проверить наличие образа на worker
      ansible.builtin.assert:
        that:
          - infra_image_reference in containerd_images_after.stdout_lines
        fail_msg: >-
          Образ {{ infra_image_reference }} не найден на
          {{ inventory_hostname }} после импорта.

- name: Развёртывание метрик приложения и ServiceMonitor
  hosts: k8s-master-ru-central1-a
  gather_facts: false
  become: true
  any_errors_fatal: true

  vars:
    kubectl_binary: kubectl
    kubeconfig_path: /etc/kubernetes/admin.conf
    remote_manifest_dir: /etc/kubernetes/diplom

    manifest_files:
      - source: "{{ playbook_dir }}/../../infra/k8s/pdb.yaml"
        remote: "{{ remote_manifest_dir }}/infra-pdb.yaml"
      - source: "{{ playbook_dir }}/../../infra/k8s/service.yaml"
        remote: "{{ remote_manifest_dir }}/infra-service.yaml"
      - source: "{{ playbook_dir }}/../../k8s_monitoring/servicemonitors/infra.yaml"
        remote: "{{ remote_manifest_dir }}/infra-servicemonitor.yaml"
      - source: "{{ playbook_dir }}/../../infra/k8s/deployment.yaml"
        remote: "{{ remote_manifest_dir }}/infra-deployment.yaml"

  tasks:
    - name: Проверить kubeconfig
      ansible.builtin.stat:
        path: "{{ kubeconfig_path }}"
      register: kubeconfig_stat

    - name: Проверить результат поиска kubeconfig
      ansible.builtin.assert:
        that:
          - kubeconfig_stat.stat.exists
          - kubeconfig_stat.stat.isreg
        fail_msg: "Не найден kubeconfig {{ kubeconfig_path }}."

    - name: Проверить готовность Kubernetes API
      ansible.builtin.command:
        argv:
          - "{{ kubectl_binary }}"
          - "--kubeconfig={{ kubeconfig_path }}"
          - get
          - "--raw=/readyz"
      register: kubernetes_ready
      changed_when: false
      failed_when: >-
        kubernetes_ready.rc != 0 or
        'ok' not in kubernetes_ready.stdout

    - name: Проверить CRD ServiceMonitor
      ansible.builtin.command:
        argv:
          - "{{ kubectl_binary }}"
          - "--kubeconfig={{ kubeconfig_path }}"
          - get
          - crd
          - servicemonitors.monitoring.coreos.com
      changed_when: false

    - name: Получить selector ServiceMonitor у Prometheus
      ansible.builtin.command:
        argv:
          - "{{ kubectl_binary }}"
          - "--kubeconfig={{ kubeconfig_path }}"
          - get
          - prometheus
          - kube-prometheus-stack-prometheus
          - --namespace
          - monitoring
          - >-
            --output=jsonpath={.spec.serviceMonitorSelector.matchLabels.release}
      register: prometheus_servicemonitor_selector
      changed_when: false

    - name: Проверить selector ServiceMonitor
      ansible.builtin.assert:
        that:
          - >-
            prometheus_servicemonitor_selector.stdout ==
            'kube-prometheus-stack'
        fail_msg: >-
          Неожиданный selector Prometheus:
          {{ prometheus_servicemonitor_selector.stdout }}.

    - name: Создать каталог манифестов
      ansible.builtin.file:
        path: "{{ remote_manifest_dir }}"
        state: directory
        owner: root
        group: root
        mode: "0755"

    - name: Скопировать манифесты
      ansible.builtin.copy:
        src: "{{ item.source }}"
        dest: "{{ item.remote }}"
        owner: root
        group: root
        mode: "0644"
      loop: "{{ manifest_files }}"
      loop_control:
        label: "{{ item.remote }}"

    - name: Проверить манифесты на Kubernetes API
      ansible.builtin.command:
        argv:
          - "{{ kubectl_binary }}"
          - "--kubeconfig={{ kubeconfig_path }}"
          - apply
          - --dry-run=server
          - "--filename={{ item.remote }}"
      loop: "{{ manifest_files }}"
      loop_control:
        label: "{{ item.remote }}"
      changed_when: false

    - name: Применить манифесты
      ansible.builtin.command:
        argv:
          - "{{ kubectl_binary }}"
          - "--kubeconfig={{ kubeconfig_path }}"
          - apply
          - "--filename={{ item.remote }}"
      loop: "{{ manifest_files }}"
      loop_control:
        label: "{{ item.remote }}"
      register: manifest_apply
      changed_when: >-
        'created' in manifest_apply.stdout or
        'configured' in manifest_apply.stdout

    - name: Дождаться завершения rolling update
      ansible.builtin.command:
        argv:
          - "{{ kubectl_binary }}"
          - "--kubeconfig={{ kubeconfig_path }}"
          - rollout
          - status
          - deployment/infra
          - --namespace
          - default
          - --timeout=300s
      changed_when: false

    - name: Получить состояние Deployment
      ansible.builtin.command:
        argv:
          - "{{ kubectl_binary }}"
          - "--kubeconfig={{ kubeconfig_path }}"
          - get
          - deployment
          - infra
          - --namespace
          - default
          - >-
            --output=jsonpath={.status.readyReplicas}{" "}{.status.updatedReplicas}{" "}{.status.availableReplicas}
      register: deployment_replicas
      changed_when: false

    - name: Проверить три готовые реплики
      ansible.builtin.assert:
        that:
          - deployment_replicas.stdout.split() == ['3', '3', '3']
        fail_msg: >-
          Ожидалось ready/updated/available 3/3/3, получено:
          {{ deployment_replicas.stdout }}.

    - name: Получить образ Deployment
      ansible.builtin.command:
        argv:
          - "{{ kubectl_binary }}"
          - "--kubeconfig={{ kubeconfig_path }}"
          - get
          - deployment
          - infra
          - --namespace
          - default
          - >-
            --output=jsonpath={.spec.template.spec.containers[?(@.name=="infra")].image}
      register: deployment_image
      changed_when: false

    - name: Проверить образ Deployment
      ansible.builtin.assert:
        that:
          - deployment_image.stdout == infra_image_reference
        fail_msg: >-
          Deployment использует {{ deployment_image.stdout }},
          ожидался {{ infra_image_reference }}.

    - name: Проверить health приложения через ClusterIP
      ansible.builtin.command:
        argv:
          - "{{ kubectl_binary }}"
          - "--kubeconfig={{ kubeconfig_path }}"
          - get
          - >-
            --raw=/api/v1/namespaces/default/services/http:infra:8080/proxy/api/health
      register: internal_application_health
      changed_when: false
      retries: 12
      delay: 5
      until: >-
        internal_application_health.rc == 0 and
        '"status":"ok"' in internal_application_health.stdout

    - name: Проверить внутренний endpoint метрик
      ansible.builtin.command:
        argv:
          - "{{ kubectl_binary }}"
          - "--kubeconfig={{ kubeconfig_path }}"
          - get
          - >-
            --raw=/api/v1/namespaces/default/services/http:infra:9090/proxy/metrics
      register: internal_application_metrics
      changed_when: false
      retries: 12
      delay: 5
      until: >-
        internal_application_metrics.rc == 0 and
        'infra_app_info' in internal_application_metrics.stdout and
        'go_goroutines' in internal_application_metrics.stdout

    - name: Дождаться трёх healthy targets в Prometheus
      ansible.builtin.command:
        argv:
          - "{{ kubectl_binary }}"
          - "--kubeconfig={{ kubeconfig_path }}"
          - get
          - >-
            --raw=/api/v1/namespaces/monitoring/services/http:kube-prometheus-stack-prometheus:9090/proxy/api/v1/query?query=count%28up%7Bjob%3D%22infra%22%7D%20%3D%3D%201%29
      register: infra_prometheus_query
      changed_when: false
      retries: 18
      delay: 5
      until: >-
        infra_prometheus_query.rc == 0 and
        '"3"' in infra_prometheus_query.stdout

    - name: Разобрать ответ Prometheus
      ansible.builtin.set_fact:
        infra_prometheus_response: >-
          {{ infra_prometheus_query.stdout | from_json }}

    - name: Проверить количество healthy targets
      ansible.builtin.assert:
        that:
          - infra_prometheus_response.status == 'success'
          - infra_prometheus_response.data.result | length == 1
          - >-
            (infra_prometheus_response.data.result[0].value[1] | int) == 3
        fail_msg: >-
          Prometheus не подтвердил три healthy target:
          {{ infra_prometheus_query.stdout }}.

    - name: Получить итоговое состояние приложения
      ansible.builtin.command:
        argv:
          - "{{ kubectl_binary }}"
          - "--kubeconfig={{ kubeconfig_path }}"
          - get
          - deployment,pods,service,pdb
          - --namespace
          - default
          - --selector
          - app=infra
          - --output=wide
      register: infra_resources
      changed_when: false

    - name: Получить состояние ServiceMonitor
      ansible.builtin.command:
        argv:
          - "{{ kubectl_binary }}"
          - "--kubeconfig={{ kubeconfig_path }}"
          - get
          - servicemonitor
          - infra
          - --namespace
          - monitoring
          - --output=wide
      register: infra_servicemonitor
      changed_when: false

    - name: Показать ресурсы приложения
      ansible.builtin.debug:
        var: infra_resources.stdout_lines

    - name: Показать ServiceMonitor
      ansible.builtin.debug:
        var: infra_servicemonitor.stdout_lines

    - name: Показать ответ Prometheus
      ansible.builtin.debug:
        var: infra_prometheus_query.stdout
EOF

    printf 'Создан playbook:\n%s\n' "$PLAYBOOK_FILE"

    printf '\n===== 5. ПРОВЕРКА СИНТАКСИСА =====\n'

    cd "$ANSIBLE_DIR"

    ansible-playbook \
        --inventory inventory/hosts.yaml \
        --syntax-check \
        "$PLAYBOOK_FILE" \
        --extra-vars "infra_image_reference=$IMAGE_REF" \
        --extra-vars "infra_image_archive=$IMAGE_ARCHIVE"

    SYNTAX_RC=$?

    printf 'Код syntax-check: %s\n' "$SYNTAX_RC"

    if [[ "$SYNTAX_RC" -eq 0 ]]; then

        printf '\n===== 6. ИМПОРТ ОБРАЗА И ROLLING UPDATE =====\n'

        ansible-playbook \
            --inventory inventory/hosts.yaml \
            "$PLAYBOOK_FILE" \
            --extra-vars "infra_image_reference=$IMAGE_REF" \
            --extra-vars "infra_image_archive=$IMAGE_ARCHIVE"

        PLAYBOOK_RC=$?

        printf 'Код playbook: %s\n' "$PLAYBOOK_RC"

        if [[ "$PLAYBOOK_RC" -eq 0 ]]; then

            printf '\n===== 7. ПОЛУЧЕНИЕ ПУБЛИЧНЫХ URL =====\n'

            cd "$TERRAFORM_DIR"

            terraform output -raw application_url > "$APPLICATION_URL_FILE"
            APPLICATION_OUTPUT_RC=$?

            terraform output -raw grafana_url > "$GRAFANA_URL_FILE"
            GRAFANA_OUTPUT_RC=$?

            read -r APPLICATION_URL < "$APPLICATION_URL_FILE"
            read -r GRAFANA_URL < "$GRAFANA_URL_FILE"

            printf 'Application URL: %s\n' "$APPLICATION_URL"
            printf 'Grafana URL: %s\n' "$GRAFANA_URL"
            printf 'Код application output: %s\n' "$APPLICATION_OUTPUT_RC"
            printf 'Код Grafana output: %s\n' "$GRAFANA_OUTPUT_RC"

            printf '\n===== 8. ПУБЛИЧНАЯ ПРОВЕРКА ПРИЛОЖЕНИЯ =====\n'

            APPLICATION_ROOT_STATUS="$(curl \
                --silent \
                --show-error \
                --output /dev/null \
                --write-out '%{http_code}' \
                "$APPLICATION_URL")"

            APPLICATION_HEALTH_STATUS="$(curl \
                --silent \
                --show-error \
                --output "$PUBLIC_HEALTH_FILE" \
                --write-out '%{http_code}' \
                "${APPLICATION_URL}api/health")"

            printf 'Application root HTTP: %s\n' "$APPLICATION_ROOT_STATUS"
            printf 'Application health HTTP: %s\n' "$APPLICATION_HEALTH_STATUS"

            cat "$PUBLIC_HEALTH_FILE"

            printf '\n===== 9. ПРОВЕРКА ЗАКРЫТОСТИ МЕТРИК СНАРУЖИ =====\n'

            PUBLIC_METRICS_STATUS="$(curl \
                --silent \
                --show-error \
                --output /dev/null \
                --write-out '%{http_code}' \
                "${APPLICATION_URL}metrics")"

            printf 'Публичный /metrics HTTP: %s\n' "$PUBLIC_METRICS_STATUS"
            printf 'Ожидаемый статус: 404\n'

            printf '\n===== 10. ПОВТОРНАЯ ПРОВЕРКА GRAFANA =====\n'

            GRAFANA_HEALTH_STATUS="$(curl \
                --silent \
                --show-error \
                --output "$GRAFANA_HEALTH_FILE" \
                --write-out '%{http_code}' \
                "${GRAFANA_URL}api/health")"

            printf 'Grafana API health HTTP: %s\n' "$GRAFANA_HEALTH_STATUS"
            cat "$GRAFANA_HEALTH_FILE"

            printf '\n===== 11. ИТОГОВЫЕ ПРОВЕРКИ =====\n'

            RESULT_READY=1

            if [[ "$APPLICATION_ROOT_STATUS" != "200" ]]; then
                printf 'ОШИБКА: главная страница приложения вернула %s.\n' \
                    "$APPLICATION_ROOT_STATUS"
                RESULT_READY=0
            fi

            if [[ "$APPLICATION_HEALTH_STATUS" != "200" ]]; then
                printf 'ОШИБКА: health приложения вернул %s.\n' \
                    "$APPLICATION_HEALTH_STATUS"
                RESULT_READY=0
            fi

            if [[ "$PUBLIC_METRICS_STATUS" != "404" ]]; then
                printf 'ОШИБКА: /metrics доступен публично со статусом %s.\n' \
                    "$PUBLIC_METRICS_STATUS"
                RESULT_READY=0
            fi

            if [[ "$GRAFANA_HEALTH_STATUS" != "200" ]]; then
                printf 'ОШИБКА: Grafana health вернул %s.\n' \
                    "$GRAFANA_HEALTH_STATUS"
                RESULT_READY=0
            fi

            printf 'Итоговая готовность: %s\n' "$RESULT_READY"

            printf '\n===== 12. GIT STATUS =====\n'

            cd "$PROJECT_DIR"
            git status --short

            printf '\n===== 13. РЕЗУЛЬТАТ =====\n'
            printf 'Образ на worker-узлах: %s\n' "$IMAGE_REF"
            printf 'Приложение: %s\n' "$APPLICATION_URL"
            printf 'Grafana: %s\n' "$GRAFANA_URL"
            printf 'ServiceMonitor: monitoring/infra\n'
            printf 'Prometheus targets приложения: 3/3 healthy\n'
            printf 'PDB приложения: minAvailable=2\n'
            printf 'Terraform apply не выполнялся.\n'
            printf 'Yandex ALB не изменялся.\n'
            printf 'README не изменялся этим блоком.\n'
            printf 'Файлы и ресурсы не удалялись.\n'
            printf 'Переменные терминала не очищались.\n'
            printf 'Текущий каталог:\n'
            pwd
        fi
    fi
fi
```

Выполнение интеграции приложения в мониторинг:
![alt text](image-141.png)
![alt text](image-142.png)
![alt text](image-143.png)
![alt text](image-144.png)
![alt text](image-145.png)
![alt text](image-146.png)
![alt text](image-147.png)
![alt text](image-148.png)


Сделано:
Добавлен /metrics endpoint в приложение на порту 9090
Собран Docker образ с метриками: infra:metrics-08cef18cf320
Образ загружен на все worker-узлы через containerd
Обновлен Deployment с новым образом
Создан Service с портом 9090 для метрик
Создан ServiceMonitor для сбора метрик в Prometheus
Создан PodDisruptionBudget для обеспечения доступности (minAvailable=2)
Проверена доступность — 3/3 targets healthy

http://51.250.75.1/
![Приложение](image-149.png)

Произведем переконфигурирование VM Гитлаб, перенесу ее в сегмент A  для верной маршрутизации в облаке Яндекс провайдера, чтобы не образовывалось сетевой петли при прохождении пакетов через nat-instance.
Переконфигурация выполнена через Терраформ, в текущем коммите.

Гитлаб. Установка и конфигурирование.
![alt text](image-150.png)
![alt text](image-151.png)
![alt text](image-152.png)

Получен пароль, пересохранен. 
![alt text](image-153.png)

Выполним пересоздание пароля, сброс.
![alt text](image-154.png)

Публикация GitLab:
![alt text](image-156.png)
![alt text](image-155.png)

Проверяем доступность gitlab:
![alt text](image-157.png)

![alt text](image-158.png)
![alt text](image-159.png)
![alt text](image-160.png)
![alt text](image-161.png)

http://51.250.75.1/gitlab/diplom/diplom-devops



### Установка GitLab Runner и настройка CI/CD для сборки образа и деплоя приложения в Kubernetes.

![alt text](image-162.png)

![alt text](image-163.png)

## Сохраняем Runner Token в Ansible Vault

Создаём отдельный зашифрованный файл. Используйте тот же Vault-пароль, что и для мониторинга.

![alt text](image-164.png)

![alt text](image-165.png)

Чарт 0.91.2 фиксируем явно: он устанавливает Runner 19.2.2, совместимый с GitLab 19.2.4. Токена в values.yml не будет — чарт получит его из Kubernetes Secret, который создаст Ansible из Vault. Это соответствует официальной схеме GitLab Runner Helm chart (https://docs.gitlab.com/runner/install/kubernetes/?utm_source=chatgpt.com).

## Создаём Helm values для Runner

![Проверка](image-166.png)

# Создаём Ansible playbook

Playbook создаёт namespace и Secret, затем устанавливает чарт 0.91.2. 
Токен передаётся kubectl через stdin, не попадая в аргументы процесса.

![alt text](image-167.png)

![alt text](image-168.png)

![alt text](image-169.png)

![alt text](image-170.png)

Проверяю обновлённый Runner и находим SSH-ключ: убеждаемся, что новый Pod готов и предупреждение long polling отсутствует, далее определяем существующий SSH-ключ для добавления в GitLab.

```
ssh k8s-master-ru-central1-a 'sudo /usr/local/bin/kubectl --kubeconfig=/etc/kubernetes/admin.conf rollout status deployment/gitlab-runner --namespace gitlab-runner --timeout=120s'

ssh k8s-master-ru-central1-a 'sudo /usr/local/bin/kubectl --kubeconfig=/etc/kubernetes/admin.conf logs deployment/gitlab-runner --namespace gitlab-runner --tail=60 | grep -E "Configuration loaded|Long polling|request_concurrency|Metrics server|Initializing executor"'

ssh -G gitlab-server | awk '/^hostname |^user |^identityfile / {print}'

find /home/vgorshkov/.ssh -maxdepth 1 -type f -name '*.pub' -printf '%p\n'
```

Добавляем существующий ключ в GitLab

![alt text](image-171.png)

![alt text](image-172.png)

![alt text](image-173.png)

Проверено из консоли подключение по ключу
![alt text](image-174.png)

Прописано и проверено подключение Git Remote
![alt text](image-175.png)

![alt text](image-176.png)

Создал, проверяем YAML
![alt text](image-177.png) 

Pipelines
![alt text](image-178.png)

Выполнили Push и на GitHub и на GitLab
![alt text](image-179.png)

![alt text](image-180.png)


Перезагрузка Воркера
![alt text](image-181.png)


