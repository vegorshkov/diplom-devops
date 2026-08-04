# ===== NAT Instance =====
output "nat_external_ip" {
  value       = yandex_compute_instance.nat_instance.network_interface[0].nat_ip_address
  description = "Внешний IP NAT-инстанса"
}

output "nat_internal_ip" {
  value       = yandex_compute_instance.nat_instance.network_interface[0].ip_address
  description = "Внутренний IP NAT-инстанса"
}

# ===== K8s Master Nodes =====
output "k8s_master_ips" {
  value = {
    for zone, vm in yandex_compute_instance.k8s_master :
    zone => vm.network_interface[0].ip_address
  }
  description = "IP-адреса K8s master-нод"
}

# ===== K8s Worker Nodes =====
output "k8s_worker_ips" {
  value = {
    for zone, vm in yandex_compute_instance.k8s_worker :
    zone => vm.network_interface[0].ip_address
  }
  description = "IP-адреса K8s worker-нод"
}

# ===== GitLab Server =====
output "gitlab_ip" {
  value       = yandex_compute_instance.gitlab.network_interface[0].ip_address
  description = "IP GitLab сервера"
}

# ===== VPC Info =====
output "vpc_info" {
  value = {
    network_id = yandex_vpc_network.diplom_vpc.id
    subnets    = [for s in yandex_vpc_subnet.k8s_subnet : s.id]
  }
  description = "Информация о VPC"
}
