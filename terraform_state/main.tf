terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
  required_version = "~> 1.15"
}

provider "yandex" {
  service_account_key_file = var.service_account_key_file
  cloud_id                 = var.cloud_id
  folder_id                = var.folder_id
  zone                     = var.default_zone
}

# Существующий terraform-sa
data "yandex_iam_service_account" "terraform_sa" {
  service_account_id = "aje7e74rinf1d7f8it0m"
}

# Отдельный сервисный аккаунт для доступа к бакету
resource "yandex_iam_service_account" "terraform_state_sa" {
  name        = "terraform-state-sa"
  description = "Сервисный аккаунт для доступа к Terraform State в S3"
}

# Статический ключ terraform-sa (для создания бакета)
resource "yandex_iam_service_account_static_access_key" "terraform_sa_key" {
  service_account_id = data.yandex_iam_service_account.terraform_sa.service_account_id
}

# Статический ключ terraform-state-sa (для доступа к бакету из terraform_infra)
resource "yandex_iam_service_account_static_access_key" "terraform_state_sa_key" {
  service_account_id = yandex_iam_service_account.terraform_state_sa.id
}

# S3 бакет
resource "yandex_storage_bucket" "terraform_state" {
  bucket     = "netology-vgorshkov-tf-state"
  access_key = yandex_iam_service_account_static_access_key.terraform_sa_key.access_key
  secret_key = yandex_iam_service_account_static_access_key.terraform_sa_key.secret_key
}
