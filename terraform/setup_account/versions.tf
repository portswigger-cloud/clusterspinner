# SPDX-FileCopyrightText: 2026 The clusterspinner contributors
# SPDX-License-Identifier: MIT

terraform {
  required_version = ">= 1.5.0"

  # Bucket and region are not specified here so they can be supplied at init time:
  # terraform init -backend-config="bucket=<bucket>" -backend-config="region=<region>"
  backend "s3" {
    key = "setup-account/terraform.tfstate"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}
