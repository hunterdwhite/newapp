# Lambda Environment Variables for Amazon SES

## Required Environment Variables

Add these to your Lambda function configuration:

### In AWS Lambda Console:
1. Go to your Lambda function
2. **Configuration** → **Environment variables**
3. **Edit** and add these variables:

```bash
AWS_SES_REGION=us-east-1
EMAIL_USER=dissonant.helpdesk@gmail.com
```

### If using Serverless Framework (serverless.yml):
```yaml
provider:
  environment:
    AWS_SES_REGION: us-east-1
    EMAIL_USER: dissonant.helpdesk@gmail.com
```

### If using AWS CLI:
```bash
aws lambda update-function-configuration \
  --function-name your-lambda-function-name \
  --environment Variables='{
    "AWS_SES_REGION":"us-east-1",
    "EMAIL_USER":"dissonant.helpdesk@gmail.com"
  }'
```

## Important Notes:

1. **AWS_SES_REGION**: Must match the region where you verified your email
2. **EMAIL_USER**: Must be the exact email you verified in SES
3. **No AWS credentials needed**: Lambda automatically uses its execution role for SES access

## Next Steps:
1. Add these environment variables to Lambda
2. Deploy the updated function
3. Test with `/test-email` endpoint

