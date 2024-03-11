### CUSTOM
variable "custom_subnets_count" {
  default = 2
}

### LOCALS VARIABLES
variable "name_suffix" {
  description = "A name to append to the end of all resources."
  type        = string
  default     = "suffix"
}

variable "additional_tags" {
  description = "A map of tags to be assigned to the resources. These will be overwritten if they conflict with required tags."
  type        = map(string)
  default = {
    Name     = "Chyngyzkan"
    Lastname = "Samatov"
  }
}

variable "required_tags" {
  description = "A map of tags that are required for all resources."
  type = object({
    application      = string
    environment      = string
    organization     = string
    provisioner-file = string
    region           = string
  })
  default = {
    application      = "jomok"
    environment      = "qa"
    organization     = "jomok"
    provisioner-file = "terraform"
    region           = "us-east-1"
  }
}

# https://registry.terraform.io/providers/figma/aws-4-49-0/latest/docs/resources/flow_log#s3-logging-in-apache-parquet-format-with-per-hour-partitions
variable "logging" {
  description = "A logging object for configuration VPC flow logs."
  type        = any
  default = {
    /*
    enabled                    = "true"
    bucket                     = "anythingbucket"
    file_format                = "parquet"
    hive_compatible_partitions = "true"
    per_hour_partition         = "true"
    destination_type           = "cloud-watch-logs"
*/
  }
}

# if to set deployment type to single and run terraform console on local.nat_gateway_list, it returns a single NAT, but main.tf apply fails
variable "nat_gateway" {
  description = "NAT gateway configuration object."
  type        = any
  default = {
    enabled = true
  }
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/default_security_group
variable "default_security_group" {
  description = "A default security group object for creating and configuring the VPC default security group."
  type        = any
  default = {
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

    egress = []
  }
}

variable "subnets" {
  description = "Subnet objects."
  type        = any
  default = {
    # This default value is a map containing sub-maps for different types of subnets (in this case, 
    # only "public" subnet is defined). Each subnet has a cidr_list and an acls sub-map defining CIDR 
    # blocks and Access Control Lists (ACLs) respectively.
    public = {
      cidr_list = {
        "us-east-1a" = "10.96.64.10/23"
        "us-east-1b" = "10.96.64.20/23"
        "us-east-1c" = "10.96.64.30/23"
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
        "us-east-1a" = "10.96.64.10/23"
        "us-east-1b" = "10.96.64.20/23"
        "us-east-1c" = "10.96.64.30/23"
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

  }
}


variable "enable_internet_gateway" {
  description = "Create an internet gateway for the VPC."
  type        = bool
  default     = true
}

variable "enable_ipv6" {
  description = "Enable IPv6 and create associated resources when necessary."
  type        = bool
  default     = false
}

### MAIN VARIABLES

variable "dns" {
  description = "DNS options object."
  type        = any
  default     = {}
}

variable "dhcp_options" {
  description = "DHCP options object."
  type        = any
  default     = {}
}

variable "cidr_block" {
  description = "The primary CIDR for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}
