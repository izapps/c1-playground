#!/bin/bash

# Exports
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
export AWS_REGION=$(aws configure get region)
export AWS_ECR=$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

function clean_ecr_repository() {
  aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ECR
  if [[ $(aws ecr describe-repositories) =~ :repository/c1-jenkins ]]; then
    aws ecr batch-delete-image --region $AWS_REGION
    --image-ids "$(aws ecr list-images --region $AWS_REGION --repository-name c1-jenkins --query 'imageIds[*]' --output json
)" || true
  else
    echo "c1-jenkins repository already deleted"
  fi
}

function delete_ecr_repository() {
  aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ECR
  if [[ $(aws ecr describe-repositories) =~ :repository/c1-jenkins ]]; then
    aws ecr delete-repository \
    --repository-name c1-jenkins \
    --region $AWS_REGION
  else
    echo "c1-jenkins repository already deleted"
  fi
}

aws ecr batch-delete-image \
     --repository-name my-repo \
     --image-ids imageTag=tag1 imageTag=tag2

kubectl delete service c1-jenkins -n jenkins
kubectl delete deploy c1-jenkins -n jenkins
kubectl delete pvc jenkins-pvc -n jenkins
kubectl delete namespace jenkins
clean_ecr_repository
delete_ecr_repository
