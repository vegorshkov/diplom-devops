# ===== Data Sources =====
data "yandex_compute_image" "ubuntu" {
  family = var.vm_image_family
}

data "yandex_vpc_network" "existing" {
  name = var.vpc_name
}

data "yandex_vpc_security_group" "existing_sg" {
  name = "nat-security-group"
}

data "yandex_vpc_route_table" "existing_rt" {
  name = "nat-route-table"
}

data "yandex_vpc_subnet" "existing_public" {
  name = "cloud-public"
}

data "yandex_vpc_subnet" "existing_private" {
  name = "cloud-private"
}

# ===== Locals =====
locals {
  vpc_network_id     = try(data.yandex_vpc_network.existing.id, yandex_vpc_network.vpc_nat[0].id)
  security_group_id  = try(data.yandex_vpc_security_group.existing_sg.id, yandex_vpc_security_group.nat_sg[0].id)
  route_table_id     = try(data.yandex_vpc_route_table.existing_rt.id, yandex_vpc_route_table.nat_route[0].id)
  public_subnet_id   = try(data.yandex_vpc_subnet.existing_public.id, yandex_vpc_subnet.public[0].id)
  private_subnet_id  = try(data.yandex_vpc_subnet.existing_private.id, yandex_vpc_subnet.private[0].id)
  database_subnet_id = try(yandex_vpc_subnet.database[0].id, null)
}

# ===== VPC и сеть =====
resource "yandex_vpc_network" "vpc_nat" {
  count       = try(data.yandex_vpc_network.existing.id, null) == null ? 1 : 0
  name        = var.vpc_name
  description = "VPC for NAT testing with public and private subnets"
}

# ===== Группа безопасности =====
resource "yandex_vpc_security_group" "nat_sg" {
  count       = try(data.yandex_vpc_security_group.existing_sg.id, null) == null ? 1 : 0
  name        = "nat-security-group"
  network_id  = local.vpc_network_id
  description = "Security group for NAT network"

  ingress {
    protocol       = "TCP"
    description    = "SSH"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 22
  }
  ingress {
    protocol       = "TCP"
    description    = "HTTP"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 80
  }
  ingress {
    protocol       = "TCP"
    description    = "HTTPS"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 443
  }
  ingress {
    protocol       = "ICMP"
    description    = "Ping"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    protocol       = "TCP"
    description    = "Internal network"
    v4_cidr_blocks = ["172.16.0.0/16"]
    from_port      = 0
    to_port        = 65535
  }
  ingress {
    protocol       = "UDP"
    description    = "Internal network UDP"
    v4_cidr_blocks = ["172.16.0.0/16"]
    from_port      = 0
    to_port        = 65535
  }
  egress {
    protocol       = "TCP"
    description    = "Allow all outgoing TCP"
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 0
    to_port        = 65535
  }
  egress {
    protocol       = "UDP"
    description    = "Allow all outgoing UDP"
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 0
    to_port        = 65535
  }
  egress {
    protocol       = "ICMP"
    description    = "Allow all outgoing ICMP"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

# ===== Подсети =====
resource "yandex_vpc_subnet" "public" {
  count          = try(data.yandex_vpc_subnet.existing_public.id, null) == null ? 1 : 0
  name           = "cloud-public"
  zone           = var.default_zone
  network_id     = local.vpc_network_id
  v4_cidr_blocks = var.public_subnet_cidr
  description    = "Public subnet - 172.16.3.0/24"
}

resource "yandex_vpc_subnet" "private" {
  count          = try(data.yandex_vpc_subnet.existing_private.id, null) == null ? 1 : 0
  name           = "cloud-private"
  zone           = var.default_zone
  network_id     = local.vpc_network_id
  v4_cidr_blocks = var.private_subnet_cidr
  route_table_id = local.route_table_id
  description    = "Private subnet - 172.16.2.0/24"
}

resource "yandex_vpc_subnet" "database" {
  count          = 1
  name           = "cloud-database"
  zone           = var.default_zone
  network_id     = local.vpc_network_id
  v4_cidr_blocks = var.db_subnet_cidr
  route_table_id = local.route_table_id
  description    = "Database subnet - 172.16.1.0/24"
}

# ===== Таблица маршрутизации =====
resource "yandex_vpc_route_table" "nat_route" {
  count      = try(data.yandex_vpc_route_table.existing_rt.id, null) == null ? 1 : 0
  name       = "nat-route-table"
  network_id = local.vpc_network_id

  static_route {
    destination_prefix = "0.0.0.0/0"
    next_hop_address   = "172.16.3.254"
  }
}
