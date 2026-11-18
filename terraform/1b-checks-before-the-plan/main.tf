# The catshop stack, declared: a load balancer, two replicas, one database.
#
# The provider is `kreuzwerker/docker` and the endpoint is a daemon — so this is
# real Terraform, with real state and a real graph, against an API that happens
# to be on this machine instead of in a datacentre. plan, state, the lock and
# destroy all behave exactly as they would against a cloud.

terraform {
  required_version = ">= 1.6"

  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "docker" {
  host = var.docker_host
}

# Generated, never written down. It lands in the state in plaintext, which is
# why the state is a secret and why *.tfstate is the first line of .gitignore.
resource "random_password" "db" {
  length  = 24
  special = false
}

# Containers find each other by name only on a user-defined network. On the
# default bridge there is no DNS, and the proxy's upstream names resolve to
# nothing.
resource "docker_network" "stack" {
  name = "${var.name}-net"
}

# Terraform builds the image. No registry, no login, no `docker build` step in
# the workflow — the build is a resource like everything else.
resource "docker_image" "app" {
  name = "${var.name}-app:${var.tag}"

  build {
    context = "${path.module}/../../app"
    tag     = ["${var.name}-app:${var.tag}"]
  }
}

resource "docker_image" "postgres" {
  name         = "postgres:16-alpine"
  keep_locally = true
}

resource "docker_image" "nginx" {
  name         = "nginx:1.27-alpine"
  keep_locally = true
}

resource "docker_container" "db" {
  name  = "${var.name}-db"
  image = docker_image.postgres.image_id

  networks_advanced {
    name = docker_network.stack.name
  }

  env = [
    "POSTGRES_DB=catshop",
    "POSTGRES_USER=catshop",
    "POSTGRES_PASSWORD=${random_password.db.result}",
  ]

  # depends_on does not wait for readiness, so the database says when it is up.
  healthcheck {
    test     = ["CMD-SHELL", "pg_isready -U catshop -d catshop"]
    interval = "3s"
    timeout  = "3s"
    retries  = 20
  }
}

# ONE resource, var.replicas copies. Two hand-written blocks would be two
# resources that happen to look alike — and the pool below would not follow.
resource "docker_container" "app" {
  count = var.replicas

  name  = "${var.name}-app-${count.index}"
  image = docker_image.app.image_id

  networks_advanced {
    name = docker_network.stack.name
  }

  # Both copies count into the same Postgres. Two replicas with two private
  # counters are two applications, not one application twice.
  env = [
    "DATABASE_URL=postgresql://catshop:${random_password.db.result}@${docker_container.db.name}:5432/catshop",
    "INSTANCE_ID=${var.name}-app-${count.index}",
  ]

  depends_on = [docker_container.db]
}

resource "docker_container" "lb" {
  name  = "${var.name}-lb"
  image = docker_image.nginx.image_id

  networks_advanced {
    name = docker_network.stack.name
  }

  ports {
    internal = 80
    external = var.port
  }

  # The reference to docker_container.app[*].name is what puts the replicas
  # BEFORE the proxy in the graph. Nothing here says "start them first".
  upload {
    file = "/etc/nginx/conf.d/default.conf"
    content = templatefile("${path.module}/nginx.conf.tftpl", {
      backends = docker_container.app[*].name
      app_port = 8080
    })
  }
}
