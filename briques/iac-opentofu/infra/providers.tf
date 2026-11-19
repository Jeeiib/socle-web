provider "docker" {
  host = var.docker_host
  # Jamais de confiance aveugle : l'empreinte du serveur doit être dans known_hosts.
  ssh_opts = ["-o", "BatchMode=yes"]

  dynamic "registry_auth" {
    for_each = var.ghcr_token == null ? [] : [1]
    content {
      address  = "ghcr.io"
      username = var.ghcr_username
      password = var.ghcr_token
    }
  }
}
