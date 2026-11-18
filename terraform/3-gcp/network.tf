# A network, one subnet, and two firewall rules — and the second rule is the one
# everybody forgets.

resource "google_compute_network" "main" {
  name                    = "${var.name}-net"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "main" {
  name          = "${var.name}-subnet"
  ip_cidr_range = "10.10.0.0/24"
  region        = var.region
  network       = google_compute_network.main.id

  # Instances get no public address. Without this they also get no way out, so
  # the image is pulled through Cloud NAT below.
  private_ip_google_access = true
}

# The load balancer's health checks do NOT come from the load balancer. They
# come from two fixed Google ranges, and if these are not allowed every backend
# is reported unhealthy and the whole thing serves 502 with nothing in the logs.
# This is the single most common reason a correct-looking GCP load balancer
# does not work.
resource "google_compute_firewall" "health_checks" {
  name    = "${var.name}-allow-health-checks"
  network = google_compute_network.main.name

  allow {
    protocol = "tcp"
    ports    = ["8080"]
  }

  source_ranges = ["35.191.0.0/16", "130.211.0.0/22"]
  target_tags   = ["${var.name}-app"]
}

# SSH, through Identity-Aware Proxy rather than from the internet. No public
# address and no open port 22 anywhere.
resource "google_compute_firewall" "iap_ssh" {
  name    = "${var.name}-allow-iap-ssh"
  network = google_compute_network.main.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["${var.name}-app"]
}

# Instances with no public address still have to reach the registry to pull the
# image. Cloud NAT is how, and it is NOT free — a router plus a NAT gateway.
# The alternative is a public address on every instance, which is cheaper and
# worse. Priced in COST.md either way.
resource "google_compute_router" "main" {
  name    = "${var.name}-router"
  region  = var.region
  network = google_compute_network.main.id
}

resource "google_compute_router_nat" "main" {
  name                               = "${var.name}-nat"
  router                             = google_compute_router.main.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}
