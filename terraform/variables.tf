variable "region" {
  description = "A Region that supports X-Ray API keys"
  type        = string
  default     = "us-east-1"
}

variable "enable_transaction_search" {
  description = "Set to false if Transaction Search is already on in this account and Region"
  type        = bool
  default     = true
}

variable "max_key_age_days" {
  description = "The longest expiry the issuer policy allows on a key"
  type        = number
  default     = 90

  validation {
    condition     = var.max_key_age_days >= 1 && var.max_key_age_days <= 36600
    error_message = "IAM allows 1 to 36600 days."
  }
}
