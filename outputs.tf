/*
output "vpc" {
  value = {
    arn        = aws_vpc.main.arn
    cidr_block = aws_vpc.main.cidr_block
    id         = aws_vpc.main.id
    name       = lookup(aws_vpc.main.tags_all, "Name", "")
    tags       = aws_vpc.main.tags_all
  }
}

output "subnets" {
  value = {
    for subnet in local.subnets : subnet.name => {
      arn        = aws_subnet.main[subnet.name].arn
      id         = aws_subnet.main[subnet.name].id
      cidr_block = aws_subnet.main[subnet.name].cidr_block
      tags       = aws_subnet.main[subnet.name].tags_all
    }
  }
}

output "subnet_groups" {
  value = {
    database = local.database_subnets.create ? {
      arn  = aws_db_subnet_group.main["enabled"].arn
      id   = aws_db_subnet_group.main["enabled"].id
      name = aws_db_subnet_group.main["enabled"].name
      tags = aws_db_subnet_group.main["enabled"].tags_all
      } : {
      arn  = null
      id   = null
      name = null
      tags = null
    }

    private = local.private_subnets.create ? {
      arn  = aws_db_subnet_group.private["enabled"].arn
      id   = aws_db_subnet_group.private["enabled"].id
      name = aws_db_subnet_group.private["enabled"].name
      tags = aws_db_subnet_group.private["enabled"].tags_all
      } : {
      arn  = null
      id   = null
      name = null
      tags = null
    }
  }
}

output "security_groups" {
  value = {
    default = lookup(var.default_security_group, "manage", false) ? {
      arn         = aws_default_security_group.main["enabled"].arn
      description = aws_default_security_group.main["enabled"].description
      id          = aws_default_security_group.main["enabled"].id
      name        = aws_default_security_group.main["enabled"].name
      } : {
      arn         = null
      description = null
      id          = null
      name        = null
    }
  }
}
*/