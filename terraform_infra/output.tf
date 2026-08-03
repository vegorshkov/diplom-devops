# ===== VPC Information =====
output "vpc_info" {
  description = "VPC Information"
  value = {
    network_id          = local.vpc_network_id
    network_name        = data.yandex_vpc_network.existing.name
    public_subnet_cidr  = try(data.yandex_vpc_subnet.existing_public.v4_cidr_blocks[0], yandex_vpc_subnet.public[0].v4_cidr_blocks[0])
    private_subnet_cidr = try(data.yandex_vpc_subnet.existing_private.v4_cidr_blocks[0], yandex_vpc_subnet.private[0].v4_cidr_blocks[0])
    route_table_id      = local.route_table_id
  }
}

# ===== NAT Instance Information =====
output "nat_instance_info" {
  description = "NAT Instance Information"
  value = {
    name        = yandex_compute_instance.nat_instance[0].name
    internal_ip = yandex_compute_instance.nat_instance[0].network_interface[0].ip_address
    external_ip = yandex_compute_instance.nat_instance[0].network_interface[0].nat_ip_address
    fqdn        = yandex_compute_instance.nat_instance[0].fqdn
  }
}

# ===== Bucket URL =====
output "bucket_url" {
  description = "Public URL of the picture in Object Storage"
  value       = "https://${yandex_storage_bucket.main.bucket}.storage.yandexcloud.net/Victor_E_Gorshkov.jpg"
}

# ===== Network Load Balancer =====
output "load_balancer_ip" {
  description = "Network Load Balancer public IP"
  value       = one([for l in yandex_lb_network_load_balancer.main.listener : one(l.external_address_spec).address])
}

# ===== Instance Group Information =====
output "instance_group_info" {
  description = "Instance Group information"
  value = {
    name      = yandex_compute_instance_group.lamp.name
    status    = yandex_compute_instance_group.lamp.status
    instances = yandex_compute_instance_group.lamp.instances[*].network_interface[0].ip_address
  }
}

# ===== Application Load Balancer Information =====
output "alb_public_ip" {
  description = "Публичный IP-адрес Application Load Balancer"
  value       = one(yandex_alb_load_balancer.lamp.listener).endpoint[0].address[0].external_ipv4_address[0].address
}

output "alb_health_status" {
  description = "Статус и лог для понимания состояния ALB"
  value = {
    alb_id           = yandex_alb_load_balancer.lamp.id
    alb_name         = yandex_alb_load_balancer.lamp.name
    status           = yandex_alb_load_balancer.lamp.status
    backend_group_id = yandex_alb_backend_group.lamp.id
  }
}

# ===== K8s Instances Information =====
output "k8s_master_info" {
  description = "K8s master nodes information"
  value = {
    for i, instance in yandex_compute_instance.k8s_master :
    instance.name => {
      name        = instance.name
      internal_ip = instance.network_interface[0].ip_address
      fqdn        = instance.fqdn
    }
  }
}

output "k8s_worker_info" {
  description = "K8s worker nodes information"
  value = {
    for i, instance in yandex_compute_instance.k8s_worker :
    instance.name => {
      name        = instance.name
      internal_ip = instance.network_interface[0].ip_address
      fqdn        = instance.fqdn
    }
  }
}

# ===== Ansible Inventory Generation =====
output "ansible_inventory" {
  description = "Ansible inventory in INI format"
  value = templatefile(
    "${path.module}/templates/inventory.tpl",
    {
      nat_ip     = yandex_compute_instance.nat_instance[0].network_interface[0].nat_ip_address
      master_ips = [for i in yandex_compute_instance.k8s_master : i.network_interface[0].ip_address]
      worker_ips = [for i in yandex_compute_instance.k8s_worker : i.network_interface[0].ip_address]
    }
  )
}
