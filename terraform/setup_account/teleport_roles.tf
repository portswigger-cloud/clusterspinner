# SPDX-FileCopyrightText: 2026 The clusterspinner contributors
# SPDX-License-Identifier: MIT

# Roles that teleport assumes. Only the role the teleport agent runs as is trusted;
# who may use which role is decided by Teleport, not by AWS.

locals {
  partition     = data.aws_partition.current.partition
  with_iam_path = "/with-iam/"

  teleport_roles = {
    admin = {
      name        = "admin"
      path        = local.with_iam_path
      description = "An admin role for teleport to assume in this account"
      policy_arns = ["arn:${local.partition}:iam::aws:policy/AdministratorAccess"]
    }
    readonly = {
      name        = "readonly"
      path        = local.with_iam_path
      description = "A readonly role for teleport to assume in this account"
      policy_arns = ["arn:${local.partition}:iam::aws:policy/ReadOnlyAccess"]
    }
    contributor = {
      name        = "contributor"
      path        = local.with_iam_path
      description = "A contributor role for teleport to assume in this account"
      policy_arns = ["arn:${local.partition}:iam::aws:policy/PowerUserAccess"]
    }
  }

  teleport_role_policy_attachments = merge([
    for role, cfg in local.teleport_roles : {
      for arn in cfg.policy_arns : "${role}/${arn}" => { role = role, policy_arn = arn }
    }
  ]...)
}

resource "aws_iam_role" "teleport" {
  for_each = local.teleport_roles

  name        = each.value.name
  path        = each.value.path
  description = each.value.description

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { AWS = var.teleport_agent_role_arn }
        Action    = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "teleport" {
  for_each = local.teleport_role_policy_attachments

  role       = aws_iam_role.teleport[each.value.role].name
  policy_arn = each.value.policy_arn
}
