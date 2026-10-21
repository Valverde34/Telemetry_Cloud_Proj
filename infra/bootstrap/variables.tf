variable "location" {
  type    = string
  default = "spaincentral"
}

variable "project" {
  type    = string
  default = "telemetry"
}

variable "github_repo" {
  description = "GitHub repository allowed to deploy, exactly as GitHub writes it in the OIDC token subject. GitHub includes the owner and repository IDs (owner@id/repo@id), so a renamed or re-created repository with the same name cannot impersonate this one."
  type        = string
  default     = "Valverde34@116815851/Telemetry_Cloud_Proj@1396478247"
}
