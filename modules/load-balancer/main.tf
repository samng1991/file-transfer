locals {
  listener_rules = flatten([
    for listener_key, listener in var.load_balancer.listeners : [
      for rule_key, rule in listener.rules : {
        listener_key            = listener_key
        rule_key                = rule_key
        listener_arn            = aws_lb_listener.this[listener_key].arn
        rule_priority           = rule.priority
        rule_host_header        = rule.host_header
        rule_path_pattern       = rule.path_pattern
        rule_target_group_name  = rule.target_group_name
      }
    ]
  ])
}

data "aws_vpc" "this" {
  count = var.load_balancer.is_create_target_group ? 1 : 0

  filter {
    name   = "tag:Name"
    values = [var.load_balancer.target_group.vpc_name]
  }
}

data "aws_lb_target_group" "this_rule_target_group" {
  for_each = {
    for rule in local.listener_rules : "${rule.listener_key}.${rule.rule_key}" => rule
  }

  name = each.value.rule_target_group_name
}


################################################################################
# Subnets
################################################################################
data "aws_subnets" "this_subnets" {
  filter {
    name   = "tag:Name"
    values = var.load_balancer.subnet_names
  }
}

data "aws_subnet" "this_subnets" {
  for_each = toset(data.aws_subnets.this_subnets.ids)

  id = each.value

  depends_on = [
    data.aws_subnets.this_subnets,
  ]
}

data "aws_subnets" "this_subnet_mapping" {
  filter {
    name   = "tag:Name"
    values = var.load_balancer.subnet_mapping != null ? [for subnet_mapping in var.load_balancer.subnet_mapping : subnet_mapping.subnet_name] : []
  }
}

data "aws_subnet" "this_subnet_mapping" {
  for_each = toset(data.aws_subnets.this_subnet_mapping.ids)

  id = each.value

  depends_on = [
    data.aws_subnets.this_subnet_mapping,
  ]
}


################################################################################
# Security Group
################################################################################
resource "aws_security_group" "this" {
  count = var.load_balancer.is_create_security_group ? 1 : 0

  name        = "sgp-${var.load_balancer.name}"
  vpc_id      = var.load_balancer.subnet_mapping == null ? data.aws_subnet.this_subnets[data.aws_subnets.this_subnets.ids[0]].vpc_id : data.aws_subnet.this_subnet_mapping[data.aws_subnets.this_subnet_mapping.ids[0]].vpc_id
  description = "${var.load_balancer.name} security group"

  tags = merge(
    var.common_tags,
    {
      Name = "sgp-${var.load_balancer.name}"
    },
  )
}

resource "aws_security_group_rule" "this_all_https_ingress" {
  count = var.load_balancer.is_create_security_group ? 1 : 0

  description              = "Allow all source to communicate with load balancer"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.this[0].id
  cidr_blocks              = ["0.0.0.0/0"]
  type                     = "ingress"
}

resource "aws_security_group_rule" "this_all_traffic_egress" {
  count = var.load_balancer.is_create_security_group ? 1 : 0

  description              = "Allow load balancer to communicate to all destinations"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "all"
  security_group_id        = aws_security_group.this[0].id
  cidr_blocks              = ["0.0.0.0/0"]
  type                     = "egress"
}


################################################################################
# Load Balancer
################################################################################
resource "aws_lb" "this" {
  name               = var.load_balancer.name
  internal           = var.load_balancer.internal
  load_balancer_type = var.load_balancer.load_balancer_type
  security_groups    = var.load_balancer.is_create_security_group ? [aws_security_group.this[0].id] : null
  subnets            = data.aws_subnets.this_subnets.ids

  dynamic "subnet_mapping" {
    for_each = data.aws_subnet.this_subnet_mapping

    content {
      subnet_id            = subnet_mapping.value.id
      private_ipv4_address = one(compact([for subnet_mapping_input in var.load_balancer.subnet_mapping: subnet_mapping_input.private_ipv4_address if subnet_mapping_input.subnet_name == subnet_mapping.value.tags["Name"]]))
    }
  }

  access_logs {
    bucket  = var.load_balancer.access_logs.bucket
    prefix  = var.load_balancer.access_logs.prefix
    enabled = var.load_balancer.access_logs.enabled
  }

  enable_deletion_protection = var.load_balancer.enable_deletion_protection
  enable_cross_zone_load_balancing = var.load_balancer.enable_cross_zone_load_balancing

  tags = merge(
    var.common_tags,
    var.load_balancer.extra_tags,
    {
      Name = var.load_balancer.name
    },
  )

  depends_on = [
    aws_security_group.this
  ]
}

data "aws_network_interfaces" "this" {
  for_each = var.load_balancer.is_create_target_group ? var.load_balancer.subnet_mapping == null ? toset(data.aws_subnets.this_subnets.ids) : toset([for subnet in data.aws_subnet.this_subnet_mapping : subnet.id]) : toset([])

  filter {
    name   = "description"
    values = ["ELB ${aws_lb.this.arn_suffix}"]
  }

  filter {
    name   = "subnet-id"
    values = [each.value]
  }

  depends_on = [
    aws_lb.this
  ]
}

# data "aws_network_interface" "this" {
#   for_each = [for network_interface in data.aws_network_interfaces.this : network_interface.ids]

#   id = each.value

#   depends_on = [
#     data.aws_network_interfaces.this
#   ]
# }


################################################################################
# Target Group
################################################################################
resource "aws_lb_target_group" "this" {
  count = var.load_balancer.is_create_target_group ? 1 : 0

  name        = "tgp-${var.load_balancer.name}"
  port        = 443
  protocol    = "HTTPS"
  target_type = "ip"
  vpc_id      = data.aws_vpc.this[0].id
  
  depends_on = [
    aws_lb.this
  ]
}

# resource "aws_lb_target_group_attachment" "this" {
#   for_each = data.aws_network_interface.this

#   target_group_arn  = aws_lb_target_group.this[0].arn
#   target_id         = each.value.private_ip
#   port              = 443
#   availability_zone = "all"

#   depends_on = [
#     aws_lb_target_group.this
#   ]
# }


################################################################################
# Load Balacer Listener
################################################################################
resource "aws_lb_listener" "this" {
  for_each = {
    for listener_key, listener in var.load_balancer.listeners : "${listener_key}" => listener
  }

  load_balancer_arn = aws_lb.this.arn
  port              = each.value.port
  protocol          = each.value.protocol
  ssl_policy        = each.value.ssl_policy
  certificate_arn   = each.value.certificate_arn

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = ""
      status_code  = "404"
    }
  }

  depends_on = [
    # aws_lb_target_group_attachment.this
  ]
}

resource "aws_lb_listener_rule" "this" {
  for_each = {
    for rule in local.listener_rules : "${rule.listener_key}.${rule.rule_key}" => rule
  }

  listener_arn = each.value.listener_arn
  priority     = each.value.rule_priority

  action {
    type             = "forward"
    target_group_arn = data.aws_lb_target_group.this_rule_target_group["${each.value.listener_key}.${each.value.rule_key}"].arn
  }

  condition {
    host_header {
      values = each.value.rule_host_header
    }
  }

  condition {
    path_pattern {
      values = each.value.rule_path_pattern
    }
  }

  depends_on = [
    aws_lb_listener.this
  ]
}