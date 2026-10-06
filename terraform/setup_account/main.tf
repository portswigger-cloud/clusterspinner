# SPDX-FileCopyrightText: 2026 The clusterspinner contributors
# SPDX-License-Identifier: MIT

# Resources that exist once per AWS account rather than once per cluster.
# Apply with a role with broad permissions such as AdministratorAccess.

provider "aws" {
  region = var.region
}

data "aws_partition" "current" {}
