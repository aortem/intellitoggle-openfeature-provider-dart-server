#!/bin/bash

set -e # Exit immediately if any command fails

echo "Navigating to Nuxt frontend directory"
cd intellitoggle/frontend

echo "Listing files in the directory"
ls -la

echo "Cleaning up previous artifacts"
rm -rf node_modules dist .nuxt .output dist

# Installing dependencies
echo "Installing Yarn globally"
npm install -g yarn
yarn --version

echo "Installing dependencies"
yarn install

# Run Build
yarn generate

echo "Listing generated files"
ls -la

echo "Current project: $(gcloud config get-value project)"

gcloud auth activate-service-account $ACCOUNT_PROD --key-file $GOOGLE_CLOUD_CREDENTIALS_PROD

echo "Setting account to: $ACCOUNT_PROD"
gcloud config set account $ACCOUNT_PROD

echo "Authenticated accounts:"
gcloud auth list

gcloud config set project intellitoggle-prod

# Verify the configuration
echo "Active account: $(gcloud config get-value account)"
echo "Active project: $(gcloud config get-value project)"

echo "Current directory: $(pwd)"
ls -la

# Navigate back to the output folder for nuxt
echo "Navigating to Nuxt Output directory for Firebase deployment"

cd .output/public

#echo "Current directory: $(pwd)"
ls -la

gcloud auth activate-service-account --key-file=$GOOGLE_APPLICATION_CREDENTIALS

gcloud config set project intellitoggle-prod

echo "Installing Firebase CLI globally"
npm install -g firebase-tools

echo "Listing available Firebase projects"
firebase projects:list

# Add the desired Firebase project to the local configuration
echo "Adding Firebase project to local configuration"
firebase use --add intellitoggle-prod || echo "Project already configured"
