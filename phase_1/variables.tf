variable "region" {
  description = "AWS region where resources will be deployed"
  type        = string

}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string

}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet"
  type        = string

}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string

}

variable "ssh_cidr" {
  description = "CIDR block allowed to SSH into the EC2 instance"
  type        = string

}