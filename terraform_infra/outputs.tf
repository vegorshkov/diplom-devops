output "nat_external_ip" {
  value       = yandex_compute_instance.nat_instance.network_interface[0].nat_ip_address
  description = "Внешний IP NAT-инстанса"
}

output "nat_internal_ip" {
  value       = yandex_compute_instance.nat_instance.network_interface[0].ip_address
  description = "Внутренний IP NAT-инстанса"
}

output "k8s_master_ips" {
  value = {
    for zone, vm in yandex_compute_instance.k8s_master :
    zone => vm.network_interface[0].ip_address
  }
  description = "IP-адреса K8s master-нод"
}

output "k8s_worker_ips" {
  value = {
    for zone, vm in yandex_compute_instance.k8s_worker :
    zone => vm.network_interface[0].ip_address
  }
  description = "IP-адреса K8s worker-нод"
}

output "gitlab_internal_ip" {
  value       = yandex_compute_instance.gitlab.network_interface[0].ip_address
  description = "Внутренний IP GitLab"
}

output "nat_route_table_id" {
  value       = yandex_vpc_route_table.nat_route.id
  description = "Идентификатор таблицы маршрутизации через NAT-инстанс"
}

output "subnets" {
  value = {
    for zone, subnet in yandex_vpc_subnet.k8s_subnet :
    zone => {
      id             = subnet.id
      cidr_blocks    = subnet.v4_cidr_blocks
      route_table_id = subnet.route_table_id
    }
  }
  description = "Параметры подсетей по зонам доступности"
}

output "security_group_ids" {
  value = {
    nat    = yandex_vpc_security_group.nat_sg.id
    k8s    = yandex_vpc_security_group.k8s_sg.id
    gitlab = yandex_vpc_security_group.gitlab_sg.id
  }
  description = "Идентификаторы групп безопасности"
}

output "vpc_id" {
  value       = yandex_vpc_network.diplom_vpc.id
  description = "Идентификатор VPC"
}
