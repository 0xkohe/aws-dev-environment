variable "ami_id" {
  description = "Pinned Canonical Ubuntu 24.04 amd64 AMI in the selected region."
  type        = string
}

variable "instance_type" {
  description = "On-demand development instance; stop it before an intentional resize."
  type        = string
  default     = "m7i.2xlarge"
}

variable "root_volume_size" {
  description = "gp3 GiB; may be increased, not shrunk."
  type        = number
  default     = 100
  validation {
    condition     = var.root_volume_size >= 100 && floor(var.root_volume_size) == var.root_volume_size
    error_message = "Use an integer of at least 100 GiB."
  }
}

variable "ssh_public_key_path" {
  description = "Only the public key is read by Terraform; the private key never enters state."
  type        = string
}

variable "account_id" {
  type = string
  validation {
    condition     = can(regex("^[0-9]{12}$", var.account_id))
    error_message = "Provide a 12-digit AWS account ID."
  }
}
variable "aws_profile" {
  type = string
}
variable "region" {
  type = string
}
variable "vpc_id" {
  type = string
}
variable "subnet_id" {
  type = string
}
variable "name" {
  type = string
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,39}$", var.name))
    error_message = "Use a lowercase name of at most 40 characters, with digits or hyphens."
  }
}
variable "state_bucket" {
  description = "Consumed by bootstrap-state.sh and init.sh; must be dedicated to this environment."
  type        = string
}
variable "state_key" {
  description = "Consumed by init.sh. Do not change for an existing environment."
  type        = string
}
