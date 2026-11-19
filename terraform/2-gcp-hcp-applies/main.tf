# Something small on purpose.
#
# This folder is not about the architecture — ../3-gcp-github-oidc has that,
# with a load balancer, two instances and a database. This one is about WHO
# RUNS TERRAFORM, and that question is answered just as well by one bucket as
# by seventy dollars a month of infrastructure.
#
# It is also something you can apply in front of people and leave running: an
# empty bucket costs approximately nothing.

resource "random_pet" "suffix" {
  length = 2
}

resource "google_storage_bucket" "notes" {
  name     = "${var.name}-${random_pet.suffix.id}"
  location = var.region

  uniform_bucket_level_access = true
  force_destroy               = true

  versioning {
    enabled = true
  }

  # Change this one line on main, push, and watch the workspace pick it up and
  # apply by itself. That is the entire demonstration.
  labels = {
    message = var.message
  }
}
