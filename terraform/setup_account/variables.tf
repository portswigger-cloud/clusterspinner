# SPDX-FileCopyrightText: 2026 The clusterspinner contributors
# SPDX-License-Identifier: MIT

variable "region" {
  description = "AWS region."
  type        = string
}

variable "teleport_agent_role_arn" {
  description = "ARN of the IAM role the teleport agent runs as. The only principal trusted by the teleport roles."
  type        = string
  default     = "arn:aws:iam::132827254700:role/pipeline-roles/CDK-management-Eks-TeleportKubeAgentRole74728980-5CGBKUTLRLU9"
}
