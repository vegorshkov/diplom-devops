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

# Создаём отдельный сервисный аккаунт для Terraform State
resource "yandex_iam_service_account" "terraform_state_sa" {
  name        = "terraform-state-sa"
  description = "Сервисный аккаунт для хранения Terraform State в S3"
}

# Роль storage.admin только на каталог
resource "yandex_resourcemanager_folder_iam_member" "terraform_state_storage_admin" {
  folder_id = var.folder_id
  role      = "storage.admin"
  member    = "serviceAccount:${yandex_iam_service_account.terraform_state_sa.id}"
}

# Статический ключ для доступа к S3
resource "yandex_iam_service_account_static_access_key" "terraform_state_sa_key" {
  service_account_id = yandex_iam_service_account.terraform_state_sa.id
}

# S3 бакет для хранения состояния Terraform
resource "yandex_storage_bucket" "terraform_state" {
  bucket     = "terraform-state"
  access_key = yandex_iam_service_account_static_access_key.terraform_state_sa_key.access_key
  secret_key = yandex_iam_service_account_static_access_key.terraform_state_sa_key.secret_key
}
