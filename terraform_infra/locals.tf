locals {
  # Читаем SSH ключи из файлов
  bastion_ssh_key    = file(var.bastion_ssh_pub_key)
  nat_ssh_key        = file(var.nat_ssh_pub_key)
  private_vm_ssh_key = file(var.private_vm_ssh_pub_key)

  # Cloud-init конфигурация для Ubuntu
  cloud_init_config = <<-YAML
    #cloud-config
    users:
      - name: ubuntu
        shell: /bin/bash
        sudo: ['ALL=(ALL) NOPASSWD:ALL']
        ssh-authorized-keys:
          - ${local.bastion_ssh_key}
          - ${local.private_vm_ssh_key}
    package_update: true
    package_upgrade: true
    packages:
      - curl
      - wget
      - traceroute
      - net-tools
      - iperf3
    runcmd:
      - systemctl enable --now ssh
      - echo "Cloud-init completed at $(date)" > /var/log/cloud-init-done.log
  YAML
}
