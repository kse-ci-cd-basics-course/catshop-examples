variable "region" {
  type        = string
  description = "One region. Unlike a Google VPC, an AWS VPC does not leave it."
  default     = "eu-west-1"
}

variable "name" {
  type        = string
  default     = "catshop"
  description = "Prefix for every resource."
}

variable "replicas" {
  type        = number
  default     = 2
  description = "How many instances the group keeps running."

  validation {
    condition     = var.replicas >= 2
    error_message = "One instance is not redundancy."
  }
}

variable "zones" {
  type        = list(string)
  description = "Two availability zones, written down rather than looked up. A data source here would need an account and make this file uncheckable."
  default     = ["eu-west-1a", "eu-west-1b"]
}

variable "ami" {
  type        = string
  description = "Passed in, never looked up for the same reason as the zones."
  default     = "ami-0c1c30571d2dae5c9"
}

variable "image" {
  type        = string
  description = "The container image. A digest, not a tag."
  default     = "ghcr.io/kse-ci-cd-basics-course/catshop:latest"
}
