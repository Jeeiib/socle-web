output "health_url" {
  value = "http://127.0.0.1:${var.app_port}/api/health"
}

output "image_tag" {
  value = var.image_tag
}

output "containers" {
  value = [docker_container.db.name, docker_container.app.name]
}

output "network" {
  value = docker_network.this.name
}
