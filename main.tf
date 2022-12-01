# --------------------
# ----- provider -----
provider "aws" {
    access_key  = "${var.aws_access_key}"
    secret_key  = "${var.aws_secret_key}"
    region      = "${var.region}"
}

# -----------------------------
# ----- S3 Buckets & acls -----
resource "aws_s3_bucket" "upload_bucket" {
    bucket  = "bridgesaws-upload-bucket"
}

resource "aws_s3_bucket" "stripped_bucket" {
    bucket  = "bridgesaws-stripped-bucket"
}

resource "aws_s3_bucket_acl" "upload_acl" {
    bucket  = aws_s3_bucket.upload_bucket.id
    acl     = var.acl_value
}

resource "aws_s3_bucket_acl" "stripped_acl" {
    bucket  = aws_s3_bucket.stripped_bucket.id
    acl     = var.acl_value
}

# ------------------------------------
# ----- S3 Upload Lambda Trigger -----
resource "aws_s3_bucket_notification" "aws-lambda-trigger" {
  bucket = aws_s3_bucket.upload_bucket.id
  lambda_function {
    lambda_function_arn = aws_lambda_function.strip_exif_lambda_func.arn
    events              = ["s3:ObjectCreated:*"]

  }
}

resource "aws_lambda_permission" "test" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.strip_exif_lambda_func.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = "arn:aws:s3:::${aws_s3_bucket.upload_bucket.id}"
}

# ------------------------------------
# ----- lambda function archive -----
data "archive_file" "archive_python" {
type        = "zip"
source_dir  = "strip_exif/"
output_path = "strip_exif.zip"
}

# ------------------------------------------------------
# ----- lambda function IAM role/policy/attachment -----
resource "aws_iam_role" "lambda_role" {
    name                = "Lambda_Function_Role"
    assume_role_policy  = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
        "Action": "sts:AssumeRole",
        "Principal": {
            "Service": "lambda.amazonaws.com"
        },
        "Effect": "Allow",
        "Sid": ""
        }
    ]
}
    EOF
}

resource "aws_iam_policy" "iam_policy_for_lambda" {
    name         = "aws_iam_policy_for_terraform_aws_lambda_role"
    path         = "/"
    description  = "AWS IAM Policy for managing aws lambda role"
    policy       = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
        "Resource": "arn:aws:logs:*:*:*",
        "Effect": "Allow"
        },
        {
            "Action": "*",
        "Resource": [
            "${aws_s3_bucket.upload_bucket.arn}",
            "${aws_s3_bucket.upload_bucket.arn}/*",
            "${aws_s3_bucket.stripped_bucket.arn}",
            "${aws_s3_bucket.stripped_bucket.arn}/*"
        ],
        "Effect": "Allow"
        }
    ]
}
    EOF
}

resource "aws_iam_role_policy_attachment" "attach_iam_policy_to_iam_role" {
    role        = aws_iam_role.lambda_role.name
    policy_arn  = aws_iam_policy.iam_policy_for_lambda.arn
}

# ---------------------------
# ----- lambda function -----
resource "aws_lambda_function" "strip_exif_lambda_func" {
    filename        = "strip_exif.zip"
    function_name   = "Strip_EXIF_Lambda_Function"
    role            = aws_iam_role.lambda_role.arn
    handler         = "strip_exif.lambda_handler"
    runtime         = "python3.8"
    layers          = ["arn:aws:lambda:eu-west-2:770693421928:layer:Klayers-p38-Pillow:5"]
    depends_on      = [aws_iam_role_policy_attachment.attach_iam_policy_to_iam_role]
    timeout         = 30
}