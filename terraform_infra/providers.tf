terraform {
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = ">= 0.217.0"
    }
  }
  required_version = "~>1.15.0"
}

provider "yandex" {
  # Приоритет применения: переменные окружения -> service_account_key_file -> token
  service_account_key_file = fileexists("authorized_key.json") ? "authorized_key.json" : null
  cloud_id                 = var.cloud_id
  folder_id                = var.folder_id
  zone                     = var.default_zone
  #endpoint                 = "api.cloud.yandex.net"
}
