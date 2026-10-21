variable "location" {
  type    = string
  default = "spaincentral"
}

variable "project" {
  type    = string
  default = "telemetry"
}

variable "github_repo" {
  description = "GitHub repository allowed to deploy, as owner/name (case-sensitive)."
  type        = string
  default     = "Valverde34/Telemetry_Cloud_Proj"
}
