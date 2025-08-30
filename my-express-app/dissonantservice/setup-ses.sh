#!/bin/bash
# Amazon SES Setup Script
# Run this after setting up AWS CLI with appropriate permissions

echo "Setting up Amazon SES for Lambda function..."

# Set variables
REGION="us-east-1"
EMAIL="dissonant.helpdesk@gmail.com"
IAM_USER="ses-lambda-user"
POLICY_NAME="SESLambdaPolicy"

echo "1. Verifying email identity in SES..."
aws ses verify-email-identity --email-address $EMAIL --region $REGION

echo "2. Creating IAM policy for SES..."
cat > ses-policy.json << EOF
{
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
}
EOF

aws iam create-policy --policy-name $POLICY_NAME --policy-document file://ses-policy.json

echo "3. Creating IAM user..."
aws iam create-user --user-name $IAM_USER

echo "4. Attaching policy to user..."
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
aws iam attach-user-policy --user-name $IAM_USER --policy-arn arn:aws:iam::${ACCOUNT_ID}:policy/$POLICY_NAME

echo "5. Creating access keys..."
aws iam create-access-key --user-name $IAM_USER

echo "Setup complete! Next steps:"
echo "1. Check your email ($EMAIL) for verification link"
echo "2. Add the access keys to your Lambda environment variables:"
echo "   - AWS_SES_REGION=$REGION"
echo "   - AWS_ACCESS_KEY_ID=<from step 5>"
echo "   - AWS_SECRET_ACCESS_KEY=<from step 5>"
echo "3. Deploy your Lambda function"
echo "4. Test with /test-email endpoint"

# Clean up
rm ses-policy.json
