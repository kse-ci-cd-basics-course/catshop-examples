output "url" {
  description = "Where it answers. Give it a few minutes after the first apply: the backends are unhealthy until the image is pulled and /health replies."
  value       = "http://${google_compute_global_address.lb.address}"
}

output "db_private_ip" {
  description = "The database has no public address at all."
  value       = google_sql_database_instance.main.private_ip_address
}

output "db_password" {
  description = "sensitive hides it from the log. It is plaintext in the state, which is why the bucket is private and versioned."
  value       = random_password.db.result
  sensitive   = true
}
