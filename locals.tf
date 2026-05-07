locals {
  name_prefix  = "${var.environment}-${var.project_name}"
  service_name = "${var.project_name}-backend"

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}
