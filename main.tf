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
  ami                    = "ami-04921b5223c6ab7f0"
  instance_type          = "t3.xlarge"
  key_name               = "HCIS_DEMO_LATAM_JJC"
  subnet_id              = "subnet-02ff49846e74a3d6e"
  vpc_security_group_ids = ["sg-0ad1240fccb511429"]
  iam_instance_profile   = "hcis-ec2-role"


  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  user_data = <<-EOF
                    #!/bin/bash
                    set -e
                    LOGFILE="/var/log/user_data.log"
                    exec > >(tee -a $LOGFILE) 2>&1

                    echo "***** Iniciando instalación de HCIS Standalone *****"
                    echo "♨️ Instalando oracle-epel-release-el8 💢 "
                    sudo dnf install -y oracle-epel-release-el8 || { echo "❌ Error al instalar oracle-epel-release-el8"; exit 1; }

                    echo "🕹️ Actualizando y paquetes necesarios 🕹️ "
                    sudo dnf -y install java-1.8.0-openjdk wget unzip telnet firewalld net-tools htop tmux mc glibc-all-langpacks dos2unix tar || { echo "❌ Error al instalar paquetes necesarios"; exit 1; }
                    sudo dnf -y update || { echo "❌ Error al actualizar paquetes"; exit 1; }

                    echo "🌎 Configurando Idioma Local 🌎"
                    nohup bash -c "sleep 60 && localectl set-locale es_ES.utf8" >/dev/null 2>&1 &

                    echo "🇨🇴 Configurar Zona Horaria 🇨🇴"
                    nohup bash -c "sleep 60 && timedatectl set-timezone America/Bogota" >/dev/null 2>&1 &

                    echo "Paso 3: Instalando AWS CLI...🔐"
                    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
                    unzip awscliv2.zip
                    sudo ./aws/install || { echo "ERROR: Falló la instalación de AWS CLI"; exit 1; }

                    echo "Instlando Tar"
                    sudo dnf install -y tar || { echo "❌ Error al instalar tar"; exit 1; }

                    echo " Instalando otros paquetes Necesarios desde /tmp"
                    cd /tmp
                    wget https://rpms.remirepo.net/enterprise/remi-release-8.rpm || { echo "❌ Error al descargar remi-release-8.rpm"; exit 1; }
                    sudo rpm -Uvh remi-release-8.rpm || { echo "❌ Error al instalar remi-release-8.rpm"; exit 1; }
                    sudo dnf -y localinstall --nogpgcheck https://download1.rpmfusion.org/free/el/rpmfusion-free-release-8.noarch.rpm || { echo "❌ Error al instalar rpmfusion-free-release-8.noarch.rpm"; exit 1; }
                    sudo dnf -y localinstall --nogpgcheck https://download1.rpmfusion.org/nonfree/el/rpmfusion-nonfree-release-8.noarch.rpm || { echo "❌ Error al instalar rpmfusion-nonfree-release-8.noarch.rpm"; exit 1; }

                    echo "📝 Editar fichero /etc/sysconfig/selinux "
                    sudo sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/sysconfig/selinux || { echo "❌ Error al deshabilitar SELinux"; exit 1; }
                    sudo setenforce 0 || { echo "❌ Error al deshabilitar SELinux"; exit 1; }

                    echo "⚙️Configurar Firewall"
                    sudo systemctl start firewalld || { echo "❌ Error al iniciar firewalld"; exit 1; }
                    sudo systemctl enable firewalld || { echo "❌ Error al habilitar firewalld"; exit 1; }
                    sudo firewall-cmd --zone=public --add-port=8080/tcp --permanent || { echo "❌ Error al abrir puerto 8080"; exit 1; }
                    sudo firewall-cmd --zone=public --add-port=8787/tcp --permanent || { echo "❌ Error al abrir puerto 8787"; exit 1; }
                    sudo firewall-cmd --zone=public --add-port=9990/tcp --permanent || { echo "❌ Error al abrir puerto 9990"; exit 1; }
                    sudo firewall-cmd --zone=public --add-port=9999/tcp --permanent || { echo "❌ Error al abrir puerto 9999"; exit 1; }
                    sudo firewall-cmd --reload || { echo "❌ Error al recargar firewalld"; exit 1; }
                    sudo systemctl stop firewalld || { echo "❌ Error al detener firewalld"; exit 1; }
                    sudo systemctl disable firewalld || { echo "❌ Error al deshabilitar firewalld"; exit 1; }

                    echo " 🚧 Crear archivo de configuración de SO 🚧 "
                    sudo bash -c 'cat << SYSCTL_EOF > /etc/sysctl.d/98-jboss.conf
                    # /etc/sysctl.d/98-jboss.conf
                    #
                    # Network tuning
                    net.core.rmem_default = 260096
                    net.core.wmem_default = 260096
                    net.core.rmem_max = 262143
                    net.core.wmem_max = 262143
                    net.core.netdev_max_backlog = 10000
                    net.core.somaxconn = 4096
                    net.ipv4.tcp_synack_retries = 2
                    net.ipv4.tcp_max_syn_backlog = 8192
                    net.ipv4.tcp_rmem = 4096 87380 8388608
                    net.ipv4.tcp_wmem = 4096 65535 8388608
                    net.ipv4.tcp_mem = 196608 262144 393216
                    net.ipv4.tcp_fin_timeout = 30
                    net.ipv4.tcp_tw_reuse = 1
                    net.ipv4.tcp_keepalive_time = 900
                    net.ipv4.tcp_keepalive_intvl = 60
                    net.ipv4.tcp_keepalive_probes = 12
                    # VM tuning
                    vm.swappiness = 1
                    SYSCTL_EOF'

                    echo "Aplicar configuración de SO 🏆"
                    sudo sysctl -p /etc/sysctl.d/98-jboss.conf || { echo "❌ Error al aplicar configuración de SO"; exit 1; }

                    echo "⚓️ Creación de 99-custom.conf ⚓️"
                    sudo bash -c 'cat << LIMITS_EOF > /etc/security/limits.d/99-custom.conf
                    # /etc/security/limits.d/99-custom.conf
                    #
                    jboss hard nofile 65536
                    jboss soft nofile 16384
                    LIMITS_EOF'
                    echo "Configuración de límites completada.✅"
                    echo "👨🏻 Creando Usuario jboss 👨🏻"
                    sudo useradd jboss || { echo "❌ Error al crear usuario jboss"; exit 1; }

                    echo "======= Configurar .bashrc para el usuario jboss========="
                    sudo bash -c 'cat << BASHRC_EOF >> /home/jboss/.bashrc
                    # ---------------------------------------------------------------------
                    # User specific aliases and functions
                    # ---------------------------------------------------------------------
                    export JAVA_HOME=/usr/lib/jvm/jre-1.8.0
                    export PATH=\$PATH:\$JAVA_HOME/bin
                    export JBOSS_HOME=/hcis/apps/jboss-eap-7.4
                    export PATH=\$PATH:\$JBOSS_HOME/bin
                    export HCIS_LOG=/hcis/logs
                    # ---------------------------------------------------------------------
                    # Personalización shell linux (opcional)
                    # ---------------------------------------------------------------------
                    HISTTIMEFORMAT="+%F %T "
                    #export PS1="\[\e[0;32m[\]\u@\h \w]$ \[\e[m\]"
                    #umask 0022
                    # ---------------------------------------------------------------------
                    # Opción sacada de una instalación pendiente de validar
                    # ---------------------------------------------------------------------
                    #JAVA_OPTIONS="-Djava.security.egd=file:/dev/./urandom -Djava.net.preferIPv4Stack=true"

                    # Some more ls aliases
                    alias ll="ls -alF"
                    alias la="ls -A"
                    alias l="ls -CF"
                    alias vim="vi"
                    BASHRC_EOF'

                    echo "Cambiar permisos para asegurar que jboss tiene acceso..."
                    sudo chown jboss:jboss /home/jboss/.bashrc
                    sudo chmod 644 /home/jboss/.bashrc

                    echo "Configuración de .bashrc para jboss completada.✅"

                    echo "Crear directorios de instalación 🗂️"
                    sudo mkdir -p /hcis/
                    sudo mkdir -p /hcis/apps
                    sudo mkdir -p /hcis/logs

                    echo "Asignar permisos a los directorios 📂 "
                    sudo chown -R jboss:jboss /hcis
                    sudo chmod -R 755 /hcis/

                    echo "Descargar archivos de instalación desde S3 ⬇️ "
                    sudo chown -R ec2-user:ec2-user /home/jboss/
                    sudo chmod -R 755 /home/jboss/
                    BUCKET_NAME="${aws_s3_bucket.hcis_bucket.bucket}"
                    aws s3 cp s3://$BUCKET_NAME/instalacion_standalone_HCIS4.tar.gz /home/jboss/ || echo "ERROR: No se pudo descargar instalacion_standalone_HCIS4.tar.gz" >> /var/log/user_data.log
                    aws s3 cp s3://$BUCKET_NAME/hcis.ear /home/jboss/ || echo "ERROR: No se pudo descargar hcis.ear" >> /var/log/user_data.log

                    sudo chown jboss:jboss /home/jboss/instalacion_standalone_HCIS4.tar.gz
                    sudo chown jboss:jboss /home/jboss/hcis.ear

                    echo "***** Descomprimir archivos de instalación ⏳ *****"
                    sudo tar -xvzf /home/jboss/instalacion_standalone_HCIS4.tar.gz -C /home/jboss/ || { echo "❌ Error al descomprimir instalacion_standalone_HCIS4.tar.gz"; exit 1; }

                    echo "****** Mover el .EAR a instalacion_standalone_HCIS4/ear/ y cambiar permisos ****"
                    sudo mv /home/jboss/hcis.ear /home/jboss/instalacion_standalone_HCIS4/ear/ || { echo "❌ Error al mover hcis.ear"; exit 1; }
                    sudo chmod -R 775 /home/jboss/instalacion_standalone_HCIS4/ || { echo "❌ Error al cambiar permisos"; exit 1; }

                    echo "==== LLevar paquete jboss-eap-7.4 a /hcis/apps/ y descomprimir ====="
                    cd /hcis/apps/ && sudo cp /home/jboss/instalacion_standalone_HCIS4/jboss/jboss-eap-7.4.0.zip . || { echo "❌ Error al copiar jboss-eap-7.4.0.zip"; exit 1; }
                    sudo unzip jboss-eap-7.4.0.zip || { echo "❌ Error al descomprimir jboss-eap-7.4.0.zip"; exit 1; }
                    sudo chown -R jboss:jboss /hcis/
                    sudo chmod -R 775 /hcis/

                    echo "Variables de entorno 🖥️"
                    export JBOSS_HOME="/hcis/apps/jboss-eap-7.4"
                    export INSTALL_DIR="/home/jboss/instalacion_standalone_HCIS4"
                    export PATCH_FILE="$INSTALL_DIR/jboss/jboss-eap-7.4.2-patch.zip"

                    cd $JBOSS_HOME/ && sudo cp /home/jboss/instalacion_standalone_HCIS4/scripts/scripts_standalone_hcis4.tar.gz .
                    sudo tar -xvf scripts_standalone_hcis4.tar.gz
                    sudo rm -rf $JBOSS_HOME/scripts_standalone_hcis4.tar.gz
                    sudo chmod -R 750 $JBOSS_HOME/standalone/scripts/

                    echo "Configurar jboss-cli 🚀 "
                    sudo chmod 770 /hcis/logs
                    sudo -u jboss nohup /hcis/apps/jboss-eap-7.4/bin/standalone.sh > /hcis/logs/jboss.log 2>&1 &
                    sleep 60



            EOF
  user_data_replace_on_change = true

  tags = {
    Name = "hcis-standalone"
  }
}

output "instance_ip" {
  value = aws_instance.hcis_ec2.public_ip
}
