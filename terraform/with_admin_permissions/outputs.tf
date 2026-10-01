# SPDX-FileCopyrightText: 2026 The clusterspinner contributors
# SPDX-License-Identifier: MIT

output "role_arn" {
  description = "ARN of the IAM role that can run clusterspinner."
  value       = aws_iam_role.this.arn
}
