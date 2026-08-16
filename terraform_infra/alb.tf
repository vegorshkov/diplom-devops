locals {
  alb_zones = toset(keys(var.k8s_worker_ips))
}

resource "yandex_vpc_address" "alb_public" {
  name        = "diplom-alb-public-ip"
  description = "Static public IPv4 address for diplom Application Load Balancer"

  external_ipv4_address {
    zone_id = "ru-central1-a"
  }
}

resource "yandex_vpc_security_group" "alb_sg" {
  name        = "diplom-alb-sg"
  description = "Security group for diplom Application Load Balancer"
  network_id  = yandex_vpc_network.diplom_vpc.id

  ingress {
    protocol       = "TCP"
    description    = "Public HTTP listener"
    port           = 80
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol          = "TCP"
    description       = "Yandex ALB health checks"
    port              = var.traefik_node_port
    predefined_target = "loadbalancer_healthchecks"
  }

  egress {
    protocol       = "TCP"
    description    = "HTTP traffic to Traefik NodePort"
    port           = var.traefik_node_port
    v4_cidr_blocks = var.internal_network_cidrs
  }
}

resource "yandex_alb_target_group" "k8s_workers" {
  name        = "diplom-k8s-workers"
  description = "Kubernetes worker nodes running Traefik"

  dynamic "target" {
    for_each = local.alb_zones

    content {
      subnet_id  = yandex_vpc_subnet.k8s_subnet[target.value].id
      ip_address = yandex_compute_instance.k8s_worker[target.value].network_interface[0].ip_address
    }
  }
}

resource "yandex_alb_backend_group" "traefik" {
  name        = "diplom-traefik-backend"
  description = "Traefik NodePort backend in Kubernetes"

  http_backend {
    name             = "traefik-http"
    weight           = 1
    port             = var.traefik_node_port
    target_group_ids = [yandex_alb_target_group.k8s_workers.id]

    load_balancing_config {
      mode = "ROUND_ROBIN"
    }

    healthcheck {
      timeout             = "2s"
      interval            = "5s"
      healthy_threshold   = 2
      unhealthy_threshold = 2

      http_healthcheck {
        path = "/ping"
      }
    }
  }
}

resource "yandex_alb_http_router" "ingress" {
  name        = "diplom-ingress-router"
  description = "HTTP router for application and monitoring"
}

resource "yandex_alb_virtual_host" "ingress" {
  name           = "diplom-ingress-vhost"
  http_router_id = yandex_alb_http_router.ingress.id

  route {
    name = "traefik-route"

    http_route {
      http_match {
        path {
          prefix = "/"
        }
      }

      http_route_action {
        backend_group_id = yandex_alb_backend_group.traefik.id
        timeout          = "3600s"
        idle_timeout     = "300s"
        upgrade_types    = ["websocket"]
      }
    }
  }
}

resource "yandex_alb_load_balancer" "ingress" {
  name               = "diplom-ingress-alb"
  description        = "Public HTTP entry point for diplom Kubernetes"
  network_id         = yandex_vpc_network.diplom_vpc.id
  security_group_ids = [yandex_vpc_security_group.alb_sg.id]

  allocation_policy {
    dynamic "location" {
      for_each = local.alb_zones

      content {
        zone_id   = location.value
        subnet_id = yandex_vpc_subnet.k8s_subnet[location.value].id
      }
    }
  }

  listener {
    name = "http"

    endpoint {
      address {
        external_ipv4_address {
          address = yandex_vpc_address.alb_public.external_ipv4_address[0].address
        }
      }

      ports = [80]
    }

    http {
      handler {
        http_router_id = yandex_alb_http_router.ingress.id
      }
    }
  }
}
