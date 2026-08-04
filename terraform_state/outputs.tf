output "access_key" {
  value       = yandex_iam_service_account_static_access_key.terraform_state_sa_key.access_key
  description = "Access key для S3 (terraform-state-sa)"
  sensitive   = true
}

output "secret_key" {
  value       = yandex_iam_service_account_static_access_key.terraform_state_sa_key.secret_key
  description = "Secret key для S3 (terraform-state-sa)"
  sensitive   = true
}

output "bucket_name" {
  value       = yandex_storage_bucket.terraform_state.bucket
  description = "Имя S3 бакета"
}
