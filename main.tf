provider "aws" {
  region = "us-east-1"
}

# Crear bucket S3 para almacenar archivos de instalación
resource "aws_s3_bucket" "hcis_bucket" {
  bucket = "hcis-installation-files-${random_id.bucket_suffix.hex}"
}

# Configurar control de propiedad de objetos en el bucket
resource "aws_s3_bucket_ownership_controls" "hcis_bucket_ownership" {
  bucket = aws_s3_bucket.hcis_bucket.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# Crear objetos en el bucket
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# Subir archivos de instalación a S3
resource "aws_s3_object" "hcis_tar" {
  bucket = aws_s3_bucket.hcis_bucket.bucket
  key    = "instalacion_standalone_HCIS4.tar.gz"
  source = "instalacion_standalone_HCIS4.tar.gz"
}

# Subir archivo EAR a S3
resource "aws_s3_object" "hcis_ear" {
  bucket = aws_s3_bucket.hcis_bucket.bucket
  key    = "hcis.ear"
  source = "hcis.ear"
}

# Crear instancia EC2
resource "aws_instance" "hcis_ec2" {
  ami           = "ami-04921b5223c6ab7f0"
  instance_type = "t3.xlarge"
  key_name      = "HCIS_DEMO_LATAM_JJC"
  subnet_id     = "subnet-02ff49846e74a3d6e"

  vpc_security_group_ids = ["sg-0ad1240fccb511429"]

  user_data = <<-EOF
  #!/bin/bash
  set -e

  # Configuración inicial
  sudo dnf -y install oracle-epel-release-el8
  sudo dnf -y install java-1.8.0-openjdk wget unzip telnet firewalld net-tools htop tmux mc glibc-all-langpacks dos2unix tar vim cronie aws-cli

  # Configurar idioma y zona horaria
  sudo localectl set-locale es_ES.utf8
  sudo timedatectl set-timezone America/Bogota

  # Configurar SELINUX
  sudo echo "SELINUX=disabled" > /etc/sysconfig/selinux
  sudo setenforce 0

  # Configurar Firewall
  sudo systemctl start firewalld
  sudo systemctl enable firewalld
  sudo firewall-cmd --zone=public --add-port=8080/tcp --permanent
  sudo firewall-cmd --zone=public --add-port=9990/tcp --permanent
  sudo firewall-cmd --reload

  # Crear usuario jboss
  sudo adduser jboss

  # Crear directorios
  mkdir -p /hcis/apps/ /hcis/logs/
  chown -R jboss:jboss /hcis/

  # Descargar archivos de instalación desde S3
  BUCKET_NAME="${aws_s3_bucket.hcis_bucket.bucket}"
  aws s3 cp s3://$BUCKET_NAME/instalacion_standalone_HCIS4.tar.gz /home/jboss/
  aws s3 cp s3://$BUCKET_NAME/hcis.ear /home/jboss/

  # Finalizar instalación
  echo "Instalación base completada"
  EOF

  tags = {
    Name = "hcis-standalone"
  }
}

output "instance_ip" {
  value = aws_instance.hcis_ec2.public_ip
}
