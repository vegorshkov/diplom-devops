data "yandex_compute_image" "ubuntu" {
  family = var.vm_image_family
}

resource "yandex_vpc_network" "diplom_vpc" {
  name        = "diplom-vpc"
  description = "VPC for diplom infrastructure"
}

resource "yandex_vpc_subnet" "k8s_subnet" {
  for_each       = var.k8s_subnet_cidrs
  name           = "k8s-subnet-${each.key}"
  zone           = each.key
  network_id     = yandex_vpc_network.diplom_vpc.id
  v4_cidr_blocks = each.value
  description    = "K8s subnet in ${each.key}"
}

resource "yandex_vpc_security_group" "k8s_sg" {
  name        = "k8s-security-group"
  network_id  = yandex_vpc_network.diplom_vpc.id
  description = "Security group for K8s cluster"

  ingress {
    protocol       = "TCP"
    description    = "SSH"
    port           = 22
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    protocol       = "TCP"
    description    = "K8s API"
    port           = 6443
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    protocol       = "TCP"
    description    = "HTTP/HTTPS"
    from_port      = 80
    to_port        = 443
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    protocol       = "ANY"
    description    = "Outgoing"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

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
    subnet_id          = yandex_vpc_subnet.k8s_subnet["ru-central1-b"].id
    nat                = true
    security_group_ids = [yandex_vpc_security_group.k8s_sg.id]
  }
  metadata = {
    ssh-keys = "ubuntu:${file(var.ssh_public_key)}"
  }
  scheduling_policy {
    preemptible = false
  }
  allow_stopping_for_update = true
}

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
    subnet_id          = yandex_vpc_subnet.k8s_subnet[each.key].id
    ip_address         = each.value
    nat                = false
    security_group_ids = [yandex_vpc_security_group.k8s_sg.id]
  }
  metadata = {
    ssh-keys = "ubuntu:${file(var.ssh_public_key)}"
  }
  scheduling_policy {
    preemptible = false
  }
}

resource "yandex_compute_instance" "k8s_worker" {
  for_each    = var.k8s_worker_ips
  name        = "k8s-worker-${each.key}"
  hostname    = "k8s-worker-${each.key}"
  platform_id = "standard-v3"
  zone        = replace(replace(each.key, "a2", "a"), "d2", "d")

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
    subnet_id          = yandex_vpc_subnet.k8s_subnet[replace(replace(each.key, "a2", "a"), "d2", "d")].id
    ip_address         = each.value
    nat                = false
    security_group_ids = [yandex_vpc_security_group.k8s_sg.id]
  }
  metadata = {
    ssh-keys = "ubuntu:${file(var.ssh_public_key)}"
  }
  scheduling_policy {
    preemptible = true
  }
}

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
    subnet_id          = yandex_vpc_subnet.k8s_subnet["ru-central1-b"].id
    ip_address         = var.gitlab_ip
    nat                = false
    security_group_ids = [yandex_vpc_security_group.k8s_sg.id]
  }
  metadata = {
    ssh-keys = "ubuntu:${file(var.ssh_public_key)}"
  }
  scheduling_policy {
    preemptible = false
  }
  allow_stopping_for_update = true
}
