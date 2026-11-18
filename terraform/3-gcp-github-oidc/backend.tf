# The state lives in a bucket, not beside the configuration and not on whatever
# machine happened to run the apply.
#
# The bucket cannot be created by the configuration whose state it holds — that
# is a chicken and an egg — so it is made once, by hand, and then never again:
#
#   gcloud storage buckets create gs://<project>-tfstate \
#     --location=europe-west1 --uniform-bucket-level-access
#   gcloud storage buckets update gs://<project>-tfstate --versioning
#
# Versioning is the only way back from a truncated state file. Turn it on.
terraform {
  required_version = ">= 1.6"

  backend "gcs" {
    bucket = "REPLACE-WITH-YOUR-PROJECT-tfstate"
    prefix = "catshop/prod"
    # Locking needs no configuration: it is a lock object in this same bucket.
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
