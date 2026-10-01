# SPDX-FileCopyrightText: 2026 The clusterspinner contributors
# SPDX-License-Identifier: MIT

provider "aws" {
  region = var.region
}

data "aws_partition" "current" {}
data "aws_caller_identity" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  cluster_version     = "1.36"
  vpc_cidr            = "10.0.0.0/16"
  node_instance_types = ["t4g.medium"]
  node_desired_size   = 2
  azs                 = data.aws_availability_zones.available.names
}
