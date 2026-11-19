locals {
  # Mêmes noms que compose.staging.yaml (projet app-staging) pour reprendre un staging existant.
  prefix      = "app-${var.environment}"
  db_password = coalesce(var.db_password, random_password.db.result)
}

resource "random_password" "db" {
  length  = 32
  special = false
}

# Pas de labels sur le réseau : un label modifié force son remplacement, donc celui de tous les conteneurs.
resource "docker_network" "this" {
  name = local.prefix
}

# Nom du volume créé par Compose (projet_volume) ; ses labels Compose ne doivent pas être réécrits.
resource "docker_volume" "pgdata" {
  name = "${local.prefix}_db-data"

  lifecycle {
    ignore_changes = [labels]
  }
}

# Même image que compose.postgres.yaml ; le digest empêche un tag qui bouge de changer la base sous nos pieds.
resource "docker_image" "db" {
  name         = "docker.io/library/postgres:16-alpine@sha256:1d5b02d3a9941fbd52437db4107f8c52d6297dac553ca1e5c299ebb3756b4857"
  keep_locally = true
}

resource "docker_image" "app" {
  name         = "${var.image}:${var.image_tag}"
  keep_locally = true
}

resource "docker_container" "db" {
  name          = "${local.prefix}-db-1"
  image         = docker_image.db.image_id
  restart       = "unless-stopped"
  security_opts = ["no-new-privileges:true"]

  env = [
    "POSTGRES_USER=app",
    "POSTGRES_PASSWORD=${local.db_password}",
    "POSTGRES_DB=app",
  ]

  volumes {
    volume_name    = docker_volume.pgdata.name
    container_path = "/var/lib/postgresql/data"
  }

  networks_advanced {
    name    = docker_network.this.id
    aliases = ["db"]
  }

  healthcheck {
    test     = ["CMD-SHELL", "pg_isready -U app -d app"]
    interval = "10s"
    timeout  = "3s"
    retries  = 10
  }

  wait         = true
  wait_timeout = 90
}

resource "docker_container" "app" {
  name          = "${local.prefix}-app-1"
  image         = docker_image.app.image_id
  restart       = "unless-stopped"
  security_opts = ["no-new-privileges:true"]

  # Comme compose.staging.yaml : système de fichiers en lecture seule, cache Next en tmpfs (uid 1000).
  read_only = true
  tmpfs = {
    "/tmp"             = ""
    "/app/.next/cache" = "uid=1000,gid=1000"
  }

  env = [
    "PORT=3000",
    "APP_ENV=${var.environment}",
    "DATABASE_URL=postgres://app:${local.db_password}@db:5432/app",
  ]

  ports {
    internal = 3000
    external = var.app_port
    ip       = "127.0.0.1"
  }

  networks_advanced {
    name    = docker_network.this.id
    aliases = ["app"]
  }

  # Identique au HEALTHCHECK du Dockerfile : pas de curl dans l'image.
  healthcheck {
    test         = ["CMD", "node", "-e", "fetch('http://127.0.0.1:3000/api/health').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"]
    interval     = "30s"
    timeout      = "5s"
    start_period = "10s"
    retries      = 3
  }

  wait         = true
  wait_timeout = 90

  depends_on = [docker_container.db]
}
