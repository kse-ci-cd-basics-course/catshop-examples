variable "project_id" {
  type        = string
  description = "The Google Cloud project. Set it as a workspace variable, not here."
}

variable "region" {
  type        = string
  description = "Where the bucket lives."
  default     = "europe-west1"
}

variable "name" {
  type        = string
  description = "Bucket name prefix. A random suffix is added because bucket names are globally unique."
  default     = "catshop-notes"
}

variable "message" {
  type        = string
  description = "A label with no purpose other than being easy to change. Edit it, push to main, and a run starts without you."
  default     = "hello"
}
