$FUNCTION_NAME='dart-runtime-x64'
$IAM_ROLE_LAMBDA_POLICY='arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole'
$IAM_ROLE_TRUSTED_POLICY='iam-trusted-policy.json'
$FUNCTION_HANDLER='hello.method'

$DOCKER_IMAGE_NAME='dart-lambda-builder-x64'
$DOCKERFILE_NAME='windows-x64-dockerfile'

function Get-ContainerId {
    return $(docker ps --all --filter ancestor=$DOCKER_IMAGE_NAME --latest --format '{{.ID}}')
}

function Get-Function {
    return $(aws lambda get-function --function-name $FUNCTION_NAME --query 'Configuration.FunctionName')
}

function Get-Deployed-IAM-Role {
    return $(aws iam get-role --role-name $FUNCTION_NAME-role --query 'Role.Arn')
}

# Get the last container created for our Image and remove it.
$CONTAINER_ID=Get-ContainerId

if ([string]::IsNullOrEmpty($CONTAINER_ID)) {
    Write-Output "No existing Docker containers to clean up."
} else {
    Write-Output "Cleaning up Docker."
    docker stop $CONTAINER_ID | Out-Null
    docker rm $CONTAINER_ID | Out-Null
    Write-Output "Docker cleaned."
}

Write-Output "Building Docker Image..."
docker build . -t $DOCKER_IMAGE_NAME -f $DOCKERFILE_NAME  | Out-Null
Write-Output "Running Docker Container..."
docker run -d $DOCKER_IMAGE_NAME  | Out-Null

Write-Output "Fetching build output..."
if ((Test-Path .\bootstrap)) {
    Remove-Item .\bootstrap
}

$CONTAINER_ID=Get-ContainerId
docker cp $CONTAINER_ID:bootstrap .\bootstrap

Write-Output "Packaging for deployment..."
if ((Test-Path .\lambda.zip)) {
    Remove-Item .\lambda.zip
}

Compress-Archive -Path .\bootstrap .\lambda.zip

Write-Output "Determining Lambda Status..."
$DEPLOYED_LAMBDA=Get-Function

if ([string]::IsNullOrEmpty($DEPLOYED_LAMBDA)) {
    Write-Output "Lambda doesn't exist - processing a fresh deployment."
    Write-Output "Creating Lambda IAM Role..."
    
    aws iam create-role `
        --role-name $FUNCTION_NAME-role `
        --assume-role-policy-document file://$IAM_ROLE_TRUSTED_POLICY `
        --no-cli-pager

    aws iam attach-role-policy `
        --role-name $FUNCTION_NAME-role `
        --policy-arn $IAM_ROLE_LAMBDA_POLICY `
        --no-cli-pager

    $DEPLOYED_IAM_ROLE_NAME=Get-Deployed-IAM-Role

    # Clean up the variable value so it doesn't contain qoutes.
    $DEPLOYED_IAM_ROLE_NAME = $DEPLOYED_IAM_ROLE_NAME.replace('"','')
    Write-Output $DEPLOYED_IAM_ROLE_NAME
}