resource "kubernetes_manifest" "test-configmap" {
  manifest = {
    "apiVersion" = "v1"
    "kind"       = "ConfigMap"
    "metadata" = {
      "name"      = "test-config"
      "namespace" = "default"
    }
    "data" = {
      "foo" = "bar"
    }
  }
}

/*
aws eks --region ap-east-1 update-kubeconfig --name dev11-aws-api-a
aws eks --region ap-east-1 update-kubeconfig --name dev11-aws-svc-a
aws eks --region ap-east-1 update-kubeconfig --name dev11-aws-obs-a

kubectl set env daemonset aws-node -n kube-system AWS_VPC_K8S_CNI_CUSTOM_NETWORK_CFG=true --context=arn:aws:eks:ap-east-1:112106310596:cluster/dev11-aws-api-a
kubectl set env daemonset aws-node -n kube-system ENI_CONFIG_LABEL_DEF=topology.kubernetes.io/zone --context=arn:aws:eks:ap-east-1:112106310596:cluster/dev11-aws-api-a
kubectl set env daemonset aws-node -n kube-system AWS_VPC_K8S_CNI_CUSTOM_NETWORK_CFG=true --context=arn:aws:eks:ap-east-1:112106310596:cluster/dev11-aws-svc-a
kubectl set env daemonset aws-node -n kube-system ENI_CONFIG_LABEL_DEF=topology.kubernetes.io/zone --context=arn:aws:eks:ap-east-1:112106310596:cluster/dev11-aws-svc-a
kubectl set env daemonset aws-node -n kube-system AWS_VPC_K8S_CNI_CUSTOM_NETWORK_CFG=true --context=arn:aws:eks:ap-east-1:112106310596:cluster/dev11-aws-obs-a
kubectl set env daemonset aws-node -n kube-system ENI_CONFIG_LABEL_DEF=topology.kubernetes.io/zone --context=arn:aws:eks:ap-east-1:112106310596:cluster/dev11-aws-obs-a

kubectl set env daemonset aws-node -n kube-system ENABLE_PREFIX_DELEGATION=true --context=arn:aws:eks:ap-east-1:112106310596:cluster/dev11-aws-api-a
kubectl set env daemonset aws-node -n kube-system ENABLE_PREFIX_DELEGATION=true --context=arn:aws:eks:ap-east-1:112106310596:cluster/dev11-aws-svc-a
kubectl set env daemonset aws-node -n kube-system ENABLE_PREFIX_DELEGATION=true --context=arn:aws:eks:ap-east-1:112106310596:cluster/dev11-aws-obs-a


cat >dev11.api.eniconfig.yaml <<EOF
apiVersion: crd.k8s.amazonaws.com/v1alpha1
kind: ENIConfig
metadata: 
  name: ap-east-1a
spec: 
  securityGroups: 
    - "sg-09f10049bfee395f0"
  subnet: "subnet-0e8a4b5a58db4f2a1"
---
apiVersion: crd.k8s.amazonaws.com/v1alpha1
kind: ENIConfig
metadata: 
  name: ap-east-1b
spec: 
  securityGroups: 
    - "sg-09f10049bfee395f0"
  subnet: "subnet-09a3f6a433ef60944"
---
apiVersion: crd.k8s.amazonaws.com/v1alpha1
kind: ENIConfig
metadata: 
  name: ap-east-1c
spec: 
  securityGroups: 
    - "sg-09f10049bfee395f0"
  subnet: "subnet-0302c00cc3b0b1896"
---
EOF


cat >dev11.svc.eniconfig.yaml <<EOF
apiVersion: crd.k8s.amazonaws.com/v1alpha1
kind: ENIConfig
metadata: 
  name: ap-east-1a
spec: 
  securityGroups:
    - "sg-045e53a9317394702"
  subnet: "subnet-0e07de53af878ee6c"
---
apiVersion: crd.k8s.amazonaws.com/v1alpha1
kind: ENIConfig
metadata: 
  name: ap-east-1b
spec: 
  securityGroups:
    - "sg-045e53a9317394702"
  subnet: "subnet-0e0c8c362f7fbc134"
---
apiVersion: crd.k8s.amazonaws.com/v1alpha1
kind: ENIConfig
metadata: 
  name: ap-east-1c
spec: 
  securityGroups:
    - "sg-045e53a9317394702"
  subnet: "subnet-05e1efcc73da75ba8"
---
EOF


cat >dev11.obs.eniconfig.yaml <<EOF
apiVersion: crd.k8s.amazonaws.com/v1alpha1
kind: ENIConfig
metadata: 
  name: ap-east-1a
spec: 
  securityGroups: 
    - "sg-03e85ae72148c4564"
  subnet: "subnet-0b97381dda3ea5721"
---
apiVersion: crd.k8s.amazonaws.com/v1alpha1
kind: ENIConfig
metadata: 
  name: ap-east-1b
spec: 
  securityGroups: 
    - "sg-03e85ae72148c4564"
  subnet: "subnet-0866ce9d71521b53a"
---
apiVersion: crd.k8s.amazonaws.com/v1alpha1
kind: ENIConfig
metadata: 
  name: ap-east-1c
spec: 
  securityGroups: 
    - "sg-03e85ae72148c4564"
  subnet: "subnet-000e13aca3f2164a5"
---
EOF


kubectl apply -f dev11.api.eniconfig.yaml --context=arn:aws:eks:ap-east-1:112106310596:cluster/dev11-aws-api-a
kubectl apply -f dev11.svc.eniconfig.yaml --context=arn:aws:eks:ap-east-1:112106310596:cluster/dev11-aws-svc-a
kubectl apply -f dev11.obs.eniconfig.yaml --context=arn:aws:eks:ap-east-1:112106310596:cluster/dev11-aws-obs-a

cat >aws-auth.configmap <<EOF
apiVersion: v1
data:
  mapRoles: |
    - rolearn: arn:aws:iam::112106310596:role/iam-role-infra-eks-nodes
      username: system:node:{{EC2PrivateDNSName}}
      groups:
        - system:bootstrappers
        - system:nodes
    - rolearn: arn:aws:iam::112106310596:role/iam-role-platform-ops-users
      username: iam-role-platform-ops-users
      groups:
        - system:masters
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
EOF

kubectl apply -f aws-auth.configmap --context=arn:aws:eks:ap-east-1:112106310596:cluster/dev11-aws-api-a
kubectl apply -f aws-auth.configmap --context=arn:aws:eks:ap-east-1:112106310596:cluster/dev11-aws-svc-a
kubectl apply -f aws-auth.configmap --context=arn:aws:eks:ap-east-1:112106310596:cluster/dev11-aws-obs-a

kubectl create ns spinnaker --context=arn:aws:eks:ap-east-1:112106310596:cluster/dev11-aws-api-a
kubectl create ns spinnaker --context=arn:aws:eks:ap-east-1:112106310596:cluster/dev11-aws-svc-a
kubectl create ns spinnaker --context=arn:aws:eks:ap-east-1:112106310596:cluster/dev11-aws-obs-a

kubectl create sa spinnaker-platform-admin -n spinnaker --context=arn:aws:eks:ap-east-1:112106310596:cluster/dev11-aws-api-a
kubectl create sa spinnaker-platform-admin -n spinnaker --context=arn:aws:eks:ap-east-1:112106310596:cluster/dev11-aws-svc-a
kubectl create sa spinnaker-platform-admin -n spinnaker --context=arn:aws:eks:ap-east-1:112106310596:cluster/dev11-aws-obs-a

kubectl create clusterrolebinding spinnaker-platform-admin-clusterrolebinding --clusterrole=cluster-admin --serviceaccount=spinnaker:spinnaker-platform-admin --context=arn:aws:eks:ap-east-1:112106310596:cluster/dev11-aws-api-a
kubectl create clusterrolebinding spinnaker-platform-admin-clusterrolebinding --clusterrole=cluster-admin --serviceaccount=spinnaker:spinnaker-platform-admin --context=arn:aws:eks:ap-east-1:112106310596:cluster/dev11-aws-svc-a
kubectl create clusterrolebinding spinnaker-platform-admin-clusterrolebinding --clusterrole=cluster-admin --serviceaccount=spinnaker:spinnaker-platform-admin --context=arn:aws:eks:ap-east-1:112106310596:cluster/dev11-aws-obs-a

kubectl create sa spinnaker-application-admin -n spinnaker --context=arn:aws:eks:ap-east-1:112106310596:cluster/dev11-aws-api-a
kubectl create sa spinnaker-application-admin -n spinnaker --context=arn:aws:eks:ap-east-1:112106310596:cluster/dev11-aws-svc-a
kubectl create sa spinnaker-application-admin -n spinnaker --context=arn:aws:eks:ap-east-1:112106310596:cluster/dev11-aws-obs-a
























eksctl utils associate-iam-oidc-provider --region=ap-east-1 --cluster=dev9-aws-api-a --approve
eksctl utils associate-iam-oidc-provider --region=ap-east-1 --cluster=dev9-aws-svc-a --approve
eksctl utils associate-iam-oidc-provider --region=ap-east-1 --cluster=dev9-aws-obs-a --approve

cat >aws-cloudwatch-trust-policy.json <<EOF
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
                "ForAllValues:StringEquals": {
                    "oidc.eks.ap-east-1.amazonaws.com/id/F0088FC1664072268837219631E88713:sub": [
                        "system:serviceaccount:logging:fluent-bit-aggregator",
                        "system:serviceaccount:observability:cwagent"
                    ],
                    "oidc.eks.ap-east-1.amazonaws.com/id/F0088FC1664072268837219631E88713:aud": [
                        "sts.amazonaws.com"
                    ]
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
                "ForAllValues:StringEquals": {
                    "oidc.eks.ap-east-1.amazonaws.com/id/0A80ADFBA57132E296AED78B321FE657:sub": [
                        "system:serviceaccount:logging:fluent-bit-aggregator",
                        "system:serviceaccount:observability:cwagent"
                    ],
                    "oidc.eks.ap-east-1.amazonaws.com/id/0A80ADFBA57132E296AED78B321FE657:aud": [
                        "sts.amazonaws.com"
                    ]
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
                "ForAllValues:StringEquals": {
                    "oidc.eks.ap-east-1.amazonaws.com/id/686D2D45F2000DE3F5E88D1464818993:sub": [
                        "system:serviceaccount:logging:fluent-bit-aggregator",
                        "system:serviceaccount:observability:cwagent"
                    ],
                    "oidc.eks.ap-east-1.amazonaws.com/id/686D2D45F2000DE3F5E88D1464818993:aud": [
                        "sts.amazonaws.com"
                    ]
                }
            }
        }
    ]
}
EOF

aws iam create-role --role-name iam-role-platform-ops-cloudwatch --assume-role-policy-document file://"aws-cloudwatch-trust-policy.json"
aws iam attach-role-policy --policy-arn arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy --role-name iam-role-platform-ops-cloudwatch

cat >load-balancer-role-trust-policy.json <<EOF
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
                    "oidc.eks.ap-east-1.amazonaws.com/id/F0088FC1664072268837219631E88713:sub": "system:serviceaccount:kube-system:aws-load-balancer-controller"
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
                    "oidc.eks.ap-east-1.amazonaws.com/id/0A80ADFBA57132E296AED78B321FE657:sub": "system:serviceaccount:kube-system:aws-load-balancer-controller"
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
                    "oidc.eks.ap-east-1.amazonaws.com/id/686D2D45F2000DE3F5E88D1464818993:sub": "system:serviceaccount:kube-system:aws-load-balancer-controller"
                }
            }
        }
    ]
}
EOF

cat >AWSLoadBalancerControllerIAMPolicy.json <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "iam:CreateServiceLinkedRole"
            ],
            "Resource": "*",
            "Condition": {
                "StringEquals": {
                    "iam:AWSServiceName": "elasticloadbalancing.amazonaws.com"
                }
            }
        },
        {
            "Effect": "Allow",
            "Action": [
                "ec2:DescribeAccountAttributes",
                "ec2:DescribeAddresses",
                "ec2:DescribeAvailabilityZones",
                "ec2:DescribeInternetGateways",
                "ec2:DescribeVpcs",
                "ec2:DescribeVpcPeeringConnections",
                "ec2:DescribeSubnets",
                "ec2:DescribeSecurityGroups",
                "ec2:DescribeInstances",
                "ec2:DescribeNetworkInterfaces",
                "ec2:DescribeTags",
                "ec2:GetCoipPoolUsage",
                "ec2:DescribeCoipPools",
                "elasticloadbalancing:DescribeLoadBalancers",
                "elasticloadbalancing:DescribeLoadBalancerAttributes",
                "elasticloadbalancing:DescribeListeners",
                "elasticloadbalancing:DescribeListenerCertificates",
                "elasticloadbalancing:DescribeSSLPolicies",
                "elasticloadbalancing:DescribeRules",
                "elasticloadbalancing:DescribeTargetGroups",
                "elasticloadbalancing:DescribeTargetGroupAttributes",
                "elasticloadbalancing:DescribeTargetHealth",
                "elasticloadbalancing:DescribeTags"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "cognito-idp:DescribeUserPoolClient",
                "acm:ListCertificates",
                "acm:DescribeCertificate",
                "iam:ListServerCertificates",
                "iam:GetServerCertificate",
                "waf-regional:GetWebACL",
                "waf-regional:GetWebACLForResource",
                "waf-regional:AssociateWebACL",
                "waf-regional:DisassociateWebACL",
                "wafv2:GetWebACL",
                "wafv2:GetWebACLForResource",
                "wafv2:AssociateWebACL",
                "wafv2:DisassociateWebACL",
                "shield:GetSubscriptionState",
                "shield:DescribeProtection",
                "shield:CreateProtection",
                "shield:DeleteProtection"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "ec2:AuthorizeSecurityGroupIngress",
                "ec2:RevokeSecurityGroupIngress"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "ec2:CreateSecurityGroup"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "ec2:CreateTags"
            ],
            "Resource": "arn:aws:ec2:*:*:security-group/*",
            "Condition": {
                "StringEquals": {
                    "ec2:CreateAction": "CreateSecurityGroup"
                },
                "Null": {
                    "aws:RequestTag/elbv2.k8s.aws/cluster": "false"
                }
            }
        },
        {
            "Effect": "Allow",
            "Action": [
                "ec2:CreateTags",
                "ec2:DeleteTags"
            ],
            "Resource": "arn:aws:ec2:*:*:security-group/*",
            "Condition": {
                "Null": {
                    "aws:RequestTag/elbv2.k8s.aws/cluster": "true",
                    "aws:ResourceTag/elbv2.k8s.aws/cluster": "false"
                }
            }
        },
        {
            "Effect": "Allow",
            "Action": [
                "ec2:AuthorizeSecurityGroupIngress",
                "ec2:RevokeSecurityGroupIngress",
                "ec2:DeleteSecurityGroup"
            ],
            "Resource": "*",
            "Condition": {
                "Null": {
                    "aws:ResourceTag/elbv2.k8s.aws/cluster": "false"
                }
            }
        },
        {
            "Effect": "Allow",
            "Action": [
                "elasticloadbalancing:CreateLoadBalancer",
                "elasticloadbalancing:CreateTargetGroup"
            ],
            "Resource": "*",
            "Condition": {
                "Null": {
                    "aws:RequestTag/elbv2.k8s.aws/cluster": "false"
                }
            }
        },
        {
            "Effect": "Allow",
            "Action": [
                "elasticloadbalancing:CreateListener",
                "elasticloadbalancing:DeleteListener",
                "elasticloadbalancing:CreateRule",
                "elasticloadbalancing:DeleteRule"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "elasticloadbalancing:AddTags",
                "elasticloadbalancing:RemoveTags"
            ],
            "Resource": [
                "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*",
                "arn:aws:elasticloadbalancing:*:*:loadbalancer/net/*/*",
                "arn:aws:elasticloadbalancing:*:*:loadbalancer/app/*/*"
            ],
            "Condition": {
                "Null": {
                    "aws:RequestTag/elbv2.k8s.aws/cluster": "true",
                    "aws:ResourceTag/elbv2.k8s.aws/cluster": "false"
                }
            }
        },
        {
            "Effect": "Allow",
            "Action": [
                "elasticloadbalancing:AddTags",
                "elasticloadbalancing:RemoveTags"
            ],
            "Resource": [
                "arn:aws:elasticloadbalancing:*:*:listener/net/*/*/*",
                "arn:aws:elasticloadbalancing:*:*:listener/app/*/*/*",
                "arn:aws:elasticloadbalancing:*:*:listener-rule/net/*/*/*",
                "arn:aws:elasticloadbalancing:*:*:listener-rule/app/*/*/*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "elasticloadbalancing:ModifyLoadBalancerAttributes",
                "elasticloadbalancing:SetIpAddressType",
                "elasticloadbalancing:SetSecurityGroups",
                "elasticloadbalancing:SetSubnets",
                "elasticloadbalancing:DeleteLoadBalancer",
                "elasticloadbalancing:ModifyTargetGroup",
                "elasticloadbalancing:ModifyTargetGroupAttributes",
                "elasticloadbalancing:DeleteTargetGroup"
            ],
            "Resource": "*",
            "Condition": {
                "Null": {
                    "aws:ResourceTag/elbv2.k8s.aws/cluster": "false"
                }
            }
        },
        {
            "Effect": "Allow",
            "Action": [
                "elasticloadbalancing:RegisterTargets",
                "elasticloadbalancing:DeregisterTargets"
            ],
            "Resource": "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "elasticloadbalancing:SetWebAcl",
                "elasticloadbalancing:ModifyListener",
                "elasticloadbalancing:AddListenerCertificates",
                "elasticloadbalancing:RemoveListenerCertificates",
                "elasticloadbalancing:ModifyRule"
            ],
            "Resource": "*"
        }
    ]
}
EOF

aws iam create-policy --policy-name AWSLoadBalancerControllerIAMPolicy --policy-document file://AWSLoadBalancerControllerIAMPolicy.json
aws iam create-role --role-name iam-role-platform-ops-aws-load-balancer-controller --assume-role-policy-document file://"load-balancer-role-trust-policy.json"
aws iam attach-role-policy --policy-arn arn:aws:iam::112106310596:policy/AWSLoadBalancerControllerIAMPolicy --role-name iam-role-platform-ops-aws-load-balancer-controller
*/