provider "aws" {
  region = "ap-south-1"
}

resource "aws_s3_bucket" "tf_state" {
  bucket = "my-ecs-tf-state-bucket-12344321"
}

resource "aws_s3_bucket_versioning" "tf_state_versioning" {
  bucket = aws_s3_bucket.tf_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

output "bucket_name" {
  value = aws_s3_bucket.tf_state.bucket
}
