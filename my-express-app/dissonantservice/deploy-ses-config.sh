#!/bin/bash
# Automated SES Configuration and Deployment Script

set -e

PROFILE="utenatenjou25"
FUNCTION_NAME="dissonantservice-dev-api"
REGION="us-east-1"
EMAIL="dissonant.helpdesk@gmail.com"

echo "🚀 Starting automated SES configuration for Lambda function..."
echo "Function: $FUNCTION_NAME"
echo "Profile: $PROFILE"
echo "Region: $REGION"
echo "Email: $EMAIL"
echo ""

# Step 1: Get Lambda function info
echo "📋 Step 1: Getting Lambda function information..."
LAMBDA_ROLE=$(aws lambda get-function --function-name $FUNCTION_NAME --profile $PROFILE --query "Configuration.Role" --output text)
ROLE_NAME=$(echo $LAMBDA_ROLE | cut -d'/' -f2)
echo "Lambda Role: $ROLE_NAME"
echo ""

# Step 2: Create SES policy
echo "📋 Step 2: Creating SES IAM policy..."
POLICY_DOCUMENT='{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ses:SendEmail",
                "ses:SendRawEmail",
                "ses:GetSendQuota",
                "ses:GetSendStatistics"
            ],
            "Resource": "*"
        }
    ]
}'

ACCOUNT_ID=$(aws sts get-caller-identity --profile $PROFILE --query Account --output text)
POLICY_ARN="arn:aws:iam::${ACCOUNT_ID}:policy/SESEmailPolicy"

# Create policy (ignore error if exists)
aws iam create-policy --policy-name SESEmailPolicy --policy-document "$POLICY_DOCUMENT" --profile $PROFILE 2>/dev/null || echo "Policy already exists"

# Step 3: Attach policy to Lambda role
echo "📋 Step 3: Attaching SES policy to Lambda role..."
aws iam attach-role-policy --role-name $ROLE_NAME --policy-arn $POLICY_ARN --profile $PROFILE 2>/dev/null || echo "Policy already attached"
echo ""

# Step 4: Update Lambda environment variables
echo "📋 Step 4: Updating Lambda environment variables..."
aws lambda update-function-configuration \
  --function-name $FUNCTION_NAME \
  --environment Variables='{
    "AWS_SES_REGION":"'$REGION'",
    "EMAIL_USER":"'$EMAIL'",
    "SHIPPO_TOKEN":"'$SHIPPO_TOKEN'",
    "STRIPE_SECRET_KEY":"'$STRIPE_SECRET_KEY'",
    "FIREBASE_PROJECT_ID":"'$FIREBASE_PROJECT_ID'"
  }' \
  --profile $PROFILE
echo ""

# Step 5: Package and deploy Lambda function
echo "📋 Step 5: Packaging and deploying Lambda function..."
cd "$(dirname "$0")"

# Create deployment package
echo "Creating deployment package..."
zip -r function.zip . -x "*.sh" "*.md" "*.json" "node_modules/.cache/*" "*.git*" "test-*.js"

# Update Lambda function code
echo "Updating Lambda function code..."
aws lambda update-function-code \
  --function-name $FUNCTION_NAME \
  --zip-file fileb://function.zip \
  --profile $PROFILE

# Clean up
rm function.zip

echo ""
echo "✅ SES configuration and deployment completed!"
echo ""
echo "📋 Next steps:"
echo "1. Test the configuration with:"
echo "   curl -X POST https://your-lambda-url/test-email"
echo "2. Monitor CloudWatch logs for SES success messages"
echo "3. Check your email inbox for test email delivery"
echo ""

# Step 6: Test configuration
echo "📋 Step 6: Getting function URL for testing..."
FUNCTION_URL=$(aws lambda get-function-url-config --function-name $FUNCTION_NAME --profile $PROFILE --query "FunctionUrl" --output text 2>/dev/null || echo "No function URL configured")

if [ "$FUNCTION_URL" != "No function URL configured" ]; then
    echo "Function URL: $FUNCTION_URL"
    echo ""
    echo "Test with:"
    echo "curl -X POST ${FUNCTION_URL}test-email -H 'Content-Type: application/json' -d '{\"test_email\":\"$EMAIL\"}'"
else
    echo "⚠️  No function URL found. You may need to configure API Gateway or Function URL"
fi

echo ""
echo "🎉 Configuration complete! Your Lambda function should now use Amazon SES for email delivery."
