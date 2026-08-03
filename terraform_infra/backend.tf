terraform {
  backend "s3" {
    endpoint   = "storage.yandexcloud.net"
    bucket     = "terraform-state"
    key        = "terraform.tfstate"
    region     = "ru-central1"
    
    skip_region_validation      = true
    skip_credentials_validation = true
    skip_requesting_account_id  = true
    skip_s3_checksum            = true
  }
}
