variable "docker_host" {
  type        = string
  default     = "unix:///var/run/docker.sock"
  description = "Démon Docker visé : unix:///var/run/docker.sock ou ssh://deploy@203.0.113.10."
}

variable "image" {
  type        = string
  description = "Image de l'application sans tag, en minuscules (ex. ghcr.io/mon-organisation/mon-projet)."

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9./_-]*$", var.image))
    error_message = "image doit être en minuscules et sans tag (ex. ghcr.io/mon-organisation/mon-projet)."
  }
}

variable "image_tag" {
  type    = string
  default = "latest"

  validation {
    condition     = can(regex("^(latest|[0-9]+\\.[0-9]+\\.[0-9]+(-rc\\.[0-9]+)?)$", var.image_tag))
    error_message = "image_tag doit être une version sans v (1.2.3 ou 1.2.3-rc.1) ou latest."
  }
}

variable "app_port" {
  type        = number
  default     = 8081
  description = "Port de l'hôte (127.0.0.1) qui mène à l'application."

  validation {
    condition     = var.app_port >= 1024 && var.app_port <= 65535
    error_message = "app_port doit être entre 1024 et 65535."
  }
}

variable "environment" {
  type    = string
  default = "staging"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*$", var.environment))
    error_message = "environment doit être en minuscules (lettres, chiffres, tirets)."
  }
}

variable "db_password" {
  type        = string
  default     = null
  sensitive   = true
  description = "Mot de passe Postgres. Sans valeur, OpenTofu en génère un et le garde dans le state."
}

variable "ghcr_username" {
  type    = string
  default = null
}

variable "ghcr_token" {
  type      = string
  default   = null
  sensitive = true
}
