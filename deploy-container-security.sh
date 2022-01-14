#!/bin/bash

set -e

# source helpers
. ./playground-helpers.sh

# get config
CLUSTER_NAME="$(jq -r '.cluster_name' config.json)"
CS_POLICY_NAME="$(jq -r '.services[] | select(.name=="container_security") | .policy_name' config.json)"
CS_NAMESPACE="$(jq -r '.services[] | select(.name=="container_security") | .namespace' config.json)"
SC_NAMESPACE="$(jq -r '.services[] | select(.name=="smartcheck") | .namespace' config.json)"
API_KEY="$(jq -r '.services[] | select(.name=="cloudone") | .api_key' config.json)"
REGION="$(jq -r '.services[] | select(.name=="cloudone") | .region' config.json)"

DEPLOY_RT_YAML=false
DEPLOY_RT_JSON=false
if [[ $(kubectl config current-context) =~ gke_.*|aks-.*|.*eksctl.io ]]; then
  DEPLOY_RT_YAML=true
  DEPLOY_RT_JSON=true
fi

# create header
API_KEY=${API_KEY} envsubst <templates/cloudone-header.txt >overrides/cloudone-header.txt

function create_namespace {

  # create namespace
  printf '%s' "Create container security namespace"
  NAMESPACE=${CS_NAMESPACE} envsubst <templates/namespace.yaml | kubectl apply -f - -o yaml > /dev/null
  printf '%s\n' " 🍼"
}

function whitelist_namsspaces {

  # whitelist some namespace for container security
  printf '%s\n' "whitelist namespaces"
  kubectl label namespace kube-system --overwrite ignoreAdmissionControl=true
}

function cluster_policy {

  # query cluster policy
  printf '%s\n' "query cluster policy id"
  CS_POLICYID=$(
    curl --silent --location --request GET 'https://container.'${REGION}'.cloudone.trendmicro.com/api/policies' \
    --header @overrides/cloudone-header.txt |
    jq -r --arg CS_POLICY_NAME "${CS_POLICY_NAME}" '.policies[] | select(.name==$CS_POLICY_NAME) | .id'
  )

  # create policy if not exist
  if [ "${CS_POLICYID}" == "" ]; then
    printf '%s\n' "getting registry address"
    get_registry_name
    printf '%s\n' "registry is on ${REGISTRY}"
    printf '%s\n' "creating policy ${CS_POLICY_NAME}"

    RESULT=$(
      CS_POLICY_NAME=${CS_POLICY_NAME} \
      REGISTRY=${REGISTRY} \
      envsubst <templates/container-security-policy.json | \
        curl --silent --location --request POST 'https://container.'${REGION}'.cloudone.trendmicro.com/api/policies' \
        --header @overrides/cloudone-header.txt \
        --data-binary "@-"
    )
    CS_POLICYID=$(echo ${RESULT} | jq -r ".id")
    printf '%s\n' "policy with id ${CS_POLICYID} created"
  else
    printf '%s\n' "reusing cluster policy with id ${CS_POLICYID}"
  fi
}

function create_cluster_object {

  # create cluster object
  printf '%s\n' "create cluster object"
  RESULT=$(
    CLUSTER_NAME=${CLUSTER_NAME//-/_} \
    CS_POLICYID=${CS_POLICYID} \
    DEPLOY_RT_JSON=${DEPLOY_RT_JSON} \
    envsubst <templates/container-security-cluster-object.json |
      curl --silent --location --request POST 'https://container.'${REGION}'.cloudone.trendmicro.com/api/clusters' \
      --header @overrides/cloudone-header.txt \
      --data-binary "@-"
  )
  API_KEY_ADMISSION_CONTROLLER=$(echo ${RESULT} | jq -r ".apiKey")
  CS_CLUSTERID=$(echo ${RESULT} | jq -r ".id")
  AP_KEY=$(echo ${RESULT} | jq -r ".runtimeKey")
  AP_SECRET=$(echo ${RESULT} | jq -r ".runtimeSecret")
}

function deploy_container_security {

  ## deploy container security
  printf '%s\n' "deploy container security"
  API_KEY_ADMISSION_CONTROLLER=${API_KEY_ADMISSION_CONTROLLER} \
  DEPLOY_RT_YAML=${DEPLOY_RT_YAML} \
    envsubst <templates/overrides-container-security.yaml >overrides/overrides-container-security.yaml

  helm upgrade \
    container-security \
    --values overrides/overrides-container-security.yaml \
    --namespace ${CS_NAMESPACE} \
    --install \
    https://github.com/trendmicro/cloudone-container-security-helm/archive/master.tar.gz

  # if [[ $(kubectl config current-context) =~ gke_.*|aks-.*|.*eksctl.io ]]; then
  #   echo Running on GKE, AKS or EKS
  #   helm upgrade \
  #     container-security \
  #     --values overrides/overrides-container-security.yaml \
  #     --namespace ${CS_NAMESPACE} \
  #     --install \
  #     https://github.com/trendmicro/cloudone-container-security-helm/archive/master.tar.gz
  # else
  #   # echo Not running on GKE, AKS or EKS
  #   helm template \
  #     container-security \
  #     --values overrides/overrides-container-security.yaml \
  #     --namespace ${CS_NAMESPACE} \
  #     https://github.com/trendmicro/cloudone-container-security-helm/archive/master.tar.gz | \
  #       sed -e '/\s*\-\sname:\ FALCO_BPF_PROBE/,/\s*value:/d' | \
  #       kubectl --namespace ${CS_NAMESPACE} apply -f -
  # fi
}

function create_scanner {

  # create scanner
  printf '%s\n' "create scanner object"
  RESULT=$(
    CLUSTER_NAME=${CLUSTER_NAME//-/_} \
    envsubst <templates/container-security-scanner.json |
      curl --silent --location --request POST 'https://container.'${REGION}'.cloudone.trendmicro.com/api/scanners' \
      --header @overrides/cloudone-header.txt \
      --data-binary "@-"
  )

  # bind smartcheck to container security
  printf '%s\n' "bind smartcheck to container security"
  API_KEY_SCANNER=$(echo ${RESULT} | jq -r ".apiKey") \
  REGION=${REGION} \
    envsubst <templates/overrides-image-security-bind.yaml >overrides/overrides-image-security-bind.yaml

  helm upgrade \
    smartcheck \
    --reuse-values \
    --values overrides/overrides-image-security-bind.yaml \
    --namespace ${SC_NAMESPACE} \
    https://github.com/deep-security/smartcheck-helm/archive/master.tar.gz >/dev/null
}

create_namespace
whitelist_namsspaces
cluster_policy
create_cluster_object
deploy_container_security
kubectl -n smartcheck get service proxy && create_scanner || echo Smartcheck not found
