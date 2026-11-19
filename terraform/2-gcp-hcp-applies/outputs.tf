output "bucket" {
  description = "The bucket that proves something really happened."
  value       = google_storage_bucket.notes.name
}

output "message" {
  description = "Read it back after a run to see which commit is live."
  value       = google_storage_bucket.notes.labels["message"]
}
