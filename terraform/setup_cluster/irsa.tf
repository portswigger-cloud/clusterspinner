# SPDX-FileCopyrightText: 2026 The clusterspinner contributors
# SPDX-License-Identifier: MIT

resource "aws_iam_role" "ebs_csi_driver" {
  name = "${var.cluster_name}-ebs-csi-driver"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.eks.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub" = "system:serviceaccount:kube-system:ebs-csi-controller-sa"
            "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ebs_csi_driver" {
  role       = aws_iam_role.ebs_csi_driver.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

resource "aws_eks_addon" "ebs_csi_driver" {
  cluster_name             = aws_eks_cluster.this.name
  addon_name               = "aws-ebs-csi-driver"
  service_account_role_arn = aws_iam_role.ebs_csi_driver.arn

  depends_on = [aws_eks_node_group.default]
}

# The role the crossplane iam provider assumes through IRSA. Its name is what
# the system repo derives for fe-dev from role-suffix: crossplane-provider-aws-iam
# plus the suffix, on /crossplane/ with the other roles the provider works with.
# The suffix keeps it apart from the role platform-dev already has in this
# account, whose trust policy names only platform-dev's OIDC provider.
resource "aws_iam_role" "crossplane_provider_aws_iam" {
  name = "crossplane-provider-aws-iam-${var.cluster_name}"
  path = "/crossplane/"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.eks.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub" = "system:serviceaccount:crossplane-system:provider-aws-iam"
            "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })
}

# Read any role, but create and change only roles under /crossplane/, and create
# only with the crossplane permissions boundary attached, so the provider cannot
# mint anything broader than that boundary allows.
resource "aws_iam_role_policy" "crossplane_provider_aws_iam" {
  name = "manage-crossplane-iam"
  role = aws_iam_role.crossplane_provider_aws_iam.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "CreateRolesWithBoundary"
        Effect   = "Allow"
        Action   = ["iam:CreateRole", "iam:PutRolePermissionsBoundary"]
        Resource = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:role/crossplane/*"
        Condition = {
          StringEquals = {
            "iam:PermissionsBoundary" = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:policy/crossplane/permissions-boundary"
          }
        }
      },
      {
        # A read of a role that does not exist yet is authorised against its bare
        # name, since there is no path to resolve, so a /crossplane/-scoped
        # resource never matches it and the provider cannot even observe a Role
        # before creating it. Reads therefore cover every role; writes below do not.
        Sid    = "ReadRoles"
        Effect = "Allow"
        Action = [
          "iam:GetRole",
          "iam:GetRolePolicy",
          "iam:ListRolePolicies",
          "iam:ListAttachedRolePolicies",
          "iam:ListInstanceProfilesForRole",
          "iam:ListRoleTags"
        ]
        Resource = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:role/*"
      },
      {
        Sid    = "ManageCrossplaneRoles"
        Effect = "Allow"
        Action = [
          "iam:DeleteRole",
          "iam:UpdateRole",
          "iam:UpdateAssumeRolePolicy",
          "iam:TagRole",
          "iam:UntagRole",
          "iam:PutRolePolicy",
          "iam:DeleteRolePolicy",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy"
        ]
        Resource = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:role/crossplane/*"
      },
      {
        # This role lives under the path it manages, so without this it could
        # rewrite its own trust or permissions.
        Sid      = "NotThisRole"
        Effect   = "Deny"
        Action   = "iam:*"
        Resource = aws_iam_role.crossplane_provider_aws_iam.arn
      }
    ]
  })
}
