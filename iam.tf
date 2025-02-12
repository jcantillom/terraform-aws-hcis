data "aws_iam_instance_profile" "hcis_ec2_profile" {
  name = var.existing_iam_role
}
