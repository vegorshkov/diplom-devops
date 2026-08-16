output "alb_public_ip" {
  value       = yandex_vpc_address.alb_public.external_ipv4_address[0].address
  description = "Статический публичный IPv4-адрес Application Load Balancer"
}

output "application_url" {
  value       = "http://${yandex_vpc_address.alb_public.external_ipv4_address[0].address}/"
  description = "Публичный URL приложения"
}

output "grafana_url" {
  value       = "http://${yandex_vpc_address.alb_public.external_ipv4_address[0].address}/grafana/"
  description = "Публичный URL Grafana"
}

output "traefik_node_port" {
  value       = var.traefik_node_port
  description = "NodePort Traefik для backend-группы ALB"
}
