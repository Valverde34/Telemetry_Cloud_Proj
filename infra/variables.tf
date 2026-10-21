variable "location" {
  type    = string
  default = "spaincentral"
}

variable "project" {
  type    = string
  default = "telemetry"
}

variable "alert_email" {
  description = "Email address that receives monitoring alerts."
  type        = string
}

variable "ghcr_owner" {
  description = "GitHub user/org that owns the images in ghcr.io (lowercase)."
  type        = string
  default     = "valverde34"
}

variable "image_tag" {
  description = "Image tag used when the container apps are first created. Later deploys are done by the CI pipeline."
  type        = string
  default     = "latest"
}
