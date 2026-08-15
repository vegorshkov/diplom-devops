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


