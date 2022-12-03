locals {
  eks-security-group-name = "sgp-${var.eks.name}-eks"
  pod-security-group-name = "sgp-${var.eks.name}-pod"
}


################################################################################
# Subnets
################################################################################
data "aws_subnet" "this" {
  for_each = toset(var.eks.vpc_config.subnet_ids)

  id = each.value
}

data "aws_subnet" "worker_node" {
  for_each = toset(flatten([for node_group in var.eks.node_groups[*] : node_group.subnet_ids[*]]))

  id = each.value
}

data "aws_subnet" "pod" {
  for_each = toset(var.eks.pod_subnet_ids)

  id = each.value
}


################################################################################
# EKS VPC Security Group
################################################################################
resource "aws_security_group_rule" "this_vpc_load_balancer_ingress" {
  description              = "Allow eks subnet resources to communicate with worker nodes"
  from_port                = 0
  to_port                  = 0
  protocol                 = "all"
  security_group_id        = data.aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
  cidr_blocks              = [for subnet in data.aws_subnet.this : subnet.cidr_block]
  type                     = "ingress"

  depends_on = [
    aws_eks_cluster.this
  ]
}

resource "aws_security_group_rule" "this_vpc_pod_ingress" {
  description              = "Allow pods to communicate with worker nodes"
  from_port                = 0
  to_port                  = 0
  protocol                 = "all"
  security_group_id        = data.aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
  cidr_blocks              = [for pod in data.aws_subnet.pod : pod.cidr_block]
  type                     = "ingress"

  depends_on = [
    aws_eks_cluster.this
  ]
}


################################################################################
# EKS Security Group
################################################################################
resource "aws_security_group" "this" {
  count = var.is_create_eks_security_group ? 1 : 0

  name        = local.eks-security-group-name
  vpc_id      = var.eks.vpc_config.id
  description = "${var.eks.name} eks security group"

  tags = merge(
    var.common_tags,
    {
      ClusterName = var.eks.name
      Name        = local.eks-security-group-name
      "kubernetes.io/cluster/${var.eks.name}"  = "owned"
      "karpenter.sh/discovery/${var.eks.name}" = "owned"
    },
  )
}

resource "aws_security_group_rule" "this_worker_node_ingress" {
  count = var.is_create_eks_security_group ? 1 : 0

  description              = "Allow worker nodes to communicate with the eks cluster api server"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.this[0].id
  cidr_blocks              = [for subnet in data.aws_subnet.worker_node : subnet.cidr_block]
  type                     = "ingress"

  depends_on = [
    aws_security_group.this
  ]
}

resource "aws_security_group_rule" "this_awscli_ingress" {
  count = var.is_create_eks_security_group && var.awscli_cidr != "" ? 1 : 0

  description       = "Allow awscli vm to communicate with the eks cluster api server"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  security_group_id = aws_security_group.this[0].id
  cidr_blocks       = [var.awscli_cidr]
  type              = "ingress"

  depends_on = [
    aws_security_group.this
  ]
}

resource "aws_security_group_rule" "this_spinnaker_ingress" {
  description              = "Allow spinnaker to communicate with the eks cluster api server"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.this[0].id
  cidr_blocks              = [var.spinnaker_cidr]
  type                     = "ingress"

  depends_on = [
    aws_eks_cluster.this
  ]
}

resource "aws_security_group_rule" "this_istiod_ingress" {
  count = var.eks.type == "svc" ? 1 : 0

  description              = "Allow api & svc cluster istiod to communicate with the eks cluster api server"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.this[0].id
  cidr_blocks              = var.istiod_egress_cidrs
  type                     = "ingress"

  depends_on = [
    aws_eks_cluster.this
  ]
}

resource "aws_security_group_rule" "this_all_traffic_egress" {
  count = var.is_create_eks_security_group ? 1 : 0

  description       = "Allow eks cluster api server to communicate to all destinations"
  security_group_id = aws_security_group.this[0].id
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]

  depends_on = [
    aws_eks_cluster.this
  ]
}

data "aws_security_group" "this" {
  name = local.eks-security-group-name

  depends_on = [
    aws_security_group.this
  ]
}


################################################################################
# POD Security Group
################################################################################
resource "aws_security_group" "pod" {
  count = var.is_create_pod_security_group ? 1 : 0

  name        = local.pod-security-group-name
  vpc_id      = var.eks.vpc_config.id
  description = "${var.eks.name} pod security group"

  tags = merge(
    var.common_tags,
    {
      ClusterName = var.eks.name
      Name        = local.pod-security-group-name
    },
  )
}

resource "aws_security_group_rule" "pod_pod_ingress" {
  count = var.is_create_pod_security_group ? 1 : 0

  description       = "Allow pods to communicate with pods"
  security_group_id = aws_security_group.pod[0].id
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = [for pod in data.aws_subnet.pod : pod.cidr_block]

  depends_on = [
    aws_security_group.pod
  ]
}

resource "aws_security_group_rule" "pod_api_server_ingress" {
  count = var.is_create_pod_security_group ? 1 : 0

  description       = "Allow api server to communicate with pods"
  security_group_id = aws_security_group.pod[0].id
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = [for subnet in data.aws_subnet.this : subnet.cidr_block]

  depends_on = [
    aws_security_group.pod
  ]
}

resource "aws_security_group_rule" "pod_all_traffic_egress" {
  count = var.is_create_pod_security_group ? 1 : 0

  description       = "Allow pods to communicate to all destinations"
  security_group_id = aws_security_group.pod[0].id
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]

  depends_on = [
    aws_security_group.pod
  ]
}