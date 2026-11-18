variable "project_id" {
  type        = string
  description = "The Google Cloud project everything is created in."
}

variable "region" {
  type        = string
  description = "One region. Everything here is regional: the group, the database and the load balancer's backend."
  default     = "europe-west1"
}

variable "name" {
  type        = string
  description = "Prefix for every resource, so two copies can coexist in one project."
  default     = "catshop"
}

variable "replicas" {
  type        = number
  description = "How many instances the managed group keeps running."
  default     = 2

  validation {
    condition     = var.replicas >= 2
    error_message = "One instance is not redundancy: nothing to balance, and no way to deploy without a gap."
  }
}

variable "image" {
  type        = string
  description = "The container image the instances run. Pass a DIGEST, not a tag: a tag can be repointed, and then two applies that both say 'No changes.' are running different code."
  default     = "ghcr.io/kse-ci-cd-basics-course/catshop:latest"
}

variable "machine_type" {
  type        = string
  description = "e2-micro is the smallest thing that runs the image."
  default     = "e2-micro"
}

variable "db_tier" {
  type        = string
  description = "db-f1-micro is the cheapest Cloud SQL tier. It is still not free — see COST.md."
  default     = "db-f1-micro"
}
