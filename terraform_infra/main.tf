# ===== Data Sources =====
data "yandex_compute_image" "ubuntu" {
  family = var.vm_image_family
}

# ===== VPC =====
resource "yandex_vpc_network" "diplom_vpc" {
  name        = "diplom-vpc"
  description = "VPC for diplom infrastructure"
}

# ===== Подсети в трёх зонах =====
resource "yandex_vpc_subnet" "k8s_subnet" {
  for_each       = var.k8s_subnet_cidrs
  name           = "k8s-subnet-${each.key}"
  zone           = each.key
  network_id     = yandex_vpc_network.diplom_vpc.id
  v4_cidr_blocks = each.value
  description    = "K8s subnet in ${each.key}"
}

# ===== NAT Instance (зона b) =====
resource "yandex_compute_instance" "nat_instance" {
  name        = "nat-instance"
  hostname    = "nat-instance"
  platform_id = "standard-v3"
  zone        = "ru-central1-b"

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
    subnet_id  = yandex_vpc_subnet.k8s_subnet["ru-central1-b"].id
    ip_address = "172.16.2.254"
    nat        = true
  }

  metadata = {
    ssh-keys = "ubuntu:${file(var.ssh_public_key)}"
  }

  scheduling_policy {
    preemptible = false
  }
}

# ===== K8s Master Nodes =====
resource "yandex_compute_instance" "k8s_master" {
  for_each    = var.k8s_master_ips
  name        = "k8s-master-${each.key}"
  hostname    = "k8s-master-${each.key}"
  platform_id = "standard-v3"
  zone        = each.key

  resources {
    cores         = 2
    memory        = 4
    core_fraction = 50
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.image_id
      size     = 30
      type     = "network-ssd"
    }
  }

  network_interface {
    subnet_id  = yandex_vpc_subnet.k8s_subnet[each.key].id
    ip_address = each.value
    nat        = false
  }

  metadata = {
    ssh-keys = "ubuntu:${file(var.ssh_public_key)}"
  }

  scheduling_policy {
    preemptible = false
  }
}

# ===== K8s Worker Nodes =====
resource "yandex_compute_instance" "k8s_worker" {
  for_each    = var.k8s_worker_ips
  name        = "k8s-worker-${each.key}"
  hostname    = "k8s-worker-${each.key}"
  platform_id = "standard-v3"
  zone        = each.key

  resources {
    cores         = 2
    memory        = 2
    core_fraction = 20
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.image_id
      size     = 20
      type     = "network-ssd"
    }
  }

  network_interface {
    subnet_id  = yandex_vpc_subnet.k8s_subnet[each.key].id
    ip_address = each.value
    nat        = false
  }

  metadata = {
    ssh-keys = "ubuntu:${file(var.ssh_public_key)}"
  }

  scheduling_policy {
    preemptible = true
  }
}

# ===== GitLab Server =====
resource "yandex_compute_instance" "gitlab" {
  name        = "gitlab-server"
  hostname    = "gitlab-server"
  platform_id = "standard-v3"
  zone        = "ru-central1-b"

  resources {
    cores         = 4
    memory        = 8
    core_fraction = 100
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.image_id
      size     = 50
      type     = "network-ssd"
    }
  }

  network_interface {
    subnet_id  = yandex_vpc_subnet.k8s_subnet["ru-central1-b"].id
    ip_address = var.gitlab_ip
    nat        = false
  }

  metadata = {
    ssh-keys = "ubuntu:${file(var.ssh_public_key)}"
  }

  scheduling_policy {
    preemptible = false
  }
}
