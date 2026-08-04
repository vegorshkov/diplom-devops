### Cloud vars
variable "token" {
  type        = string
  description = "OAuth-token"
  default     = ""
  sensitive   = true
}

variable "cloud_id" {
  type        = string
  description = "Cloud ID"
}

variable "folder_id" {
  type        = string
  description = "Folder ID"
}

variable "default_zone" {
  type        = string
  default     = "ru-central1-b"
  description = "Зона доступности"
}

variable "zones" {
  type        = list(string)
  default     = ["ru-central1-a", "ru-central1-b", "ru-central1-d"]
  description = "Зоны доступности для распределения нод"
}

variable "vpc_name" {
  type        = string
  default     = "diplo-vpc"
  description = "VPC network name"
}

variable "k8s_subnet_cidrs" {
  type = map(list(string))
  default = {
    "ru-central1-a" = ["172.16.1.0/24"]
    "ru-central1-b" = ["172.16.2.0/24"]
    "ru-central1-d" = ["172.16.3.0/24"]
  }
  description = "CIDR для подсетей Kubernetes по зонам"
}

variable "vm_image_family" {
  type        = string
  default     = "ubuntu-2204-lts"
  description = "OS image family"
}

variable "nat_image_id" {
  type        = string
  default     = "fd80mrhj8fl2oe87o4e1"
  description = "Image ID for NAT instance"
}

variable "ssh_public_key" {
  type        = string
  default     = "/home/vgorshkov/.ssh/netology-ext-key.pub"
  description = "Path to public SSH key"
}

variable "k8s_master_ips" {
  type = map(string)
  default = {
    "ru-central1-a" = "172.16.1.10"
    "ru-central1-b" = "172.16.2.10"
    "ru-central1-d" = "172.16.3.10"
  }
  description = "Static IPs for K8s master nodes"
}

variable "k8s_worker_ips" {
  type = map(string)
  default = {
    "ru-central1-a" = "172.16.1.21"
    "ru-central1-b" = "172.16.2.21"
    "ru-central1-d" = "172.16.3.21"
  }
  description = "Static IPs for K8s worker nodes"
}

variable "gitlab_ip" {
  type        = string
  default     = "172.16.2.100"
  description = "Static IP for GitLab server"
}
