resource "aws_eks_addon" "aws_ebs_csi_driver" {
 addon_name   = "aws-ebs-csi-driver"
 cluster_name = var.cluster_name

 tags = merge(
   var.common_tags,
   {
     ClusterName = var.cluster_name
     Name        = "aws-ebs-csi-driver"
   },
 )
}

# resource "kubernetes_manifest" "test-configmap" {
#   manifest = {
#     "apiVersion" = "v1"
#     "kind"       = "ConfigMap"
#     "metadata" = {
#       "name"      = "test-config"
#       "namespace" = "default"
#     }
#     "data" = {
#       "foo" = "bar"
#     }
#   }
# }

/*
kubectl annotate serviceaccount ebs-csi-controller-sa -n kube-system eks.amazonaws.com/role-arn=arn:aws:iam::112106310596:role/iam-role-dev11-aws-api-a-ebs-csi-controller --context=arn:aws:eks:ap-east-1:112106310596:cluster/dev11-aws-api-a
kubectl annotate serviceaccount ebs-csi-controller-sa -n kube-system eks.amazonaws.com/role-arn=arn:aws:iam::112106310596:role/iam-role-dev11-aws-svc-a-ebs-csi-controller --context=arn:aws:eks:ap-east-1:112106310596:cluster/dev11-aws-svc-a
kubectl annotate serviceaccount ebs-csi-controller-sa -n kube-system eks.amazonaws.com/role-arn=arn:aws:iam::112106310596:role/iam-role-dev11-aws-obs-a-ebs-csi-controller --context=arn:aws:eks:ap-east-1:112106310596:cluster/dev11-aws-obs-a














aws eks describe-cluster --name poc-aws-api-a --query "cluster.identity.oidc.issuer" --output text
aws eks describe-cluster --name poc-aws-svc-a --query "cluster.identity.oidc.issuer" --output text
aws eks describe-cluster --name poc-aws-obs-a --query "cluster.identity.oidc.issuer" --output text

cat >aws-ebs-csi-driver-trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::112106310596:oidc-provider/oidc.eks.ap-east-1.amazonaws.com/id/F0088FC1664072268837219631E88713"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "oidc.eks.ap-east-1.amazonaws.com/id/F0088FC1664072268837219631E88713:aud": "sts.amazonaws.com",
          "oidc.eks.ap-east-1.amazonaws.com/id/F0088FC1664072268837219631E88713:sub": "system:serviceaccount:kube-system:ebs-csi-controller-sa"
        }
      }
    },
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::112106310596:oidc-provider/oidc.eks.ap-east-1.amazonaws.com/id/0A80ADFBA57132E296AED78B321FE657"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "oidc.eks.ap-east-1.amazonaws.com/id/0A80ADFBA57132E296AED78B321FE657:aud": "sts.amazonaws.com",
          "oidc.eks.ap-east-1.amazonaws.com/id/0A80ADFBA57132E296AED78B321FE657:sub": "system:serviceaccount:kube-system:ebs-csi-controller-sa"
        }
      }
    },
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::112106310596:oidc-provider/oidc.eks.ap-east-1.amazonaws.com/id/686D2D45F2000DE3F5E88D1464818993"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "oidc.eks.ap-east-1.amazonaws.com/id/686D2D45F2000DE3F5E88D1464818993:aud": "sts.amazonaws.com",
          "oidc.eks.ap-east-1.amazonaws.com/id/686D2D45F2000DE3F5E88D1464818993:sub": "system:serviceaccount:kube-system:ebs-csi-controller-sa"
        }
      }
    }
  ]
}
EOF

aws iam create-role --role-name iam-role-platform-ops-ebs-csi --assume-role-policy-document file://"aws-ebs-csi-driver-trust-policy.json"
aws iam attach-role-policy --policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy --role-name iam-role-platform-ops-ebs-csi

kubectl annotate serviceaccount ebs-csi-controller-sa -n kube-system eks.amazonaws.com/role-arn=arn:aws:iam::112106310596:role/iam-role-platform-ops-ebs-csi --context=arn:aws:eks:ap-east-1:112106310596:cluster/poc-aws-api-a
kubectl annotate serviceaccount ebs-csi-controller-sa -n kube-system eks.amazonaws.com/role-arn=arn:aws:iam::112106310596:role/iam-role-platform-ops-ebs-csi --context=arn:aws:eks:ap-east-1:112106310596:cluster/poc-aws-svc-a
kubectl annotate serviceaccount ebs-csi-controller-sa -n kube-system eks.amazonaws.com/role-arn=arn:aws:iam::112106310596:role/iam-role-platform-ops-ebs-csi --context=arn:aws:eks:ap-east-1:112106310596:cluster/poc-aws-obs-a


kubectl annotate serviceaccount fluent-bit-aggregator -n logging eks.amazonaws.com/role-arn=arn:aws:iam::112106310596:role/iam-role-platform-ops-cloudwatch --context=arn:aws:eks:ap-east-1:112106310596:cluster/poc-aws-api-a
kubectl annotate serviceaccount fluent-bit-aggregator -n logging eks.amazonaws.com/role-arn=arn:aws:iam::112106310596:role/iam-role-platform-ops-cloudwatch --context=arn:aws:eks:ap-east-1:112106310596:cluster/poc-aws-svc-a
kubectl annotate serviceaccount fluent-bit-aggregator -n logging eks.amazonaws.com/role-arn=arn:aws:iam::112106310596:role/iam-role-platform-ops-cloudwatch --context=arn:aws:eks:ap-east-1:112106310596:cluster/poc-aws-obs-a
*/