FUNCTION_NAME='dart-runtime-test'
IAM_ROLE_LAMBDA_POLICY='arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole'
IAM_ROLE_TRUSTED_POLICY='iam-trusted-policy.json'
FUNCTION_HANDLER='hello.method'
DOCKER_IMAGE_NAME='dart-lambda-builder'

# Cleaning up Docker container
CONTAINER_ID=$(docker ps -all --filter ancestor=${DOCKER_IMAGE_NAME} --latest --format '{{.ID}}')

if [ -z $CONTAINER_ID ]
then
    echo "No existing Docker containers to clean up."
else
    echo "Cleaning up Docker"
    docker stop $CONTAINER_ID
    docker rm $CONTAINER_ID
    echo "Docker cleaned."
fi

echo "Building Docker Image..."
docker build . -t ${DOCKER_IMAGE_NAME} -f ./dockerfile
echo "Running Docker Container..."
docker run -d ${DOCKER_IMAGE_NAME}

echo "Fetching build output..."
rm bootstrap
CONTAINER_ID="$(docker ps -all --filter ancestor=${DOCKER_IMAGE_NAME} --format '{{.ID}}')"
docker cp $CONTAINER_ID:bootstrap ./bootstrap

echo "Packaging for deployment..."
rm lambda.zip
zip lambda.zip bootstrap

echo "Determing Lambda Status..."
DEPLOYED_LAMBDA="$(aws lambda get-function --function-name $FUNCTION_NAME --query 'Configuration.FunctionName')"

if [ -z $DEPLOYED_LAMBDA ]
then
    echo "Lambda doesn't exist - processing a fresh deployment..."
    echo "Creating Lambda IAM Role"
    aws iam create-role \
        --role-name ${FUNCTION_NAME}-role \
        --assume-role-policy-document file://${IAM_ROLE_TRUSTED_POLICY} \
        --no-cli-pager
    aws iam attach-role-policy \
        --role-name ${FUNCTION_NAME}-role \
        --policy-arn ${IAM_ROLE_LAMBDA_POLICY} \
        --no-cli-pager

    DEPLOYED_IAM_ROLE_NAME=$(aws iam get-role --role-name ${FUNCTION_NAME}-role --query 'Role.Arn')
    
    # Clean up the variable value so it doesn't contain quotes.
    DEPLOYED_IAM_ROLE_NAME="${DEPLOYED_IAM_ROLE_NAME%\"}"
    DEPLOYED_IAM_ROLE_NAME="${DEPLOYED_IAM_ROLE_NAME#\"}"
    echo Role created: ${DEPLOYED_IAM_ROLE_NAME}
    
    echo "Deploying new ${FUNCTION_NAME} function..."
    # We need to provide the IAM Role time to establish the Trust relationship policy when just attached.
    # Deploying the Lambda function to quickly afterwards can sometimes fail due to the IAM Role not meeting
    # the required Lambda Trust policy.
    sleep 10
    aws lambda create-function \
        --function-name $FUNCTION_NAME \
        --handler $FUNCTION_HANDLER \
        --zip-file fileb://./lambda.zip \
        --runtime provided.al2 \
        --architecture arm64 \
        --environment Variables={DART_BACKTRACE=1} \
        --tracing-config Mode=Active \
        --role ${DEPLOYED_IAM_ROLE_NAME} \
        --no-cli-pager
else
    echo "Deploying updated function..."
    aws lambda update-function-code \
        --function-name $FUNCTION_NAME \
        --zip-file fileb://./lambda.zip \
        --no-cli-pager
fi

echo 'Cleaning up artifacts...'
rm ./lambda.zip
rm ./bootstrap
echo Done.