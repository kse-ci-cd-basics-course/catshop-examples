# There is no backend block and no cloud block in this folder. Neither is a
# mistake, and the absence is the point.
#
# Where the state lives and who runs Terraform are NOT properties of this
# configuration. The workspace already knows the repository, the branch, this
# directory and its own state, so nothing here has to name any of it — and the
# organization is not hardcoded into a file every fork would have to edit.
#
# Run `terraform init` on your own machine in this folder and you get a LOCAL
# state file, because that is what a configuration with no backend means. To
# talk to the same workspace from a terminal, say so in the environment rather
# than in the code:
#
#   export TF_CLOUD_ORGANIZATION=your-org
#   export TF_WORKSPACE=catshop-gcp
#   terraform init
#
# Compare ../3-gcp-github-oidc/backend.tf, which has to name a bucket because
# there the CLI is the thing doing the work.
terraform {
  required_version = ">= 1.6"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}
