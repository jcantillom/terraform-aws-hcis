variable "aws_region" {
  description = "Región de AWS"
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  description = "Tipo de instancia EC2"
  type        = string
  default     = "t3.xlarge"
}

variable "ami_id" {
  description = "AMI de la instancia EC2"
  type        = string
  default     = "ami-04921b5223c6ab7f0"
}

variable "key_name" {
  description = "Nombre de la llave SSH"
  type        = string
  default     = "HCIS_DEMO_LATAM_JJC"
}

variable "subnet_id" {
  description = "ID de la subred"
  type        = string
  default     = "subnet-02ff49846e74a3d6e"
}

variable "security_group_ids" {
  description = "Lista de Security Groups"
  type        = list(string)
  default     = ["sg-0ad1240fccb511429"]
}

variable "bucket_name" {
  description = "Nombre del bucket de S3"
  type        = string
  default     = "hcis-installation-files"
}

variable "existing_iam_role" {
  description = "IAM Role existente para la instancia EC2"
  type        = string
  default     = "hcis-ec2-role"
}
