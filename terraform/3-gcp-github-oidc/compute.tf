# The replicas. A managed instance group is the cloud's `count`: you declare how
# many there should be and something else keeps that true.

resource "google_compute_health_check" "app" {
  name                = "${var.name}-hc"
  check_interval_sec  = 5
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 3

  http_health_check {
    port         = 8080
    request_path = "/health"
  }
}

resource "google_compute_instance_template" "app" {
  name_prefix  = "${var.name}-"
  machine_type = var.machine_type
  tags         = ["${var.name}-app"]

  disk {
    # Container-Optimized OS: a minimal image with Docker already on it, so the
    # startup script is three lines instead of an installation.
    source_image = "cos-cloud/cos-stable"
    auto_delete  = true
    boot         = true
  }

  network_interface {
    network    = google_compute_network.main.id
    subnetwork = google_compute_subnetwork.main.id
    # No access_config block: no public address. The way out is Cloud NAT and
    # the way in is the load balancer.
  }

  metadata = {
    "google-logging-enabled" = "true"
    startup-script           = <<-EOT
      #!/bin/bash
      docker run -d --restart=always --name catshop -p 8080:8080 \
        -e DATABASE_URL="postgresql://catshop:${random_password.db.result}@${google_sql_database_instance.main.private_ip_address}:5432/catshop" \
        -e PORT=8080 \
        ${var.image}
    EOT
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_compute_region_instance_group_manager" "app" {
  name               = "${var.name}-mig"
  region             = var.region
  base_instance_name = "${var.name}-app"
  target_size        = var.replicas

  version {
    instance_template = google_compute_instance_template.app.id
  }

  named_port {
    name = "http"
    port = 8080
  }

  # The group replaces an instance the health check gives up on. This is the
  # difference between two copies and two copies that stay.
  auto_healing_policies {
    health_check      = google_compute_health_check.app.id
    initial_delay_sec = 120
  }
}
