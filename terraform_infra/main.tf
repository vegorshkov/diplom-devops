data "yandex_compute_image" "ubuntu" {
  family = var.vm_image_family
}

resource "yandex_vpc_network" "diplom_vpc" {
  name        = "diplom-vpc"
  description = "VPC for diplom infrastructure"
}

resource "yandex_vpc_route_table" "nat_route" {
  name        = "nat-route"
  description = "Default route from private subnets through NAT instance"
  network_id  = yandex_vpc_network.diplom_vpc.id

  static_route {
    destination_prefix = "0.0.0.0/0"
    next_hop_address   = var.nat_internal_ip
  }
}

resource "yandex_vpc_subnet" "k8s_subnet" {
  for_each       = var.subnet_cidrs
  name           = "k8s-subnet-${each.key}"
  zone           = each.key
  network_id     = yandex_vpc_network.diplom_vpc.id
  v4_cidr_blocks = each.value
  route_table_id = each.key == var.nat_zone ? null : yandex_vpc_route_table.nat_route.id
  description    = "Infrastructure subnet in ${each.key}"
}

resource "yandex_vpc_security_group" "nat_sg" {
  name        = "nat-sg"
  network_id  = yandex_vpc_network.diplom_vpc.id
  description = "Security group for NAT instance"

  ingress {
    protocol       = "TCP"
    description    = "SSH access to NAT instance"
    port           = 22
    v4_cidr_blocks = var.ssh_ingress_cidrs
  }

  ingress {
    protocol       = "ANY"
    description    = "Traffic from internal network"
    v4_cidr_blocks = var.internal_network_cidrs
  }

  egress {
    protocol       = "ANY"
    description    = "Outgoing traffic"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "yandex_vpc_security_group" "k8s_sg" {
  name        = "k8s-security-group"
  network_id  = yandex_vpc_network.diplom_vpc.id
  description = "Security group for K8s cluster"

  ingress {
    protocol       = "ANY"
    description    = "Traffic inside infrastructure network"
    v4_cidr_blocks = var.internal_network_cidrs
  }

  egress {
    protocol       = "ANY"
    description    = "Outgoing traffic"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "yandex_vpc_security_group" "gitlab_sg" {
  name        = "gitlab-sg"
  network_id  = yandex_vpc_network.diplom_vpc.id
  description = "Security group for GitLab"

  ingress {
    protocol       = "ANY"
    description    = "Traffic from internal network"
    v4_cidr_blocks = var.internal_network_cidrs
  }

  egress {
    protocol       = "ANY"
    description    = "Outgoing traffic"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "yandex_compute_instance" "nat_instance" {
  name        = "nat-instance"
  hostname    = "nat-instance"
  platform_id = "standard-v3"
  zone        = var.nat_zone

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
    subnet_id          = yandex_vpc_subnet.k8s_subnet[var.nat_zone].id
    ip_address         = var.nat_internal_ip
    nat                = true
    security_group_ids = [yandex_vpc_security_group.nat_sg.id]
  }

  metadata = {
    ssh-keys = "ubuntu:${file(var.ssh_public_key_path)}"
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
    ssh-keys = "ubuntu:${file(var.ssh_public_key_path)}"
  }

  scheduling_policy {
    preemptible = false
  }

  allow_stopping_for_update = true
}

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
    subnet_id          = yandex_vpc_subnet.k8s_subnet[each.key].id
    ip_address         = each.value
    nat                = false
    security_group_ids = [yandex_vpc_security_group.k8s_sg.id]
  }

  metadata = {
    ssh-keys = "ubuntu:${file(var.ssh_public_key_path)}"
  }

  scheduling_policy {
    preemptible = true
  }

  allow_stopping_for_update = true
}

resource "yandex_compute_instance" "gitlab" {
  name        = "gitlab-server"
  hostname    = "gitlab-server"
  platform_id = "standard-v3"
  zone        = var.gitlab_zone

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
    subnet_id          = yandex_vpc_subnet.k8s_subnet[var.gitlab_zone].id
    ip_address         = var.gitlab_internal_ip
    nat                = false
    security_group_ids = [yandex_vpc_security_group.gitlab_sg.id]
  }

  metadata = {
    ssh-keys = "ubuntu:${file(var.ssh_public_key_path)}"
  }

  scheduling_policy {
    preemptible = false
  }

  allow_stopping_for_update = true
}

