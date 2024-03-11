

locals {
  # ----------------------------------------------------------------------------
  # Initial Variables
  # ----------------------------------------------------------------------------
  # https://developer.hashicorp.com/terraform/language/functions/regex
  # regex applies a regular expression to a string and returns the matching substrings.
  # regex(pattern, string)
  # define a local, called `name_suffix`
  # ^: Matches the start of the string.
  #[a-z0-9\\-]: Matches any lowercase letter (a-z), any digit (0-9), or a hyphen (-).
  # {0,10}: Quantifier that specifies the minimum and maximum number of occurrences 
  # of the preceding character set. In this case, it allows for 0 to 10 occurrences 
  # of lowercase letters, digits, or hyphens.
  # lower converts all cased letters in the given string to lowercase.
  # This part converts the name_suffix variable to lowercase before applying the regular 
  # expression. This ensures that the regex pattern matches against lowercase characters.
  name_suffix = regex("^[a-z0-9\\-]{0,10}", lower(var.name_suffix))

  #########################
  ### TERRAFORM CONSOLE ### STRING RETURNED
  #########################
  /*
chyngyzkan-samatov string data type was provided to `name_suffix`
> local.name_suffix
"chyngyzkan"
*/

  # define a local, called `major_environment`
  # https://developer.hashicorp.com/terraform/language/functions/contains
  # contains determines whether a given list or set contains a given single value as one of its elements.
  # returns true or false, if it returns true, assign `prod`, otherwise `dev` 
  # contains(list, value)
  major_environment = contains(["prod", "production"], local.tags.environment) ? "prod" : "dev"

  #########################
  ### TERRAFORM CONSOLE ### STRING RETURNED
  #########################
  /*
for `required_tags` object variable's key named `environment` was assigned `prod` value
> local.major_environment
"prod"

for `required_tags` object variable's key named `environment` was assigned `qa` value
> local.major_environment
"dev"
*/

  # define a local, called `tags`
  # https://developer.hashicorp.com/terraform/language/functions/merge
  # merge takes an arbitrary number of maps or objects, and returns a single 
  # map or object that contains a merged set of elements from all arguments.
  tags = merge(
    var.additional_tags, # map of strings
    var.required_tags,   # object of strings
    {
      provisioner        = "terraform"
      provisioner-module = "terraform-aws-vpc"
      creation-time      = time_static.main.rfc3339
      # https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/static
      # time_static.main.rfc3339: This refers to the rfc3339 attribute of the time_static 
      # module, specifically the main output of that module. The rfc3339 attribute typically
      # represents a timestamp in the RFC 3339 format, which is a standard for representing 
      # dates and times in a machine-readable format.
      # So, this line of code calculates the RFC 3339 formatted timestamp using the 
      # time_static module and assigns it to the creation-time local value.
    }
  )

  #########################
  ### TERRAFORM CONSOLE ### MAP OF STRINGS RETURNED CONSISTING OF KEY VALUE PAIRS
  #########################
  /*
> local.tags
{
  "Lastname" = "Samatov"                   -> additional_tags
  "Name" = "Chyngyzkan"   

  "application" = "jomok"                  -> required_tags
  "creation-time" = "2024-02-15T20:14:53Z"
  "environment" = "qa"
  "organization" = "jomok"
  "provisioner" = "terraform"
  "provisioner-file" = "terraform"
  "provisioner-module" = "terraform-aws-vpc"
  "region" = "us-east-1"
}
> local.tags.application
"jomok"
*/

  # define a local, called `name_base`
  # https://developer.hashicorp.com/terraform/language/functions/join
  # join produces a string by concatenating all of the elements of the 
  # specified list of strings with the specified separator.
  # join(separator, list)
  # https://developer.hashicorp.com/terraform/language/functions/compact
  # compact takes a list of strings and returns a new list with any null or empty string elements removed.
  name_base = join("-", compact([
    local.tags.application, # all there are string data types
    local.tags.environment,
    local.tags.region,
    local.name_suffix,
    "vpc"
    ]
    )
  )

  #########################
  ### TERRAFORM CONSOLE ### STRING DATA TYPE IS RETURNED
  #########################
  /*
> local.name_base
"jomok-qa-us-east-1-chyngyzkan-vpc"
> length(local.name_base)
33
*/


  # ----------------------------------------------------------------------------
  # Logging
  # ----------------------------------------------------------------------------
  # defined a local called `logging_target_prefix`
  # https://developer.hashicorp.com/terraform/language/functions/join
  # join produces a string by concatenating all of the elements of the specified list 
  # of strings with the specified separator. join(separator, list)
  # https://developer.hashicorp.com/terraform/language/functions/compact
  # compact takes a list of strings and returns a new list with any null or empty string elements removed.
  logging_target_prefix = join(
    "/",
    compact(
      [
        # data.aws_caller_identity.current is returned as a map containing 4 key value pairs
        # when its specific key is accessed, it's returned as a string data type 
        data.aws_caller_identity.current.account_id,

        #query the following keys of `tags` map and combine all together
        local.tags.application,
        local.tags.environment,
        local.tags.region,
        local.name_suffix,
      ]
    )
  )

  #########################
  ### TERRAFORM CONSOLE ### STRING DATA TYPE IS RETURNED
  #########################
  /*
> local.logging_target_prefix
"326014234008/jomok/qa/us-east-1/chyngyzkan"
*/

  # defined another local called `logging` for the following definition
  # https://registry.terraform.io/providers/figma/aws-4-49-0/latest/docs/resources/flow_log#s3-logging-in-apache-parquet-format-with-per-hour-partitions
  # https://developer.hashicorp.com/terraform/language/functions/lookup
  # lookup retrieves the value of a single element from a map, given its key. 
  # If the given key does not exist, the given default value is returned instead.
  # lookup(map, key, default)
  # `logging` variable is of type `any` which defaults to an empty map 
  # interpolation is in used, all these keys are customizable within `logging` variable
  logging = {
    enabled          = lookup(var.logging, "enabled", false)
    bucket           = lookup(var.logging, "bucket", "arn:aws:s3:::jomok-2148-${local.major_environment}-logging-vpc-flow-logs")
    prefix           = lookup(var.logging, "prefix", local.logging_target_prefix)
    destination_type = lookup(var.logging, "destination_type", "s3")
    traffic_type     = lookup(var.logging, "traffic_type", "ALL")
    log_format       = lookup(var.logging, "log_format", null)

    # there parameters designed not to be changed
    iam_role                 = ""
    max_aggregation_interval = 600

    # defined a nested parameter that aligns with terraform definition, that returns a map
    # if key `destination_type` wasn't defined or was defined with s3, if it's not going to be s3
    # empty tomap({}) will be returned
    destination_options = lookup(var.logging, "destination_type", "s3") == "s3" ? {
      file_format                = "plain-text"
      hive_compatible_partitions = false
      per_hour_partition         = false
    } : {}
  }

  #########################
  ### TERRAFORM CONSOLE ### STRING DATA TYPE IS RETURNED
  #########################
  /*
### THESE ARE DEFAULT VALUES RETURNED, WHEN GIVEN KEYS DON'T DEFINED within `logging` variable
> local.logging
{
  "bucket" = "arn:aws:s3:::jomok-2148-dev-logging-vpc-flow-logs"
  "destination_options" = tomap({
    "file_format" = "plain-text"
    "hive_compatible_partitions" = "false"
    "per_hour_partition" = "false"
  })
  "destination_type" = "s3"
  "enabled" = false
  "iam_role" = ""
  "log_format" = null
  "max_aggregation_interval" = 600
  "prefix" = "326014234008/jomok/qa/us-east-1/chyngyzkan"
  "traffic_type" = "ALL"
}

### GIVEN KEYS within `logging` variable were defined or provided by end-user
> var.logging
{
  "bucket" = "anythingbucket"
  "destination_type" = "cloud-watch-logs"
  "enabled" = "true"
  "file_format" = "parquet"
  "hive_compatible_partitions" = "true"
  "per_hour_partition" = "true"
}
> local.logging
{
  "bucket" = "anythingbucket"
  "destination_options" = tomap({})
  "destination_type" = "cloud-watch-logs"
  "enabled" = "true"
  "iam_role" = ""
  "log_format" = null
  "max_aggregation_interval" = 600
  "prefix" = "326014234008/jomok/qa/us-east-1/chyngyzkan"
  "traffic_type" = "ALL"
}
*/

  # ----------------------------------------------------------------------------
  # Gateway
  # ----------------------------------------------------------------------------
  # ???? WHERE IS terraform definition doc ????? NEEDS TO MODIFY THIS BLOCK OF CODE 
  # https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/nat_gateway
  # defined a local called `nat_gateway`
  # `nat_gateway` variable is of type `any` which defaults to an empty map 
  nat_gateway = {
    enabled = lookup(var.nat_gateway, "enabled", false)
    type    = lookup(var.nat_gateway, "type", "per-subnet")
  }

  #########################
  ### TERRAFORM CONSOLE ### 
  #########################
  /*
> local.nat_gateway
{
  "enabled" = false
  "type" = "per-subnet"
}

### THE VALUES ARE DEFINED
> var.nat_gateway
{
  "enabled" = true
  "type" = "custom-size"
}
> local.nat_gateway
{
  "enabled" = true
  "type" = "custom-size"
}
*/


  # ----------------------------------------------------------------------------
  # Security Group
  # ----------------------------------------------------------------------------
  # defined another local called `default_security_group`
  # https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/default_security_group
  # https://developer.hashicorp.com/terraform/language/functions/lookup
  # lookup retrieves the value of a single element from a map, given its key. 
  # If the given key does not exist, the given default value is returned instead.
  # lookup(map, key, default)
  # conditional evaluation was defined, if `manage` key was defined by end-user and it's set to true
  # assign the following block of code to this local, with main key `enabled` 
  # that has two nested keys of type map that contains information about ingress and egress rules.
  default_security_group = lookup(var.default_security_group, "manage", false) ? {
    enabled = {
      # if `ingress` key wasn't defined by end-user or if it was defined as an empty list, assign an empty map
      # otherwise ????
      ingress = lookup(var.default_security_group, "ingress", []) == [] ? {} : {
        # for loop was defined: https://developer.hashicorp.com/terraform/language/expressions/for
        # A for expression's input (given after the in keyword) can be a list, a set, a tuple, a map, or an object.
        # The type of brackets around the for expression decide what type of result it produces.
        # This line begins a loop over the ingress rules defined in the `var.default_security_group`
        # For each ingress_values object in the list, 
        # Terraform assigns the value of ingress_values.rule_number as the key for the resulting map
        # for example 100 
        # =>: This is the Terraform syntax for mapping keys to values in a map. 
        # In this context, it's used to assign the ingress_values.rule_number as the key for the resulting map.
        # ingress_values: This variable represents each element (ingress rule) 
        # in the var.default_security_group.ingress list during each iteration of the loop.
        # So, ingress_values is a temporary variable that holds each ingress rule object 
        # during each iteration of the loop. 
        #The => symbol maps the rule_number of each ingress rule to the resulting map.
        for ingress_values in var.default_security_group.ingress : ingress_values.rule_number => {
          # `var.default_security_group.ingress` is a list of map object, 
          # assign the value of the key `rule_number` as a key and return a map
          # via lookup() function check the following keys in returned map, if found assign values
          # otherwise set to null
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
      # if `egress` key wasn't defined by end-user or if it was defined as an empty list, assign an empty map
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
  } : {} #if `manage` key wasn't defined by end-user, assign an empty map to `default_security_group` local


  #########################
  ### TERRAFORM CONSOLE ### 
  #########################
  /*
> var.default_security_group
{}
> local.default_security_group
tomap({})

### VALUES WERE DEFINED
> var.default_security_group
{
  "manage" = true
}
> local.default_security_group
tomap({
  "enabled" = {
    "egress" = {}
    "ingress" = {}
  }
})

### VALUES WERE DEFINED
> var.default_security_group
{
  "egress" = []
  "ingress" = []
  "manage" = true
}
> local.default_security_group
tomap({
  "enabled" = {
    "egress" = {}
    "ingress" = {}
  }
})

### VALUES WERE DEFINED
> var.default_security_group
{
  "egress" = []
  "ingress" = [
    {
      "cidr_blocks" = [
        "0.0.0.0/0",
      ]
      "description" = "Allow all"
      "from_port" = 0
      "protocol" = "all"
      "rule_number" = 100
      "to_port" = 0
    },
  ]
  "manage" = true
}
> local.default_security_group
tomap({
  "enabled" = {
    "egress" = {}
    "ingress" = tomap({
      "100" = {
        "cidr_blocks" = [
          "0.0.0.0/0",
        ]
        "description" = "Allow all"
        "from_port" = 0
        "ipv6_cidr_blocks" = null
        "prefix_list_ids" = null
        "protocol" = "all"
        "security_groups" = null
        "self" = null
        "to_port" = 0
      }
    })
  }
})
> local.default_security_group.enabled
{
  "egress" = {}
  "ingress" = tomap({
    "100" = {
      "cidr_blocks" = [
        "0.0.0.0/0",
      ]
      "description" = "Allow all"
      "from_port" = 0
      "ipv6_cidr_blocks" = null
      "prefix_list_ids" = null
      "protocol" = "all"
      "security_groups" = null
      "self" = null
      "to_port" = 0
    }
  })
}
> local.default_security_group.enabled.ingress
tomap({
  "100" = {
    "cidr_blocks" = [
      "0.0.0.0/0",
    ]
    "description" = "Allow all"
    "from_port" = 0
    "ipv6_cidr_blocks" = null
    "prefix_list_ids" = null
    "protocol" = "all"
    "security_groups" = null
    "self" = null
    "to_port" = 0
  }
})
> local.default_security_group.enabled.ingress.100
{
  "cidr_blocks" = [
    "0.0.0.0/0",
  ]
  "description" = "Allow all"
  "from_port" = 0
  "ipv6_cidr_blocks" = null
  "prefix_list_ids" = null
  "protocol" = "all"
  "security_groups" = null
  "self" = null
  "to_port" = 0
}
> local.default_security_group.enabled.ingress.100.protocol
"all"
*/


  # ----------------------------------------------------------------------------
  # Subnets
  # ----------------------------------------------------------------------------
  # Convert the subnet variable to a list of maps
  # https://developer.hashicorp.com/terraform/language/functions/flatten
  # flatten takes a list and replaces any elements that are lists with a flattened sequence of the list contents.
  # define a local called `subnets_list` that accepts a list and returns a list of objects 
  # that each can be accessed via its index location within a list 
  subnets_list = flatten([
    # The code starts by looping through each subnet type (public in this case) and its associated values defined in the var.subnets
    for subnet_type, subnet_values in var.subnets : [
      # Within each subnet type, there's another loop that iterates over each availability 
      # zone and its associated CIDR block defined in the cidr_list.
      # For each availability zone and CIDR block combination, an object representing the subnet configuration is created. 
      # This object contains various attributes like name, route_table_name, and etc.
      for availability_zone, cidr in subnet_values.cidr_list : [
        # return a list of map objects each accessed at its index location within a list 
        {
          # https://developer.hashicorp.com/terraform/language/functions/lookup
          # lookup retrieves the value of a single element from a map, given its key. 
          # If the given key does not exist, the given default value is returned instead.
          # lookup(map, key, default)
          # These attributes are constructed based on the subnet type and availability zone. 
          # If the subnet type is public, the route_table_name defaults to "public".
          name             = "${lookup(subnet_values, "name_suffix", subnet_type)}-${availability_zone}"
          route_table_name = subnet_type == "public" ? "public" : "${lookup(subnet_values, "name_suffix", subnet_type)}-${availability_zone}"

          # This attribute simply store the availability zone.
          availability_zone = availability_zone
          #  It takes a boolean value retrieved from the subnet_values or defaults to false.
          map_public_ip_on_launch = lookup(subnet_values, "map_public_ip_on_launch", false)
          # This attribute simply store the availability cidr
          cidr = cidr
          # Stores the subnet type.
          type = subnet_type
          # https://developer.hashicorp.com/terraform/language/functions/merge
          # merge takes an arbitrary number of maps or objects, and returns a single map 
          # or object that contains a merged set of elements from all arguments.
          # Merges `additional tags` specified in subnet_values with local tags.
          tags = merge(lookup(subnet_values, "additional_tags", {}), local.tags)

          # Subnets in this list are able to create a subnet-group resource.
          # https://developer.hashicorp.com/terraform/language/functions/contains
          # contains determines whether a given list or set contains a given single value as one of its elements.
          # contains(list, value)
          # Determines if the subnet can create a subnet group based on the subnet type. 
          # If the subnet type is "database", it's set to true.
          create_group = contains(["database"], subnet_type) ? lookup(subnet_values, "create_group", true) : null
        }
      ]
    ]
  ])


  #########################
  ### TERRAFORM CONSOLE ### 
  #########################
  /*
> var.subnets
{
  "private" = {
    "cidr_list" = {
      "us-east-1a" = "10.97.32.192/26"
      "us-east-1b" = "10.97.33.0/26"
      "us-east-1c" = "10.97.33.64/26"
    }
  }
  "public" = {
    "cidr_list" = {
      "us-east-1a" = "10.97.32.0/26"
      "us-east-1b" = "10.97.32.64/26"
      "us-east-1c" = "10.97.32.128/26"
    }
  }
}
> length(var.subnets)
2
> var.subnets.private
{
  "cidr_list" = {
    "us-east-1a" = "10.97.32.192/26"
    "us-east-1b" = "10.97.33.0/26"
    "us-east-1c" = "10.97.33.64/26"
  }
}

> local.subnets_list
[
  {
    "availability_zone" = "us-east-1a"
    "cidr" = "10.97.32.192/26"
    "create_group" = tobool(null)
    "map_public_ip_on_launch" = false
    "name" = "private-us-east-1a"
    "route_table_name" = "private-us-east-1a"
    "tags" = {
      "Lastname" = "Samatov"
      "Name" = "Chyngyzkan"
      "application" = "jomok"
      "creation-time" = "2024-02-15T20:14:53Z"
      "environment" = "qa"
      "organization" = "jomok"
      "provisioner" = "terraform"
      "provisioner-file" = "terraform"
      "provisioner-module" = "terraform-aws-vpc"
      "region" = "us-east-1"
    }
    "type" = "private"
  },
  {
    "availability_zone" = "us-east-1b"
    "cidr" = "10.97.33.0/26"
    "create_group" = tobool(null)
    "map_public_ip_on_launch" = false
    "name" = "private-us-east-1b"
    "route_table_name" = "private-us-east-1b"
    "tags" = {
      "Lastname" = "Samatov"
      ...
      "region" = "us-east-1"
    }
    "type" = "private"
  },
  {
    "availability_zone" = "us-east-1c"
    "cidr" = "10.97.33.64/26"
    "create_group" = tobool(null)
    "map_public_ip_on_launch" = false
    "name" = "private-us-east-1c"
    "route_table_name" = "private-us-east-1c"
    "tags" = {
      "Lastname" = "Samatov"
      ...
      "region" = "us-east-1"
    }
    "type" = "private"
  },
  {
    "availability_zone" = "us-east-1a"
    "cidr" = "10.97.32.0/26"
    "create_group" = tobool(null)
    "map_public_ip_on_launch" = false
    "name" = "public-us-east-1a"
    "route_table_name" = "public"
    "tags" = {
      "Lastname" = "Samatov"
      ...
      "region" = "us-east-1"
    }
    "type" = "public"
  },
  {
    "availability_zone" = "us-east-1b"
    "cidr" = "10.97.32.64/26"
    "create_group" = tobool(null)
    "map_public_ip_on_launch" = false
    "name" = "public-us-east-1b"
    "route_table_name" = "public"
    "tags" = {
      "Lastname" = "Samatov"
      ...
      "region" = "us-east-1"
    }
    "type" = "public"
  },
  {
    "availability_zone" = "us-east-1c"
    "cidr" = "10.97.32.128/26"
    "create_group" = tobool(null)
    "map_public_ip_on_launch" = false
    "name" = "public-us-east-1c"
    "route_table_name" = "public"
    "tags" = {
      "Lastname" = "Samatov"
      ...
      "region" = "us-east-1"
    }
    "type" = "public"
  },
]
> length(local.subnets_list)
6
> local.subnets_list.0.cidr
"10.97.32.192/26"
*/



  # Convert the list of subnet maps into a nested map
  # make name argument a key for each map
  subnets = {
    for subnet in local.subnets_list : subnet.name => subnet
  }

  #########################
  ### TERRAFORM CONSOLE ### 
  #########################
  /*
> local.subnets
{
  "private-us-east-1a" = {
    "availability_zone" = "us-east-1a"
    "cidr" = "10.97.32.192/26"
    "create_group" = tobool(null)
    "map_public_ip_on_launch" = false
    "name" = "private-us-east-1a"
    "route_table_name" = "private-us-east-1a"
    "tags" = {
      "Lastname" = "Samatov"
      "Name" = "Chyngyzkan"
      "application" = "jomok"
      "creation-time" = "2024-02-15T20:14:53Z"
      "environment" = "qa"
      "organization" = "jomok"
      "provisioner" = "terraform"
      "provisioner-file" = "terraform"
      "provisioner-module" = "terraform-aws-vpc"
      "region" = "us-east-1"
    }
    "type" = "private"
  }
  "private-us-east-1b" = {
    "availability_zone" = "us-east-1b"
    "cidr" = "10.97.33.0/26"
    "create_group" = tobool(null)
    "map_public_ip_on_launch" = false
    "name" = "private-us-east-1b"
    "route_table_name" = "private-us-east-1b"
    "tags" = {
      "Lastname" = "Samatov"
      ...
      "region" = "us-east-1"
    }
    "type" = "private"
  }
  "private-us-east-1c" = {
    "availability_zone" = "us-east-1c"
    "cidr" = "10.97.33.64/26"
    "create_group" = tobool(null)
    "map_public_ip_on_launch" = false
    "name" = "private-us-east-1c"
    "route_table_name" = "private-us-east-1c"
    "tags" = {
      "Lastname" = "Samatov"
      ...
      "region" = "us-east-1"
    }
    "type" = "private"
  }
  "public-us-east-1a" = {
    "availability_zone" = "us-east-1a"
    "cidr" = "10.97.32.0/26"
    "create_group" = tobool(null)
    "map_public_ip_on_launch" = false
    "name" = "public-us-east-1a"
    "route_table_name" = "public"
    "tags" = {
      "Lastname" = "Samatov"
      ...
      "region" = "us-east-1"
    }
    "type" = "public"
  }
  "public-us-east-1b" = {
    "availability_zone" = "us-east-1b"
    "cidr" = "10.97.32.64/26"
    "create_group" = tobool(null)
    "map_public_ip_on_launch" = false
    "name" = "public-us-east-1b"
    "route_table_name" = "public"
    "tags" = {
      "Lastname" = "Samatov"
      ...
      "region" = "us-east-1"
    }
    "type" = "public"
  }
  "public-us-east-1c" = {
    "availability_zone" = "us-east-1c"
    "cidr" = "10.97.32.128/26"
    "create_group" = tobool(null)
    "map_public_ip_on_launch" = false
    "name" = "public-us-east-1c"
    "route_table_name" = "public"
    "tags" = {
      "Lastname" = "Samatov"
      ...
      "region" = "us-east-1"
    }
    "type" = "public"
  }
}

> length(local.subnets)
6
> local.subnets.private-us-east-1a
{
  "availability_zone" = "us-east-1a"
  "cidr" = "10.97.32.192/26"
  "create_group" = tobool(null)
  "map_public_ip_on_launch" = false
  "name" = "private-us-east-1a"
  "route_table_name" = "private-us-east-1a"
  "tags" = {
    "Lastname" = "Samatov"
    ...
    "region" = "us-east-1"
  }
  "type" = "private"
}
> local.subnets.private-us-east-1a.cidr
"10.97.32.192/26"
*/




  #### MAP THAT GENERATE ONLY PUBLIC GUYS
#  for_custom_subnets = {
#    for subnet in local.subnets_list : subnet.name => subnet
#    if subnet.type == "public" ############
#  }

#  custom_subnets_count = 2 // This value can be controlled by the user

  #### FILTER AND GET ME EXACT NUMBER OF SUBNETS FOR NAT
#  custom_subnets = {
#    for idx, subnet in slice((values(local.for_custom_subnets)), 0, local.custom_subnets_count) : subnet.name => subnet
#  }



  # Database subnets
  # The true/false results must have consisten types
  # https://developer.hashicorp.com/terraform/language/functions/contains
  # contains determines whether a given list or set contains a given single value as one of its elements.
  # contains(list, value)
  # https://developer.hashicorp.com/terraform/language/functions/keys
  # keys takes a map and returns a list containing the keys from that map.
  database_subnets = contains(keys(var.subnets), "database") ? {
    # https://developer.hashicorp.com/terraform/language/functions/lookup
    create = lookup(var.subnets.database, "create_group", true)
    # https://developer.hashicorp.com/terraform/language/functions/join
    # join produces a string by concatenating all of the elements of the specified list of strings with the specified separator.
    # join(separator, list)
    group_name = join("-", [local.name_base, lookup(var.subnets.database, "name_suffix", "database"), "grp"])
    # https://developer.hashicorp.com/terraform/language/functions/merge
    tags = merge(lookup(var.subnets.database, "additional_tags", {}), local.tags)
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

  #########################
  ### TERRAFORM CONSOLE ### 
  #########################
  /*
> var.subnets
{
  "private" = {
    "cidr_list" = {
      "us-east-1a" = "10.97.32.192/26"
      "us-east-1b" = "10.97.33.0/26"
      "us-east-1c" = "10.97.33.64/26"
    }
  }
  "public" = {
    "cidr_list" = {
      "us-east-1a" = "10.97.32.0/26"
      "us-east-1b" = "10.97.32.64/26"
      "us-east-1c" = "10.97.32.128/26"
    }
  }
}
> local.database_subnets
{
  "create" = false
  "group_name" = null
  "subnets" = null
  "tags" = null
}

> var.subnets
{
  "database" = {
    "cidr_list" = {
      "us-east-1a" = "10.97.33.128/26"
      "us-east-1b" = "10.97.33.192/26"
      "us-east-1c" = "10.97.34.0/26"
    }
  }
  "private" = {
    "cidr_list" = {
      "us-east-1a" = "10.97.32.192/26"
      "us-east-1b" = "10.97.33.0/26"
      "us-east-1c" = "10.97.33.64/26"
    }
  }
  "public" = {
    "cidr_list" = {
      "us-east-1a" = "10.97.32.0/26"
      "us-east-1b" = "10.97.32.64/26"
      "us-east-1c" = "10.97.32.128/26"
    }
  }
}

> local.database_subnets
{
  "create" = true
  "group_name" = "jomok-qa-us-east-1-chyngyzkan-vpc-database-grp"
  "subnets" = {
    "database-us-east-1a" = {
      "availability_zone" = "us-east-1a"
      "cidr" = "10.97.33.128/26"
      "create_group" = true
      "map_public_ip_on_launch" = false
      "name" = "database-us-east-1a"
      "route_table_name" = "database-us-east-1a"
      "tags" = {
        "Lastname" = "Samatov"
        ...
        "region" = "us-east-1"
      }
      "type" = "database"
    }
    "database-us-east-1b" = {
      "availability_zone" = "us-east-1b"
      "cidr" = "10.97.33.192/26"
      "create_group" = true
      "map_public_ip_on_launch" = false
      "name" = "database-us-east-1b"
      "route_table_name" = "database-us-east-1b"
      "tags" = {
        "Lastname" = "Samatov"
        ... 
        "region" = "us-east-1"
      }
      "type" = "database"
    }
    "database-us-east-1c" = {
      "availability_zone" = "us-east-1c"
      "cidr" = "10.97.34.0/26"
      "create_group" = true
      "map_public_ip_on_launch" = false
      "name" = "database-us-east-1c"
      "route_table_name" = "database-us-east-1c"
      "tags" = {
        "Lastname" = "Samatov"
        ... 
        "region" = "us-east-1"
      }
      "type" = "database"
    }
  }
  "tags" = {
    "Lastname" = "Samatov"
    ... 
    "region" = "us-east-1"
  }
}
> length(local.database_subnets)
4
> local.database_subnets.create
true
> local.database_subnets.group_name
"jomok-qa-us-east-1-chyngyzkan-vpc-database-grp"
> local.database_subnets.subnets
{
  "database-us-east-1a" = {
    "availability_zone" = "us-east-1a"
    "cidr" = "10.97.33.128/26"
    "create_group" = true
    "map_public_ip_on_launch" = false
    "name" = "database-us-east-1a"
    "route_table_name" = "database-us-east-1a"
    "tags" = {
      "Lastname" = "Samatov"
      ... 
      "region" = "us-east-1"
    }
    "type" = "database"
  }
  "database-us-east-1b" = {
    "availability_zone" = "us-east-1b"
    "cidr" = "10.97.33.192/26"
    "create_group" = true
    "map_public_ip_on_launch" = false
    "name" = "database-us-east-1b"
    "route_table_name" = "database-us-east-1b"
    "tags" = {
      "Lastname" = "Samatov"
      ... 
      "region" = "us-east-1"
    }
    "type" = "database"
  }
  "database-us-east-1c" = {
    "availability_zone" = "us-east-1c"
    "cidr" = "10.97.34.0/26"
    "create_group" = true
    "map_public_ip_on_launch" = false
    "name" = "database-us-east-1c"
    "route_table_name" = "database-us-east-1c"
    "tags" = {
      "Lastname" = "Samatov"
      ... 
      "region" = "us-east-1"
    }
    "type" = "database"
  }
}
> local.database_subnets.subnets.database-us-east-1c
{
  "availability_zone" = "us-east-1c"
  "cidr" = "10.97.34.0/26"
  "create_group" = true
  "map_public_ip_on_launch" = false
  "name" = "database-us-east-1c"
  "route_table_name" = "database-us-east-1c"
  "tags" = {
    "Lastname" = "Samatov"
    ... 
    "region" = "us-east-1"
  }
  "type" = "database"
}
*/

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
  # is used to generate ACL (Access Control List) configurations based on the subnets variable.
  acls = {
    # This line iterates over each entry in the subnets variable, which is a map containing subnet configurations 
    # for different subnet types (e.g., "public", "private", etc.). For each subnet type, it creates a new ACL configuration.
    for subnet_type, subnet_values in var.subnets : subnet_type => {
      # This line retrieves the value of the key "dedicated_acl" from the subnet_values map using the lookup function. 
      # If the key doesn't exist, it defaults to true. This determines whether a dedicated 
      # ACL should be created for this subnet type.
      create = lookup(subnet_values, "dedicated_acl", true)
      # This line generates the name for the ACL configuration by joining the local.name_base 
      #, the subnet_type, and "acl" with a hyphen separator.
      name = join("-", [local.name_base, subnet_type, "acl"])
      # This line retrieves the value of the key "acls" from the subnet_values map using the lookup function. 
      # If the key doesn't exist, it defaults to an empty map {}. This provides 
      # ACL rules specific to the subnet type, overriding any defaults.
      acls = lookup(subnet_values, "acls", {})
      # This line merges additional tags specified in the additional_tags key of the subnet_values map 
      # (if present) with the local.tags. It allows adding extra tags to the ACL configuration.
      tags = merge(lookup(subnet_values, "additional_tags", {}), local.tags)
      # This line creates a map of subnets filtered by subnet_type. It iterates over local.subnets 
      # (presumably another variable or resource containing subnet configurations), filtering them by their 
      # type attribute matching the current subnet_type, and then mapping them to a map where the key is the
      # subnet name and the value is the subnet configuration.
      subnets = {
        for subnet in local.subnets : subnet.name => subnet
        if subnet.type == subnet_type
      }
    }
  }

  #########################
  ### TERRAFORM CONSOLE ### 
  #########################
  /*
> var.subnets
{
  "public" = {
    "acls" = {
      "egress" = [
        {
          "cidr_block" = "0.0.0.0/0"
          "protocol" = "all"
          "rule_number" = 100
        },
      ]
      "ingress" = [
        {
          "cidr_block" = "0.0.0.0/0"
          "protocol" = "all"
          "rule_number" = 200
        },
      ]
    }
    "cidr_list" = {
      "us-east-1a" = "10.97.32.0/26"
      "us-east-1b" = "10.97.32.64/26"
      "us-east-1c" = "10.97.32.128/26"
    }
  }
}
> local.acls
{
  "public" = {
    "acls" = {
      "egress" = [
        {
          "cidr_block" = "0.0.0.0/0"
          "protocol" = "all"
          "rule_number" = 100
        },
      ]
      "ingress" = [
        {
          "cidr_block" = "0.0.0.0/0"
          "protocol" = "all"
          "rule_number" = 200
        },
      ]
    }
    "create" = true
    "name" = "jomok-qa-us-east-1-chyngyzkan-vpc-public-acl"
    "subnets" = {
      "public-us-east-1a" = {
        "availability_zone" = "us-east-1a"
        "cidr" = "10.97.32.0/26"
        "create_group" = tobool(null)
        "map_public_ip_on_launch" = false
        "name" = "public-us-east-1a"
        "route_table_name" = "public"
        "tags" = {
          "Lastname" = "Samatov"
          ... 
          "region" = "us-east-1"
        }
        "type" = "public"
      }
      "public-us-east-1b" = {
        "availability_zone" = "us-east-1b"
        "cidr" = "10.97.32.64/26"
        "create_group" = tobool(null)
        "map_public_ip_on_launch" = false
        "name" = "public-us-east-1b"
        "route_table_name" = "public"
        "tags" = {
          "Lastname" = "Samatov"
          ... 
          "region" = "us-east-1"
        }
        "type" = "public"
      }
      "public-us-east-1c" = {
        "availability_zone" = "us-east-1c"
        "cidr" = "10.97.32.128/26"
        "create_group" = tobool(null)
        "map_public_ip_on_launch" = false
        "name" = "public-us-east-1c"
        "route_table_name" = "public"
        "tags" = {
          "Lastname" = "Samatov"
          ... 
          "region" = "us-east-1"
        }
        "type" = "public"
      }
    }
    "tags" = {
      "Lastname" = "Samatov"
      ... 
      "region" = "us-east-1"
    }
  }
}
  */

  # Pull the ACL rules out of the acls object and create a list of rules
  # https://developer.hashicorp.com/terraform/language/functions/flatten
  # flatten takes a list and replaces any elements that are lists with a flattened sequence of the list contents.
  # define a local called `acl_rules_list` that accepts a list and returns a list of objects 
  # that each can be accessed via its index location within a list 
  # The acl_rules_list local variable is responsible for generating a flattened list of ACL rules
  # based on the ACL configurations provided in the local.acls variable.
  acl_rules_list = flatten([
    # The code iterates over each ACL configuration specified in the local.acls variable. 
    # This iteration is done for each subnet, hence the nested loops.
    # The flatten function is used to flatten the nested list structure generated by the nested loops into a single list of ACL rules.
    for acl_subnet, acl_values in local.acls : [
      # Within the nested loops, each ACL rule specified in the ACL configuration is processed. 
      # For each rule, a map is created containing various attributes such as egress, rule_number, protocol, rule_action, etc.
      for acl_type, acl_list in acl_values.acls : [
        for acl_rule in acl_list : [
          {
            egress      = acl_type == "egress" ? true : false
            rule_number = acl_rule.rule_number
            protocol    = acl_rule.protocol
            # The lookup function is used to retrieve values from the ACL rule configuration. 
            # If a particular attribute is not provided in the ACL rule configuration, default values are used. 
            # For example, if rule_action, from_port, to_port, icmp_code, icmp_type, cidr_block, or 
            # ipv6_cidr_block is not specified, default values are assigned.
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

  #########################
  ### TERRAFORM CONSOLE ### 
  #########################
  /*
  > local.acl_rules_list
[
  {
    "acl_name" = "public"
    "cidr_block" = "0.0.0.0/0"
    "egress" = true
    "from_port" = null
    "icmp_code" = null
    "icmp_type" = null
    "ipv6_cidr_block" = null
    "protocol" = "all"
    "rule_action" = "allow"
    "rule_name" = "public-egress-100"
    "rule_number" = 100
    "to_port" = null
  },
  {
    "acl_name" = "public"
    "cidr_block" = "0.0.0.0/0"
    "egress" = false
    "from_port" = null
    "icmp_code" = null
    "icmp_type" = null
    "ipv6_cidr_block" = null
    "protocol" = "all"
    "rule_action" = "allow"
    "rule_name" = "public-ingress-200"
    "rule_number" = 200
    "to_port" = null
  },
]
  */

  # Convert the list of acl rule maps into a nested map
  acl_rules = {
    for acl_rule in local.acl_rules_list : acl_rule.rule_name => acl_rule
  }

  #########################
  ### TERRAFORM CONSOLE ### 
  #########################
  /*
> local.acl_rules
{
  "public-egress-100" = {
    "acl_name" = "public"
    "cidr_block" = "0.0.0.0/0"
    "egress" = true
    "from_port" = null
    "icmp_code" = null
    "icmp_type" = null
    "ipv6_cidr_block" = null
    "protocol" = "all"
    "rule_action" = "allow"
    "rule_name" = "public-egress-100"
    "rule_number" = 100
    "to_port" = null
  }
  "public-ingress-200" = {
    "acl_name" = "public"
    "cidr_block" = "0.0.0.0/0"
    "egress" = false
    "from_port" = null
    "icmp_code" = null
    "icmp_type" = null
    "ipv6_cidr_block" = null
    "protocol" = "all"
    "rule_action" = "allow"
    "rule_name" = "public-ingress-200"
    "rule_number" = 200
    "to_port" = null
  }
}
*/

  # ----------------------------------------------------------------------------
  # NAT Gateway
  # ----------------------------------------------------------------------------
  # https://developer.hashicorp.com/terraform/language/functions/sort
  # sort takes a list of strings and returns a new list with those strings sorted lexicographically.
  # The sort is in terms of Unicode codepoints, with higher codepoints appearing after lower ones in the result.
  # https://developer.hashicorp.com/terraform/language/functions/distinct
  # distinct takes a list and returns a new list with any duplicate elements removed.
  # The first occurrence of each value is retained and the relative ordering of these elements is preserved.
  public_availability_zones = sort(distinct([
    for subnet in local.subnets : subnet.availability_zone # `local.subnets` is a map of key and value pairs, this is to bypass
    if subnet.type == "public"                             # key definition and access any values via `subnet.ANYTHING`
  ]))

  #########################
  ### TERRAFORM CONSOLE ### 
  #########################
  /*
> local.public_availability_zones
tolist([
  "us-east-1a",
  "us-east-1b",
  "us-east-1c",
])
*/

  # Build a map of NAT gateways to create, regardless of the deployment type.
  # This is a variable being defined that will hold a map of configurations for NAT gateways. 
  # This is a conditional expression. It checks if the value of the variable var.nat_gateway has 
  # an attribute named "enabled". If it does, it evaluates to the value of that attribute. 
  # If it doesn't, it evaluates to false. 
  nat_gateway_map = lookup(var.nat_gateway, "enabled", false) ? {
    # This is the key in the map when there is only one NAT gateway configuration.
    single = {
      # This is an object block defining the configuration for a single NAT gateway.
      single = {
        # This line creates a list comprehension ([...]) that iterates over each subnet in local.subnets.
        # It filters the subnets based on certain conditions (type is "public" and availability zone 
        # matches the first availability zone in local.public_availability_zones) and then extracts 
        # the name attribute of the first matching subnet.
        subnet_id = [
          for subnet in local.subnets : subnet.name
          if subnet.type == "public" && subnet.availability_zone == local.public_availability_zones[0]
        ][0]
        # This line merges any additional tags specified in the var.nat_gateway variable with the existing tags in local.tags.
        tags = merge(lookup(var.nat_gateway, "additional_tags", {}), local.tags)
      }
    }
    # This is the key in the map when there is a separate NAT gateway configuration for each subnet.
    per_subnet = {
      # This line iterates over each subnet in local.subnets and creates a map where the key is the 
      # name of the subnet and the value is another object block defining the configuration for each subnet.
      for subnet in local.subnets : subnet.name => { #custom_subnets
        # This line assigns the name attribute of the subnet as the value of subnet_id.
        subnet_id = subnet.name
        # Similar to before, this line merges any additional tags specified in the var.nat_gateway 
        # variable with the existing tags in local.tags.
        tags = merge(lookup(var.nat_gateway, "additional_tags", {}), local.tags)
      }
      # This line filters only the subnets whose type is "public".
      #      if subnet.type == "public"
    }
    /*    per_subnet_count = {
      for index, subnet in local.subnets : index => {
        subnet_id = subnet.name
        tags      = merge(lookup(var.nat_gateway, "additional_tags", {}), local.tags)
      }
      if subnet.type == "public" && 0 < length(local.subnets) / var.nat_gateway_count
    }*/
  } : {}


  #########################
  ### TERRAFORM CONSOLE ### 
  #########################
  /*
> local.nat_gateway_map
tomap({
  "per_subnet" = tomap({
    "public-us-east-1a" = {
      "subnet_id" = "public-us-east-1a"
      "tags" = {
        "Lastname" = "Samatov"
        ...
        "region" = "us-east-1"
      }
    }
    "public-us-east-1b" = {
      "subnet_id" = "public-us-east-1b"
      "tags" = {
        "Lastname" = "Samatov"
        ...
        "region" = "us-east-1"
      }
    }
    "public-us-east-1c" = {
      "subnet_id" = "public-us-east-1c"
      "tags" = {
        "Lastname" = "Samatov"
        "Name" = "Chyngyzkan"
        ... 
        "region" = "us-east-1"
      }
    }
  })
  "single" = tomap({
    "single" = {
      "subnet_id" = "public-us-east-1a"
      "tags" = {
        "Lastname" = "Samatov"
        ... 
        "region" = "us-east-1"
      }
    }
  })
})
> length(local.nat_gateway_map.per_subnet)
3
> length(local.nat_gateway_map.single)
1
*/


  # Pick the gateway to use
  # This is a variable being defined that will hold a list of NAT gateway configurations.
  # This function looks up the value of the attribute "enabled" in the variable var.nat_gateway. 
  # If the attribute exists, it returns its value. If it doesn't exist, it returns false.
  # This is a conditional expression that checks the value returned by the lookup function. 
  # If the value is true (meaning NAT gateway is enabled), it selects a deployment type configuration 
  # from local.nat_gateway_map based on the value of the "deployment_type" attribute in var.nat_gateway. 
  # If the "deployment_type" attribute doesn't exist, it defaults to "per_subnet".
  # This is the else part of the conditional expression. If the value returned by the lookup function 
  # is false (meaning NAT gateway is not enabled), it assigns an empty map {} to nat_gateway_list.
  nat_gateway_list = lookup(var.nat_gateway, "enabled", false) ? local.nat_gateway_map[lookup(var.nat_gateway, "deployment_type", "per_subnet")] : {}

  #########################
  ### TERRAFORM CONSOLE ### 
  #########################
  /*
> local.nat_gateway_list
tomap({
  "public-us-east-1a" = {
    "subnet_id" = "public-us-east-1a"
    "tags" = {
      "Lastname" = "Samatov"
      ... 
      "region" = "us-east-1"
    }
  }
  "public-us-east-1b" = {
    "subnet_id" = "public-us-east-1b"
    "tags" = {
      "Lastname" = "Samatov"
      ... 
      "region" = "us-east-1"
    }
  }
  "public-us-east-1c" = {
    "subnet_id" = "public-us-east-1c"
    "tags" = {
      "Lastname" = "Samatov"
      ... 
      "region" = "us-east-1"
    }
  }
})
*/


  # ----------------------------------------------------------------------------
  # Route Tables
  # ----------------------------------------------------------------------------
  # This code block defines a route_tables_list variable. It's a flattened list that 
  # concatenates different types of route tables.
  route_tables_list = flatten([
    # The first element in the list is determined based on the existence of "public" subnets. 
    # If there are public subnets defined in the subnets variable, it adds a route table named "public" to the list.
    lookup(var.subnets, "public", []) == [] ? [] : [{ name = "public" }],

    #lookup(var.subnets, "redshift", []) == [] ? [] : [{ name = "redshift" }],
    #lookup(var.subnets, "outpost", []) == [] ? [] : [{ name = "outpust" }],
    #lookup(var.subnets, "elasticache", []) == [] ? [] : [{ name = "elasticache" }],

    # The second element is a list comprehension looped over local.subnets to generate route tables 
    # for private subnets. It constructs a map for each private subnet with keys name and 
    # availability_zone, derived from subnet.type and subnet.availability_zone respectively. 
    # This comprehension is conditional, only including subnets where subnet.type is "private".
    # The flatten function is used to flatten the list of lists into a single list. 
    # This ensures that all route tables are included in a single list.
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

  #########################
  ### TERRAFORM CONSOLE ### 
  #########################
  /*
### ONLY PUBLIC IS GIVEN
> local.route_tables_list
[
  {
    "name" = "public"
  },
]

### PUBLIC AND PRIVATE SUBNETS ARE GIVEN
> local.route_tables_list
[
  {
    "name" = "public"
  },
  {
    "availability_zone" = "us-east-1a"
    "name" = "private-us-east-1a"
  },
  {
    "availability_zone" = "us-east-1b"
    "name" = "private-us-east-1b"
  },
  {
    "availability_zone" = "us-east-1c"
    "name" = "private-us-east-1c"
  },
]
*/


  # This line initializes a map called route_tables.
  route_tables = {
    # This is a for expression that iterates over each item in the local.route_tables_list.
    # For each item in local.route_tables_list, it creates a key-value pair in the route_tables map, 
    # where the key is route_table.name.
    for route_table in local.route_tables_list : route_table.name => {
      # This line extracts the value of the availability_zone attribute from the route_table.
      # It uses the lookup function to safely retrieve the value. 
      # If the attribute doesn't exist in route_table, it defaults to null.
      availability_zone = lookup(route_table, "availability_zone", null)
      # This line creates the tags attribute for each route table entry in the route_tables map.
      # It merges the local.tags map (containing additional tags) with a new map containing a single tag named "Name".
      # The "Name" tag is constructed by joining several elements using the join function
      tags = merge(local.tags, { Name = join("-", [local.name_base, route_table.name, "rtb"]) })
    }
  }

  #########################
  ### TERRAFORM CONSOLE ### 
  #########################
  /*
> local.route_tables
{
  "private-us-east-1a" = {
    "availability_zone" = "us-east-1a"
    "tags" = {
      "Lastname" = "Samatov"
      ... 
      "region" = "us-east-1"
    }
  }
  "private-us-east-1b" = {
    "availability_zone" = "us-east-1b"
    "tags" = {
      "Lastname" = "Samatov"
      ... 
      "region" = "us-east-1"
    }
  }
  "private-us-east-1c" = {
    "availability_zone" = "us-east-1c"
    "tags" = {
      "Lastname" = "Samatov"
      ... 
      "region" = "us-east-1"
    }
  }
  "public" = {
    "availability_zone" = null
    "tags" = {
      "Lastname" = "Samatov"
      ... 
      "region" = "us-east-1"
    }
  }
}
> length(local.route_tables)
4
*/


  # This code block creates a map called route_table_associations.
  route_table_associations = {
    # This is a for expression that iterates over each subnet object in the local.subnets map.
    # For each subnet, it creates a key-value pair in the route_table_associations map, where the key is subnet.name.
    # This is a conditional expression using the ternary operator ? :.
    # If the type attribute of the subnet is equal to "public", it returns "public".
    # Otherwise, if the type attribute is not equal to "public", it constructs a string 
    # "private-${subnet.availability_zone}".
    for subnet in local.subnets : subnet.name => subnet.type == "public" ? "public" : "private-${subnet.availability_zone}"
  }

  #########################
  ### TERRAFORM CONSOLE ### 
  #########################
  /*
> local.route_table_associations
{
  "private-us-east-1a" = "private-us-east-1a"
  "private-us-east-1b" = "private-us-east-1b"
  "private-us-east-1c" = "private-us-east-1c"
  "public-us-east-1a" = "public"
  "public-us-east-1b" = "public"
  "public-us-east-1c" = "public"
}
> local.route_table_associations.private-us-east-1a
"private-us-east-1a"
> length(local.route_table_associations)
6
*/

  # This is a variable that will contain a list of route configurations.
  # flatten is a function that takes a list of lists and flattens it into a single list.
  route_list = flatten([
    # This section constructs the route configurations based on the values of enable_internet_gateway and nat_gateway.
    # If enable_internet_gateway is true, it adds a route configuration for the 
    # internet gateway (igw) with the destination CIDR block 0.0.0.0/0.
    var.enable_internet_gateway ? [{
      name                   = "igw"
      route_table            = "public"
      destination_cidr_block = "0.0.0.0/0"
      gateway_id             = "enabled"
      nat_gateway_id         = null
    }] : [],
    # If nat_gateway is enabled, it iterates over the local route tables.
    # For each route table (except the "public" route table), it adds a route 
    # configuration with the destination CIDR block 0.0.0.0/0.
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
    # The nat_gateway_id is determined based on the deployment_type specified in the nat_gateway variable.
    # If deployment_type is "single", the nat_gateway_id is set to "public".
    # Otherwise, it's set to "public-${table_values.availability_zone}", where ${table_values.availability_zone} 
    # represents the availability zone of the route table.
    # The resulting route_list contains all the configured routes for the VPC, 
    # including routes for internet gateway and NAT gateway if enabled.
  ])

  #########################
  ### TERRAFORM CONSOLE ### 
  #########################
  /*
> local.route_list
[
  {
    "destination_cidr_block" = "0.0.0.0/0"
    "gateway_id" = "enabled"
    "name" = "igw"
    "nat_gateway_id" = null
    "route_table" = "public"
  },
  {
    "destination_cidr_block" = "0.0.0.0/0"
    "gateway_id" = null
    "name" = "private-us-east-1a"
    "nat_gateway_id" = "public-us-east-1a"
    "route_table" = "private-us-east-1a"
  },
  {
    "destination_cidr_block" = "0.0.0.0/0"
    "gateway_id" = null
    "name" = "private-us-east-1b"
    "nat_gateway_id" = "public-us-east-1b"
    "route_table" = "private-us-east-1b"
  },
  {
    "destination_cidr_block" = "0.0.0.0/0"
    "gateway_id" = null
    "name" = "private-us-east-1c"
    "nat_gateway_id" = "public-us-east-1c"
    "route_table" = "private-us-east-1c"
  },
]
> length(local.route_list)
4
*/


  # This code constructs a map called routes, where each key 
  # is the name attribute of a route and each value is the entire route configuration.
  # The code starts by defining a new map called routes.
  routes = {
    # It uses a for expression to iterate over each item in the local.route_list, 
    # which contains the list of route configurations.
    # For each route in local.route_list, the code creates a key-value pair in the routes map.
    # The key is specified as route.name, which is the name attribute of the route configuration.
    # The value associated with each key is the entire route configuration represented by route.
    for route in local.route_list : route.name => route
    # After iterating over all the routes in local.route_list, the routes map contains all 
    # the route configurations, with each route's name as the key and the full route configuration as the value.
    # This construction allows easy access to route configurations using their names as keys, 
    # which can be useful for referencing specific routes within the Terraform configuration.
  }

  #########################
  ### TERRAFORM CONSOLE ### 
  #########################
  /*
> local.routes
{
  "igw" = {
    "destination_cidr_block" = "0.0.0.0/0"
    "gateway_id" = "enabled"
    "name" = "igw"
    "nat_gateway_id" = null
    "route_table" = "public"
  }
  "private-us-east-1a" = {
    "destination_cidr_block" = "0.0.0.0/0"
    "gateway_id" = null
    "name" = "private-us-east-1a"
    "nat_gateway_id" = "public-us-east-1a"
    "route_table" = "private-us-east-1a"
  }
  "private-us-east-1b" = {
    "destination_cidr_block" = "0.0.0.0/0"
    "gateway_id" = null
    "name" = "private-us-east-1b"
    "nat_gateway_id" = "public-us-east-1b"
    "route_table" = "private-us-east-1b"
  }
  "private-us-east-1c" = {
    "destination_cidr_block" = "0.0.0.0/0"
    "gateway_id" = null
    "name" = "private-us-east-1c"
    "nat_gateway_id" = "public-us-east-1c"
    "route_table" = "private-us-east-1c"
  }
}
*/

}