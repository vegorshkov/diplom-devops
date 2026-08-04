variable "cloud_id" {
  type        = string
  description = "Cloud ID Yandex Cloud"
}

variable "folder_id" {
  type        = string
  description = "Folder ID Yandex Cloud"
}

variable "default_zone" {
  type        = string
  default     = "ru-central1-b"
  description = "Зона доступности по умолчанию"
}

variable "service_account_key_file" {
  type        = string
  default     = "../authorized_key.json"
  description = "Путь к ключу сервисного аккаунта"
}
