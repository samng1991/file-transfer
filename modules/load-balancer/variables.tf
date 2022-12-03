variable "common_tags" {
  type = map(string)
}

variable "load_balancer" {
  type = object({
    name     = string
    internal = bool
    load_balancer_type = string
    subnet_names = optional(list(string), [])
    subnet_mapping = optional(list(object({
      subnet_name = string
      private_ipv4_address = string
    })))
    access_logs = object({
        bucket  = optional(string, "")
        prefix  = optional(string, "")
        enabled = bool
    })
    enable_deletion_protection = optional(bool, true)
    enable_cross_zone_load_balancing = optional(bool, true)
    is_create_target_group           = optional(bool, false)
    target_group = optional(object({
      vpc_name = string
    }))
    is_create_security_group         = optional(bool, false)
    listeners = optional(list(object({
      port            = string
      protocol        = string
      ssl_policy      = string
      certificate_arn = string

      rules = list(object({
        priority          = number
        host_header       = list(string)
        path_pattern      = list(string)
        target_group_name = string
      }))
    })), [])
    extra_tags = optional(map(string), {})
  })
}
