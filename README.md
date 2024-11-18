# tam_workbench_creator

gcloud functions update diagram-to-tf-gcs \
    --region=asia-northeast1 \
    --service-account=sa-mizuki-demo-joonix@mizuki-demo-joonix.iam.gserviceaccount.com

# Automated Terraform Code Generation and GitHub Push using Vertex AI and Cloud Functions

This project demonstrates a system that automatically generates Terraform code from an image and pushes it to a GitHub repository using Vertex AI's image generation model and Cloud Functions.

## System Overview

1.  A user uploads an image to a Cloud Storage bucket.
2.  A Cloud Storage trigger activates a Cloud Function.
3.  The Cloud Function uses Vertex AI's image generation model to generate Terraform code from the uploaded image.
4.  The generated Terraform code is pushed to a GitHub repository.
5.  Auto terraform plan/apply by cloudbuilds

## How to Use

1.  Create a Cloud Storage bucket and configure a trigger for the function.
2.  Deploy the Cloud Function.
3.  Create a GitHub repository and obtain a personal access token (PAT).
4.  Set the `GITHUB_TOKEN` environment variable in your Cloud Function to your GitHub PAT.
5.  Upload an image to the Cloud Storage bucket.
6.  Auto terraform plan/apply by cloudbuilds

## Notes

*   This system uses Vertex AI's image generation model to generate Terraform code. As a result, the generated code may not be perfect and might require some adjustments.
*   The generated Terraform code is pushed to a GitHub repository. It is recommended to review the code before merging any pull requests.