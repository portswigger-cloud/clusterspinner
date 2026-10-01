# SPDX-FileCopyrightText: 2026 The clusterspinner contributors
# SPDX-License-Identifier: MIT

variable "region" {
  description = "AWS region to deploy the cluster in."
  type        = string
}

variable "cluster_name" {
  description = "Name of the EKS cluster."
  type        = string
}

variable "github_namespace" {
  description = "GitHub organisation or user under which the cluster manifests repo is hosted."
  type        = string
  default     = "noa-portswigger"
}
