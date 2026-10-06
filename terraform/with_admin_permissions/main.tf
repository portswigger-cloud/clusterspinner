# SPDX-FileCopyrightText: 2026 The clusterspinner contributors
# SPDX-License-Identifier: MIT

provider "aws" {
  region = var.region
}

data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

locals {
  role_name       = "clusterspinner"
  policy_name     = "clusterspinner-policy"
  region          = var.region
  tf_state_bucket = var.tf_state_bucket

  tf_state_keys = [
    "setup-cluster/terraform.tfstate",
    "admin-permissions/terraform.tfstate",
  ]

  managed_policy_arns = [
    "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKSClusterPolicy",
    "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEC2ContainerRegistryPullOnly",
    "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonSSMManagedInstanceCore",
    "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy",
  ]

  cluster_role_arns               = [for name in var.cluster_names : "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:role/${name}-cluster-role"]
  node_role_arns                  = [for name in var.cluster_names : "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:role/${name}-node-role"]
  ebs_csi_role_arns               = [for name in var.cluster_names : "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:role/${name}-ebs-csi-driver"]
  irsa_role_arns                  = [for name in var.cluster_names : "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:role/${name}-*"]
  crossplane_provider_role_arns   = [for name in var.cluster_names : "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:role/with-iam/crossplane-provider-aws-*-${name}"]
  irsa_policy_arns                = [for name in var.cluster_names : "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:policy/${name}-*"]
  karpenter_node_role_arns        = [for name in var.cluster_names : "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:role/${name}-karpenter-node-role"]
  karpenter_controller_role_arns  = [for name in var.cluster_names : "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:role/with-iam/${name}-karpenter"]
  karpenter_policy_arns           = [for name in var.cluster_names : "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:policy/KarpenterController*-${name}"]
  karpenter_queue_arns            = [for name in var.cluster_names : "arn:${data.aws_partition.current.partition}:sqs:${local.region}:${data.aws_caller_identity.current.account_id}:${name}"]
  karpenter_event_rule_arns       = [for name in var.cluster_names : "arn:${data.aws_partition.current.partition}:events:${local.region}:${data.aws_caller_identity.current.account_id}:rule/${name}-karpenter-*"]
  cluster_access_entry_arns       = [for name in var.cluster_names : "arn:${data.aws_partition.current.partition}:eks:${local.region}:${data.aws_caller_identity.current.account_id}:access-entry/${name}/role/*"]
  karpenter_access_entry_arns     = [for name in var.cluster_names : "arn:${data.aws_partition.current.partition}:eks:${local.region}:${data.aws_caller_identity.current.account_id}:access-entry/${name}/role/${data.aws_caller_identity.current.account_id}/${name}-karpenter-node-role/*"]
  karpenter_instance_profile_arns = [for name in var.cluster_names : "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:instance-profile/karpenter/*/${name}/*"]
  eks_nodegroup_slr_arn           = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/eks-nodegroup.amazonaws.com/AWSServiceRoleForAmazonEKSNodegroup"
  cluster_arns                    = [for name in var.cluster_names : "arn:${data.aws_partition.current.partition}:eks:${local.region}:${data.aws_caller_identity.current.account_id}:cluster/${name}"]
  nodegroup_arns                  = [for name in var.cluster_names : "arn:${data.aws_partition.current.partition}:eks:${local.region}:${data.aws_caller_identity.current.account_id}:nodegroup/${name}/*/*"]
  addon_arns                      = [for name in var.cluster_names : "arn:${data.aws_partition.current.partition}:eks:${local.region}:${data.aws_caller_identity.current.account_id}:addon/${name}/*/*"]
  oidc_provider_arns              = ["arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/*"]
  tf_state_bucket_arn             = "arn:${data.aws_partition.current.partition}:s3:::${local.tf_state_bucket}"
  tf_state_object_arns = [
    for key in local.tf_state_keys :
    "${local.tf_state_bucket_arn}/${key}"
  ]
}

resource "aws_iam_role" "this" {
  name = local.role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = var.trusted_principals
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_policy" "clusterspinner" {
  name        = local.policy_name
  description = "Permissions needed to apply the clusterspinner EKS stack."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EksCreateAndList"
        Effect = "Allow"
        Action = [
          "eks:CreateAddon",
          "eks:CreateCluster",
          "eks:CreateNodegroup",
          "eks:DescribeAddonVersions",
          "eks:ListAddons",
          "eks:ListClusters",
          "eks:ListUpdates",
          "eks:DescribeUpdate"
        ]
        Resource = "*"
      },
      {
        Sid    = "EksManageNamedClusterAndNodegroup"
        Effect = "Allow"
        Action = [
          "eks:DeleteAddon",
          "eks:DeleteCluster",
          "eks:DescribeAddon",
          "eks:DescribeCluster",
          "eks:DeleteNodegroup",
          "eks:DescribeNodegroup",
          "eks:ListNodegroups",
          "eks:TagResource",
          "eks:UntagResource",
          "eks:UpdateAddon",
          "eks:UpdateClusterConfig",
          "eks:UpdateClusterVersion",
          "eks:UpdateNodegroupConfig",
          "eks:UpdateNodegroupVersion"
        ]
        Resource = concat(local.cluster_arns, local.nodegroup_arns, local.addon_arns)
      },
      {
        Sid    = "Ec2NetworkLifecycle"
        Effect = "Allow"
        Action = [
          "ec2:AllocateAddress",
          "ec2:AssociateRouteTable",
          "ec2:AttachInternetGateway",
          "ec2:AuthorizeSecurityGroupEgress",
          "ec2:CreateInternetGateway",
          "ec2:CreateNatGateway",
          "ec2:CreateRoute",
          "ec2:CreateRouteTable",
          "ec2:CreateSecurityGroup",
          "ec2:CreateSubnet",
          "ec2:CreateTags",
          "ec2:CreateVpc",
          "ec2:DeleteNatGateway",
          "ec2:DeleteInternetGateway",
          "ec2:DeleteRoute",
          "ec2:DeleteRouteTable",
          "ec2:DeleteSecurityGroup",
          "ec2:DeleteSubnet",
          "ec2:DeleteTags",
          "ec2:DeleteVpc",
          "ec2:DetachInternetGateway",
          "ec2:DisassociateRouteTable",
          "ec2:ModifySubnetAttribute",
          "ec2:ModifyVpcAttribute",
          "ec2:ReleaseAddress",
          "ec2:ReplaceRoute",
          "ec2:ReplaceRouteTableAssociation",
          "ec2:DisassociateAddress",
          "ec2:RevokeSecurityGroupEgress"
        ]
        Resource = "*"
      },
      {
        Sid    = "Ec2ReadOnlyDiscovery"
        Effect = "Allow"
        Action = [
          "ec2:DescribeAddresses",
          "ec2:DescribeAddressesAttribute",
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeInternetGateways",
          "ec2:DescribeNatGateways",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DescribeRouteTables",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSubnets",
          "ec2:DescribeTags",
          "ec2:DescribeVpcAttribute",
          "ec2:DescribeVpcs"
        ]
        Resource = "*"
      },
      {
        Sid    = "IamRolesForEks"
        Effect = "Allow"
        Action = [
          "iam:AttachRolePolicy",
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:DetachRolePolicy",
          "iam:GetRole",
          "iam:ListAttachedRolePolicies",
          "iam:ListInstanceProfilesForRole",
          "iam:DeleteRolePolicy",
          "iam:GetRolePolicy",
          "iam:ListRolePolicies",
          "iam:PutRolePolicy",
          "iam:TagRole",
          "iam:UntagRole",
          "iam:UpdateAssumeRolePolicy"
        ]
        Resource = concat(local.cluster_role_arns, local.node_role_arns, local.ebs_csi_role_arns, local.irsa_role_arns, local.crossplane_provider_role_arns, [local.eks_nodegroup_slr_arn])
      },
      {
        Sid    = "IamManagedPolicyReadAndPassRole"
        Effect = "Allow"
        Action = [
          "iam:GetPolicy",
          "iam:GetPolicyVersion",
          "iam:ListPolicyVersions",
          "iam:PassRole"
        ]
        Resource = concat(local.managed_policy_arns, local.cluster_role_arns, local.node_role_arns, local.ebs_csi_role_arns, local.irsa_role_arns)
      },
      {
        Sid    = "IamCustomerManagedPolicyLifecycle"
        Effect = "Allow"
        Action = [
          "iam:CreatePolicy",
          "iam:DeletePolicy",
          "iam:CreatePolicyVersion",
          "iam:DeletePolicyVersion",
          "iam:GetPolicy",
          "iam:GetPolicyVersion",
          "iam:ListPolicyVersions",
          "iam:TagPolicy",
          "iam:UntagPolicy"
        ]
        Resource = local.irsa_policy_arns
      },
      {
        Sid    = "IamCreateEksServiceLinkedRole"
        Effect = "Allow"
        Action = [
          "iam:CreateServiceLinkedRole"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "iam:AWSServiceName" = [
              "eks.amazonaws.com",
              "eks-nodegroup.amazonaws.com"
            ]
          }
        }
      },
      {
        Sid    = "IamOidcProviderCreate"
        Effect = "Allow"
        Action = [
          "iam:CreateOpenIDConnectProvider"
        ]
        Resource = "*"
      },
      {
        Sid    = "IamOidcProviderManage"
        Effect = "Allow"
        Action = [
          "iam:DeleteOpenIDConnectProvider",
          "iam:GetOpenIDConnectProvider",
          "iam:TagOpenIDConnectProvider",
          "iam:UntagOpenIDConnectProvider"
        ]
        Resource = local.oidc_provider_arns
      },
      {
        Sid    = "S3ListTerraformStateBucket"
        Effect = "Allow"
        Action = [
          "s3:GetBucketLocation",
          "s3:ListBucket"
        ]
        Resource = local.tf_state_bucket_arn
        Condition = {
          StringLike = {
            "s3:prefix" = local.tf_state_keys
          }
        }
      },
      {
        Sid    = "S3ManageTerraformStateObjects"
        Effect = "Allow"
        Action = [
          "s3:DeleteObject",
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = local.tf_state_object_arns
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach" {
  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.clusterspinner.arn
}

resource "aws_iam_policy" "clusterspinner_karpenter" {
  name        = "clusterspinner-karpenter-policy"
  description = "Permissions needed to apply the Karpenter resources in the clusterspinner EKS stack."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "IamRolesForKarpenter"
        Effect = "Allow"
        Action = [
          "iam:AttachRolePolicy",
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:DetachRolePolicy",
          "iam:GetRole",
          "iam:ListAttachedRolePolicies",
          "iam:ListInstanceProfilesForRole",
          "iam:DeleteRolePolicy",
          "iam:GetRolePolicy",
          "iam:ListRolePolicies",
          "iam:PutRolePolicy",
          "iam:TagRole",
          "iam:UntagRole",
          "iam:UpdateAssumeRolePolicy"
        ]
        Resource = concat(local.karpenter_node_role_arns, local.karpenter_controller_role_arns)
      },
      {
        Sid    = "IamManagedPoliciesAndPassRoleForKarpenter"
        Effect = "Allow"
        Action = [
          "iam:GetPolicy",
          "iam:GetPolicyVersion",
          "iam:ListPolicyVersions",
          "iam:PassRole"
        ]
        Resource = concat(
          [
            "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEC2ContainerRegistryPullOnly",
            "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonSSMManagedInstanceCore",
          ],
          local.karpenter_node_role_arns,
          local.karpenter_controller_role_arns
        )
      },
      {
        Sid    = "IamKarpenterControllerPolicies"
        Effect = "Allow"
        Action = [
          "iam:CreatePolicy",
          "iam:DeletePolicy",
          "iam:CreatePolicyVersion",
          "iam:DeletePolicyVersion",
          "iam:GetPolicy",
          "iam:GetPolicyVersion",
          "iam:ListPolicyVersions",
          "iam:TagPolicy",
          "iam:UntagPolicy"
        ]
        Resource = local.karpenter_policy_arns
      },
      {
        Sid    = "IamKarpenterInstanceProfileRoleDetach"
        Effect = "Allow"
        Action = [
          "iam:RemoveRoleFromInstanceProfile"
        ]
        Resource = local.karpenter_instance_profile_arns
      },
      {
        Sid    = "EksAccessEntryForKarpenterNodes"
        Effect = "Allow"
        Action = [
          "eks:CreateAccessEntry",
          "eks:DeleteAccessEntry",
          "eks:DescribeAccessEntry"
        ]
        Resource = concat(local.cluster_arns, local.karpenter_access_entry_arns)
      },
      {
        Sid    = "EksAccessEntryForClusterAccess"
        Effect = "Allow"
        Action = [
          "eks:AssociateAccessPolicy",
          "eks:CreateAccessEntry",
          "eks:DeleteAccessEntry",
          "eks:DescribeAccessEntry",
          "eks:DisassociateAccessPolicy",
          "eks:ListAssociatedAccessPolicies",
          "eks:UpdateAccessEntry"
        ]
        Resource = concat(local.cluster_arns, local.cluster_access_entry_arns)
      },
      {
        Sid    = "SqsKarpenterInterruptionQueue"
        Effect = "Allow"
        Action = [
          "sqs:CreateQueue",
          "sqs:DeleteQueue",
          "sqs:GetQueueAttributes",
          "sqs:GetQueueUrl",
          "sqs:ListQueueTags",
          "sqs:SetQueueAttributes",
          "sqs:TagQueue",
          "sqs:UntagQueue"
        ]
        Resource = local.karpenter_queue_arns
      },
      {
        Sid    = "EventBridgeKarpenterRules"
        Effect = "Allow"
        Action = [
          "events:DeleteRule",
          "events:DescribeRule",
          "events:ListTagsForResource",
          "events:ListTargetsByRule",
          "events:PutRule",
          "events:PutTargets",
          "events:RemoveTargets",
          "events:TagResource",
          "events:UntagResource"
        ]
        Resource = local.karpenter_event_rule_arns
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_karpenter" {
  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.clusterspinner_karpenter.arn
}
