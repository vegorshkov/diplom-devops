# ===== NAT-инстанс =====
resource "yandex_compute_instance" "nat_instance" {
  count       = 1 # отключаем пишем ноль, один включает
  name        = "cloud-netology-nat-instance"
  hostname    = "cloud-netology-nat-instance"
  platform_id = "standard-v3"
  zone        = var.default_zone

  resources {
    cores         = 2
    memory        = 2
    core_fraction = 20
  }

  boot_disk {
    initialize_params {
      image_id = var.nat_image_id
      size     = 10
      type     = "network-hdd"
    }
  }

  network_interface {
    subnet_id          = local.public_subnet_id
    ip_address         = "172.16.3.254"
    nat                = true
    security_group_ids = [local.security_group_id]
  }

  metadata = {
    ssh-keys = "ubuntu:${local.nat_ssh_key}"
  }

  scheduling_policy {
    preemptible = true
  }

  allow_stopping_for_update = true
}
