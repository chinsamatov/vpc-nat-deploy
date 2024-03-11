
# https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/static
resource "time_static" "main" {}

output "RFC3339_format" {
  value       = time_static.main.rfc3339
  description = "Base timestamp in RFC3339 format (see RFC3339 time string e.g., YYYY-MM-DDTHH:MM:SSZ). Defaults to the current time."
}

output "day" {
  value       = time_static.main.day
  description = "Number day of timestamp."
}


# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc
resource "aws_vpc" "main" {
  cidr_block                       = var.cidr_block
  instance_tenancy                 = "default"
  enable_dns_support               = lookup(var.dns, "enable_dns_support", true)
  enable_dns_hostnames             = lookup(var.dns, "enable_dns_hostnames", false)
  assign_generated_ipv6_cidr_block = false
  tags                             = merge(local.tags, { Name = local.name_base })
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/default_security_group
resource "aws_default_security_group" "main" {
  for_each = local.default_security_group

  vpc_id = aws_vpc.main.id
  tags   = merge(local.tags, { Name = join("-", [local.name_base, "default-sg"]) })

  dynamic "ingress" {
    for_each = each.value.ingress

    content {
      cidr_blocks      = ingress.value.cidr_blocks
      description      = ingress.value.description
      from_port        = ingress.value.from_port
      to_port          = ingress.value.to_port
      ipv6_cidr_blocks = ingress.value.ipv6_cidr_blocks
      prefix_list_ids  = ingress.value.prefix_list_ids
      protocol         = ingress.value.protocol
      security_groups  = ingress.value.security_groups
      self             = ingress.value.self
    }
  }

  dynamic "egress" {
    for_each = each.value.egress

    content {
      cidr_blocks      = egress.value.cidr_blocks
      description      = egress.value.description
      from_port        = egress.value.from_port
      to_port          = egress.value.to_port
      ipv6_cidr_blocks = egress.value.ipv6_cidr_blocks
      prefix_list_ids  = egress.value.prefix_list_ids
      protocol         = egress.value.protocol
      security_groups  = egress.value.security_groups
      self             = egress.value.self
    }
  }

  # Use the depends_on meta block to enforce a specific order for resource creation.
  depends_on = [
    aws_vpc.main,
  ]
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/default_security_group
resource "aws_vpc_dhcp_options" "main" {
  for_each = lookup(var.dhcp_options, "enabled", true) ? { enabled = true } : {}

  domain_name          = lookup(var.dhcp_options, "domain_name", "aws.palig.com")
  domain_name_servers  = lookup(var.dhcp_options, "domain_name_servers", ["AmazonProvidedDNS"])
  ntp_servers          = lookup(var.dhcp_options, "ntp_servers", [])
  netbios_name_servers = lookup(var.dhcp_options, "netbios_name_servers", [])
  netbios_node_type    = lookup(var.dhcp_options, "netbios_node_type", null)
  tags                 = merge(local.tags, { Name = join("-", [local.name_base, "dhcp-ops"]) })

  # Use the depends_on meta block to enforce a specific order for resource creation.
  depends_on = [
    aws_vpc.main,
  ]
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_dhcp_options_association
resource "aws_vpc_dhcp_options_association" "main" {
  for_each = lookup(var.dhcp_options, "enabled", true) ? { enabled = true } : {}

  vpc_id          = aws_vpc.main.id
  dhcp_options_id = aws_vpc_dhcp_options.main["enabled"].id

  # Use the depends_on meta block to enforce a specific order for resource creation.
  depends_on = [
    aws_vpc.main,
    aws_vpc_dhcp_options.main,
  ]
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/default_route_table

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/main_route_table_association

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table
resource "aws_route_table" "main" {
  for_each = local.route_tables

  vpc_id = aws_vpc.main.id
  tags   = each.value.tags

  timeouts {
    create = "10m"
  }

  # Use the depends_on meta block to enforce a specific order for resource creation.
  depends_on = [
    aws_subnet.main,
  ]
}



#### THE ISSUE IS HERE 
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route
resource "aws_route" "main" {
  for_each = local.routes ############################## NEED TO CREATE FILTERED ROUTE TABLES ????

 # aws_nat_gateway.main is object with 2 attributes
 # each.value.nat_gateway_id is "public-us-east-1c"
 # The given key does not identify an element in this collection value.


  route_table_id         = aws_route_table.main[each.value.route_table].id
  destination_cidr_block = each.value.destination_cidr_block
  gateway_id             = lookup(each.value, "gateway_id", null) == null ? null : aws_internet_gateway.main[each.value.gateway_id].id
  nat_gateway_id         = lookup(each.value, "nat_gateway_id", null) == null ? null : aws_nat_gateway.main[each.value.nat_gateway_id].id

  timeouts {
    create = "10m"
  }

  # Use the depends_on meta block to enforce a specific order for resource creation.
  depends_on = [
    aws_route_table.main,
    aws_internet_gateway.main,
    aws_nat_gateway.main,
  ]
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association
resource "aws_route_table_association" "main" {
  for_each = local.route_table_associations

  subnet_id      = aws_subnet.main[each.key].id
  route_table_id = aws_route_table.main[each.value].id

  # Use the depends_on meta block to enforce a specific order for resource creation.
  depends_on = [
    aws_route_table.main,
    aws_subnet.main,
  ]
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet
resource "aws_subnet" "main" {
  for_each = local.subnets ############# it has public and private subnets, need to define filtered here?

  availability_zone               = each.value.availability_zone
  cidr_block                      = each.value.cidr
  customer_owned_ipv4_pool        = null
  ipv6_cidr_block                 = null
  map_customer_owned_ip_on_launch = null
  map_public_ip_on_launch         = each.value.map_public_ip_on_launch
  outpost_arn                     = null
  assign_ipv6_address_on_creation = null
  vpc_id                          = aws_vpc.main.id
  tags                            = merge(each.value.tags, { Name = join("-", [local.name_base, each.value.name]) })

  # Use the depends_on meta block to enforce a specific order for resource creation.
  depends_on = [
    aws_vpc.main,
  ]
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_subnet_group
resource "aws_db_subnet_group" "main" {
  for_each = local.database_subnets.create ? { enabled = local.database_subnets } : {}

  name        = each.value.group_name
  subnet_ids  = [for subnet in each.value.subnets : aws_subnet.main[subnet.name].id]
  description = "Database subnet group for ${local.name_base}"
  tags        = merge(each.value.tags, { Name = each.value.group_name })

  # Use the depends_on meta block to enforce a specific order for resource creation.
  depends_on = [
    aws_subnet.main,
  ]
}

resource "aws_db_subnet_group" "private" {
  for_each = local.private_subnets.create ? { enabled = local.private_subnets } : {}

  name        = each.value.group_name
  subnet_ids  = [for subnet in each.value.subnets : aws_subnet.main[subnet.name].id]
  description = "Private subnet group for ${local.name_base}"
  tags        = merge(each.value.tags, { Name = each.value.group_name })

  # Use the depends_on meta block to enforce a specific order for resource creation.
  depends_on = [
    aws_subnet.main,
  ]
}


# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/default_network_acl

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/network_acl
resource "aws_network_acl" "main" {
  for_each = local.acls

  vpc_id     = aws_vpc.main.id
  subnet_ids = [for subnet in each.value.subnets : aws_subnet.main[subnet.name].id]
  tags       = merge(each.value.tags, { Name = each.value.name })

  # Use the depends_on meta block to enforce a specific order for resource creation.
  depends_on = [
    aws_route_table.main,
    aws_subnet.main,
  ]
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/network_acl_rule
resource "aws_network_acl_rule" "main" {
  for_each = local.acl_rules

  network_acl_id = aws_network_acl.main[each.value.acl_name].id

  egress          = each.value.egress
  rule_number     = each.value.rule_number
  rule_action     = each.value.rule_action
  from_port       = each.value.from_port
  to_port         = each.value.to_port
  icmp_code       = each.value.icmp_code
  icmp_type       = each.value.icmp_type
  protocol        = each.value.protocol
  cidr_block      = each.value.cidr_block
  ipv6_cidr_block = each.value.ipv6_cidr_block

  # Use the depends_on meta block to enforce a specific order for resource creation.
  depends_on = [
    aws_network_acl.main,
  ]
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/internet_gateway
resource "aws_internet_gateway" "main" {
  for_each = var.enable_internet_gateway ? { enabled = true } : {}

  vpc_id = aws_vpc.main.id
  tags   = merge(local.tags, { Name = join("-", [local.name_base, "igw"]) })

  # Use the depends_on meta block to enforce a specific order for resource creation.
  depends_on = [
    aws_vpc.main,
  ]
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eip
resource "aws_eip" "main" {
  for_each = local.nat_gateway_list

  domain = "vpc"
  tags   = merge(local.tags, { Name = join("-", [local.name_base, each.key, "eip"]) })

  # Use the depends_on meta block to enforce a specific order for resource creation.
  depends_on = [
    aws_vpc.main,
  ]
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/nat_gateway
resource "aws_nat_gateway" "main" {
  for_each = local.nat_gateway_list #######?????????

  allocation_id     = aws_eip.main[each.key].id
  connectivity_type = "public"
  subnet_id         = aws_subnet.main[each.value.subnet_id].id ######## ???????????????????
  tags              = merge(each.value.tags, { Name = join("-", [local.name_base, each.key, "ngw"]) })

  # Use the depends_on meta block to enforce a specific order for resource creation.
  depends_on = [
    aws_subnet.main,
    aws_eip.main,
  ]
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/flow_log
resource "aws_flow_log" "main" {
  for_each = local.logging.enabled ? { enabled = local.logging } : {}

  log_destination_type     = each.value.destination_type
  log_destination          = join("/", [each.value.bucket, each.value.prefix])
  traffic_type             = each.value.traffic_type
  log_format               = each.value.log_format
  iam_role_arn             = each.value.iam_role
  vpc_id                   = aws_vpc.main.id
  max_aggregation_interval = each.value.max_aggregation_interval
  tags                     = merge(local.tags, { Name = join("-", [local.name_base, "flow-logs"]) })

  dynamic "destination_options" {
    for_each = each.value.destination_type == "s3" ? { enabled = each.value.destination_options } : {}

    content {
      file_format                = destination_options.value.file_format
      hive_compatible_partitions = destination_options.value.hive_compatible_partitions
      per_hour_partition         = destination_options.value.per_hour_partition
    }
  }

  # Use the depends_on meta block to enforce a specific order for resource creation.
  depends_on = [
    aws_vpc.main,
  ]
}
