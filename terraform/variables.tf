variable "aws_region" {
  description = "The AWS region to deploy to"
  type        = string
  default     = "eu-central-1"
}

variable "project_name" {
  description = "The name of the project"
  type        = string
  default     = "techstarter-test"
}

variable "github_owner" {
  description = "GitHub repository owner"
  type        = string
  default     = "RaupeCHR"
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
  default     = "aws-codepipeline-nextjs"
}

variable "github_branch" {
  description = "GitHub repository branch"
  type        = string
  default     = "main"
}

variable "instance_ami" {
  description = "instance ami"
  type        = string
  default     = "ami-0faab6bdbac9486fb"
}

variable "instance_type" {
  description = "instance ami"
  type        = string
  default     = "t3.small"
}

variable "availability_zones" {
  description = "instance ami"
  type        = list(any)
  default     = ["eu-central-1a", "eu-central-1b"]
}

variable "pem_key" {
  description = "instance ami"
  type        = string
  default     = "Mainkey"
}