# Introduction

Dart is a programming language developed by Google initially for Android development. Over time, the language has grown to have larger applications such as desktop, web and server side.

AWS provides serverless technologies via their Lambda service. While there are only a handful of supported languages natively with Lambda, custom runtimes can be uploaded. 

This repository provides the framework for creating a custom Dart runtime that can be deployed into an AWS Lambda. The Dart code assumes it is receiving an API Gateway event and returns an API Gateway response.

# Building

> This repository has only been tested on a M1 Macbook Air.

When you specify a custom runtime, Amazon deploys the Lambda using their Amazon Linux 2 OS. This is a modified version of the Alpine OS. Amazon Linux 2 can run both x64 and Arm64 architectures.

At the time of this repository being created, the Dart SDK did not support cross-platform compilation for their AOT compiler. You must compile the source on the target OS that you'll be deploying to. Since we're deploying onto Linux for Lambda, compiling AOT on a Mac or Windows won't produce a binary that can execute within the Lambda execution environment.

To solve for this, this repository provides a Dockerfile that creates a Linux image to compile the dart API Gateway source into a native Linux binary. This repository includes a bash script (`deploy.sh`) that performs the following steps: 

- Build the Arm64 Linux Docker image
- Use the image to create a Container
- Run the container to compile the Dart source
- Copies the compiled binary to the local file system
- Packages binary for deploying to Lambda
- Creates AWS IAM Role needed to execute the Lambda
- Attaches the Basic Lambda Execution policy
- Deploys the AWS Lambda

You can run the same `deploy.sh` script a 2nd time to re-compile changes to the `api.dart` source code and have those changes re-deployed into AWS. Each time the script is created, the Docker image is rebuilt and a new Container is started. The previous Container is removed. If the script ever failed during the cleanup then you could end up with orphaned Containers that will need to be manually cleaned up. Only the latest container created is auto-removed.

**NOTE**: In some instances the IAM Role doesn't get the Trust Policy attached quickly enough on the AWS end. This causes the initial Lambda creation to fail. You can run the `deploy.sh` script a 2nd time and it will complete the deployment. Running the script anytime after the successful function deployment will run the updates without issue.

