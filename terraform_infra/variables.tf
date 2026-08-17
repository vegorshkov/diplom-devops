variable "cloud_id" {
  type        = string
  description = "Идентификатор облака Yandex Cloud"
}

variable "folder_id" {
  type        = string
  description = "Идентификатор каталога Yandex Cloud"
}

variable "default_zone" {
  type        = string
  description = "Зона доступности провайдера по умолчанию"
  default     = "ru-central1-b"
}

variable "service_account_key_file" {
  type        = string
  description = "Путь к JSON-ключу сервисного аккаунта Terraform"
  default     = "../authorized_key.json"
}

variable "subnet_cidrs" {
  type        = map(list(string))
  description = "CIDR-блоки подсетей по зонам доступности"

  default = {
    "ru-central1-a" = ["172.16.1.0/24"]
    "ru-central1-b" = ["172.16.2.0/24"]
    "ru-central1-d" = ["172.16.3.0/24"]
    "ru-central1-e" = ["172.16.4.0/24"]
  }

  validation {
    condition = toset(keys(var.subnet_cidrs)) == toset([
      "ru-central1-a",
      "ru-central1-b",
      "ru-central1-d",
      "ru-central1-e"
    ])

    error_message = "subnet_cidrs должен содержать только зоны ru-central1-a, ru-central1-b, ru-central1-d и ru-central1-e."
  }
}

variable "nat_zone" {
  type        = string
  description = "Зона размещения NAT-инстанса"
  default     = "ru-central1-b"

  validation {
    condition     = var.nat_zone == "ru-central1-b"
    error_message = "NAT-инстанс должен находиться в зоне ru-central1-b."
  }
}

variable "nat_internal_ip" {
  type        = string
  description = "Статический внутренний IP-адрес NAT-инстанса"
  default     = "172.16.2.254"
}

variable "k8s_master_ips" {
  type        = map(string)
  description = "Статические IP-адреса master-узлов Kubernetes по зонам"

  default = {
    "ru-central1-a" = "172.16.1.10"
    "ru-central1-d" = "172.16.3.10"
    "ru-central1-e" = "172.16.4.10"
  }

  validation {
    condition = toset(keys(var.k8s_master_ips)) == toset([
      "ru-central1-a",
      "ru-central1-d",
      "ru-central1-e"
    ])

    error_message = "k8s_master_ips должен содержать только зоны ru-central1-a, ru-central1-d и ru-central1-e."
  }
}

variable "k8s_worker_ips" {
  type        = map(string)
  description = "Статические IP-адреса worker-узлов Kubernetes по зонам"

  default = {
    "ru-central1-a" = "172.16.1.21"
    "ru-central1-d" = "172.16.3.21"
    "ru-central1-e" = "172.16.4.21"
  }

  validation {
    condition = toset(keys(var.k8s_worker_ips)) == toset([
      "ru-central1-a",
      "ru-central1-d",
      "ru-central1-e"
    ])

    error_message = "k8s_worker_ips должен содержать только зоны ru-central1-a, ru-central1-d и ru-central1-e."
  }
}

variable "vm_image_family" {
  type        = string
  description = "Семейство образов ОС для Kubernetes и GitLab"
  default     = "ubuntu-2204-lts"
}

variable "nat_image_id" {
  type        = string
  description = "Идентификатор образа NAT-инстанса"
  default     = "fd80mrhj8fl2oe87o4e1"
}

variable "ssh_public_key_path" {
  type        = string
  description = "Путь к открытому SSH-ключу"
  default     = "/home/vgorshkov/.ssh/netology-ext-key.pub"
}

variable "gitlab_zone" {
  type        = string
  description = "Зона размещения GitLab"
  default     = "ru-central1-a"
}

variable "gitlab_internal_ip" {
  type        = string
  description = "Статический внутренний IP-адрес GitLab"
  default     = "172.16.1.100"
}

variable "internal_network_cidrs" {
  type        = list(string)
  description = "CIDR-блоки внутренней сети, разрешённые группами безопасности"
  default     = ["172.16.0.0/16"]
}

variable "ssh_ingress_cidrs" {
  type        = list(string)
  description = "CIDR-блоки, которым разрешён SSH-доступ к NAT-инстансу"
  default     = ["0.0.0.0/0"]
}
