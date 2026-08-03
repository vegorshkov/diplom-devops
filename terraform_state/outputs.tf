output "service_account_id" {
  value       = yandex_iam_service_account.terraform_state_sa.id
  description = "ID сервисного аккаунта для Terraform State"
}

output "terraform_state_key_file" {
  value = {
    id                  = yandex_iam_service_account_static_access_key.terraform_state_sa_key.id
    service_account_id  = yandex_iam_service_account.terraform_state_sa.id
    created_at          = yandex_iam_service_account_static_access_key.terraform_state_sa_key.created_at
    key_algorithm       = "STATIC_ACCESS_KEY"
    access_key          = yandex_iam_service_account_static_access_key.terraform_state_sa_key.access_key
    secret_key          = yandex_iam_service_account_static_access_key.terraform_state_sa_key.secret_key
  }
  description = "Ключ сервисного аккаунта для S3 (сохранить как authorized_key_terraform_state.json)"
  sensitive   = true
}

output "bucket_name" {
  value       = yandex_storage_bucket.terraform_state.bucket
  description = "Имя S3 бакета"
}
