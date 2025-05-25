# provider "aws" {
#   profile = var.profile_name        # Replace with your actual AWS CLI profile_name
#   region  = var.aws_region        # Replace with your target AWS region
# }


resource "aws_iam_role" "arc_for_server_ssm_role" {
  name               = var.ArcForServerEC2SSMRoleName
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })

  description = "Azure Arc for servers to access SSM services role"

  tags  = var.tags
}

resource "aws_iam_role_policy_attachment" "ssm_core_attach" {
  role       = aws_iam_role.arc_for_server_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "arc_for_server_ssm_instance_profile" {
  name = var.ArcForServerSSMInstanceProfileName
  role = aws_iam_role.arc_for_server_ssm_role.name
  path = "/"
}

resource "aws_iam_openid_connect_provider" "microsoft_oidc" {
  client_id_list  = var.client_id_list
  thumbprint_list = var.oidc_thumbprint
  url             = var.oidc_url

  tags = var.tags
}

resource "aws_iam_role" "arc_for_server_role" {
  name = "ArcForServer"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Federated = aws_iam_openid_connect_provider.microsoft_oidc.arn
        },
        Action = "sts:AssumeRoleWithWebIdentity",
        Condition = {
          StringEquals = {
            "sts:RoleSessionName" = "ConnectorPrimaryIdentifier_${var.connector_primary_identifier}",
            "${replace(var.oidc_url, "https://", "")}:aud" = var.oidc_audience,
            "${replace(var.oidc_url, "https://", "")}:sub" = var.oidc_subject
          }
        }
      }
    ]
  })

  description = "Azure Arc for servers role"
  tags        = var.tags
}


resource "aws_iam_role_policy" "arc_for_server_policy" {
  name = "ArcForServer"
  role = aws_iam_role.arc_for_server_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid = "RunInstallationCommands",
        Effect = "Allow",
        Action = "ssm:SendCommand",
        Resource = [
          "arn:aws:ssm:*::document/AWS-RunPowerShellScript",
          "arn:aws:ssm:*::document/AWS-RunShellScript",
          "arn:aws:ec2:*:${data.aws_caller_identity.current.account_id}:instance/*"
        ]
      },
      {
        Sid = "CheckInstallationCommandStatus",
        Effect = "Allow",
        Action = [
          "ssm:CancelCommand",
          "ssm:DescribeInstanceInformation",
          "ssm:GetCommandInvocation"
        ],
        Resource = "*"
      },
      {
        Sid = "GetEC2Information",
        Effect = "Allow",
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeImages"
        ],
        Resource = "*"
      },
      {
        Sid = "ListStackInstancesInformation",
        Effect = "Allow",
        Action = "cloudformation:ListStackInstances",
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role" "lambda_exec_role" {
  name = "EC2SSMIAMRoleAutoAssignmentFunctionRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  description = "Lambda function to assign SSM role to EC2 instances"
  tags  = var.tags
}

resource "aws_iam_role_policy" "lambda_exec_policy" {
  name = "LambdaExecutionPolicy"
  role = aws_iam_role.lambda_exec_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeRegions",
          "ec2:DescribeIamInstanceProfileAssociations",
          "ec2:AssociateIamInstanceProfile",
          "ec2:DisassociateIamInstanceProfile",
          "iam:GetInstanceProfile",
          "iam:ListAttachedRolePolicies",
          "iam:AttachRolePolicy",
          "iam:PassRole",
          "iam:AddRoleToInstanceProfile",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "ssm:GetServiceSetting"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = "lambda:DeleteFunction",
        Resource = "arn:aws:lambda:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:function:EC2SSMIAMRoleAutoAssignmentFunction"
      }
    ]
  })
}

resource "aws_cloudwatch_event_rule" "lambda_schedule" {
  name                = "EC2SSMIAMRoleAutoAssignmentFunctionScheduler"
  description         = "Triggers Lambda based on schedule interval."
  schedule_expression = "rate(${var.EC2SSMIAMRoleAutoAssignmentScheduleInterval})"
  state               = var.EC2SSMIAMRoleAutoAssignment == "true" && var.EC2SSMIAMRoleAutoAssignmentSchedule == "Enable" ? "ENABLED" : "DISABLED"
}


resource "aws_cloudwatch_event_target" "lambda_target" {
  rule      = aws_cloudwatch_event_rule.lambda_schedule.name
  target_id = "EC2SSMIAMRoleAutoAssignmentFunctionScheduler"
  arn       = aws_lambda_function.ec2_ssm_auto_assign.arn

  input = jsonencode({
    ArcForServerSSMInstanceProfileName = var.ArcForServerSSMInstanceProfileName,
    ArcForServerEC2SSMRoleName         = var.ArcForServerEC2SSMRoleName,
    EC2SSMIAMRolePolicyUpdateAllowed   = var.EC2SSMIAMRolePolicyUpdateAllowed
  })
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ec2_ssm_auto_assign.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.lambda_schedule.arn
}

resource "aws_lambda_code_signing_config" "lambda_signing_config" {
  description          = "Code signing config for Lambda function"
  allowed_publishers {
    signing_profile_version_arns = [
      aws_signer_signing_profile.lambda_signing.arn
    ]
  }
}


# Step 1: Upload lambda.zip to the S3 bucket
resource "aws_s3_object" "lambda_zip" {
  bucket       = var.lambda_code_bucket
  key          = "signed/lambda.zip"
  source       = "${path.module}/lambda.zip"
  etag         = filemd5("${path.module}/lambda.zip")
  content_type = "application/zip"
}

# Step 3: Create AWS Signer Profile (code signing config)
resource "aws_signer_signing_profile" "lambda_signing" {
  name           = "LambdaSigningProfile9"
  platform_id    = "AWSLambda-SHA384-ECDSA" # Recommended AWS Lambda platform
  signature_validity_period {
    type  = "DAYS"
    value = 365
  }
}

# Step 4: Lambda function using S3 object and code signing config
resource "aws_lambda_function" "ec2_ssm_auto_assign" {
  function_name = "EC2SSMIAMRoleAutoAssignmentFunction"
  role          = aws_iam_role.lambda_exec_role.arn
  handler       = "index.lambda_handler"
  runtime       = "python3.12"
  timeout       = 900

  s3_bucket = aws_s3_object.lambda_zip.bucket
  s3_key    = aws_s3_object.lambda_zip.key

  code_signing_config_arn = aws_lambda_code_signing_config.lambda_signing_config.arn

  tags = var.tags
}
