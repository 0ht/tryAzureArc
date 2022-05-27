# Declare TF variables
variable "gcp_project_id" {
}

variable "gcp_credentials_filename" {
}

variable "gcp_region" {
  default = "us-west1"
}

variable "gcp_zone" {
  default = "us-west1-a"
}

variable "admin_username" {
  default = "arcadmin"
}

variable "admin_password" {
  default = "arcdemo123!!"
}

variable "azure_location" {
  default = "japaneast"
}

variable "azure_resource_group" {
  default = "rg-arcdemo"
}

variable "subscription_id" {
}

variable "client_id" {
}

variable "client_secret" {
}

variable "tenant_id" {
}
