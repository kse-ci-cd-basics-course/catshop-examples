# A managed database on a private address. Reaching one privately needs a VPC
# peering to Google's own network, which is these two resources — the piece
# that is invisible until the database has no address you are allowed to use.

resource "google_compute_global_address" "private_ip" {
  name          = "${var.name}-private-ip"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.main.id
}

resource "google_service_networking_connection" "main" {
  network                 = google_compute_network.main.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip.name]
}

resource "random_password" "db" {
  length  = 24
  special = false
}

resource "google_sql_database_instance" "main" {
  name             = "${var.name}-db"
  database_version = "POSTGRES_16"
  region           = var.region

  # The default is true, and it makes `terraform destroy` fail with an error
  # about the API rather than about this setting. Correct for production,
  # wrong for anything you intend to take down again.
  deletion_protection = false

  settings {
    tier = var.db_tier

    ip_configuration {
      ipv4_enabled    = false
      private_network = google_compute_network.main.id
    }

    backup_configuration {
      enabled = false
    }
  }

  depends_on = [google_service_networking_connection.main]
}

resource "google_sql_database" "catshop" {
  name     = "catshop"
  instance = google_sql_database_instance.main.name
}

resource "google_sql_user" "catshop" {
  name     = "catshop"
  instance = google_sql_database_instance.main.name
  password = random_password.db.result
}
