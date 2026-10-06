# SPDX-FileCopyrightText: 2026 The clusterspinner contributors
# SPDX-License-Identifier: MIT

# The ceiling on roles the crossplane IAM provider creates under /crossplane/.
# The provider's IRSA role (setup_cluster/irsa.tf) may only create roles with
# exactly this policy attached, found at policy/crossplane/permissions-boundary.
# Both the path and the name are expected by the templates that render those
# roles, so they are not free to change.
#
# Account-wide rather than per-cluster, and the runner role is not allowed to
# manage policies at this path, so it lives in setup_account.
#
# A deny-list rather than an allow-list: the roles' own policies are what narrow
# them, and the boundary only has to rule out the categories that must never be
# reachable from a role crossplane mints.
resource "aws_iam_policy" "crossplane_permissions_boundary" {
  name = "permissions-boundary"
  path = "/crossplane/"
  # Changing the description forces replacement, which fails for a fixed name.
  description = "Maximum permissions a role crossplane creates at /crossplane/ can have"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # IAM has no implicit allow: a boundary only permits what it explicitly
        # allows, so the deny-list below needs a permissive default to subtract from.
        Sid      = "AllowByDefault"
        Effect   = "Allow"
        Action   = "*"
        Resource = "*"
      },
      {
        # Nothing here may touch identity or org configuration, or it could
        # re-derive the privilege escalation this boundary exists to prevent.
        Sid      = "DenyIdentityAndOrgManagement"
        Effect   = "Deny"
        Action   = ["iam:*", "organizations:*"]
        Resource = "*"
      },
      {
        Sid      = "DenyAccountAndBilling"
        Effect   = "Deny"
        Action   = ["account:*", "aws-portal:*", "ce:*", "budgets:*"]
        Resource = "*"
      },
      {
        # Blocks role chaining out of the boundary. These roles are reached by
        # IRSA, so nothing legitimate needs it.
        Sid      = "DenyAssumeRole"
        Effect   = "Deny"
        Action   = "sts:AssumeRole"
        Resource = "*"
      },
    ]
  })
}

output "crossplane_permissions_boundary_arn" {
  description = "ARN of the permissions boundary for roles created by crossplane."
  value       = aws_iam_policy.crossplane_permissions_boundary.arn
}
