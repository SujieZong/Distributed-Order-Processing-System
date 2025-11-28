# modules/logging/variables.tf

variable "project_name" {
  description = "Project name for log group naming"
  type        = string
}

variable "retention_in_days" {
  description = "Number of days to retain logs"
  type        = number
  default     = 7
}
