resource "aws_instance" "hcis_ec2" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name               = var.key_name
  subnet_id              = var.subnet_id
  vpc_security_group_ids = var.security_group_ids
  iam_instance_profile   = data.aws_iam_instance_profile.hcis_ec2_profile.name
  associate_public_ip_address = true


  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  user_data = templatefile("${path.module}/user_data.sh", {
    BUCKET_NAME = aws_s3_bucket.hcis_bucket.bucket
  })

  tags = {
    Name = "hcis-standalone"
  }
}
