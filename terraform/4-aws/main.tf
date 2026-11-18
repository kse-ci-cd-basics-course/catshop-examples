# The same architecture as ../3-gcp, on AWS — and the differences are not
# cosmetic. Read them in this order: the network, then the load balancer.
#
# NOTHING HERE IS APPLIED. `init -backend=false` and `validate` run offline, so
# this file can be read and checked without an account.

terraform {
  required_version = ">= 1.6"

  backend "s3" {
    bucket = "REPLACE-WITH-YOUR-BUCKET"
    key    = "catshop/prod.tfstate"
    region = "eu-west-1"
    # Locking is a lock file beside the state since S3 gained conditional
    # writes. The DynamoDB table this used to require is no longer needed.
    use_lockfile = true
  }

  required_providers {
    aws    = { source = "hashicorp/aws", version = "~> 5.0" }
    random = { source = "hashicorp/random", version = "~> 3.6" }
  }
}

provider "aws" {
  region = var.region
}

resource "random_password" "db" {
  length  = 24
  special = false
}
