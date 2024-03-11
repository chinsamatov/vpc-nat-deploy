locals {
  # ----------------------------------------------------------------------------
  # Initial Variables
  # ----------------------------------------------------------------------------
  name_suffix = regex("^[a-z0-9\\-]{0,10}", lower(var.name_suffix))

  major_environment = contains(["prod", "production"], local.tags.environment) ? "prod" : "dev"

  tags = merge(
    var.additional_tags,
    var.required_tags,
    {
      provisioner        = "terraform"
      provisioner-module = "terraform-aws-vpc"
      creation-time      = time_static.main.rfc3339
    }
  )

  name_base = join(
    "-",
    compact(
      [
        local.tags.application,
        local.tags.environment,
        local.tags.region,
        local.name_suffix,
        "vpc"
      ]
    )
  )

  # ----------------------------------------------------------------------------
  # Logging
  # ----------------------------------------------------------------------------
  logging_target_prefix = join(
    "/",
    compact(
      [
        data.aws_caller_identity.current.account_id,
        local.tags.application,
        local.tags.environment,
        local.tags.region,
        local.name_suffix,
      ]
    )
  )

  logging = {
    enabled                  = lookup(var.logging, "enabled", false)
    bucket                   = lookup(var.logging, "bucket", "arn:aws:s3:::jomok-2148-${local.major_environment}-logging-vpc-flow-logs")
    prefix                   = lookup(var.logging, "prefix", local.logging_target_prefix)
    destination_type         = lookup(var.logging, "destination_type", "s3")
    traffic_type             = lookup(var.logging, "traffic_type", "ALL")
    log_format               = lookup(var.logging, "log_format", null)
    iam_role                 = ""
    max_aggregation_interval = 600

    destination_options = lookup(var.logging, "destination_type", "s3") == "s3" ? {
      file_format                = "plain-text"
      hive_compatible_partitions = false
      per_hour_partition         = false
    } : {}
  }

  # ----------------------------------------------------------------------------
  # Gateway
  # ----------------------------------------------------------------------------
  nat_gateway = {
    enabled = lookup(var.nat_gateway, "enabled", false)
    type    = lookup(var.nat_gateway, "type", "per-subnet")
  }

  # ----------------------------------------------------------------------------
  # Security Group
  # ----------------------------------------------------------------------------
  default_security_group = lookup(var.default_security_group, "manage", false) ? {
    enabled = {
      ingress = lookup(var.default_security_group, "ingress", []) == [] ? {} : {
        for ingress_values in var.default_security_group.ingress : ingress_values.rule_number => {
          cidr_blocks      = lookup(ingress_values, "cidr_blocks", null)
          description      = lookup(ingress_values, "description", null)
          from_port        = lookup(ingress_values, "from_port", null)
          to_port          = lookup(ingress_values, "to_port", null)
          ipv6_cidr_blocks = lookup(ingress_values, "ipv6_cidr_blocks", null)
          prefix_list_ids  = lookup(ingress_values, "prefix_list_ids", null)
          protocol         = lookup(ingress_values, "protocol", null)
          security_groups  = lookup(ingress_values, "security_groups", null)
          self             = lookup(ingress_values, "self", null)
        }
      }
      egress = lookup(var.default_security_group, "egress", []) == [] ? {} : {
        for egress_values in var.default_security_group.egress : egress_values.rule_number => {
          cidr_blocks      = lookup(egress_values, "cidr_blocks", null)
          description      = lookup(egress_values, "description", null)
          from_port        = lookup(egress_values, "from_port", null)
          to_port          = lookup(egress_values, "to_port", null)
          ipv6_cidr_blocks = lookup(egress_values, "ipv6_cidr_blocks", null)
          prefix_list_ids  = lookup(egress_values, "prefix_list_ids", null)
          protocol         = lookup(egress_values, "protocol", null)
          security_groups  = lookup(egress_values, "security_groups", null)
          self             = lookup(egress_values, "self", null)
        }
      }
    }
  } : {}

  # ----------------------------------------------------------------------------
  # Subnets
  # ----------------------------------------------------------------------------
  # Convert the subnet variable to a list of maps
  subnets_list = flatten([
    for subnet_type, subnet_values in var.subnets : [
      for availability_zone, cidr in subnet_values.cidr_list : [
        {
          name                    = "${lookup(subnet_values, "name_suffix", subnet_type)}-${availability_zone}"
          route_table_name        = subnet_type == "public" ? "public" : "${lookup(subnet_values, "name_suffix", subnet_type)}-${availability_zone}"
          availability_zone       = availability_zone
          map_public_ip_on_launch = lookup(subnet_values, "map_public_ip_on_launch", false)
          cidr                    = cidr
          type                    = subnet_type
          tags                    = merge(lookup(subnet_values, "additional_tags", {}), local.tags)

          # Subnets in this list are able to create a subnet-group resource.
          create_group = contains(["database"], subnet_type) ? lookup(subnet_values, "create_group", true) : null
        }
      ]
    ]
  ])

  # Convert the list of subnet maps into a nested map
  subnets = { for subnet in local.subnets_list : subnet.name => subnet }

  # Database subnets
  # The true/false results must have consisten types
  database_subnets = contains(keys(var.subnets), "database") ? {
    create     = lookup(var.subnets.database, "create_group", true)
    group_name = join("-", [local.name_base, lookup(var.subnets.database, "name_suffix", "database"), "grp"])
    tags       = merge(lookup(var.subnets.database, "additional_tags", {}), local.tags)
    subnets = {
      for subnet in local.subnets : subnet.name => subnet
      if subnet.type == "database"
    }
    } : {
    create     = false
    group_name = null
    tags       = null
    subnets    = null
  }

  private_subnets = contains(keys(var.subnets), "private") ? {
    create     = lookup(var.subnets.private, "create_group", true)
    group_name = join("-", [local.name_base, lookup(var.subnets.private, "name_suffix", "private"), "grp"])
    tags       = merge(lookup(var.subnets.private, "additional_tags", {}), local.tags)
    subnets = {
      for subnet in local.subnets : subnet.name => subnet
      if subnet.type == "private"
    }
    } : {
    create     = false
    group_name = null
    tags       = null
    subnets    = null
  }

  # ----------------------------------------------------------------------------
  # ACLs
  # ----------------------------------------------------------------------------
  acls = {
    for subnet_type, subnet_values in var.subnets : subnet_type => {
      create = lookup(subnet_values, "dedicated_acl", true)
      name   = join("-", [local.name_base, subnet_type, "acl"])
      acls   = lookup(subnet_values, "acls", {})
      tags   = merge(lookup(subnet_values, "additional_tags", {}), local.tags)
      subnets = {
        for subnet in local.subnets : subnet.name => subnet
        if subnet.type == subnet_type
      }
    }
  }

  # Pull the ACL rules out of the acls object and create a list of rules
  acl_rules_list = flatten([
    for acl_subnet, acl_values in local.acls : [
      for acl_type, acl_list in acl_values.acls : [
        for acl_rule in acl_list : [
          {
            egress          = acl_type == "egress" ? true : false
            rule_number     = acl_rule.rule_number
            protocol        = acl_rule.protocol
            rule_action     = lookup(acl_rule, "rule_action", "allow")
            from_port       = lookup(acl_rule, "from_port", null)
            to_port         = lookup(acl_rule, "to_port", null)
            icmp_code       = lookup(acl_rule, "icmp_code", null)
            icmp_type       = lookup(acl_rule, "icmp_type", null)
            cidr_block      = lookup(acl_rule, "cidr_block", "10.96.0.0/12")
            ipv6_cidr_block = var.enable_ipv6 ? lookup(acl_rule, "ipv6_cidr_block", null) : null
            acl_name        = acl_subnet
            rule_name       = join("-", [acl_subnet, acl_type, acl_rule.rule_number])
          }
        ]
      ]
    ]
  ])

  # Convert the list of acl rule maps into a nested map
  acl_rules = { for acl_rule in local.acl_rules_list : acl_rule.rule_name => acl_rule }

  # ----------------------------------------------------------------------------
  # NAT Gateway
  # ----------------------------------------------------------------------------
  public_availability_zones = sort(distinct([
    for subnet in local.subnets : subnet.availability_zone
    if subnet.type == "public"
  ]))

  # Build a map of NAT gateways to create, regardless of the deployment type.
  nat_gateway_map = lookup(var.nat_gateway, "enabled", false) ? {
    single = {
      single = {
        subnet_id = [
          for subnet in local.subnets : subnet.name
          if subnet.type == "public" && subnet.availability_zone == local.public_availability_zones[0]
        ][0]
        tags = merge(lookup(var.nat_gateway, "additional_tags", {}), local.tags)
      }
    }
    per_subnet = {
      for subnet in local.subnets : subnet.name => {
        subnet_id = subnet.name
        tags      = merge(lookup(var.nat_gateway, "additional_tags", {}), local.tags)
      }
      if subnet.type == "public"
    }
  } : {}

  # Pick the gateway to use
  nat_gateway_list = lookup(var.nat_gateway, "enabled", false) ? local.nat_gateway_map[lookup(var.nat_gateway, "deployment_type", "per_subnet")] : {}

  # ----------------------------------------------------------------------------
  # Route Tables
  # ----------------------------------------------------------------------------
  route_tables_list = flatten([
    lookup(var.subnets, "public", []) == [] ? [] : [{ name = "public" }],
    #lookup(var.subnets, "redshift", []) == [] ? [] : [{ name = "redshift" }],
    #lookup(var.subnets, "outpost", []) == [] ? [] : [{ name = "outpust" }],
    #lookup(var.subnets, "elasticache", []) == [] ? [] : [{ name = "elasticache" }],
    [
      for subnet in local.subnets : [
        {
          name              = "${subnet.type}-${subnet.availability_zone}"
          availability_zone = subnet.availability_zone
        }
      ]
      if subnet.type == "private"
    ]
  ])

  route_tables = {
    for route_table in local.route_tables_list : route_table.name => {
      availability_zone = lookup(route_table, "availability_zone", null)
      tags              = merge(local.tags, { Name = join("-", [local.name_base, route_table.name, "rtb"]) })

    }
  }

  route_table_associations = {
    for subnet in local.subnets : subnet.name => subnet.type == "public" ? "public" : "private-${subnet.availability_zone}"
  }

  route_list = flatten([
    var.enable_internet_gateway ? [{
      name                   = "igw"
      route_table            = "public"
      destination_cidr_block = "0.0.0.0/0"
      gateway_id             = "enabled"
      nat_gateway_id         = null
    }] : [],
    lookup(var.nat_gateway, "enabled", false) ? [
      for table_name, table_values in local.route_tables : [
        {
          name                   = table_name
          route_table            = table_name
          destination_cidr_block = "0.0.0.0/0"
          nat_gateway_id         = lookup(var.nat_gateway, "deployment_type", "per_subnet") == "single" ? "public" : "public-${table_values.availability_zone}"
          gateway_id             = null
        }
      ]
      if table_name != "public"
    ] : []
  ])

  routes = { for route in local.route_list : route.name => route }
}
