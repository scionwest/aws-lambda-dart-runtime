$FUNCTION_NAME='dart-runtime-x64'
$IAM_ROLE_LAMBDA_POLICY='arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole'
$IAM_ROLE_TRUSTED_POLICY='iam-trusted-policy.json'
$FUNCTION_HANDLER='hello.method'

$DOCKER_IMAGE_NAME='dart-lambda-builder-x64'
$DOCKERFILE_NAME='dockerfile'
$DART_IMAGE='dart'

function Get-ContainerId {
    return $(docker ps --all --filter ancestor=${DOCKER_IMAGE_NAME} --latest --format '{{.ID}}')
}

function Get-Function {
    return $(aws lambda get-function --function-name ${FUNCTION_NAME} --query 'Configuration.FunctionName')
}

# Get the last container created for our Image and remove it.
$CONTAINER_ID=Get-ContainerId

if ([string]::IsNullOrEmpty(${CONTAINER_ID})) {
    Write-Output "No existing Docker containers to clean up."
} else {
    Write-Output "Cleaning up Docker."
    docker stop ${CONTAINER_ID} | Out-Null
    docker rm ${CONTAINER_ID} | Out-Null
    Write-Output "Docker cleaned."
}

Write-Output "Building Docker Image..."
docker build . -t ${DOCKER_IMAGE_NAME} -f ${DOCKERFILE_NAME} --build-arg ${DART_IMAGE}
Write-Output "Running Docker Container..."
docker run -d ${DOCKER_IMAGE_NAME}

Write-Output "Fetching build output..."
if ((Test-Path .\bootstrap)) {
    Remove-Item .\bootstrap
}

$CONTAINER_ID=$(docker ps --all --filter ancestor=${DOCKER_IMAGE_NAME} --latest --format '{{.ID}}')
docker cp ${CONTAINER_ID}:.\bootstrap .\bootstrap

Write-Output "Packaging for deployment..."
if ((Test-Path .\lambda.zip)) {
    Remove-Item .\lambda.zip
}

Compress-Archive -Path .\bootstrap .\lambda.zip

Write-Output "Determining Lambda Status..."
$DEPLOYED_LAMBDA=Get-Function

if ([string]::IsNullOrEmpty(${DEPLOYED_LAMBDA})) {
    Write-Output "Lambda doesn't exist - processing a fresh deployment."
    Write-Output "Creating Lambda IAM Role..."
    
    aws iam create-role `
        --role-name ${FUNCTION_NAME}-role `
        --assume-role-policy-document file://${IAM_ROLE_TRUSTED_POLICY} `
        --no-cli-pager

    aws iam attach-role-policy `
        --role-name ${FUNCTION_NAME}-role `
        --policy-arn ${IAM_ROLE_LAMBDA_POLICY} `
        --no-cli-pager

    $DEPLOYED_IAM_ROLE_NAME=$(aws iam get-role --role-name ${FUNCTION_NAME}-role --query "Role.Arn")

    # Clean up the variable value so it doesn't contain qoutes.
    $DEPLOYED_IAM_ROLE_NAME = ${DEPLOYED_IAM_ROLE_NAME}.replace('"','')
    Write-Output "Role created: ${DEPLOYED_IAM_ROLE_NAME}"

    Write-Output "Deploying new ${FUNCTION_NAME} function..."
    aws lambda create-function `
        --function-name ${FUNCTION_NAME} `
        --handler ${FUNCTION_HANDLER} `
        --zip-file fileb://.\lambda.zip `
        --runtime provided.al2 `
        --architecture x86_64 `
        --environment Variables="{DART_BACKTRACE=1}" `
        --tracing-config Mode=Active `
        --role ${DEPLOYED_IAM_ROLE_NAME} `
        --no-cli-pager
} else {
    Write-Output "Deploying updated function..."
    aws lambda update-function-code `
        --function-name ${FUNCTION_NAME} `
        --zip-file fileb://.\lambda.zip `
        --no-cli-pager
}

Write-Output "Cleaning up artifacts..."
Remove-Item .\lambda.zip
Remove-Item .\bootstrap
Write-Output "Done."