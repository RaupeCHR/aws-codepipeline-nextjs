resource "aws_codestarconnections_connection" "github" {
  name          = "${var.project_name}-github"
  provider_type = "GitHub"
}

resource "random_pet" "bucket_suffix" {
  length = 2
  prefix = var.project_name
}

resource "aws_s3_bucket" "artifact_store" {
  bucket = random_pet.bucket_suffix.id
}

resource "aws_codepipeline" "pipeline" {
  name     = "${var.project_name}-pipeline"
  role_arn = aws_iam_role.pipeline.arn

  artifact_store {
    location = aws_s3_bucket.artifact_store.bucket
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        ConnectionArn    = aws_codestarconnections_connection.github.arn
        FullRepositoryId = "${var.github_owner}/${var.github_repo}"
        BranchName       = var.github_branch
      }
    }
  }


  stage {
    name = "Build"

    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]
      version          = "1"

      configuration = {
        ProjectName = aws_codebuild_project.build_project.name
      }
    }
  }
stage {
    name = "Staging"

    action {
      name             = "DeployToStaging"
      category         = "Deploy"
      owner            = "AWS"
      provider         = "CodeDeploy"
      input_artifacts  = ["build_output"]
      version          = "1"

      configuration = {
        ApplicationName     = aws_codedeploy_app.starter.name
        DeploymentGroupName = aws_codedeploy_deployment_group.starter.deployment_group_name
      }
    }
  }

  stage {
    name = "Approval"
    action {
      name     = "Manual_Approval"
      category = "Approval"
      owner    = "AWS"
      provider = "Manual"
      version  = "1"
    }
  }

  stage {
    name = "Deploy"

    action {
      name            = "Deploy"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "CodeDeploy"
      input_artifacts = ["build_output"]
      version         = "1"

      configuration = {
        ApplicationName     = aws_codedeploy_app.starter.name
        DeploymentGroupName = aws_codedeploy_deployment_group.starter.deployment_group_name
      }
    }
  }
}

resource "aws_iam_role" "pipeline" {
  name = "${var.project_name}-pipeline-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "codepipeline.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "codestar_connections" {
  name = "${var.project_name}-codestar-connections-policy"
  role = aws_iam_role.pipeline.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "codestar-connections:UseConnection",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "s3" {
  name = "${var.project_name}-s3-policy"
  role = aws_iam_role.pipeline.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "s3:PutObject",
      "Resource": "arn:aws:s3:::*/*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:GetObjectVersion",
        "s3:ListBucket"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "codedeploy:*"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "codebuild_access" {
  name = "${var.project_name}-codebuild-policy"
  role = aws_iam_role.pipeline.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "codebuild:*"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_codebuild_project" "build_project" {
  name          = "${var.project_name}-build"
  description   = "My techstarter starter project"
  build_timeout = "5"
  service_role  = aws_iam_role.codebuild.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:7.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = file("${path.module}/../codebuild/buildspec.yml")
  }
}

resource "aws_iam_role" "codebuild" {
  name = "${var.project_name}-codebuild-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "codebuild.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "codebuild" {
  name = "${var.project_name}-codebuild-start"
  role = aws_iam_role.codebuild.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "codebuild:StartBuild",
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": "codebuild:BatchGetBuilds",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "codebuild_logs" {
  name = "${var.project_name}-codebuild-logs"
  role = aws_iam_role.codebuild.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "logs:CreateLogStream",
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": "logs:CreateLogGroup",
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": "logs:PutLogEvents",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "codebuild_s3" {
  name = "CodeBuildS3Policy"
  role = aws_iam_role.codebuild.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:GetObjectVersion",
        "s3:Put*"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_codedeploy_app" "starter" {
  name = var.project_name
}

resource "aws_codedeploy_deployment_group" "starter" {
  app_name              = aws_codedeploy_app.starter.name
  deployment_group_name = var.project_name
  service_role_arn      = aws_iam_role.codedeploy.arn

  autoscaling_groups = [aws_autoscaling_group.example.name]

  deployment_config_name = "CodeDeployDefault.OneAtATime"

  ec2_tag_set {
    ec2_tag_filter {
      key   = "Name"
      type  = "KEY_AND_VALUE"
      value = var.project_name
    }
  }
}

resource "aws_iam_role" "codedeploy" {
  name = "${var.project_name}-codedeploy-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "codedeploy.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "ec2_policy" {
  name = "ec2_policy"
  role = aws_iam_role.codedeploy.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = "ec2:*"
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}

resource "aws_iam_role_policy" "autoscaling" {
  name = "autoscaling-policy"
  role = aws_iam_role.codedeploy.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "autoscaling:CompleteLifecycleAction",
        "autoscaling:RecordLifecycleActionHeartbeat",
        "autoscaling:DescribeAutoScalingGroups",
        "autoscaling:DescribeLifecycleHooks",
        "autoscaling:DeleteLifecycleHook",
        "autoscaling:PutLifecycleHook"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "codedeploy" {
  name   = "s3-policy"
  role   = aws_iam_role.codedeploy.id
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "s3:Get*",
        "s3:List*"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_autoscaling_group" "example" {
  availability_zones = var.availability_zones
  name_prefix        = var.project_name

  launch_configuration = aws_launch_configuration.example.name

  min_size = 1
  max_size = 1
}

resource "aws_security_group" "allow_ssh" {
  name        = "allow_ssh"
  description = "Allow SSH inbound traffic"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

}

data "aws_ami" "latest_ubuntu_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

resource "aws_launch_configuration" "example" {
  name_prefix          = var.project_name
  image_id             = data.aws_ami.latest_ubuntu_linux.id
  instance_type        = var.instance_type
  iam_instance_profile = aws_iam_instance_profile.s3_access_profile.name

  key_name        = var.pem_key
  security_groups = [aws_security_group.allow_ssh.id]
  user_data       = file("user_data.sh")

}

# Create the IAM role
resource "aws_iam_role" "s3_access_role" {
  name = "s3_access_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Principal = {
          Service = "ec2.amazonaws.com"
        },
        Effect = "Allow",
      },
    ]
  })
}


# Attach the S3 access policy to the role
resource "aws_iam_role_policy" "s3_access_policy" {
  name = "s3_access_policy"
  role = aws_iam_role.s3_access_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ],
        Effect   = "Allow",
        Resource = "*"
      },
    ]
  })
}

# Create the instance profile that will be used by the EC2 instances
resource "aws_iam_instance_profile" "s3_access_profile" {
  name = "s3_access_profile"
  role = aws_iam_role.s3_access_role.name
}