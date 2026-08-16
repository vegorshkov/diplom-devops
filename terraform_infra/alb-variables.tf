variable "traefik_node_port" {
  type        = number
  description = "Фиксированный NodePort Traefik для Yandex ALB"
  default     = 30080

  validation {
    condition     = var.traefik_node_port >= 30000 && var.traefik_node_port <= 32767
    error_message = "traefik_node_port должен находиться в диапазоне 30000-32767."
  }
}
