resource "aws_s3_bucket" "hcis_bucket" {
  bucket = "${var.bucket_name}-${random_id.bucket_suffix.hex}"
}

resource "aws_s3_bucket_ownership_controls" "hcis_bucket_ownership" {
  bucket = aws_s3_bucket.hcis_bucket.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

resource "aws_s3_object" "hcis_tar" {
  bucket = aws_s3_bucket.hcis_bucket.bucket
  key    = "instalacion_standalone_HCIS4.tar.gz"
  source = "instalacion_standalone_HCIS4.tar.gz"
}

resource "aws_s3_object" "hcis_ear" {
  bucket = aws_s3_bucket.hcis_bucket.bucket
  key    = "hcis.ear"
  source = "hcis.ear"
}
