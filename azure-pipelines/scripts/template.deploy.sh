#!/bin/bash

environment="__ENVIRONMENT__"
source_version="__SOURCE_VERSION__"
cloud_name="__CLOUD_NAME__"
subscription_id="__SUBSCRIPTION_ID__"
tenant_id="__TENANT_ID__"
layers="__LAYERS__"
deployments="__DEPLOYMENTS__"

usage() {
    _information "Usage: deploy.sh -c <client_id> \n\t-s <client_secret>\n" 1>&2
    exit 1
}

# Initialize parameters specified from command line
while getopts "c:s:" arg; do
    case "${arg}" in
    c)
        client_id="${OPTARG}"
        ;;
    s)
        client_secret="${OPTARG}"
        ;;
    esac
done
shift $((OPTIND - 1))

check_input() {
    _information "Validating Inputs..."
    if [ -z "${client_id}" ] || [ -z "${client_secret}" ]; then
        _error "Required parameters not set."
        usage
        return 1
    fi
}

_error() {
    printf "\e[31mERROR: $@\n\e[0m"
}

_information() {
    printf "\e[36m$@\n\e[0m"
}

_success() {
    printf "\e[32m$@\n\e[0m"
}

setupenv() {
    environment=$1

    set -o allexport && . ${environment}.compiled.env && set +o allexport
}

azlogin() {
    subscription_id=$1
    tenant_id=$2
    client_id=$3
    client_secret=$4
    cloud_name=$5

    # AzureCloud AzureChinaCloud AzureUSGovernment AzureGermanCloud
    az cloud set --name ${cloud_name}
    az login --service-principal --username ${client_id} --password ${client_secret} --tenant ${tenant_id}
    az account set --subscription ${subscription_id}

    export ARM_CLIENT_ID="${client_id}"
    export ARM_CLIENT_SECRET="${client_secret}"
    export ARM_SUBSCRIPTION_ID="${subscription_id}"
    export ARM_TENANT_ID="${tenant_id}"

    #https://www.terraform.io/docs/providers/azurerm/index.html#environment
    # environment - (Optional) The Cloud Environment which should be used. 
    # Possible values are public, usgovernment, german, and china. Defaults to public. 
    # This can also be sourced from the ARM_ENVIRONMENT environment variable.

    if [ "${cloud_name}" == 'AzureCloud' ]; then
        export ARM_ENVIRONMENT="public"
    elif [ "${cloud_name}" == 'AzureUSGovernment' ]; then
        export ARM_ENVIRONMENT="usgovernment"
    elif [ "${cloud_name}" == 'AzureChinaCloud' ]; then 
        export ARM_ENVIRONMENT="usgovernment" 
    elif [ "${cloud_name}" == 'AzureGermanCloud' ]; then
        export ARM_ENVIRONMENT="german" 
    else
        _error "Unknown cloud. Check documentation https://www.terraform.io/docs/providers/azurerm/index.html#environment"
        return 1
    fi
}

tfinit() {
    backend_config=$1
    key=$2
    subscription_id=$3
    tenant_id=$4
    client_id=$5
    client_secret=$6
    storage_account_name=${TF_VAR_BACKEND_STORAGE_ACCOUNT_NAME}
    container_name=${TF_VAR_BACKEND_CONTAINER_NAME}
    resource_group_name=${TF_VAR_BACKEND_RESOURCE_GROUP_NAME}

    if [ "${backend_config}" == "false" ]; then
        terraform init
    else
        terraform init \
            -backend-config=storage_account_name=${storage_account_name} \
            -backend-config=container_name=${container_name} \
            -backend-config=key=${key} \
            -backend-config=resource_group_name=${resource_group_name} \
            -backend-config=subscription_id=${subscription_id} \
            -backend-config=tenant_id=${tenant_id} \
            -backend-config=client_id=${client_id} \
            -backend-config=client_secret=${client_secret} \
            -reconfigure
    fi
}

tfplan() {
    terraform plan -input=false -out=terraform.tfplan
}

tfapply() {
    terraform apply -input=false -auto-approve terraform.tfplan
}

inttest() {
    cd "test/terraform"

    IFS=' ' read -r -a layers <<<$1
    for layer in "${layers[@]}"; do
        IFS='_' read -r -a _layer <<<"${layer}"

        count=$(find . -maxdepth 1 -type f -name "${_layer[0]}*" | wc -l)

        if [ ${count} -gt 0 ]; then
            go build *.go
            if [ -z "${_layer[0]}" ]; then
                go test -v .
            else
                go test -v -tags ${_layer[0]} .
            fi
        fi
    done

    cd ../../
}

deploy(){
    IFS=' ' read -r -a deployments <<<$1
    for deployment in "${deployments[@]}"; do
        cd "terraform/${deployment}"
        tfinit "true" ${deployment} ${subscription_id} ${tenant_id} ${client_id} ${client_secret}
        tfplan
        tfapply
        cd ../../../
    done
}

check_input
setupenv "${environment}"
azlogin "${subscription_id}" "${tenant_id}" "${client_id}" "${client_secret}" "${cloud_name}"
deploy "${deployments}"
inttest "${layers}"
