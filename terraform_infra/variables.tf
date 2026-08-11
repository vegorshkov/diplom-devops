variable "cloud_id" {
  type    = string
  default = "b1gb43b8b56tkbsflrmt"
}
variable "folder_id" {
  type    = string
  default = "b1geebjq1terf546fn7j"
}
variable "default_zone" {
  type    = string
  default = "ru-central1-b"
}
variable "k8s_subnet_cidrs" {
  type = map(list(string))
  default = {
    "ru-central1-a" = ["172.16.1.0/24"]
    "ru-central1-b" = ["172.16.2.0/24"]
    "ru-central1-d" = ["172.16.3.0/24"]
    "ru-central1-e" = ["172.16.4.0/24"]
  }
}
variable "k8s_master_ips" {
  type = map(string)
  default = {
    "ru-central1-a" = "172.16.1.10"
    "ru-central1-d" = "172.16.3.10"
    "ru-central1-e" = "172.16.4.10"
  }
}
variable "k8s_worker_ips" {
  type = map(string)
  default = {
    "ru-central1-a"  = "172.16.1.21"
    "ru-central1-a"  = "172.16.1.22"
    "ru-central1-d"  = "172.16.3.21"
    "ru-central1-d"  = "172.16.3.22"
  }
}
variable "vm_image_family" {
  type    = string
  default = "ubuntu-2204-lts"
}
variable "nat_image_id" {
  type    = string
  default = "fd80mrhj8fl2oe87o4e1"
}
variable "ssh_public_key" {
  type    = string
  default = "/home/vgorshkov/.ssh/netology-ext-key.pub"
}
variable "gitlab_ip" {
  type    = string
  default = "172.16.2.100"
}
