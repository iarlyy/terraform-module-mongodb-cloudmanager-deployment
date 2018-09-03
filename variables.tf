variable "name" {}
variable "key_name" {}
variable "instance_type" {}
variable "cloud_manager_group_id_secret_name" {}
variable "cloud_manager_api_key_secret_name" {}
variable "vpc_id" {}
variable "ami" {}

variable "pool_size" {
  default = 1
}

variable "associate_public_ip_address" {
  default = true
}

variable "root_volume_size" {
  default = 80
}

variable "datadir_volume_size" {
  default = 80
}

variable "ebs_optimized" {
  default = true
}

variable "datadir_volume_delete_on_termination" {
  default = true
}

variable "associate_iam_policies" {
  type    = "list"
  default = []
}

variable "security_group_ids" {
  type    = "list"
  default = []
}

variable "ec2_subnet_ids" {
  type    = "list"
  default = []
}

variable "lb_subnet_ids" {
  type    = "list"
  default = []
}
