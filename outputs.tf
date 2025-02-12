output "instance_id" {
  description = "ID de la instancia EC2"
  value       = aws_instance.hcis_ec2.id
}

output "public_ip" {
  description = "Dirección IP pública de la instancia"
  value       = aws_instance.hcis_ec2.public_ip
}

output "private_ip" {
  description = "Dirección IP privada de la instancia"
  value       = aws_instance.hcis_ec2.private_ip
}

output "s3_bucket_name" {
  description = "Nombre del bucket S3 donde se almacenan los archivos de instalación"
  value       = aws_s3_bucket.hcis_bucket.id
}
