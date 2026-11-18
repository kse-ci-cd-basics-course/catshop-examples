# The load balancer, which on this cloud is not one object but five — and that
# is the honest shape of it everywhere. The nginx version of this file is an
# upstream block and a proxy_pass: a pool, and a rule.

resource "google_compute_backend_service" "app" {
  name                  = "${var.name}-backend"
  protocol              = "HTTP"
  port_name             = "http"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  timeout_sec           = 10
  health_checks         = [google_compute_health_check.app.id]

  # The pool. `upstream { server ...; server ...; }`, as a managed group.
  backend {
    group           = google_compute_region_instance_group_manager.app.instance_group
    balancing_mode  = "UTILIZATION"
    capacity_scaler = 1.0
  }
}

# The rule. `location / { proxy_pass http://catshop; }`
resource "google_compute_url_map" "app" {
  name            = "${var.name}-urlmap"
  default_service = google_compute_backend_service.app.id
}

resource "google_compute_target_http_proxy" "app" {
  name    = "${var.name}-proxy"
  url_map = google_compute_url_map.app.id
}

resource "google_compute_global_address" "lb" {
  name = "${var.name}-lb-ip"
}

# The listener. `listen 80;`
resource "google_compute_global_forwarding_rule" "app" {
  name                  = "${var.name}-fr"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  port_range            = "80"
  target                = google_compute_target_http_proxy.app.id
  ip_address            = google_compute_global_address.lb.id
}
