# No default for the endpoint, on purpose. A default that works on the author's
# machine is the reason this kind of configuration breaks the first time anyone
# else runs it — and the error it produces does not mention the default.
variable "docker_host" {
  type        = string
  description = "Where the Docker daemon listens. Linux and CI: unix:///var/run/docker.sock. Docker Desktop on macOS: unix://$HOME/.docker/run/docker.sock"
}

variable "name" {
  type        = string
  description = "Prefix for every resource this stack creates, so two copies can coexist."
  default     = "catshop"
}

variable "port" {
  type        = number
  description = "The host port the load balancer publishes on."
  default     = 8080
}

variable "replicas" {
  type        = number
  description = "How many copies of the application sit behind the proxy."
  default     = 2

  validation {
    condition     = var.replicas >= 2
    error_message = "One copy is not redundancy: with one replica there is nothing to balance and no way to deploy without a gap."
  }
}

variable "tag" {
  type        = string
  description = "The tag Terraform builds the application image under."
  default     = "local"
}
