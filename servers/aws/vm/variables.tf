# Declare TF variables
variable "aws_region" {
  //default = "us-west-2"
  default = "ap-northeast-1"
}
variable "aws_availabilityzone" {
  //default = "us-west-2a"
  default = "ap-northeast-1a"
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

variable "hostname" {
  default = "arc-aws-demo-ubuntu1804"
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
