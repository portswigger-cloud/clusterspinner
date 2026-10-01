# SPDX-FileCopyrightText: 2026 The clusterspinner contributors
# SPDX-License-Identifier: MIT

# TODO: this should in the long run probably go into a crossplane composition

locals {
  idcat_kms_key_arn = "arn:aws:kms:eu-west-2:658786808637:key/2cefb541-e00e-4332-b325-bcc7928a9652"
}

resource "aws_iam_role" "idcat" {
  name = "${var.cluster_name}-idcat"

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
            "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub" = "system:serviceaccount:idcat:idcat"
            "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      },
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::658786808637:role/pipeline-roles/teleport-administrator-role"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_policy" "idcat" {
  name = "${var.cluster_name}-idcat"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "SignAndReadPublicKey"
        Effect = "Allow"
        Action = [
          "kms:DescribeKey",
          "kms:GetPublicKey",
          "kms:Sign"
        ]
        Resource = local.idcat_kms_key_arn
      },
      {
        Sid      = "ListKmsAliases"
        Effect   = "Allow"
        Action   = ["kms:ListAliases"]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "idcat" {
  role       = aws_iam_role.idcat.name
  policy_arn = aws_iam_policy.idcat.arn
}
