# Module `terraform-aws-vpc`

This module creates and manages an AWS VPC and associated resources (subnets, ACLs, route tables, etc.).

## Requirements

### Core Version Constraints:

* `>= 0.12`

### Provider Requirements:

* **aws (`hashicorp/aws`):** `< 4`
* **time (`hashicorp/time`):** `< 1`

## Examples

```hcl
module "vpc" {
  source = "git@gitlab.com:jomok/infrastructure/terraform-modules/terraform-aws-vpc.git?ref=v0.0.0"

  cidr_block              = "10.97.32.0/20"
  required_tags           = local.required_tags
  enable_internet_gateway = true

  subnets = {
    public = {
      cidr_list = {
        "us-east-1a" = "10.97.32.0/26"
        "us-east-1b" = "10.97.32.64/26"
        "us-east-1c" = "10.97.32.128/26"
      }
      acls = {
        egress = [
          {
            rule_number = 100
            protocol    = "all"
            cidr_block  = "0.0.0.0/0"
          }
        ]
        ingress = [
          {
            rule_number = 200
            protocol    = "all"
            cidr_block  = "0.0.0.0/0"
          }
        ]
      }
    }
    private = {
      cidr_list = {
        "us-east-1a" = "10.97.32.192/26"
        "us-east-1b" = "10.97.33.0/26"
        "us-east-1c" = "10.97.33.64/26"
      }
      acls = {
        ingress = [
          {
            rule_number = 100
            protocol    = "all"
          }
        ]
        egress = [
          {
            rule_number = 200
            protocol    = "all"
          }
        ]
      }
    }
    database = {
      cidr_list = {
        "us-east-1a" = "10.97.33.128/26"
        "us-east-1b" = "10.97.33.192/26"
        "us-east-1c" = "10.97.34.0/26"
      }
      acls = {
        ingress = [
          {
            rule_number = 100
            from_port   = 1433
            to_port     = 1433
            protocol    = "tcp"
          }
        ]
        egress = [
          {
            rule_number = 200
            protocol    = "all"
            cidr_block  = "0.0.0.0/0"
          }
        ]
      }
    }
  }

  default_security_group = {
    manage = true
    ingress = [
      {
        rule_number = 100
        cidr_blocks = ["0.0.0.0/0"]
        description = "Allow all"
        from_port   = 0
        to_port     = 0
        protocol    = "all"
      }
    ]
    egress = [
      {
        rule_number = 200
        cidr_blocks = ["0.0.0.0/0"]
        description = "Allow all"
        from_port   = 0
        to_port     = 0
        protocol    = "all"
      }
    ]
  }

  dns = {
    enable_dns_hostnames = true
  }

  nat_gateway = {
    enabled = true
  }

  dhcp_options = {
    enabled = true
  }
}
```

```hcl
module "vpc" {
  source = "git@gitlab.com:jomok/infrastructure/terraform-modules/terraform-aws-vpc.git?ref=v0.0.0"

  cidr_block    = "10.97.32.0/20"
  required_tags = local.required_tags

  subnets = {
    private = {
      cidr_list = {
        "us-east-1a" = "10.97.32.192/26"
        "us-east-1b" = "10.97.33.0/26"
        "us-east-1c" = "10.97.33.64/26"
      }
    }
    intra = {
      cidr_list = {
        "us-east-1a" = "10.97.33.128/26"
        "us-east-1b" = "10.97.33.192/26"
        "us-east-1c" = "10.97.34.0/26"
      }
    }
  }

  dns = {
    enable_dns_hostnames = true
  }

  dhcp_options = {
    enabled = true
  }
}
```

## Input Variables

### Required

* `cidr_block`    (required): The primary CIDR for the VPC.
* `required_tags` (required): A map of tags that are required for all resources.
* `subnets`       (required): A `subnet` object.

### Optional

* `additional_tags`         (default `{}`):    A map of tags to be assigned to the resources. These will be overwritten if they conflict with required tags.
* `default_security_group`  (default `{}`):    A default security group object for creating and configuring the VPC default security group.
* `dhcp_options`            (default `{}`):    A `dhcp_options` object.
* `dns`                     (default `{}`):    A `dns` object.
* `enable_internet_gateway` (default `false`): Create an internet gateway for the VPC.
* `enable_ipv6`             (default `false`): Enable IPv6 and create associated resources when necessary.
* `logging`                 (default `{}`):    A `logging` object for configuration VPC flow logs.
* `name_suffix`             (default `""`):    A name to append to the end of all resources.
* `nat_gateway`             (default `{}`):    A `nat_gateway` configuration object.

### Objects

A `required_tags` object supports the following arguments:
  * `application`      (required): The application this resource is assigned to.
  * `environment`      (required): The lifecycle environment of the resource. This should almost always be `local.environment_vars.locals.environment`.
  * `organization`     (required): The organization this resource is assigned to. Almost always `palig`.
  * `provisioner-file` (required): The full HTTPS path to the Terraform/Terragrunt file. This should almost always be `join("/",[local.account_vars.locals.gitlab_repo,"${path_relative_to_include()}","terragrunt.hcl"])`.
  * `region`           (required): The AWS region for this resource. This should almost always be `local.region_vars.locals.region`.

A `subnet` object supports the following arguments:
* `public`   (default `{}`): A `subnet_definition` object.
* `private`  (default `{}`): A `subnet_definition` object.
* `database` (default `{}`): A `subnet_definition` object.

**NOTE** - Additional subnet types can be added here as needed (`intra`, etc). Any additional custom subnet type will share the default private route table.

A `subnet_definition` object supports the following arguments:
* `acls`            (default `{}`):   An `acls` object, for egress and ingress.
* `additional_tags` (default `{}`):   A map of additional tags to assign to the subnet-related resources.
* `cidr_list`       (required):       A map subnet CIDRs for each availabilty zone. Formated like `availability_zone = cidr`. Example: `{ "us-east-1a" = "10.0.0.0/24" }`.
* `create_group`    (default `true`): If the subnet type supports it, create a subnet group. For example, the database subnets can be assigned to a database subnet group for use with RDS.
* `name_suffix`     (default `null`): By default, the subnet type (`public`, `private`, `database`, etc) is used for naming resources. If `name_suffix` is specified, that value will be used instead.
* `map_public_ip_on_launch`    (default `false`): Specify `true` to indicate that instances launched into the subnet should be assigned a public IP address.

An `acls` object supports the following arguments:
* `egress`  (default `[]`): A list of `acl_definition` objects to assign to the subnets.
* `ingress` (default `[]`): A list of `acl_definition` objects to assign to the subnets.

An `acl_definition` object supports the following arguments:
* `rule_number`     (required):               A rule number for the ACL. Rule numbers must be unique within the list, and are applied in numerical order.
* `protocol`        (required):               The protocol for the rule. When `all` or `-1`, `from_port` and `to_port` are ignored.
* `rule_action`     (default `allow`):        The action (`deny`, `allow`) to apply to the rule.
* `from_port`       (default `null`):         The beginning port number for the rule.
* `to_port`         (default `null`):         The ending port number for the rule.
* `icmp_code`       (default `null`):         The ICMP code for the rule.
* `icmp_type`       (default `null`):         The ICMP type for the rule.
* `cidr_block`      (default `10.96.0.0/12`): The CIDR block for the rule.
* `ipv6_cidr_block` (default `null`):         The ipv6 CIDR block for the rule.

A `default_security_group` objet supports the following arguments:
* `manage`  (default `false`): Whether to have Terraform manage the default security group. A default security group is always created in AWS. Managing the group allows customizing the ingress and egress rules when needed.
* `egress`  (default `[]`):    A list of `group_rules` objects.
* `ingress` (default `[]`):    A list of `group_rules` objects.

A `group_rules` object supports the following arguments:
* `rule_number`      (required):       A unique rule number.
* `cidr_blocks`      (default `null`): List of CIDR blocks.
* `description`      (default `null`): Description of this rule.
* `from_port`        (default `null`): Start port (or ICMP type number if protocol is `icmp`).
* `to_port`          (default `null`): End range port (or ICMP type number if protocl is `icmp`).
* `ipv6_cidr_blocks` (default `null`): List if IPv6 CIDR blocks.
* `prefix_list_ids`  (default `null`): List of prefix list IDs (for allowing access tp VPC endpoints).
* `protocol`         (default `null`): Protocol. If you select a protocol of `-1` (semantically equivalent to `all`.
* `security_groups`  (default `null`): List of security group Group Names if using EC2-Classic, or Group IDs if using a VPC.
* `self`             (default `null`): Whether the security group itself will be added as a source to this egress rule.

A `dhcp_options` object supports the following arguments:
* `create`               (default `true`):                  Whether to create a DHCP Options resource.
* `domain_name`          (default `aws.palig.com`):         The suffix domain name to use by default.
* `domain_name_servers`  (default `["AmazonProvidedDNS"]`): List of name servers.
* `ntp_servers`          (default `[]`):                    List of NTP servers.
* `netbios_name_servers` (default `[]`):                    List of NETBIOS name servers.
* `netbios_node_type`    (default `null`):                  The NETBIOS node type.

A `dns` object supports the following arguments:
* `enable_dns_support`   (default `true`):  Enable DNS support for the VPC.
* `enable_dns_hostnames` (default `false`): Enable DNS hostnames for the VPC.

A `logging` object supports the following arguments:
* `enabled`          (default `false`):                                                  A
* `bucket`           (default `arn:aws:s3:::palig-2148-ENV-logging-vpc-flow-logs`):      The bucket for VPC flow logs when `destination_type` is `s3`. ENV will be dev or prod, based on the environment tag.
* `prefix`           (default `account_id/organization/environment/region/name_suffix`): The prefix to assign logs when `destination_type` is `s3`. The values of the default will be populated based on the variable values.
* `destination_type` (default `s3`):                                                     The destination type for VPC flow logs. Currently only `s3` is supported.
* `traffic_type`     (default `all`):                                                    The traffic type to log.
* `log_format`       (default `null`):                                                   Custom formatting for logs.

A `nat_gateway` object supports the following arguments:
* `enabled` (default `false`):      Enable NAT gateway. Must also set `enable_internet_gateway` to `true`.
* `type`    (default `per_subnet`): Create a NAT gateway in each public subnet (`per_subnet`), or create a single gateway in the first defined public subnet (`single`).

## Output Values

* `security_groups`: A map of the security groups managed by this module. Each group has the following attributes:
  * `arn`
  * `description`
  * `id`
  * `name`

* `subnets`: A map of the subnets created. Each subnet has the following attributes:
  * `arn`
  * `id`
  * `cidr_block`
  * `tags`

* `subnet_groups`: A map of the subnet groups created. The key of the map will be tye group type (ie. `database`). Each subnet group has the following attributes:
  * `arn`
  * `id`
  * `name`
  * `tags`

* `vpc`: Attributes of the created VPC.
  * `arn`
  * `cidr_block`
  * `id`
  * `name`
  * `tags`

## Managed Resources

* `aws_db_subnet_group.main` from `aws`
* `aws_default_security_group.main` from `aws`
* `aws_eip.main` from `aws`
* `aws_flow_log.main` from `aws`
* `aws_internet_gateway.main` from `aws`
* `aws_nat_gateway.main` from `aws`
* `aws_network_acl.main` from `aws`
* `aws_network_acl_rule.main` from `aws`
* `aws_route.main` from `aws`
* `aws_route_table.main` from `aws`
* `aws_route_table_association.main` from `aws`
* `aws_subnet.main` from `aws`
* `aws_vpc.main` from `aws`
* `aws_vpc_dhcp_options.main` from `aws`
* `aws_vpc_dhcp_options_association.main` from `aws`
* `time_static.main` from `time`

## Data Resources

* `data.aws_caller_identity.current` from `aws`

