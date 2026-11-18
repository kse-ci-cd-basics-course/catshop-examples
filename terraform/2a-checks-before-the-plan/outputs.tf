output "url" {
  description = "Where the stack answers. Everything that probes this stack reads it from here, never from a hard-coded port."
  value       = "http://localhost:${var.port}"
}

output "backends" {
  description = "The names in the proxy's pool, so you can see that raising replicas changed it."
  value       = docker_container.app[*].name
}

output "db_password" {
  description = "Marked sensitive, so it is hidden in the log. It is NOT hidden in terraform.tfstate."
  value       = random_password.db.result
  sensitive   = true
}
