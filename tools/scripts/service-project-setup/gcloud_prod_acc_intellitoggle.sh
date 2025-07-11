#!/bin/bash

echo "Current project: $(gcloud config get-value project)"

gcloud auth activate-service-account $ACCOUNT_PROD --key-file $GOOGLE_CLOUD_CREDENTIALS_PROD

echo "Setting account to: $ACCOUNT_PROD"
gcloud config set account $ACCOUNT_PROD

echo "Authenticated accounts:"
gcloud auth list

# gcloud projects describe dartcloud functions-prod

gcloud config set project intellitoggle-prod

# Verify the configuration
echo "Active account: $(gcloud config get-value account)"
echo "Active project: $(gcloud config get-value project)"
