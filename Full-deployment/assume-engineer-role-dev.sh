#!/bin/bash

# Script to assume the Engineer role on AWS and export the credentials
# Created: May 13, 2025

# ANSI color codes for better output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}Assuming Engineer role...${NC}"

# Execute the assume-role command and capture the output as JSON
CREDENTIALS=$(aws sts assume-role \
  --role-arn "arn:aws:iam::924305315126:role/Engineer" \
  --role-session-name Engineer \
  --duration-seconds 43200)

# Check if the command was successful
if [ $? -ne 0 ]; then
  echo -e "${YELLOW}Failed to assume the Engineer role. Check your AWS configuration and permissions.${NC}"
  exit 1
fi

# Extract credentials from the JSON response
export AWS_ACCESS_KEY_ID=$(echo $CREDENTIALS | jq -r '.Credentials.AccessKeyId')
export AWS_SECRET_ACCESS_KEY=$(echo $CREDENTIALS | jq -r '.Credentials.SecretAccessKey')
export AWS_SESSION_TOKEN=$(echo $CREDENTIALS | jq -r '.Credentials.SessionToken')

# Verify if the credentials were set correctly
if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ] || [ -z "$AWS_SESSION_TOKEN" ]; then
  echo -e "${YELLOW}Failed to extract credentials from the response.${NC}"
  exit 1
fi

echo -e "${GREEN}Successfully assumed Engineer role.${NC}"
echo -e "${BLUE}Credentials exported to environment:${NC}"
echo -e "AWS_ACCESS_KEY_ID=${GREEN}set${NC}"
echo -e "AWS_SECRET_ACCESS_KEY=${GREEN}set${NC}"
echo -e "AWS_SESSION_TOKEN=${GREEN}set${NC}"

# Display expiration time (12 hours from now)
EXPIRATION_TIME=$(date -v +12H "+%Y-%m-%d %H:%M:%S")
echo -e "${BLUE}Credentials will expire at approximately:${NC} ${YELLOW}$EXPIRATION_TIME${NC}"

echo -e "\n${BLUE}Verifying identity with assumed role:${NC}"
aws sts get-caller-identity

echo -e "\n${GREEN}=======================================${NC}"
echo -e "${GREEN}Engineer role credentials are now active${NC}"
echo -e "${GREEN}=======================================${NC}"
echo -e "${YELLOW}Note: These credentials will only be active in this terminal session.${NC}"
echo -e "${YELLOW}To use in a new terminal, source this script again:${NC}"
echo -e "${BLUE}source $(pwd)/assume-engineer-role.sh${NC}"
