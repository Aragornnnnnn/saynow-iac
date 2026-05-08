locals {
  name_prefix     = "${var.environment}-${var.project_name}"
  service_name    = "${var.project_name}-backend"
  ai_service_name = "${var.project_name}-ai"

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}
