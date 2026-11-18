# There is no backend block here and no workflow in this folder. Both absences
# are the lesson.
#
# The workspace is connected to this repository through HCP Terraform's GitHub
# App, so HCP sees the commit itself: it plans every pull request and posts the
# result as a check, and it applies on merge. Nothing in GitHub Actions runs
# Terraform, so there is no token in this repository to store or rotate.
#
# What moved rather than vanished: the credential to Google now lives in the
# workspace. Use dynamic provider credentials — HCP federates to Google the same
# way a runner would — rather than pasting a service-account key into a form.
terraform {
  required_version = ">= 1.6"

  cloud {
    organization = "REPLACE-WITH-YOUR-ORG"

    workspaces {
      name = "catshop-gcp"
    }
  }

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
