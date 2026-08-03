# ===== K8s Master Instance =====
resource "yandex_compute_instance" "k8s_master" {
  count       = var.k8s_master_count
  name        = "k8s-master-${format("%02d", count.index + 1)}"
  hostname    = "k8s-master-${format("%02d", count.index + 1)}"
  platform_id = "standard-v3"
  zone        = var.default_zone

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
    subnet_id          = local.private_subnet_id
    ip_address         = var.k8s_master_ips[count.index]
    nat                = false
    security_group_ids = [local.security_group_id]
  }

  metadata = {
    ssh-keys  = "ubuntu:${local.nat_ssh_key}"
    user-data = <<-EOT
      #cloud-config
      users:
        - name: ubuntu
          shell: /bin/bash
          sudo: ['ALL=(ALL) NOPASSWD:ALL']
          ssh-authorized-keys:
            - ${local.nat_ssh_key}
      package_update: true
      package_upgrade: true
      packages:
        - apt-transport-https
        - ca-certificates
        - curl
        - gnupg
      runcmd:
        - echo "K8s master node initialized" > /var/log/k8s-init.log
    EOT
  }

  scheduling_policy {
    preemptible = true
  }

  allow_stopping_for_update = true

  depends_on = [yandex_compute_instance.nat_instance]
}

# ===== K8s Worker Instances =====
resource "yandex_compute_instance" "k8s_worker" {
  count       = var.k8s_worker_count
  name        = "k8s-worker-${format("%02d", count.index + 1)}"
  hostname    = "k8s-worker-${format("%02d", count.index + 1)}"
  platform_id = "standard-v3"
  zone        = var.default_zone

  resources {
    cores         = 2
    memory        = 2
    core_fraction = 50
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.image_id
      size     = 20
      type     = "network-ssd"
    }
  }

  network_interface {
    subnet_id          = local.private_subnet_id
    ip_address         = var.k8s_worker_ips[count.index]
    nat                = false
    security_group_ids = [local.security_group_id]
  }

  metadata = {
    ssh-keys  = "ubuntu:${local.nat_ssh_key}"
    user-data = <<-EOT
      #cloud-config
      users:
        - name: ubuntu
          shell: /bin/bash
          sudo: ['ALL=(ALL) NOPASSWD:ALL']
          ssh-authorized-keys:
            - ${local.nat_ssh_key}
      package_update: true
      package_upgrade: true
      packages:
        - apt-transport-https
        - ca-certificates
        - curl
        - gnupg
      runcmd:
        - echo "K8s worker node initialized" > /var/log/k8s-init.log
    EOT
  }

  scheduling_policy {
    preemptible = true
  }

  allow_stopping_for_update = true

  depends_on = [yandex_compute_instance.nat_instance]
}
