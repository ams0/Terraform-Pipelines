#!/bin/bash

set -euo pipefail

# Includes
source lib/http.sh
source lib/shell_logger.sh

usage() {
    local jqStatusMessage
    if [ -x "$(command -v jq)" ]; then
        jqStatusMessage="(installed - you're good to go!)"
    else
        jqStatusMessage="\e[31m(not installed)\e[0m"
    fi    
    local sedStatusMessage
    if [ -x "$(command -v sed)" ]; then
        sedStatusMessage="(installed - you're good to go!)"
    else
        sedStatusMessage="\e[31m(not installed)\e[0m"
    fi    

    _helpText="
        Usage: install.sh
        -o | --org <AZDO_ORG_NAME> (User if provisioning to Azure DevOps Service)
        -l | --server <Azure DevOps Server and Collection> (Ex. server/collectionName)
            Must specify the server and collection name
            Must also use -u parameter to specify the user 
        -u | --user specifies the user to use with PAT on Azure DevOps server
        -n | --name <AZDO_PROJECT_NAME>
        -p | --pat <AZDO_PAT>
        -r | --region <REGION>
        -i | --installInternal (Optional: set if attempting to install internal version of CredScan) 
        -c | --cloudName (Optional cloud name if service connection is for other cloud 'az cloud list')
           | --subName '<Azure Subscription Name>' (Optional - if included, can be ommitted from -s.)
                        ** Note: if the subscription name has spaces, you must use this input parameter. ** 
           | --metaDataHost The Hostname of the Azure Metadata Service (for example management.azure.com), used to obtain the Cloud Environment when using a Custom Azure Environment.                
           | --private This flag indicates that the deployment target is an Azure Private Cloud.
           | --useExistingEnvs This flag indicates that you will use existing env files and it skips generating dev and prod env files and the environments folder.           
        -s | --servicePrincipal <SP_INFORMATION>
                Expected Format:
                SUB_NAME='<Azure Subscription Name>' SP_ID=<Service Principal ID> SP_SUBSCRIPTION_ID=<Azure Subscription ID> SP_SECRET=<Service Principal Secret> SP_TENANT_ID=<Service Principal Tenant ID>
                ** Note: if the subscription name has spaces, you must use the --subName parameter. ** 
        --offline (Optional) Enable project creation without importing source from public repos. This will set up the project with files from this repo and the associated Terraform-Code Repo.
                ** Note: For offline to function correctly, it's expected that the Terraform-Code repo sits alongside this (Terraform-Pipelines) repo.
        --sourceLocalPath (Optional) Root folder of Terraform-Code and Terraform-Pipelines repos. Default ~/tfsource.
                ** Note: Works only with --offline
        -d | --debug Turn debug logging on
         
         dependencies:
         -jq $jqStatusMessage
         -sed $sedStatusMessage
         "
                
    _information "$_helpText" 1>&2
    exit 1
}


#Script Parameters (Required)
declare AZDO_ORG_NAME=''
declare AZDO_PROJECT_NAME=''
declare AZURE_CLOUD_ENVIRONMENT='AzureCloud'
declare MANAGEMENT_URI=''
declare AZDO_PAT=''
declare AZDO_USER='AzureUser'
declare SP_RAW=''
declare SP_SUBSCRIPTION_NAME=''
declare SP_ID=''
declare SP_SUBSCRIPTION_ID=''
declare SP_SECRET=''
declare SP_TENANT_ID=''
declare REGION=''
declare INSTALL_INTERNAL_CREDSCAN=false
declare INSTALL_TYPE='PAAS'
declare DEBUG_FLAG=false
declare OFFLINE_INSTALL=false
declare USE_EXISTING_ENVS=false
declare SOURCE_LOCAL_PATH=''
# Defaults AZDO
declare AZDO_ORG_URI=''
declare AZDO_EXT_MGMT_URI=''
declare AZDO_PROJECT_PROCESS_TEMPLATE='Agile'
declare AZDO_PROJECT_SOURCE_CONTROL='git'
declare AZDO_PROJECT_VISIBILITY='private'
declare AZDO_SC_AZURERM_NAME='sc-azurerm-sp'

declare TEMPLATE_REPO_BASE='https://csedevops@dev.azure.com/csedevops/terraform-template-public'
declare PIPELINE_REPO_NAME='Terraform-Pipelines'
declare CODE_REPO_NAME='Terraform-Code'
declare TEMPLATE_PIPELINE_REPO=''
declare TEMPLATE_CODE_REPO=''
declare CODE_REPO_ID=''
declare PIPELINE_REPO_ID=''

# Locals
declare SEARCH_STRING="csedevops@"
declare REPO_GIT_HTTP_URL=''
declare PIPELINE_REPO_GIT_HTTP_URL=''
declare CODE_REPO_GIT_HTTP_URL=''
declare PR_SEED=
declare DEV_SEED=
declare PROD_SEED=
#declare ENVIRONMENT='dev'
declare AZDO_PROJECT_ID=
declare ARM_METADATA_HOST=
declare PRIVATE_CLOUD=false
declare AZURE_ENVIRONMENT_FILEPATH=

# Initialize parameters specified from command line
while [[ "$#" -gt 0 ]]
do
  case $1 in
    -h | --help)
        usage
        exit 0
        ;;
    -o | --org )                 
        # PAAS Azure DevOps
        AZDO_ORG_NAME=$2
        AZDO_ORG_URI="https://dev.azure.com/$2"
        AZDO_EXT_MGMT_URI="https://extmgmt.dev.azure.com/$2"
        INSTALL_TYPE='PAAS'                             
        ;;
    -l | --server )
        # Azure DevOps Server
        AZDO_ORG_NAME=$2
        AZDO_ORG_URI="https://$2"
        AZDO_EXT_MGMT_URI="https://$2"
        INSTALL_TYPE='SERVER'        
        ;;  
    -n | --name )
        AZDO_PROJECT_NAME=$2
        ;;
    -u | --user )
        AZDO_USER=$2
        ;;
    -p | --pat )
        AZDO_PAT=$2
        ;;
    -r | --region )            
        REGION=$2
        ;;
    -c | --cloudName )         
        AZURE_CLOUD_ENVIRONMENT=$2
        ;;
    --subName )                
        SP_SUBSCRIPTION_NAME=$2
        ;;
    --metaDataHost )                
        ARM_METADATA_HOST=$2
        ;;        
    --private)
        PRIVATE_CLOUD=true
        ;;
    --useExistingEnvs)
        USE_EXISTING_ENVS=true
        ;;        
    -s | --servicePrincipal )   
        SP_RAW=$2
        ;;
    -i | --installInternal )    
        INSTALL_INTERNAL_CREDSCAN=true
        ;;         
    -t | --templateRepo )
        TEMPLATE_REPO_BASE=$2
        ;;    
    --offline )
        OFFLINE_INSTALL=true
        ;;
    --sourceLocalPath )
        SOURCE_LOCAL_PATH=$2
        ;;  
    -d | --debug )             
        DEBUG_FLAG=true
        ;; 
  esac
  shift
done

check_input() {
    _information "Validating Inputs..."
    echo $AZDO_ORG_NAME
    echo $AZDO_PROJECT_NAME
    echo $AZDO_PAT
    echo $REGION
    echo $SP_RAW

    #TODO add check for server and check for PAAS
    if [ -z "$AZDO_ORG_NAME" ] || [ -z "$AZDO_PROJECT_NAME" ] || [ -z "$AZDO_PAT" ] || [ -z "$REGION" ] || [ -z "$SP_RAW" ]; then
        _error "Required parameter not set."
        usage
        return 1
    fi

    TEMPLATE_PIPELINE_REPO="${TEMPLATE_REPO_BASE}/_git/${PIPELINE_REPO_NAME}"
    TEMPLATE_CODE_REPO="${TEMPLATE_REPO_BASE}/_git/${CODE_REPO_NAME}"   

    echo "ARM_METADATA_HOST: ${ARM_METADATA_HOST}"

    if [ ! -x "$(command -v jq)" ]; then
        _error "jq is not installed! jq is a dependency needed to run the install script.
Please ensure all requirements from the project installation document are met:
https://dev.azure.com/csedevops/terraform-template-public/_git/Terraform-Pipelines?path=%2Fdocs%2FPROJECT_INSTALLATION.md&_a=preview&anchor=pre-requisites
"
        exit 1
    fi   

    if [ ! -x "$(command -v az)" ]; then
        _error "az cli is not installed! az cli is a dependency needed to run the install script.
Please ensure all requirements from the project installation document are met:
https://dev.azure.com/csedevops/terraform-template-public/_git/Terraform-Pipelines?path=%2Fdocs%2FPROJECT_INSTALLATION.md&_a=preview&anchor=pre-requisites
"
        exit 1
    fi       
}

parse_sp() {
    # Expected Format "SUB_NAME='<Azure Subscription Name>' SP_ID=<Service Principal ID> SP_SUBSCRIPTION_ID=<Azure Subscription ID> SP_SECRET=<Service Principal Secret> SP_TENANT_ID=<Service Principal Tenant ID>"
    # NOTE: format is with quotes ""

    _information "Parsing Service Principal credentials..."
    BFS=$IFS
    IFS=' '
    read -ra kv_pairs <<<${1}
    IFS=$BFS

    len=${#kv_pairs[@]}
    expectedLength=5
    if [ ! -z "$SP_SUBSCRIPTION_NAME" ]; then
      expectedLength=4 
    fi

    if [ $len != $expectedLength ]; then
        _error "SP_RAW contains invalid # of parameters"
        _error "Expected Format SUB_NAME='<Azure Subscription Name>' SP_ID=<Service Principal ID> SP_SUBSCRIPTION_ID=<Azure Subscription ID> SP_SECRET=<Service Principal Secret> SP_TENANT_ID=<Service Principal Tenant ID>"
        usage
        return 1
    fi

    for kv in "${kv_pairs[@]}"; do

        BFS=$IFS
        IFS='='
        read -ra arr <<<"$kv"
        IFS=$BFS

        k=${arr[0]}
        v=${arr[1]}

        case "$k" in
        "SUB_NAME") SP_SUBSCRIPTION_NAME=$v ;;
        "SP_ID") SP_ID=$v ;;
        "SP_SUBSCRIPTION_ID") SP_SUBSCRIPTION_ID=$v ;;
        "SP_SECRET") SP_SECRET=$v ;;
        "SP_TENANT_ID") SP_TENANT_ID=$v ;;
        *)
            _error "Invalid service principal parameter."
            return 1
            ;;
        esac
    done

    _success "Sucessfully parsed service principal credentials..."
}



set_login_pat(){
    export AZURE_DEVOPS_EXT_PAT=${AZDO_PAT}
}

create_project(){
    _information "Starting project creation for project ${AZDO_PROJECT_NAME}"

    # Refactor
    # 1. GET Get all processes to get template id
    # AzDo Service     : Processes - Get https://docs.microsoft.com/rest/api/azure/devops/core/processes/get?view=azure-devops-rest-5.1
    # AzDo Server 2019 : Processes - Get https://docs.microsoft.com/rest/api/azure/devops/core/processes/get?view=azure-devops-server-rest-5.0
    # GET https://{instance}/{collection}/_apis/process/processes/{processId}?api-version=5.0
    _uri=$(_set_api_version "${AZDO_ORG_URI}/_apis/process/processes?api-version=" '5.1' '5.1')
    
    _debug "Requesting process templates"

    _response=$(request_get "${_uri}")
    echo $_response > ./temp/pt.json
    
    if [[ "$_response" == *"Access Denied: The Personal Access Token used has expired"* ]]; then
      _error "Authentication Error Personal Access Token used has expired!"
      exit 1      
    fi
    
    if [[ "$_response" == *"Azure DevOps Services | Sign In"* ]]; then
      _error "Authentication Error Requesting process templates. Please ensure the PAT is valid."
      exit 1      
    fi

    if [ -z "$_response" ]; then
        _error "Error Requesting process templates. Please ensure the PAT is valid and has not expired."
        exit 1
    fi
    _processTemplateId=$(cat ./temp/pt.json | jq -r '.value[] | select(.name == "'"${AZDO_PROJECT_PROCESS_TEMPLATE}"'") | .id')

    # 2. Create Project
    # AzDo Service     : Projects - Create https://docs.microsoft.com/rest/api/azure/devops/core/projects/create?view=azure-devops-rest-5.1
    # AzDo Server 2019 : Projects - Create https://docs.microsoft.com/rest/api/azure/devops/core/projects/create?view=azure-devops-server-rest-5.0
    # POST https://{{coreServer}}/{{organization}}/_apis/projects?api-version={{api-version}}
    _payload=$(cat "payloads/template.project-create.json" | sed 's~__AZDO_PROJECT_NAME__~'"${AZDO_PROJECT_NAME}"'~' | sed 's~__AZDO_PROJECT_SOURCE_CONTROL__~'"${AZDO_PROJECT_SOURCE_CONTROL}"'~' | sed 's~__AZDO_PROCESS_TEMPLATE_ID__~'"${_processTemplateId}"'~')
    _uri=$(_set_api_version "${AZDO_ORG_URI}/_apis/projects?api-version=" '5.1' '5.1')

    _debug "Creating project"
    # 2. POST Create project
    _response=$( request_post \
                   "${_uri}" \
                   "${_payload}" 
               )
    echo $_response > ./temp/cp.json    
    local _createProjectTypeKey=$(echo $_response | jq -r '.typeKey')
    if [ "$_createProjectTypeKey" = "ProjectAlreadyExistsException" ]; then
        _error "Error creating project in org '${AZDO_ORG_URI}. \nProject repo '${AZDO_PROJECT_NAME}' already exists."
        exit 1
    fi
    
    _debug_log_post "$_uri" "$_response" "$_payload"

    #When going through rest apis, there is a timing issue from project create to querying the repo properties.
    sleep 10s

    # Fetch The list of projects to get this project's id
    # https://docs.microsoft.com/rest/api/azure/devops/core/Projects/List?view=azure-devops-server-rest-5.0
    # GET https://{instance}/{collection}/_apis/projects?api-version=5.0
    _uri="${AZDO_ORG_URI}/_apis/projects?api-version=5.0"
    _response=$(request_get $_uri)
    echo $_response > './temp/get-project-id.json'
    AZDO_PROJECT_ID=$(cat './temp/get-project-id.json' | jq -r '.value[] | select (.name == "'"${AZDO_PROJECT_NAME}"'") | .id')
    
    # 3. Create Repos
    #https://docs.microsoft.com/rest/api/azure/devops/git/repositories/create?view=azure-devops-rest-5.1
    _information "Creating ${PIPELINE_REPO_NAME} Repository"
    _uri=$(_set_api_version "${AZDO_ORG_URI}/${AZDO_PROJECT_NAME}/_apis/git/repositories/${AZDO_PROJECT_NAME}?api-version=" '5.1' '5.1')
    _payload=$(cat "payloads/template.repo-create.json" | sed 's~__AZDO_PROJECT_ID__~'"${AZDO_PROJECT_ID}"'~' | sed 's~__REPO_NAME__~'"${PIPELINE_REPO_NAME}"'~' )
    _response=$(request_post "${_uri}" "${_payload}") 
    echo _response > "./temp/$PIPELINE_REPO_NAME-create-response.json"

    _information "Creating ${CODE_REPO_NAME} Repository"
    _uri=$(_set_api_version "${AZDO_ORG_URI}/${AZDO_PROJECT_NAME}/_apis/git/repositories/${AZDO_PROJECT_NAME}?api-version=" '5.1' '5.1')
    _payload=$(cat "payloads/template.repo-create.json" | sed 's~__AZDO_PROJECT_ID__~'"${AZDO_PROJECT_ID}"'~' | sed 's~__REPO_NAME__~'"${CODE_REPO_NAME}"'~' )
    _response=$(request_post "${_uri}" "${_payload}") 
    echo _response > "./temp/$CODE_REPO_NAME-create-response.json"    

    # 4. GET Repos Git Url and Repo Id's
    # AzDo Service     : Repositories - Get Repository https://docs.microsoft.com/rest/api/azure/devops/git/repositories/get%20repository?view=azure-devops-rest-5.1
    # AzDo Server 2019 : Repositories - Get Repository https://docs.microsoft.com/rest/api/azure/devops/git/repositories/get%20repository?view=azure-devops-server-rest-5.0
    # GET https://dev.azure.com/{organization}/{project}/_apis/git/repositories/{repositoryId}?api-version=5.1
    _uri=$(_set_api_version "${AZDO_ORG_URI}/${AZDO_PROJECT_NAME}/_apis/git/repositories/${PIPELINE_REPO_NAME}?api-version=" '5.1' '5.1')
    _debug "Fetching ${PIPELINE_REPO_NAME} repository information"
    
    _response=$( request_get ${_uri}) 
    _debug_log_get "$_uri" "$_response"
    
    echo $_response > "./temp/${PIPELINE_REPO_NAME}-ri.json"
    PIPELINE_REPO_GIT_HTTP_URL=$(cat "./temp/${PIPELINE_REPO_NAME}-ri.json" | jq -c -r '.remoteUrl')
    PIPELINE_REPO_ID=$(cat "./temp/${PIPELINE_REPO_NAME}-ri.json" | jq -c -r '.id')
    _debug "$PIPELINE_REPO_GIT_HTTP_URL"

    echo "${PIPELINE_REPO_NAME} Git Repo remote URL: "$PIPELINE_REPO_GIT_HTTP_URL

    _uri=$(_set_api_version "${AZDO_ORG_URI}/${AZDO_PROJECT_NAME}/_apis/git/repositories/${CODE_REPO_NAME}?api-version=" '5.1' '5.1')
    _debug "Fetching ${CODE_REPO_NAME} repository information"
    _response=$( request_get ${_uri}) 
    _debug_log_get "$_uri" "$_response"

    echo $_response > "./temp/${CODE_REPO_NAME}-ri.json"
    CODE_REPO_GIT_HTTP_URL=$(cat "./temp/${CODE_REPO_NAME}-ri.json" | jq -c -r '.remoteUrl')
    CODE_REPO_ID=$(cat "./temp/${CODE_REPO_NAME}-ri.json" | jq -c -r '.id')
    _debug "$CODE_REPO_GIT_HTTP_URL"
    echo "${CODE_REPO_NAME} Git Repo remote URL: "$CODE_REPO_GIT_HTTP_URL

    _information "Project '${AZDO_PROJECT_NAME}' created."
}

import_multi_template_repo(){
    templateRepoName=$1
    if [ -z "$templateRepoName" ]; then
        _error "Missing Template Repo Name from import"
        exit 1
    fi

    templateRepoUrl=$2
    if [ -z "$templateRepoUrl" ]; then
        _error "Missing Template Repo Url from import"
        exit 1
    fi

    _information "Starting Import of template repo (URL: ${templateRepoName})"

    # AzDo Service     : Import Requests - Create https://docs.microsoft.com/rest/api/azure/devops/git/import%20requests/create?view=azure-devops-rest-5.1
    # AzDo Server 2019 : Import Requests - Create https://docs.microsoft.com/rest/api/azure/devops/git/import%20requests/create?view=azure-devops-server-rest-5.0
    # POST https://dev.azure.com/{organization}/{project}/_apis/git/repositories/{repositoryId}/importRequests?api-version=5.1-preview.1

    _payload=$(cat "payloads/template.import-repo.json" | sed 's~__GIT_SOURCE_URL__~'"${templateRepoUrl}"'~')
    _importTemplateUri="${AZDO_ORG_URI}/${AZDO_PROJECT_NAME}/_apis/git/repositories/${templateRepoName}/importRequests?api-version=5.1-preview.1"

    _debug "Import POST Request"
    _debug "payload: "
    _debug_json "${_payload}"

    _response=$( request_post \
                   "${_importTemplateUri}" \
                   "${_payload}"
               )
    
    _debug_log_post "$_importTemplateUri" "$_response" "$_payload"
    
    echo $_response > "./temp/$templateRepoName.impreqrepo.json"
    _importRequestId=$(cat "./temp/$templateRepoName.impreqrepo.json" | jq -r '.importRequestId')

    if [ "$_importRequestId" != "null" ]; then
        echo "Import in progress - Import Request Id:${_importRequestId}"
        
        sleep 5

        # AzDo Service     : Import Requests - Get https://docs.microsoft.com/rest/api/azure/devops/git/import%20requests/get?view=azure-devops-rest-5.1
        # AzDo Server 2019 : Import Requests - Get https://docs.microsoft.com/rest/api/azure/devops/git/import%20requests/get?view=azure-devops-server-rest-5.0
        # GET https://dev.azure.com/{organization}/{project}/_apis/git/repositories/{repositoryId}/importRequests/{importRequestId}?api-version=5.1-preview.1

        _debug "Checking import status"
        _response=$(request_get "${_importTemplateUri}")

        _debug_log_get "$_importTemplateUri" "$_response"

        _importRequestStatus=$(echo $_response | jq -r .value[].status)

        _debug "$_importRequestStatus"

        if [ "$_importRequestStatus" = "completed" ]; then
            _success "Import Complete from source '${TEMPLATE_REPO_BASE}' into project repo '${AZDO_PROJECT_NAME}'"
        fi
    else
        # Failed to Submit Import Request
        _importTypeKey=$(echo $_response | jq -r '.typeKey')
        if [ "$_importTypeKey" = "GitImportForbiddenOnNonEmptyRepository" ]; then
            _error "Error importing from source '${TEMPLATE_REPO_BASE}'. \nProject repo '${AZDO_PROJECT_NAME}' is not Empty."
        elif [ "$_importTypeKey" = "GitRepositoryNotFoundException" ]; then
            _error "importing from source '${TEMPLATE_REPO_BASE}'. \nProject repo '${AZDO_PROJECT_NAME}' was not found."
        fi
    fi
}

_getProjectRootPath(){
    scriptPath=$(realpath  "$0")
    relativePath="tools/install/install.sh"
    echo ${scriptPath%/$relativePath}
}

offline_install_template_repo(){
    templateRepoName=$1
    if [ -z "$templateRepoName" ]; then
        _error "Missing Template Repo Name from offline Install"
        exit 1
    fi

    templateRepoUrl=$2
    if [ -z "$templateRepoUrl" ]; then
        _error "Missing Template Repo Url from offline Install"
        exit 1
    fi

    sourcePath=$3
    if [ -z "$sourcePath" ]; then
        _error "Missing sourcePath from offline Install"
        exit 1
    fi    
 
    _information "Starting offline set up of template repo (URL: ${templateRepoName})"

    _debug "** offline_install_template_repo **"
    _debug "templateRepoName: $templateRepoName"
    _debug "templateRepoUrl: $templateRepoUrl"
    _debug "sourcePath: $sourcePath"
    _debug "** /offline_install_template_repo **"

    pushd $sourcePath
        local _token=$(echo -n ":${AZDO_PAT}" | base64)
        local tarFlags="-zxf"
        local gitVerbosity="-q"
        if [ "${DEBUG_FLAG}" == true ]; then
            tarFlags="-zxvf"
            gitVerbosity="-v"
        fi  
        
        git config user.email "installer@terraform-template.com"
        git config user.name "Terraform template"  
        git remote set-url origin ${templateRepoUrl} 
        git -c http.extraHeader="Authorization: Basic ${_token}" push -u origin --all  ${gitVerbosity}  
    popd
}

_gen_random_seed(){
    PR_SEED=$(head -30 /dev/urandom  | LC_CTYPE=c tr -dc 'a-z0-9' | fold -w $1 | head -n 1)
    DEV_SEED=$(head -30 /dev/urandom  | LC_CTYPE=c tr -dc 'a-z0-9' | fold -w $1 | head -n 1)
    PROD_SEED=$(head -30 /dev/urandom  | LC_CTYPE=c tr -dc 'a-z0-9' | fold -w $1 | head -n 1)
    echo "PR SEED CREATED: "$PR_SEED
    echo "DEV SEED CREATED: "$DEV_SEED
    echo "PRD SEED CREATED: "$PROD_SEED
}

clone_repo() {
    local temp_dir=$1
    local repoGitHttpUrl=$2

    mkdir -p $temp_dir

    if [ $INSTALL_TYPE == 'PAAS ' ]; then
        SEARCH_STRING="${AZDO_ORG_NAME}@"
        echo "Searching for ${SEARCH_STRING} and replacing with ${AZDO_PAT}"
        SED_SEARCH_REPLACE="s|${SEARCH_STRING}|${AZDO_PAT}@|"
        _debug "$SED_SEARCH_REPLACE"
        GIT_REPO_URL=$(echo $repoGitHttpUrl | sed $SED_SEARCH_REPLACE | sed s/\"//g)
        
        #Clone the repo (GIT_CURL_VERBOSE=1 GIT_TRACE=1 if debugging is needed)
        git clone $repoGitHttpUrl $TEMP_DIR
    else
        _debug "Cloning repo from server"
        _debug "Git URL: ${repoGitHttpUrl} TEMP_DIR:${TEMP_DIR}" 
        _token=$(echo -n ":${AZDO_PAT}" | base64)
        _debug "$_token"
        git -c http.extraHeader="Authorization: Basic ${_token}" clone $repoGitHttpUrl $TEMP_DIR  
    fi
}

git_push() {
    if [ $INSTALL_TYPE == 'PAAS ' ]; then
        git push origin master
    else
        _token=$(echo -n ":${AZDO_PAT}" | base64)
        git -c http.extraHeader="Authorization: Basic ${_token}" push origin master 
    fi 
}

create_default_env_files() {

    _information "Cloning "$CODE_REPO_GIT_HTTP_URL
    TEMP_DIR=~/git_repos/${AZDO_PROJECT_NAME}/${CODE_REPO_NAME}

    clone_repo "$TEMP_DIR" "$CODE_REPO_GIT_HTTP_URL"

    _information "Creating default environments..."
    _gen_random_seed "4"

    pushd $TEMP_DIR
    
    #create tmp dir for loggin
    if [[ -d "environments" ]]; then
        _error "Environments Folder found in Terraform-Code Repo. Please rename the environments, as this template will auto-generate an environments folder."
        exit 1
    fi

    mkdir environments
    mkdir environments/pr
    mkdir environments/dev
    mkdir environments/prod

    # Create PR Env Files
    cat >./environments/pr/pr.remotestate.env <<EOL
    ####################
    # TERRAFORM values #
    ####################

    ## global
    TF_VAR_ENVIRONMENT=pr
    TF_VAR_NAME=apppr
    
    TF_VAR_SUBSCRIPTION_ID=${SP_SUBSCRIPTION_ID}
    TF_VAR_LOCATION=${REGION}
    TF_VAR_TENANT_ID=${SP_TENANT_ID}

    ## 01_Init state storage
    TF_VAR_BACKEND_STORAGE_ACCOUNT_NAME=sttfrspr${PR_SEED}
    TF_VAR_BACKEND_RESOURCE_GROUP_NAME=tf-remote-state-pr
    TF_VAR_BACKEND_CONTAINER_NAME=tfrs
    TF_VAR_STORAGE_ACCOUNT_ACCOUNT_TIER=Standard
    TF_VAR_STORAGE_ACCOUNT_ACCOUNT_REPLICATION_TYPE=RAGRS
    TF_VAR_STORAGE_ACCOUNT_ACCOUNT_KIND=StorageV2
    TF_VAR_IDENTITY_TYPE=SystemAssigned
    TF_VAR_TAGS_ENVIRONMENT=pr
    TF_VAR_TAGS_VERSION=3.0.0

    ## Remote state backup
    TF_VAR_BACKEND_BACKUP_RESOURCE_GROUP_NAME=tf-remote-state-backup-pr
    TF_VAR_BACKUP_STORAGE_ACCOUNT_NAME=sttfrsbakpr${PR_SEED}
EOL

    cat >./environments/pr/pr.03_webapp.env <<EOL
    ## 03_webapp
    TF_VAR_PLAN_SKU_TIER=Standard
    TF_VAR_PLAN_SKU_SIZE=S1
    TF_VAR_APP_NAME=appeshoppr
    TF_VAR_APP_PLAN_NAME=planpr
    TF_VAR_DOCKER_IMAGE_NAME=dariuszporowski/eshopwebmvc:latest

EOL

    # Create Dev Env Files
    cat >./environments/dev/dev.remotestate.env <<EOL
    ####################
    # TERRAFORM values #
    ####################

    ## global
    TF_VAR_ENVIRONMENT=dev
    TF_VAR_NAME=appdev

    TF_VAR_SUBSCRIPTION_ID=${SP_SUBSCRIPTION_ID}
    TF_VAR_LOCATION=${REGION}
    TF_VAR_TENANT_ID=${SP_TENANT_ID}

    ## 01_Init state storage
    TF_VAR_BACKEND_STORAGE_ACCOUNT_NAME=sttfrsdev${DEV_SEED}
    TF_VAR_BACKEND_RESOURCE_GROUP_NAME=tf-remote-state-dev
    TF_VAR_BACKEND_CONTAINER_NAME=tfrs
    TF_VAR_STORAGE_ACCOUNT_ACCOUNT_TIER=Standard
    TF_VAR_STORAGE_ACCOUNT_ACCOUNT_REPLICATION_TYPE=RAGRS
    TF_VAR_STORAGE_ACCOUNT_ACCOUNT_KIND=StorageV2
    TF_VAR_IDENTITY_TYPE=SystemAssigned
    TF_VAR_TAGS_ENVIRONMENT=dev
    TF_VAR_TAGS_VERSION=3.0.0

    ## Remote state backup
    TF_VAR_BACKEND_BACKUP_RESOURCE_GROUP_NAME=tf-remote-state-backup-dev
    TF_VAR_BACKUP_STORAGE_ACCOUNT_NAME=sttfrsbakdev${DEV_SEED}
EOL

    cat >./environments/dev/dev.03_webapp.env <<EOL
    ## 03_webapp
    TF_VAR_PLAN_SKU_TIER=Standard
    TF_VAR_PLAN_SKU_SIZE=S1
    TF_VAR_APP_NAME=appeshopdev
    TF_VAR_APP_PLAN_NAME=plandev
    TF_VAR_DOCKER_IMAGE_NAME=dariuszporowski/eshopwebmvc:latest
EOL

    # Create Prod Env Files
    cat >./environments/prod/prod.remotestate.env <<EOL
    ####################
    # TERRAFORM values #
    ####################

    ## global
    TF_VAR_ENVIRONMENT=prod
    TF_VAR_NAME=appprod

    TF_VAR_SUBSCRIPTION_ID=${SP_SUBSCRIPTION_ID}
    TF_VAR_LOCATION=${REGION}
    TF_VAR_TENANT_ID=${SP_TENANT_ID}

    ## 01_Init state storage
    TF_VAR_BACKEND_STORAGE_ACCOUNT_NAME=sttfrsprod${PROD_SEED}
    TF_VAR_BACKEND_RESOURCE_GROUP_NAME=tf-remote-state-prod
    TF_VAR_BACKEND_CONTAINER_NAME=tfrs
    TF_VAR_STORAGE_ACCOUNT_ACCOUNT_TIER=Standard
    TF_VAR_STORAGE_ACCOUNT_ACCOUNT_REPLICATION_TYPE=RAGRS
    TF_VAR_STORAGE_ACCOUNT_ACCOUNT_KIND=StorageV2
    TF_VAR_IDENTITY_TYPE=SystemAssigned
    TF_VAR_TAGS_ENVIRONMENT=prod
    TF_VAR_TAGS_VERSION=3.0.0

    ## Remote state backup
    TF_VAR_BACKEND_BACKUP_RESOURCE_GROUP_NAME=tf-remote-state-backup-prod
    TF_VAR_BACKUP_STORAGE_ACCOUNT_NAME=sttfrsbakprod${PROD_SEED}
EOL

    cat >./environments/prod/prod.03_webapp.env <<EOL
    ## 03_webapp
    TF_VAR_PLAN_SKU_TIER=Standard
    TF_VAR_PLAN_SKU_SIZE=S1
    TF_VAR_APP_NAME=appeshop
    TF_VAR_APP_PLAN_NAME=plan
    TF_VAR_DOCKER_IMAGE_NAME=dariuszporowski/eshopwebmvc:latest
EOL

    #commit pr.env to the repo
    git add ./environments/pr/pr.remotestate.env
    git add ./environments/pr/pr.03_webapp.env

    #commit dev.env to the repo
    git add ./environments/dev/dev.remotestate.env
    git add ./environments/dev/dev.03_webapp.env

    #commit prod.env to the repo
    git add ./environments/prod/prod.remotestate.env
    git add ./environments/prod/prod.03_webapp.env

    git config user.email "installer@terraform-template.com"
    git config user.name "Terraform template"

    git commit -m "Initialize environments"

    git_push

    #before you delete the clone, we need to upload the file to secure files.


    popd

    #delete local copy of repo
    rm -rf $TEMP_DIR

    _success "Completed configuring env"
}

declare QUERY_EXTENSION_RESULT=''
query_extension() {
    # AzDo Service     : Import Requests - Get https://docs.microsoft.com/rest/api/azure/devops/git/import%20requests/get?view=azure-devops-rest-5.1
    # AzDo Server 2019 : Import Requests - Get https://docs.microsoft.com/rest/api/azure/devops/git/import%20requests/get?view=azure-devops-server-rest-5.0
    # GET https://dev.azure.com/{organization}/{project}/_apis/git/repositories/{repositoryId}/importRequests/{importRequestId}?api-version=5.1-preview.1

    _publisherName=$1
    _extensionName=$2
    _uri=$(_set_api_version "${AZDO_EXT_MGMT_URI}/_apis/extensionmanagement/installedextensionsbyname/${_publisherName}/${_extensionName}?api-version=" '5.1-preview.1' '5.1-preview.1')
    _debug "$_uri"
    _response=$(request_get $_uri)
    echo $_response > ./temp/${1}${2}.json

    _debug_log_get "$_uri" "$_response"

    _queryExtentionTypeKey=$(cat ./temp/${1}${2}.json | jq -r '.typeKey')
    if [ "$_queryExtentionTypeKey" == "InstalledExtensionNotFoundException" ]; then
        QUERY_EXTENSION_RESULT='[]'
        return 0
    fi
    QUERY_EXTENSION_RESULT=$_response
}

check_and_install_extension_by_name() {
  # AzDo Service     : Install Extension By Name - https://docs.microsoft.com/rest/api/azure/devops/extensionmanagement/installed%20extensions/install%20extension%20by%20name?view=azure-devops-rest-5.1
  # AzDo Server 2019 : Install Extension By Name - https://docs.microsoft.com/rest/api/azure/devops/extensionmanagement/installed%20extensions/install%20extension%20by%20name?view=azure-devops-server-rest-5.0
  # POST https://extmgmt.dev.azure.com/{organization}/_apis/extensionmanagement/installedextensionsbyname/{publisherName}/{extensionName}/{version}?api-version=5.1-preview.1

  _publisherName=$1
  _extensionName=$2
   
  query_extension "${_publisherName}" "${_extensionName}"
  
  _debug "query result: $QUERY_EXTENSION_RESULT"
    if [ "$QUERY_EXTENSION_RESULT" == '[]' ]; then
        echo "Installing extension $_extensionName..."
        
        _uri=$(_set_api_version "${AZDO_EXT_MGMT_URI}/_apis/extensionmanagement/installedextensionsbyname/${_publisherName}/${_extensionName}?api-version=" '5.1-preview.1' '5.1-preview.1')
        _response=$(request_post $_uri "")
        echo $_response > "./temp/install${1}${2}.json"
        _debug_log_post "$_uri" "$_response" ""

        _installExtensionTypeKey=$(cat "./temp/install${1}${2}.json" | jq -r '.typeKey')

        if [ "$_installExtensionTypeKey" == "ExtensionDoesNotExistException" ]; then
            _error "The extension $_publisherName.$_extensionName does not exist."     

        elif [ "$_installExtensionTypeKey" == "AccessCheckException" ]; then
            _error "Access Denied."
            echo $_response | jq

        else
            _success "Extension ${_extensionName} from publisher ${_publisherName} was installed in organization."
        fi      
    else
        _success "Extension ${_extensionName} from publisher ${_publisherName} already installed in organization.."
    fi
}

install_extensions() {
    _information "Installing ADO extensions"

    check_and_install_extension_by_name "charleszipp" "azure-pipelines-tasks-terraform"
    check_and_install_extension_by_name "CSE-DevOps"  "RunPipelines"

    # Only install credscan in PAAS projects.
    if [ "$INSTALL_TYPE" == "PAAS" ]; then
        if [ $INSTALL_INTERNAL_CREDSCAN == true ]; then
            check_and_install_extension_by_name "securedevelopmentteam" "vss-secure-development-tools"
        else
            check_and_install_extension_by_name "ms-codeanalysis" "vss-microsoft-security-code-analysis-devops"
        fi
    fi
}

_get_management_endpoint() {
    local _response=$(az cloud show -n ${AZURE_CLOUD_ENVIRONMENT})
    echo $_response > "./temp/az-cloud-show-response.json"
    if [ "$INSTALL_TYPE" == "PAAS" ]; then
        MANAGEMENT_URI=`echo $_response | jq .endpoints.management | sed "s/^\([\"']\)\(.*\)\1\$/\2/g"`
    else
        MANAGEMENT_URI=`echo $_response | jq .endpoints.resourceManager | sed "s/^\([\"']\)\(.*\)\1\$/\2/g"`
    fi
    _debug "MANAGEMENT_URI: ${MANAGEMENT_URI}"
    
}


_create_svc_connection_payload() {
    local _payload
    
    if [ "$INSTALL_TYPE" == "PAAS" ]; then
        _payload=$(cat "payloads/template.service-connection-create.json" \
        | sed 's~__SERVICE_PRINCIPAL_ID__~'"${SP_ID}"'~' \
        | sed 's@__SERVICE_PRINCIPAL_KEY__@'"${SP_SECRET}"'@' \
        | sed 's~__SERVICE_PRINCIPAL_TENANT_ID__~'"${SP_TENANT_ID}"'~' \
        | sed 's~__CLOUD_ENVIRONMENT__~'"${AZURE_CLOUD_ENVIRONMENT}"'~' \
        | sed 's~__SUBSCRIPTION_ID__~'"${SP_SUBSCRIPTION_ID}"'~' \
        | sed 's~__SUBSCRIPTION_NAME__~'"${SP_SUBSCRIPTION_NAME}"'~' \
        | sed 's~__SERVICE_CONNECTION_NAME__~'"${AZDO_SC_AZURERM_NAME}"'~' \
        | sed 's~__PROJECT_ID__~'"${AZDO_PROJECT_ID}"'~' \
        | sed 's~__PROJECT_NAME__~'"${AZDO_PROJECT_NAME}"'~' \
        | sed 's~__MANAGEMENT_URI__~'"${MANAGEMENT_URI}"'~' \
        ) 
    else
        local targetEnvironment=${AZURE_CLOUD_ENVIRONMENT}
        if [ "${PRIVATE_CLOUD}" == true ]; then
            targetEnvironment="AzureStack"
        fi
        _payload=$(cat "payloads/template.service-connection-create-azdovm.json" \
        | sed 's~__SERVICE_PRINCIPAL_ID__~'"${SP_ID}"'~' \
        | sed 's@__SERVICE_PRINCIPAL_KEY__@'"${SP_SECRET}"'@' \
        | sed 's~__SERVICE_PRINCIPAL_TENANT_ID__~'"${SP_TENANT_ID}"'~' \
        | sed 's~__CLOUD_ENVIRONMENT__~'"${targetEnvironment}"'~' \
        | sed 's~__SUBSCRIPTION_ID__~'"${SP_SUBSCRIPTION_ID}"'~' \
        | sed 's~__SUBSCRIPTION_NAME__~'"${SP_SUBSCRIPTION_NAME}"'~' \
        | sed 's~__SERVICE_CONNECTION_NAME__~'"${AZDO_SC_AZURERM_NAME}"'~' \
        | sed 's~__MANAGEMENT_URI__~'"${MANAGEMENT_URI}"'~' \
        ) 
    fi

    echo $_payload
}

create_arm_svc_connection() {
    # https://docs.microsoft.com/rest/api/azure/devops/serviceendpoint/endpoints/create?view=azure-devops-rest-5.1#endpointauthorization
    # https://docs.microsoft.com/rest/api/azure/devops/serviceendpoint/endpoints/create?view=azure-devops-server-rest-5.0
    # Create Azure RM Service connection

    _information "Creating AzureRM service connection"

    # Get the management endpoint for whatever cloud we are provisioning for.
    _get_management_endpoint

    _uri=$(_set_api_version "${AZDO_ORG_URI}/${AZDO_PROJECT_NAME}/_apis/serviceendpoint/endpoints?api-version=" '5.1-preview.2' '5.1-preview.2')
    _payload=$(_create_svc_connection_payload)
    echo "${_payload}" > ./temp/casc_payload.json
    _response=$( request_post \
        "${_uri}" \
        "${_payload}"
        )

    echo $_response > ./temp/casc.json
    _debug_log_post "$_uri" "$_response" "$_payload"

    sc_id=`cat ./temp/casc.json | jq -r .id`

    _debug "Service Connection ID: ${sc_id}"
    sleep 10
    _uri=$(_set_api_version "${AZDO_ORG_URI}/${AZDO_PROJECT_NAME}/_apis/serviceendpoint/endpoints/${sc_id}?api-version=" '5.1-preview.2' '5.1-preview.1' )
    _response=$(request_get $_uri)

    echo $_response > ./temp/isready.json

    _isReady=$(cat ./temp/isready.json | jq -r '.isReady')
    if [ $_isReady != true ]; then    
        _error "Error creating AzureRM service connection"
    fi

    # https://docs.microsoft.com/rest/api/azure/devops/build/authorizedresources/authorize%20project%20resources?view=azure-devops-rest-5.1
    # https://docs.microsoft.com/rest/api/azure/devops/build/authorizedresources/authorize%20project%20resources?view=azure-devops-server-rest-5.0
    # Authorize the service connection for all pipelines.
    _information "Authorizing service connection for all pipelines."

    _payload=$(cat "payloads/template.authorized-resources.json" | sed 's~__SERVICE_CONNECTION_ID__~'"${sc_id}"'~')
    _uri=$(_set_api_version "${AZDO_ORG_URI}/${AZDO_PROJECT_NAME}/_apis/build/authorizedresources?api-version=" '5.1-preview.1' '5.1-preview.1')

    _response=$( request_patch \
        "${_uri}" \
        "${_payload}"
        )
    
    _debug_log_patch "$_uri" "$_response" "$_payload"

    _success "AzureRM service connection created and authorized"
    #az devops service-endpoint update --org ${AZDO_ORG_URI} --project ${AZDO_PROJECT_NAME} --enable-for-all true --id ${scId}
}

list_svc_connection_types() {
    # AzDo Service     : Service Endpoint Types List - https://docs.microsoft.com/rest/api/azure/devops/serviceendpoint/types/list?view=azure-devops-rest-5.1
    # AzDo Server 2019 : Service Endpoint Types List - https://docs.microsoft.com/rest/api/azure/devops/serviceendpoint/types/list?view=azure-devops-server-rest-5.0
    # GET https://dev.azure.com/{organization}/_apis/serviceendpoint/types?api-version=5.1-preview.1
    request_get "${AZDO_ORG_URI}/_apis/serviceendpoint/types?api-version=5.1-preview.1" | jq '.value[].name'
}

get_svc_connection_type() {
    type=$1

    # AzDo Service     : Service Endpoint - Get https://docs.microsoft.com/rest/api/azure/devops/serviceendpoint/endpoints/get?view=azure-devops-rest-5.1
    # AzDo Server 2019 : Service Endpoint - Get https://docs.microsoft.com/rest/api/azure/devops/serviceendpoint/endpoints/get?view=azure-devops-server-rest-5.0
    # GET https://dev.azure.com/{organization}/_apis/serviceendpoint/types?type={type}&api-version=5.1-preview.1

  # AzDo Service     : Service Endpoint - Get https://docs.microsoft.com/rest/api/azure/devops/serviceendpoint/endpoints/get?view=azure-devops-rest-5.1
  # AzDo Server 2019 : Service Endpoint - Get https://docs.microsoft.com/rest/api/azure/devops/serviceendpoint/endpoints/get?view=azure-devops-server-rest-5.0
  # GET https://dev.azure.com/{organization}/_apis/serviceendpoint/types?type={type}&api-version=5.1-preview.1
  _uri=$(_set_api_version "${AZDO_ORG_URI}/_apis/serviceendpoint/types?type=${type}&api-version=" '5.1-preview.2' '5.0-preview.2')
  echo $_uri
  _response=$(request_get 'https://b2020-server-vm/ProjectCollection/_apis/serviceendpoint/types?type=externaltfs')
  echo $_response | jq
}

create_azdo_svc_connection() {
    _information "Creating azdo service connection"
    # AzDo Service     : Service Endpoint - Create https://docs.microsoft.com/rest/api/azure/devops/serviceendpoint/endpoints/create?view=azure-devops-rest-5.1
    # AzDo Server 2019 : Service Endpoint - Create https://docs.microsoft.com/rest/api/azure/devops/serviceendpoint/endpoints/create?view=azure-devops-server-rest-5.0
   
    _templateFile=''

     if [ "$INSTALL_TYPE" == "PAAS" ]; then
        _templateFile='template.sc-ado-paas.json'
    else
        _templateFile='template.sc-ado-server.json'
    fi

    _debug "starting payload $_templateFile"
                 
    _payload=$( cat "payloads/$_templateFile" | sed 's~__ADO_ORG_NAME__~'"${AZDO_ORG_NAME}"'~' | sed 's~__ADO_ORG_URI__~'"${AZDO_ORG_URI}"'~' | sed 's~__ADO_PAT__~'"${AZDO_PAT}"'~' )

    _debug "done payload"
    _debug_json "$_payload"            

    _uri=$(_set_api_version "${AZDO_ORG_URI}/${AZDO_PROJECT_NAME}/_apis/serviceendpoint/endpoints?api-version=" '5.1-preview.1' '5.1-preview.1')

    _response=$( request_post \
        "${_uri}" \
        "${_payload}"
    )

    echo $_response > ./temp/scado.json
    _debug_log_post "$_uri" "$_response" "$_payload"

    _scId=$(cat ./temp/scado.json | jq -r '.id')
    _isReady=$(cat ./temp/scado.json | jq -r '.isReady')

    if [ $_isReady != true ]; then    
        _error "Error creating azdo service connection"
    fi

    _success "azdo service connection created.  service connection id: ${_scId}"

    _payload=$(cat "payloads/template.sc-ado-auth.json" | sed 's~__SC_ADO_ID__~'"${_scId}"'~')
    _uri=$(_set_api_version "${AZDO_ORG_URI}/${AZDO_PROJECT_NAME}/_apis/pipelines/pipelinePermissions/endpoint/${_scId}?api-version=" '5.1-preview' '5.1-preview' )
    _response=$( request_patch \
        "${_uri}" \
        "${_payload}"
    )
    echo $_response > ./temp/sc-ado-auth.json

    _debug_log_patch "$_uri" "$_response" "$_payload"

    _allPipelinesAuthorized=$(cat ./temp/sc-ado-auth.json | jq -r '.allPipelines.authorized')

    if [ $_allPipelinesAuthorized == true ]; then    
        _success "azdo service connection authorized for all pipelines"
    fi
}

create_variable_groups() {
    # AzDo Service     : Variablegroups - Add https://docs.microsoft.com/rest/api/azure/devops/distributedtask/variablegroups/add?view=azure-devops-rest-5.1
    # AzDo Server 2019 : Variablegroups - Add https://docs.microsoft.com/rest/api/azure/devops/distributedtask/variablegroups/add?view=azure-devops-server-rest-5.0
    # POST https://dev.azure.com/{organization}/{project}/_apis/distributedtask/variablegroups?api-version=5.1-preview.1
    _information "Creating Variable Groups"
    local _vgName="tool_versions"
    local _tfCloudEnvironment=$(get_tf_azure_clound_env)
    local _cloudConfigPayload=""

    if [ ! -z "${ARM_METADATA_HOST}" ]; then
        _cloudConfigPayload=$_cloudConfigPayload',"ARM_METADATA_HOST":{"value":"'${ARM_METADATA_HOST}'"}'
    fi

    if [ "${PRIVATE_CLOUD}" == true ];then
       _cloudConfigPayload=$_cloudConfigPayload',"ARM_ENVIRONMENT":{"value":"'${_tfCloudEnvironment}'"}'
       _cloudConfigPayload=$_cloudConfigPayload',"AZURE_ENVIRONMENT":{"value":"'${_tfCloudEnvironment}'"}'
       _cloudConfigPayload=$_cloudConfigPayload',"AZURE_CLOUD_NAME":{"value":"'${AZURE_CLOUD_ENVIRONMENT}'"}'
    fi  
    if [ ! -z "${AZURE_ENVIRONMENT_FILEPATH}" ]; then
       _cloudConfigPayload=$_cloudConfigPayload',"AZURE_ENVIRONMENT_FILEPATH":{"value":"'${AZURE_ENVIRONMENT_FILEPATH}'"}'
    fi         
    echo $_cloudConfigPayload
    _payload=$(cat "payloads/template.vg.json" | sed 's~__VG_NAME__~'"${_vgName}"'~' | sed 's~__ARM_CLOUD_CONFIGS__~'"${_cloudConfigPayload}"'~')
    echo $_payload > temp/vg.payload.json
    _uri=$(_set_api_version "${AZDO_ORG_URI}/${AZDO_PROJECT_NAME}/_apis/distributedtask/variablegroups?api-version=" '5.1-preview.1' '5.1-preview.1')
    _response=$( request_post \
                    "${_uri}" \
                    "${_payload}" 
                )  
    echo $_response > ./temp/cvg.json

    _debug_log_post "$_uri" "$_response" "$_payload"
        
    _createVgTypeKey=$(cat ./temp/cvg.json | jq -r '.typeKey')
    if [ "$_createVgTypeKey" == "VariableGroupExistsException" ]; then
        _error "can't add variable group ${_vgName}. Variable group exists"
    fi
    
    _vgId=$(cat ./temp/cvg.json | jq -r '.id')
    if [ "$_vgId" != null ]; then
        # AzDo Service     : Authorize Project Resources - https://docs.microsoft.com/rest/api/azure/devops/build/authorizedresources/authorize%20project%20resources?view=azure-devops-rest-5.1
        # AzDo Server 2019 : Authorize Project Resources - https://docs.microsoft.com/rest/api/azure/devops/build/authorizedresources/authorize%20project%20resources?view=azure-devops-server-rest-5.0  
        # PATCH https://dev.azure.com/{organization}/{project}/_apis/build/authorizedresources?api-version=5.1-preview.1
        _payload=$(cat "payloads/template.vg-auth.json"  | sed 's~__VG_ID__~'"${_vgId}"'~' | sed 's~__VG_NAME__~'"${_vgName}"'~')
        _uri=$(_set_api_version "${AZDO_ORG_URI}/${AZDO_PROJECT_NAME}/_apis/build/authorizedresources?api-version=" '5.1-preview.1' '5.1-preview.1')

        _response=$(  request_patch \
                        "${_uri}" \
                        "${_payload}"
                    )
        echo $_response > ./temp/vgauth.json

        _debug_log_patch "$_uri" "$_response" "$_payload"

        _vgAuthorized=$(cat ./temp/vgauth.json | jq -r --arg _vgId "$_vgId" '.value[] | select( (.type == "variablegroup") and (.id == $_vgId)) | .authorized')

        _debug "Variable Group Authrized ${_vgAuthorized}"

        if [ $_vgAuthorized == true ]; then    
            _success "variable group ${_vgName} created and authorized for all pipelines."
        fi
    fi
}

create_and_upload_pr_state_secfile() {
    local _fileName="pr.storage.init.state"
    touch ./$_fileName

    # POST https://dev.azure.com/{organization}/{project}/_apis/distributedtask/securefiles?api-version=6.0-preview.1&name={fileName}
    _information "Uploading PR State File to Secure Files"

    _uri=$(_set_api_version "${AZDO_ORG_URI}/${AZDO_PROJECT_NAME}/_apis/distributedtask/securefiles?name=${_fileName}&api-version=" '6.0-preview.1' '5.1-preview.1')

    local _response=$(request_post_binary "${_uri}" "${_fileName}")

    _debug_log_post_binary "$_uri" "$_response" "$_fileName"

    echo $_response > ./temp/usf.json

    _id=$(cat ./temp/usf.json | jq -c -r '.id')

    _debug "Secure File ID: ${_id}"

    # PATCH https://dev.azure.com/{organization}/{project}/_apis/build/authorizedresources?api-version=5.1-preview.1
    _uri=$(_set_api_version "${AZDO_ORG_URI}/${AZDO_PROJECT_NAME}/_apis/build/authorizedresources?api-version=" '5.1-preview.1' '5.1-preview.1')
    _payload="[{\"authorized\":true,\"id\":\"${_id}\",\"name\":\"${_fileName}\",\"type\":\"securefile\"}]"

    _response=$( request_patch \
    "${_uri}" \
    "${_payload}"
    )
    echo "${_response}"
    _debug_log_patch "$_uri" "$_response" "$_payload"

    rm ./$_fileName
}

create_pr_variable_group() {
    if [ ${INSTALL_TYPE} == 'SERVER' ]; then
        _information "Install targets Azure DevOps Server 2020. Skipping PR Variable Group creation."
        return 0
    fi

    # AzDo Service     : Variablegroups - Add https://docs.microsoft.com/rest/api/azure/devops/distributedtask/variablegroups/add?view=azure-devops-rest-5.1
    # AzDo Server 2019 : Variablegroups - Add https://docs.microsoft.com/rest/api/azure/devops/distributedtask/variablegroups/add?view=azure-devops-server-rest-5.0
    # POST https://dev.azure.com/{organization}/{project}/_apis/distributedtask/variablegroups?api-version=5.1-preview.1
    _information "Creating PR Variable Group"
    local _vgName="pullrequest.state"
    local _cloudConfigPayload=""

   
 
    _payload=$(cat "payloads/template.vg.pr.json" | sed 's~__VG_NAME__~'"${_vgName}"'~')
    echo $_payload > temp/vg.payload.json
    _uri=$(_set_api_version "${AZDO_ORG_URI}/${AZDO_PROJECT_NAME}/_apis/distributedtask/variablegroups?api-version=" '5.1-preview.1' '5.1-preview.1')
    _response=$( request_post \
                    "${_uri}" \
                    "${_payload}" 
                )  
    echo $_response > ./temp/cprvg.json

    _debug_log_post "$_uri" "$_response" "$_payload"
        
    _createVgTypeKey=$(cat ./temp/cprvg.json | jq -r '.typeKey')
    if [ "$_createVgTypeKey" == "VariableGroupExistsException" ]; then
        _error "can't add variable group ${_vgName}. Variable group exists"
    fi
    
    _vgId=$(cat ./temp/cprvg.json | jq -r '.id')
    if [ "$_vgId" != null ]; then
        # AzDo Service     : Authorize Project Resources - https://docs.microsoft.com/rest/api/azure/devops/build/authorizedresources/authorize%20project%20resources?view=azure-devops-rest-5.1
        # AzDo Server 2019 : Authorize Project Resources - https://docs.microsoft.com/rest/api/azure/devops/build/authorizedresources/authorize%20project%20resources?view=azure-devops-server-rest-5.0  
        # PATCH https://dev.azure.com/{organization}/{project}/_apis/build/authorizedresources?api-version=5.1-preview.1
        _payload=$(cat "payloads/template.vg-auth.json"  | sed 's~__VG_ID__~'"${_vgId}"'~' | sed 's~__VG_NAME__~'"${_vgName}"'~')
        _uri=$(_set_api_version "${AZDO_ORG_URI}/${AZDO_PROJECT_NAME}/_apis/build/authorizedresources?api-version=" '5.1-preview.1' '5.1-preview.1')

        _response=$(  request_patch \
                        "${_uri}" \
                        "${_payload}"
                    )
        echo $_response > ./temp/vg.pr.auth.json

        _debug_log_patch "$_uri" "$_response" "$_payload"

        local _vgAuthorized=$(cat ./temp/vg.pr.auth.json | jq -r --arg _vgId "$_vgId" '.value[] | select( (.type == "variablegroup") and (.id == $_vgId)) | .authorized')

        _debug "PR Variable Group Authorized |${_vgAuthorized}|"

        if [ $_vgAuthorized == true ]; then    
            _success "PR variable group created and authorized for all pipelines."
        fi
    fi
}

_list_pipelines() {
    # GET https://dev.azure.com/{organization}/{project}/_apis/build/definitions?api-version=5.1

    _uri="${AZDO_ORG_URI}/${AZDO_PROJECT_NAME}/_apis/build/definitions/?api-version=5.1"
    request_get $_uri  
}

_get_agent_pool_queue() {
    # https://docs.microsoft.com/rest/api/azure/devops/distributedtask/queues/get%20agent%20queues?view=azure-devops-rest-5.1

    _uri="https://dev.azure.com/${AZDO_ORG_NAME}/${AZDO_PROJECT_NAME}/_apis/distributedtask/queues?api-version=5.1-preview.1"
    _response=$(request_get $_uri)

    _is_ubuntu=$(echo $_response | jq '.value[] | select( .name | contains("Ubuntu") )')

    if [ -z "${_is_ubuntu}" ]; then
        _default_pool=$(echo $_response | jq '.value[] | select( .name | contains("Default") )')
        agent_pool_queue_id=$(echo $_default_pool | jq -r '.id')
        agent_pool_queue_name=$(echo $_default_pool | jq -r '.name')
    else
        agent_pool_queue_id=$(echo $_is_ubuntu | jq -r '.id')
        agent_pool_queue_name=$(echo $_is_ubuntu | jq -r '.name')
    fi

    echo "{\"agent_pool_queue_id\":\"$agent_pool_queue_id\",\"agent_pool_queue_name\":\"$agent_pool_queue_name\"}"

}

_get_agent_pool_queue() {
    # https://docs.microsoft.com/rest/api/azure/devops/distributedtask/queues/get%20agent%20queues?view=azure-devops-rest-5.1
    
    local _uri="${AZDO_ORG_URI}/${AZDO_PROJECT_NAME}/_apis/distributedtask/queues?api-version=5.1-preview.1"
    _response=$(request_get $_uri)
    _is_ubuntu=$(echo $_response | jq '.value[] | select( .name | contains("Ubuntu") )')

    if [ -z "${_is_ubuntu}" ]; then
        _default_pool=$(echo $_response | jq '.value[] | select( .name | contains("Default") )')
        agent_pool_queue_id=$(echo $_default_pool | jq -r '.id')
        agent_pool_queue_name=$(echo $_default_pool | jq -r '.name')
    else
        agent_pool_queue_id=$(echo $_is_ubuntu | jq -r '.id')
        agent_pool_queue_name=$(echo $_is_ubuntu | jq -r '.name')
    fi

    echo "{\"agent_pool_queue_id\":\"$agent_pool_queue_id\",\"agent_pool_queue_name\":\"$agent_pool_queue_name\"}"
}

_create_pipeline() {
    # AzDo Service     : Definitions - Create https://docs.microsoft.com/rest/api/azure/devops/build/definitions/create?view=azure-devops-rest-5.1
    # AzDo Server 2019 : Definitions - Create https://docs.microsoft.com/rest/api/azure/devops/build/definitions/create?view=azure-devops-server-rest-5.0
    # POST https://dev.azure.com/{organization}/{project}/_apis/build/definitions?api-version=5.1
    # usage: _create_pipeline storageinit "/azure-pipelines/pipeline.storageinit.yml"
    _information "Creating pipelines..."

    local _template_file="payloads/template.pipeline-create.json"
    local _name="${1}"
    local _yaml_path=${2}
    local _folder_path=${3}
    local _variables=${4}
    local _pipelineRepoName=${5}

    local _agent_queue=$(_get_agent_pool_queue)
    local _agent_pool_queue_id=$(echo $_agent_queue | jq -c -r '.agent_pool_queue_id')
    local _agent_pool_queue_name=$(echo $_agent_queue | jq -c -r '.agent_pool_queue_name')

    #Ensure the agent pool is setup correctly.
    local _branch_name="master"
    local _uri=$(_set_api_version "${AZDO_ORG_URI}/${AZDO_PROJECT_NAME}/_apis/build/definitions?api-version=" '5.1' '5.1')

    local _payload=$( cat "${_template_file}" \
                | sed 's~__ADO_PIPELINE_NAME__~'"${_name}"'~' \
                | sed 's~__ADO_PIPELINE_FOLDER_PATH__~'"${_folder_path}"'~' \
                | sed 's~__ADO_PIPELINE_REPO_BRANCH__~'"${_branch_name}"'~' \
                | sed 's~__ADO_PIPELINE_REPO_NAME__~'"${_pipelineRepoName}"'~' \
                | sed 's~__ADO_PIPELINE_YAML_FILE_PATH__~'"${_yaml_path}"'~' \
                | sed 's~__ADO_PIPELINE_VARIABLES__~'"${_variables}"'~' \
                | sed 's~__ADO_POOL_ID__~'"${_agent_pool_queue_id}"'~' \
                | sed 's~__ADO_POOL_NAME__~'"${_agent_pool_queue_name}"'~' \
                | sed 's~__AZDO_ORG_URI__~'"${AZDO_ORG_URI}"'~' \
              )

    local _response=$(request_post "${_uri}" "${_payload}")

    echo $_payload > ./temp/${_name}-cp-payload.json
    echo $_response > ./temp/${_name}-cp.json

    _debug_log_post "$_uri" "$_response" "$_payload"

    local _createPipelineTypeKey=$(cat ./temp/${_name}-cp.json | jq -r '.typeKey')

    if [ "$_createPipelineTypeKey" == "DefinitionExistsException" ]; then
        _error "Pipeline ${_name} already exists."
    fi

    local _pipeId=$(cat ./temp/${_name}-cp.json | jq -r '.id')

    
    # Authorize Pipeline 
    _uri=$(_set_api_version "${AZDO_ORG_URI}/${AZDO_PROJECT_NAME}/_apis/pipelines/pipelinePermissions/queue/${_agent_pool_queue_id}?api-version=" '5.1-preview.1' '5.1-preview.1')
    _debug "${_uri}"
    _payload=$( cat "payloads/template.pipeline-authorize.json" \
                | sed 's~__PIPELINE_ID__~'"${_pipeId}"'~' \
              )
    _response=$(request_patch "${_uri}" "${_payload}")
    echo $_payload > ./temp/${_name}-cp-authorize-payload.json
    echo $_response > ./temp/${_name}-cp-authorize.json

    if [ "$_pipeId" != null ]; then
        if [ "${_name}" == "env.compile" ]; then
            envCompilePipelineId=$_pipeId
        fi
        _success "Created Pipeline ${_name} - id:${_pipeId}"
    fi


    # Authorize Terraform-Code Repo Access for Pipeline
    _uri=$(_set_api_version "${AZDO_ORG_URI}/${AZDO_PROJECT_NAME}/_apis/pipelines/pipelinePermissions/repository/${AZDO_PROJECT_ID}.${CODE_REPO_ID}?api-version=" '5.1-preview.1' '5.1-preview.1')
    _debug "${_uri}"
    _payload=$( cat "payloads/template.pipeline-authorize.json" \
                | sed 's~__PIPELINE_ID__~'"${_pipeId}"'~' \
              )
    _response=$(request_patch "${_uri}" "${_payload}")
    echo $_payload > ./temp/${_name}-cp-authorize-code-repo-payload.json
    echo $_response > ./temp/${_name}-cp-authorize-code-repo.json
    

    # Authorize Terraform-Pipeline Repo Access for Pipeline
    _uri=$(_set_api_version "${AZDO_ORG_URI}/${AZDO_PROJECT_NAME}/_apis/pipelines/pipelinePermissions/repository/${AZDO_PROJECT_ID}.${PIPELINE_REPO_ID}?api-version=" '5.1-preview.1' '5.1-preview.1')
    _debug "${_uri}"
    _payload=$( cat "payloads/template.pipeline-authorize.json" \
                | sed 's~__PIPELINE_ID__~'"${_pipeId}"'~' \
              )
    _response=$(request_patch "${_uri}" "${_payload}")
    echo $_payload > ./temp/${_name}-cp-authorize-pipeline-repo-payload.json
    echo $_response > ./temp/${_name}-cp-authorize-pipeline-repo.json


    if [ "$_pipeId" != null ]; then
        if [ "${_name}" == "env.compile" ]; then
            envCompilePipelineId=$_pipeId
        fi
        if [ "${_name}" == "pr" ]; then
            prPipelineId=$_pipeId
        fi        
        _success "Created Pipeline ${_name} - id:${_pipeId}"
    fi
}

_get_pipeline_var_defintion() {
    local _var_key=${1}
    local _var_value=${2}
    local _allowOverride=${3}
    local _template_file="payloads/template.pipeline-variable.json"
    local _payload=$(
        cat "${_template_file}" |
            sed 's~__PIPELINE_VAR_NAME__~'"${_var_key}"'~' |
            sed 's~__PIPELINE_VAR_VALUE__~'"${_var_value}"'~' |
            sed 's~__PIPELINE_VAR_IS_SECRET__~'false'~' |
            sed 's~__PIPELINE_ALLOW_OVERRIDE__~'"${_allowOverride}"'~'
    )
    echo $_payload
}

get_tf_azure_clound_env() {
  local tf_cloud_env=''
  case $AZURE_CLOUD_ENVIRONMENT in
    AzureCloud)
      tf_cloud_env='public'
      ;;
    AzureChinaCloud)
      tf_cloud_env='china'
      ;;
    AzureUSGovernment)
      tf_cloud_env='usgovernment'
      ;;
    AzureGermanCloud)
      tf_cloud_env='german'
      ;;            
  esac
  
  echo $tf_cloud_env
}

create_pipelines() {
    echo "Creating Azure Pipelines "
    local pipelineVariables
    
    # Create PR pipelines
    if [ ${INSTALL_TYPE} == 'PAAS' ]; then
        pipelineVariables=$(_get_pipeline_var_defintion environment pr false)
        pipelineVariables="$pipelineVariables, $(_get_pipeline_var_defintion INSTALL_TYPE ${INSTALL_TYPE} false)"
        pipelineVariables="$pipelineVariables, $(_get_pipeline_var_defintion autoDestroy true true)"
        pipelineVariables="$pipelineVariables, $(_get_pipeline_var_defintion tfCodeBranch master true)"
        pipelineVariables="$pipelineVariables, $(_get_pipeline_var_defintion DEPLOYMENT_DIR "" true)"
        pipelineVariables="$pipelineVariables, $(_get_pipeline_var_defintion NODE_TLS_REJECT_UNAUTHORIZED 0 false)"
        pipelineVariables="$pipelineVariables, $(_get_pipeline_var_defintion FULL_DEPLOYMENT false false)"
        pipelineVariables="$pipelineVariables, $(_get_pipeline_var_defintion azureSubscription ${AZDO_SC_AZURERM_NAME} false)"
        pipelineVariables="$pipelineVariables, $(_get_pipeline_var_defintion gitDiffBaseBranch master true)"
        _create_pipeline pr "/azure-pipelines/pipeline.pr.yml" "infrastructure/utility" "${pipelineVariables}"  "${PIPELINE_REPO_NAME}"
   
        pipelineVariables=$(_get_pipeline_var_defintion environment pr false)
        pipelineVariables="$pipelineVariables, $(_get_pipeline_var_defintion INSTALL_TYPE ${INSTALL_TYPE} false)"
        pipelineVariables="$pipelineVariables, $(_get_pipeline_var_defintion tfCodeBranch master true)"
        pipelineVariables="$pipelineVariables, $(_get_pipeline_var_defintion NODE_TLS_REJECT_UNAUTHORIZED 0 false)"
        pipelineVariables="$pipelineVariables, $(_get_pipeline_var_defintion azureSubscription ${AZDO_SC_AZURERM_NAME} false)"
        pipelineVariables="$pipelineVariables, $(_get_pipeline_var_defintion resetTFStateContainer false true)"        
        _create_pipeline pr.storageinit "/azure-pipelines/pipeline.storageinit.yml" "infrastructure/utility" "${pipelineVariables}"  "${PIPELINE_REPO_NAME}"

        pipelineVariables=$(_get_pipeline_var_defintion environment pr false)
        pipelineVariables="$pipelineVariables, $(_get_pipeline_var_defintion INSTALL_TYPE ${INSTALL_TYPE} false)"
        pipelineVariables="$pipelineVariables, $(_get_pipeline_var_defintion NODE_TLS_REJECT_UNAUTHORIZED 0 false)"
        pipelineVariables="$pipelineVariables, $(_get_pipeline_var_defintion azureSubscription ${AZDO_SC_AZURERM_NAME} false)"
        _create_pipeline pr.backupremotestate "/azure-pipelines/pipeline.backupremotestate.yml" "infrastructure/utility" "${pipelineVariables}" "${PIPELINE_REPO_NAME}"

        pipelineVariables=$(_get_pipeline_var_defintion environment pr false)
        pipelineVariables="$pipelineVariables, $(_get_pipeline_var_defintion INSTALL_TYPE ${INSTALL_TYPE} false)"
        pipelineVariables="$pipelineVariables, $(_get_pipeline_var_defintion tfCodeBranch master true)"
        pipelineVariables="$pipelineVariables, $(_get_pipeline_var_defintion NODE_TLS_REJECT_UNAUTHORIZED 0 false)"
        pipelineVariables="$pipelineVariables, $(_get_pipeline_var_defintion DEPLOYMENT_DIR "" true)"
        pipelineVariables="$pipelineVariables, $(_get_pipeline_var_defintion azureSubscription ${AZDO_SC_AZURERM_NAME} false)"
        pipelineVariables="$pipelineVariables, $(_get_pipeline_var_defintion FULL_DEPLOYMENT false true)"
        pipelineVariables="$pipelineVariables, $(_get_pipeline_var_defintion gitDiffBaseBranch master true)"
        pipelineVariables="$pipelineVariables, $(_get_pipeline_var_defintion gitDiffCompareBranch \$\(Build.SourceBranch\) true)"
        _create_pipeline pr.infrastructure "/azure-pipelines/pipeline.infrastructure.yml" "infrastructure" "${pipelineVariables}" "${PIPELINE_REPO_NAME}"
    fi
    # Create Dev pipelines
    pipelineVariables=$(_get_pipeline_var_defintion environment dev false)
    pipelineVariables="$pipelineVariables, $(_get_pipeline_var_defintion INSTALL_TYPE ${INSTALL_TYPE} false)"
    pipelineVariables="$pipelineVariables, $(_get_pipeline_var_defintion tfCodeBranch master true)"
    pipelineVariables="$pipelineVariables, $(_get_pipeline_var_defintion NODE_TLS_REJECT_UNAUTHORIZED 0 false)"
    pipelineVariables="$pipelineVariables, $(_get_pipeline_var_defintion azureSubscription ${AZDO_SC_AZURERM_NAME} false)"
    _create_pipeline dev.storageinit "/azure-pipelines/pipeline.storageinit.yml" "infrastructure/utility" "${pipelineVariables}"  "${PIPELINE_REPO_NAME}"

    pipelineVariables=$(_get_pipeline_var_defintion environment dev false)
    pipelineVariables="$pipelineVariables, $(_get_pipeline_var_defintion INSTALL_TYPE ${INSTALL_TYPE} false)"
    pipelineVariables="$pipelineVariables, $(_get_pipeline_var_defintion NODE_TLS_REJECT_UNAUTHORIZED 0 false)"
    pipelineVariables="$pipelineVariables, $(_get_pipeline_var_defintion azureSubscription ${AZDO_SC_AZURERM_NAME} false)"
    _create_pipeline dev.backupremotestate "/azure-pipelines/pipeline.backupremotestate.yml" "infrastructure/utility" "${pipelineVariables}" "${PIPELINE_REPO_NAME}"

    pipelineVariables=$(_get_pipeline_var_defintion environment dev false)
    pipelineVariables="$pipelineVariables, $(_get_pipeline_var_defintion INSTALL_TYPE ${INSTALL_TYPE} false)"
    pipelineVariables="$pipelineVariables, $(_get_pipeline_var_defintion tfCodeBranch master true)"
    pipelineVariables="$pipelineVariables, $(_get_pipeline_var_defintion NODE_TLS_REJECT_UNAUTHORIZED 0 false)"
    pipelineVariables="$pipelineVariables, $(_get_pipeline_var_defintion DEPLOYMENT_DIR "" true)"
    pipelineVariables="$pipelineVariables, $(_get_pipeline_var_defintion azureSubscription ${AZDO_SC_AZURERM_NAME} false)"
    pipelineVariables="$pipelineVariables, $(_get_pipeline_var_defintion FULL_DEPLOYMENT false true)"
    pipelineVariables="$pipelineVariables, $(_get_pipeline_var_defintion gitDiffBaseBranch master true)"
    pipelineVariables="$pipelineVariables, $(_get_pipeline_var_defintion gitDiffCompareBranch \$\(Build.SourceBranch\) true)"
    _create_pipeline dev.infrastructure "/azure-pipelines/pipeline.infrastructure.yml" "infrastructure" "${pipelineVariables}" "${PIPELINE_REPO_NAME}"

    # Create Prod pipelines
    pipelineVariables=$(_get_pipeline_var_defintion environment prod false)
    pipelineVariables="$pipelineVariables, $(_get_pipeline_var_defintion INSTALL_TYPE ${INSTALL_TYPE} false)"
    pipelineVariables="$pipelineVariables, $(_get_pipeline_var_defintion tfCodeBranch master true)"
    pipelineVariables="$pipelineVariables, $(_get_pipeline_var_defintion NODE_TLS_REJECT_UNAUTHORIZED 0 false)"
    pipelineVariables="$pipelineVariables, $(_get_pipeline_var_defintion azureSubscription ${AZDO_SC_AZURERM_NAME} false)"
    _create_pipeline prod.storageinit "/azure-pipelines/pipeline.storageinit.yml" "infrastructure/utility" "${pipelineVariables}" "${PIPELINE_REPO_NAME}"

    pipelineVariables=$(_get_pipeline_var_defintion environment prod false)
    pipelineVariables="$pipelineVariables, $(_get_pipeline_var_defintion INSTALL_TYPE ${INSTALL_TYPE} false)"
    pipelineVariables="$pipelineVariables, $(_get_pipeline_var_defintion NODE_TLS_REJECT_UNAUTHORIZED 0 false)"
    pipelineVariables="$pipelineVariables, $(_get_pipeline_var_defintion azureSubscription ${AZDO_SC_AZURERM_NAME} false)"
    _create_pipeline prod.backupremotestate "/azure-pipelines/pipeline.backupremotestate.yml" "infrastructure/utility" "${pipelineVariables}" "${PIPELINE_REPO_NAME}"

    pipelineVariables=$(_get_pipeline_var_defintion environment prod false)
    pipelineVariables="$pipelineVariables, $(_get_pipeline_var_defintion INSTALL_TYPE ${INSTALL_TYPE} false)"
    pipelineVariables="$pipelineVariables, $(_get_pipeline_var_defintion tfCodeBranch master true)"
    pipelineVariables="$pipelineVariables, $(_get_pipeline_var_defintion NODE_TLS_REJECT_UNAUTHORIZED 0 false)"
    pipelineVariables="$pipelineVariables, $(_get_pipeline_var_defintion azureSubscription ${AZDO_SC_AZURERM_NAME} false)"
    pipelineVariables="$pipelineVariables, $(_get_pipeline_var_defintion FULL_DEPLOYMENT false true)"
    pipelineVariables="$pipelineVariables, $(_get_pipeline_var_defintion gitDiffBaseBranch master true)"
    pipelineVariables="$pipelineVariables, $(_get_pipeline_var_defintion gitDiffCompareBranch \$\(Build.SourceBranch\) true)"
    _create_pipeline prod.infrastructure "/azure-pipelines/pipeline.infrastructure.yml" "infrastructure" "${pipelineVariables}" "${PIPELINE_REPO_NAME}"

    pipelineVariables=$(_get_pipeline_var_defintion environment dev true)
    pipelineVariables="$pipelineVariables, $(_get_pipeline_var_defintion tfCodeBranch master true)"
    pipelineVariables="$pipelineVariables, $(_get_pipeline_var_defintion INSTALL_TYPE ${INSTALL_TYPE} false)"
    _create_pipeline env.compile "/azure-pipelines/pipeline.compile.env.yml" "infrastructure/shared" "${pipelineVariables}" "${PIPELINE_REPO_NAME}"

    pipelineVariables=$(_get_pipeline_var_defintion environment dev true)
    pipelineVariables="$pipelineVariables, $(_get_pipeline_var_defintion INSTALL_TYPE ${INSTALL_TYPE} false)"
    pipelineVariables="$pipelineVariables, $(_get_pipeline_var_defintion tfCodeBranch master true)"
    pipelineVariables="$pipelineVariables, $(_get_pipeline_var_defintion NODE_TLS_REJECT_UNAUTHORIZED 0 false)"
    pipelineVariables="$pipelineVariables, $(_get_pipeline_var_defintion azureSubscription ${AZDO_SC_AZURERM_NAME} true)"
    pipelineVariables="$pipelineVariables, $(_get_pipeline_var_defintion DEPLOYMENT_DIR "XX_layer/XX_deployment" true)"
    pipelineVariables="$pipelineVariables, $(_get_pipeline_var_defintion DEPLOYMENT_DIR "XX_layer/XX_deployment" true)" 
    _create_pipeline tfapply "/azure-pipelines/pipeline.tfapply.yml" "infrastructure/shared" "${pipelineVariables}" "${PIPELINE_REPO_NAME}"

    pipelineVariables=$(_get_pipeline_var_defintion environment dev true)
    pipelineVariables="$pipelineVariables, $(_get_pipeline_var_defintion INSTALL_TYPE ${INSTALL_TYPE} false)"
    pipelineVariables="$pipelineVariables, $(_get_pipeline_var_defintion tfCodeBranch master true)"
    pipelineVariables="$pipelineVariables, $(_get_pipeline_var_defintion NODE_TLS_REJECT_UNAUTHORIZED 0 false)"
    pipelineVariables="$pipelineVariables, $(_get_pipeline_var_defintion azureSubscription ${AZDO_SC_AZURERM_NAME} true)"
    pipelineVariables="$pipelineVariables, $(_get_pipeline_var_defintion DEPLOYMENT_DIR "XX_layer/XX_deployment" true)"
    _create_pipeline tfplan "/azure-pipelines/pipeline.tfplan.yml" "infrastructure/shared" "${pipelineVariables}" "${PIPELINE_REPO_NAME}"

    pipelineVariables=$(_get_pipeline_var_defintion environment dev true)
    pipelineVariables="$pipelineVariables, $(_get_pipeline_var_defintion INSTALL_TYPE ${INSTALL_TYPE} false)"
    pipelineVariables="$pipelineVariables, $(_get_pipeline_var_defintion tfCodeBranch master true)"
    pipelineVariables="$pipelineVariables, $(_get_pipeline_var_defintion NODE_TLS_REJECT_UNAUTHORIZED 0 false)"
    pipelineVariables="$pipelineVariables, $(_get_pipeline_var_defintion azureSubscription ${AZDO_SC_AZURERM_NAME} true)"
    pipelineVariables="$pipelineVariables, $(_get_pipeline_var_defintion DEPLOYMENT_DIR "XX_layer/XX_deployment" true)"
    _create_pipeline tfdestroy "/azure-pipelines/pipeline.tfdestroy.yml" "infrastructure/shared" "${pipelineVariables}" "${PIPELINE_REPO_NAME}"

    pipelineVariables=$(_get_pipeline_var_defintion environment dev true)
    pipelineVariables="$pipelineVariables, $(_get_pipeline_var_defintion INSTALL_TYPE ${INSTALL_TYPE} false)"
    pipelineVariables="$pipelineVariables, $(_get_pipeline_var_defintion tfCodeBranch master true)"
    pipelineVariables="$pipelineVariables, $(_get_pipeline_var_defintion NODE_TLS_REJECT_UNAUTHORIZED 0 false)"
    pipelineVariables="$pipelineVariables, $(_get_pipeline_var_defintion azureSubscription ${AZDO_SC_AZURERM_NAME} true)"
    pipelineVariables="$pipelineVariables, $(_get_pipeline_var_defintion DEPLOYMENT_DIR "" true)"
    _create_pipeline tfdestroy.full "/azure-pipelines/pipeline.tfdestroy.full.yml" "infrastructure/shared" "${pipelineVariables}" "${PIPELINE_REPO_NAME}"

    pipelineVariables=$(_get_pipeline_var_defintion environment dev true)
    pipelineVariables="$pipelineVariables, $(_get_pipeline_var_defintion INSTALL_TYPE ${INSTALL_TYPE} false)"
    pipelineVariables="$pipelineVariables, $(_get_pipeline_var_defintion tfCodeBranch master true)"
    pipelineVariables="$pipelineVariables, $(_get_pipeline_var_defintion NODE_TLS_REJECT_UNAUTHORIZED 0 false)"
    pipelineVariables="$pipelineVariables, $(_get_pipeline_var_defintion azureSubscription ${AZDO_SC_AZURERM_NAME} true)"
    pipelineVariables="$pipelineVariables, $(_get_pipeline_var_defintion DEPLOYMENT_DIR "" true)"
    _create_pipeline generate.tfdestroy.full "/azure-pipelines/pipeline.generate.tfdestroy.full.yml" "infrastructure/utility" "${pipelineVariables}" "${PIPELINE_REPO_NAME}"
}

list_users() {
    _uri=$(_set_api_version "https://vssps.dev.azure.com/${AZDO_ORG_NAME}/_apis/graph/users?api-version=" '5.0-preview.1' '5.0-preview.1')
    request_get $_uri
}

grant_perms_build_svc_account() {

    if [ ${INSTALL_TYPE} == 'SERVER' ]; then
        _information "Granting the build service account 'ALLOW QUEUE' permissions is not supported on Azure DevOps Server.  Skipping..."
        return 0
    fi

    _information "Granting Build Service Account - Allow Queue permissions"

    # AzDo Service     : Users - Get https://docs.microsoft.com/rest/api/azure/devops/graph/users/get?view=azure-devops-rest-5.0
    # AzDo Server 2019 : Users - Get -  ** Not available for Azure DevOps Server 2019 **
    # GET https://vssps.dev.azure.com/<org>/_apis/graph/users/?api-version=5.0-preview.1
    
    _uri=$(_set_api_version "https://vssps.dev.azure.com/${AZDO_ORG_NAME}/_apis/graph/users?api-version=" '5.0-preview.1' '5.0-preview.1')
    _response=$(request_get $_uri)

    _debug_log_get "$_uri" "$_response"

    echo $_response > ./temp/getuser.json

    _principalName=$(cat ./temp/getuser.json | jq -c -r '.value[] | select( .displayName == "'"${AZDO_PROJECT_NAME}"' Build Service ('"${AZDO_ORG_NAME}"')" ) | .principalName')

    # echo $_principalName

    # AzDo Service     : Groups - Get https://docs.microsoft.com/rest/api/azure/devops/graph/groups/get?view=azure-devops-rest-5.1
    # AzDo Server 2019 : Groups - Get  ** Not available for Azure DevOps Server 2019 **
    # GET https://vssps.dev.azure.com/{organization}/_apis/graph/groups/{groupDescriptor}?api-version=5.1-preview.1
    _uri=$(_set_api_version "https://vssps.dev.azure.com/${AZDO_ORG_NAME}/_apis/graph/groups?api-version=" '5.1-preview.1' '5.1-preview.1')
    _response=$(request_get $_uri)

    _debug_log_get "$_uri" "$_response"

    echo $_response > ./temp/getgroups.json

    if [[ "$OSTYPE" == "darwin"* ]]; then
        # Mac OSX
        _groupDomainId=$(cat ./temp/getgroups.json | jq -c -r '.value[] | select( .displayName == "Enterprise Service Accounts" ) | .domain' | ggrep -oP '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}')
    else
        # All Others
        # https://vssps.dev.azure.com/<org>/_apis/graph/groups?api-version=5.1-preview.1

        _groupDomainId=$(cat ./temp/getgroups.json | jq -c -r '.value[] | select( .displayName == "Enterprise Service Accounts" ) | .domain' | grep -oP '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}')
    fi
    # [0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12} https://docs.microsoft.com/windows/win32/wes/eventschema-guidtype-simpletype
    # echo $_groupDomainId

    # AzDo Service     : Security Namespaces - Query https://docs.microsoft.com/rest/api/azure/devops/security/security%20namespaces/query?view=azure-devops-rest-5.1
    # AzDo Server 2019 : Security Namespaces - Query https://docs.microsoft.com/rest/api/azure/devops/security/security%20namespaces/query?view=azure-devops-server-rest-5.0
    # GET https://dev.azure.com/<org>/_apis/securitynamespaces?api-version=5.1

    _uri=$(_set_api_version "${AZDO_ORG_URI}/_apis/securitynamespaces?api-version=" '5.1-preview.1' '5.1')
    _response=$(request_get $_uri)

    _debug_log_get "$_uri" "$_response"

    echo $_response > ./temp/getsecnamespaces.json

    _namespaceId=$(cat ./temp/getsecnamespaces.json | jq -c -r '.value[] | select( .name == "Build" ) | .namespaceId')

    _debug "Namespace id: ${_namespaceId}"

    # AzDo Service     : Access Control Entries - Set Access Control Entries - https://docs.microsoft.com/rest/api/azure/devops/security/access%20control%20entries/set%20access%20control%20entries?view=azure-devops-server-rest-5.0
    # AzDo Server 2019 : Access Control Entries - Set Access Control Entries - https://docs.microsoft.com/rest/api/azure/devops/security/access%20control%20entries/set%20access%20control%20entries?view=azure-devops-server-rest-5.0
    # POST https://dev.azure.com/<org>/_apis/AccessControlEntries/33344d9c-fc72-4d6f-aba5-fa317101a7e9?api-version=5.1
    _payload=$(cat "payloads/template.perm.json" | sed 's~__PRINCIPAL_NAME__~'"${_principalName}"'~' | sed 's~__GROUP_DOMAIN_ID__~'"${_groupDomainId}"'~')
    echo $_payload > ./temp/perm.json

    _uri=$(_set_api_version "${AZDO_ORG_URI}/_apis/AccessControlEntries/${_namespaceId}?api-version=" '5.1' '5.1')

    request_post $_uri "$_payload"


    echo $_response > ./temp/setace.json    
    
    _success "\nPermissions granted"
}


grant_perms_build_svc_account_library() {

    _information "Granting Build Service Account for Lib - Allow Queue permissions"
    _information "AZDO_PROJECT_ID = ${AZDO_PROJECT_ID}"

    # AzDo Service     : Users - Get https://docs.microsoft.com/rest/api/azure/devops/graph/users/get?view=azure-devops-rest-5.0
    # AzDo Server 2019 : Users - Get -  ** Not available for Azure DevOps Server 2019 **
    # GET https://vssps.dev.azure.com/<org>/_apis/graph/users/?api-version=5.0-preview.1

    local _principalName=''''
    local _originId=''
    
    if [ ${INSTALL_TYPE} == 'SERVER' ]; then
        sleep 10
        _uri=$(_set_api_version "${AZDO_ORG_URI}/_apis/securityroles/scopes/distributedtask.library/roleassignments/resources/${AZDO_PROJECT_ID}%240?api-version" '5.0-preview.1' '5.0-preview.1')
        _debug "roleassignments uri: $_uri"
        _response=$(request_get $_uri)
        echo $_response > ./temp/getuser.json

        _principalName=${AZDO_PROJECT_ID}
        _originId=$(cat ./temp/getuser.json |  jq -c -r '.value[].identity | select( .displayName == "'"${AZDO_PROJECT_NAME} Build Service (ProjectCollection)"'" ) | .id')

        _debug "_principalName: $_principalName"
        _debug "_originId: $_originId"

    else
        _uri=$(_set_api_version "https://vssps.dev.azure.com/${AZDO_ORG_NAME}/_apis/graph/users?api-version=" '5.0-preview.1' '5.0-preview.1')
        _response=$(request_get $_uri)

        _debug_log_get "$_uri" "$_response"
        
        echo $_response > ./temp/getuser.json

        _principalName=$(cat ./temp/getuser.json | jq -c -r '.value[] | select( .displayName == "'"${AZDO_PROJECT_NAME}"' Build Service ('"${AZDO_ORG_NAME}"')" ) | .principalName')
        _originId=$(cat ./temp/getuser.json | jq -c -r '.value[] | select( .displayName == "'"${AZDO_PROJECT_NAME}"' Build Service ('"${AZDO_ORG_NAME}"')" ) | .originId')
    fi    
    

    _debug "_principalName: $_principalName"
    _debug "_originId: $_originId"
    
    _uri=$(_set_api_version "${AZDO_ORG_URI}/_apis/securityroles/scopes/distributedtask.library/roleassignments/resources/${_principalName}%240?api-version=" '5.1-preview.1' '5.1-preview.1')
    _debug $_uri
    _payload=$(cat "payloads/template.build-service-library-permissions.json" | sed 's~__ORIGIN_ID__~'"${_originId}"'~')
    _debug $_payload

    _response=$(request_put $_uri $_payload)
    echo $_response > ./temp/build-service-permission-response.json

    _success "\nPermissions granted"
}

updateAgentPools(){
  if [ "$INSTALL_TYPE" == "PAAS" ]; then
        _information "Running on Azure DevOps Service. Skipping Agent Pool Update of yaml."
    else
        _information "Running on Azure DevOps Server! Updating Agent Pool references to use Default agent pool."
        _information "Cloning Project Repo: "$PIPELINE_REPO_GIT_HTTP_URL

        TEMP_DIR=~/git_repos/${AZDO_PROJECT_NAME}/${PIPELINE_REPO_NAME}
        clone_repo $TEMP_DIR $PIPELINE_REPO_GIT_HTTP_URL
        
        pushd $TEMP_DIR
            yamlFiles=$(grep -lrnw "$TEMP_DIR/azure-pipelines" -e 'vmImage: "ubuntu-latest"' || true)
            if [ ! -z "${yamlFiles}" ]; then
                for file in $yamlFiles
                do
                    echo "Updating pipeline yaml for: $file"
                    sed -i 's/pool://g' $file
                    sed -i 's/  vmImage: "ubuntu-latest"/pool: "Default"/g' $file
                done

                #commit updated pipelines to the repo
                git add azure-pipelines/*

                git config user.email "installer@terraform-template.com"
                git config user.name "Terraform template"

                git commit -m "Adding updated Pipelines"

                git_push
            else
                _information "No yaml files found with hosted ubuntu agents. Skipping update of agent pool in yaml."
            fi
        popd

        #delete local copy of repo
        rm -rf $TEMP_DIR
    fi
}

_get_project_id() {
    _uri="${AZDO_ORG_URI}/_apis/projects/${AZDO_PROJECT_NAME}?api-version=5.1-preview.2"
    _response=$(request_get "${_uri}")
    
    _projectId=$(echo $_response | jq -c -r '.id')
    echo $_projectId
}

_get_default_team() {
    _uri="${AZDO_ORG_URI}/_apis/projects/${AZDO_PROJECT_NAME}/teams?api-version=5.1-preview.2"
    _response=$(request_get "${_uri}")
    _defaultTeamId=$(echo $_response | jq -c -r '.value[] | select(.name == "'"${AZDO_PROJECT_NAME}"' Team") | .id')
    echo $_defaultTeamId
}

_add_user() {
    _projectId=$1
    _defaultTeamId=$2
    _upn=$3

    _payload=$(cat "payloads/template.add-user.json" | sed 's~__PROJECT_ID__~'"${_projectId}"'~' | sed 's~__TEAM_ID__~'"${_defaultTeamId}"'~' | sed 's~__UPN__~'"${_upn}"'~')
    _uri="https://vsaex.dev.azure.com/${AZDO_ORG_NAME}/_apis/UserEntitlements?doNotSendInviteForNewUsers=true&api-version=5.1-preview.3"

    _response=$(request_post "${_uri}" "${_payload}")

    _debug_log_post "$_uri" "$_response" "$_payload"
}

try_add_users() {

    if [ ${INSTALL_TYPE} == 'SERVER' ]; then
        _information "Add users is not supported on Azure DevOps Server.  Skipping..."
        return 0
    fi

    _projectId=$(_get_project_id)
    _defaultTeamId=$(_get_default_team)

    INPUT=users.csv

    if [ -f "$INPUT" ]; then   
        OLDIFS=$IFS
        IFS=$'\r'

        while read upn; do
            _add_user $_projectId $_defaultTeamId $upn
        done <$INPUT

        IFS=$OLDIFS
    fi
}

credScanRemovalForAzDoServer(){
    if [ "$INSTALL_TYPE" != "PAAS" ]; then
        _information "Running on Azure DevOps Server! Removing CredScan Task"
        _information "Cloning Project Repo: "$PIPELINE_REPO_GIT_HTTP_URL

        TEMP_DIR=~/git_repos/${AZDO_PROJECT_NAME}/${PIPELINE_REPO_NAME}
        clone_repo $TEMP_DIR $PIPELINE_REPO_GIT_HTTP_URL

        templatePath="azure-pipelines/templates/template.stage.infrastructure.yml"

        pushd $TEMP_DIR
            #Remove Cred Scan Section (multi-line delete)
            sed -i '/# Check for Credentials #/,+12 d' $templatePath

            #commit updated pipeline template to the repo
            git add  $templatePath

            git config user.email "installer@terraform-template.com"
            git config user.name "Terraform template"

            git commit -m "Removing CredScan Task"

            git_push
        popd

        #delete local copy of repo
        rm -rf $TEMP_DIR
    fi
}

cleanUpPipelineArtifactForAzdoServer(){
    if [ "$INSTALL_TYPE" != "PAAS" ]; then
        _information "Running on Azure DevOps Server! Removing Publish Pipeline Artifacts"
        _information "Cloning Project Repo: "$PIPELINE_REPO_GIT_HTTP_URL

        TEMP_DIR=~/git_repos/${AZDO_PROJECT_NAME}/${PIPELINE_REPO_NAME}
        clone_repo $TEMP_DIR $PIPELINE_REPO_GIT_HTTP_URL

        pushd $TEMP_DIR

            git config user.email "installer@terraform-template.com"
            git config user.name "Terraform template"

            #Remove Publish Pipeline Artifact from Tf Plan pipeline
            _information "Removing PublishPipelineArtifact from pipeline.tfplan.yml"
            file="azure-pipelines/pipeline.tfplan.yml"
            sed -i '/task: PublishPipelineArtifact@1/,+3 d' $file
      
            git add $file
            git commit -m "Removing Publish Artifact from tfPlan pipeline" --allow-empty

            #Remove Publish Pipeline Artifact from Infrastructure Stage
            _information "Converting PublishPipelineArtifact to PublishBuildArtifacts in template.stage.infrastructure.yml"
            file='azure-pipelines/templates/template.stage.infrastructure.yml'                      
            sed -i 's/task: PublishPipelineArtifact@1/task: PublishBuildArtifacts@1/g' $file
            sed -i "s/targetPath: '\$(Build.ArtifactStagingDirectory)'/PathtoPublish: '\$(Build.ArtifactStagingDirectory)'/g" $file
            sed -i "s/artifact: 'script'/ArtifactName: 'script'/g" $file
            sed -i "s/publishLocation: 'pipeline'/publishLocation: 'Container'/g" $file
            git add  $file
            git commit -m "Converting PublishPipelineArtifact to PublishBuildArtifacts in template.stage.infrastructure.yml"

            git_push
        popd

        #delete local copy of repo
        rm -rf $TEMP_DIR
    fi
}

run_env_compile_pipeline(){
    # https://${AZDO_ORG_URI}/${AZDO_PROJECT_NAME}/_apis/pipelines/${PIPELINE_ID}/runs
    _uri=$(_set_api_version "${AZDO_ORG_URI}/${AZDO_PROJECT_NAME}/_apis/build/builds?api-version=" '5.1' '5.1')
    _payload=$(cat "payloads/template.env-compile-run.json" | sed 's~__PIPELINE_ID__~'"${envCompilePipelineId}"'~')

    _debug $_uri
    _debug $_payload

    _response=$(request_post "$_uri" "$_payload")
    echo $_response > 'temp/run-env-compile-pipeline-response.json'
    _success "Started Env Compile Pipeline"
}

configure_private_cloud() {
    if [ "${PRIVATE_CLOUD}" == true ];then
        _information "Private Cloud: Setting up configs for private cloud support."
        configPath=~/.lucidity_config/
        echo "${configPath}"
        if [ ! -d "$configPath" ]; then
            _debug "Creating ${configPath}"
            mkdir "${configPath}"
        fi
        AZURE_ENVIRONMENT_FILEPATH="${configPath}private.cloud.json"  
        cp "payloads/private.cloud.json" "${AZURE_ENVIRONMENT_FILEPATH}"   

        TEMP_DIR=~/git_repos/${AZDO_PROJECT_NAME}/${PIPELINE_REPO_NAME}
        clone_repo $TEMP_DIR $PIPELINE_REPO_GIT_HTTP_URL
        
        cp ./payloads/template.pipeline.tfplan-private.yml $TEMP_DIR/azure-pipelines/pipeline.tfplan.yml
        cp ./payloads/template.pipeline.tfapply-private.yml $TEMP_DIR/azure-pipelines/pipeline.tfapply.yml

        pushd $TEMP_DIR
            git config user.email "installer@terraform-template.com"
            git config user.name "Terraform template"
                
            git add azure-pipelines/pipeline.tfapply.yml
            git commit -m "Adding pipeline.tfapply.yml for private" --allow-empty

            git add azure-pipelines/pipeline.tfplan.yml
            git commit -m "Adding pipeline.tfplan.yml for private" --allow-empty

            git_push
        popd

        #delete local copy of repo
        rm -rf $TEMP_DIR        
    fi

}

configure_checkout_template(){
     
    _information "Configuring Checkout Template Project Repo: "$PIPELINE_REPO_GIT_HTTP_URL

    TEMP_DIR=~/git_repos/${AZDO_PROJECT_NAME}/${PIPELINE_REPO_NAME}
    
    _debug "TEMP_DIR: ${TEMP_DIR}"

    clone_repo $TEMP_DIR $PIPELINE_REPO_GIT_HTTP_URL
    file="template.step.checkout.terraform-code.yml"
    destinationFile="$TEMP_DIR/azure-pipelines/templates/$file"
    cp "./payloads/$file" "$TEMP_DIR/azure-pipelines/templates"
    
     pushd $TEMP_DIR

        git config user.email "installer@terraform-template.com"
        git config user.name "Terraform template"

        #Remove Publish Pipeline Artifact from Tf Plan pipeline
        _information "Removing PublishPipelineArtifact from pipeline.tfplan.yml"

        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS sed requires extra '' after -i for in place updates.
            sed -i '' "s/__AZDO_PROJECT_NAME__/${AZDO_PROJECT_NAME}/g" $destinationFile
        else
            sed -i "s/__AZDO_PROJECT_NAME__/${AZDO_PROJECT_NAME}/g" $destinationFile
        fi

        git add -A
        git commit -m "Adding checkout template with project name" --allow-empty

        git_push
    popd

    #delete local copy of repo
    rm -rf $TEMP_DIR
 
}

_get_build_policy_id() {
    # https://docs.microsoft.com/rest/api/azure/devops/policy/configurations/list?view=azure-devops-rest-5.1
    # GET https://dev.azure.com/{organization}/{project}/_apis/policy/configurations?api-version=5.1
    local _response=$(request_get "${AZDO_ORG_URI}/${AZDO_PROJECT_NAME}/_apis/policy/types?api-version=5.1")
    echo $_response > "temp/policy.types.response.json"
    local _buildPolicy=$(cat "temp/policy.types.response.json" | jq -r '.value[] | select(.displayName == "Build") | .id' )
    echo $_buildPolicy
}


configure_pr_build_policy() {
    if [ ${INSTALL_TYPE} == 'SERVER' ]; then
      _information "skipping configure pr build policy. Install targets AzDo Server 2020"
      return 0
    fi
        
    _information "Creating PR Pipeline Build Policy on Terraform-Code Repo"
    # https://docs.microsoft.com/rest/api/azure/devops/policy/configurations/create?view=azure-devops-rest-5.1#build-policy
    # POST https://dev.azure.com/{organization}/{project}/_apis/policy/configurations/{configurationId}?api-version=5.1
    local _buildPolicyId=$(_get_build_policy_id)
    local _uri=$(_set_api_version "${AZDO_ORG_URI}/${AZDO_PROJECT_NAME}/_apis/policy/configurations/?api-version=" '5.0' '5.0')
    local _payload=$(cat "payloads/template.build-policy.json" | sed 's~__POLICY_ID__~'"${_buildPolicyId}"'~' | sed 's~__REPOSITORY_ID__~'"${CODE_REPO_ID}"'~' | sed 's~__PIPELINE_ID__~'"${prPipelineId}"'~')
    echo $_payload > temp/build-policy.payload.json
    
    local _response=$(request_post "$_uri" "$_payload")
    echo $_response > 'temp/build-policy-response.json'
    
    local _importTypeKey=$(echo $_response | jq -r '.typeKey')   
}

configure_destroy_full_pipeline(){
     
    _information "Configuring Checkout Template Project Repo: "$PIPELINE_REPO_GIT_HTTP_URL

    TEMP_DIR=~/git_repos/${AZDO_PROJECT_NAME}/${PIPELINE_REPO_NAME}
    
    _debug "TEMP_DIR: ${TEMP_DIR}"

    clone_repo $TEMP_DIR $PIPELINE_REPO_GIT_HTTP_URL
    file="template.pipeline.tfdestroy.full.yml"
    destinationFile="$TEMP_DIR/azure-pipelines/pipeline.tfdestroy.full.yml"
    sourcePath="../../../Terraform-Code/terraform "
    cp "./payloads/$file" "$TEMP_DIR/azure-pipelines/pipeline.tfdestroy.full.yml"
     ../../azure-pipelines/scripts/generatematrix.sh $destinationFile $sourcePath

     pushd $TEMP_DIR
        git config user.email "installer@terraform-template.com"
        git config user.name "Terraform template"  
      
        git add -A
        git commit -m "Adding Full Destroy Pipeline yaml" --allow-empty

        git_push
    popd

    #delete local copy of repo
    rm -rf $TEMP_DIR
 
}

grant_perms_build_svc_account_terraform_code_repo() {

    _information "Granting Build Service Account - Contributor Access to Terraform-Code Repo"

    if [ ${INSTALL_TYPE} == 'SERVER' ]; then
        _information "Granting the Granting Build Service Account - Contributor Access to Terraform-Code Repo is not supported on Azure DevOps Server.  Skipping..."
        return 0
    fi

    # AzDo Service     : Groups - Get https://docs.microsoft.com/rest/api/azure/devops/graph/groups/get?view=azure-devops-rest-5.1
    # AzDo Server 2019 : Groups - Get  ** Not available for Azure DevOps Server 2019 **
    # GET https://vssps.dev.azure.com/{organization}/_apis/graph/groups/{groupDescriptor}?api-version=5.1-preview.1
    _uri=$(_set_api_version "https://vssps.dev.azure.com/${AZDO_ORG_NAME}/_apis/graph/groups?api-version=" '5.1-preview.1' '5.1-preview.1')
    _response=$(request_get $_uri)

    _debug_log_get "$_uri" "$_response"

    echo $_response > ./temp/getgroups-tf-code.json

    if [[ "$OSTYPE" == "darwin"* ]]; then
        # Mac OSX
        _groupDomainId=$(cat ./temp/getgroups-tf-code.json | jq -c -r '.value[] | select( .displayName == "Enterprise Service Accounts" ) | .domain' | ggrep -oP '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}')
    else
        # All Others
        # https://vssps.dev.azure.com/<org>/_apis/graph/groups?api-version=5.1-preview.1

        _groupDomainId=$(cat ./temp/getgroups-tf-code.json | jq -c -r '.value[] | select( .displayName == "Enterprise Service Accounts" ) | .domain' | grep -oP '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}')
    fi

    # AzDo Service     : Security Namespaces - Query https://docs.microsoft.com/rest/api/azure/devops/security/security%20namespaces/query?view=azure-devops-rest-5.1
    # AzDo Server 2019 : Security Namespaces - Query https://docs.microsoft.com/rest/api/azure/devops/security/security%20namespaces/query?view=azure-devops-server-rest-5.0
    # GET https://dev.azure.com/<org>/_apis/securitynamespaces?api-version=5.1

    _uri=$(_set_api_version "${AZDO_ORG_URI}/_apis/securitynamespaces?api-version=" '5.1-preview.1' '5.0')
    _response=$(request_get $_uri)

    _debug_log_get "$_uri" "$_response"

    echo $_response > ./temp/getsecnamespaces-tf-code.json

    _namespaceId=$(cat ./temp/getsecnamespaces-tf-code.json | jq -c -r '.value[] | select( .name == "Git Repositories" ) | .namespaceId')

    _debug "Git Repositories Namespace id: ${_namespaceId}"

    # AzDo Service     : Access Control Entries - Set Access Control Entries - https://docs.microsoft.com/rest/api/azure/devops/security/access%20control%20entries/set%20access%20control%20entries?view=azure-devops-server-rest-5.0
    # AzDo Server 2019 : Access Control Entries - Set Access Control Entries - https://docs.microsoft.com/rest/api/azure/devops/security/access%20control%20entries/set%20access%20control%20entries?view=azure-devops-server-rest-5.0
    # POST https://dev.azure.com/<org>/_apis/AccessControlEntries/33344d9c-fc72-4d6f-aba5-fa317101a7e9?api-version=5.1
    _payload=$(cat "payloads/template.perm.tfcoderepo.json" | sed 's~__PROJECT_ID__~'"${AZDO_PROJECT_ID}"'~' | sed 's~__GROUP_DOMAIN_ID__~'"${_groupDomainId}"'~' | sed 's~__REPOSITORY_ID__~'"${PIPELINE_REPO_ID}"'~')
    echo $_payload > ./temp/perm-payload-tfcode.json

    _uri=$(_set_api_version "${AZDO_ORG_URI}/_apis/AccessControlEntries/${_namespaceId}?api-version=" '5.0' '5.0')
    _debug "url: $_uri"
    _response=$(request_post $_uri "$_payload")
    _debug_log_post "$_uri" "$_response" "$_payload"

    echo $_response > ./temp/setace-tfcoderepo.json    
    
    _success "\nPermissions granted"
}
#MAIN
mkdir -p ./temp

check_input
parse_sp "${SP_RAW}"
set_login_pat
create_project
if [ "${OFFLINE_INSTALL}"  == true ]; then
    if [ ${INSTALL_TYPE} == 'SERVER' ]; then
        if [ "${SOURCE_LOCAL_PATH}" == "" ]; then
            SOURCE_LOCAL_PATH=~/tfsource
        fi
        offline_install_template_repo "${PIPELINE_REPO_NAME}" "${PIPELINE_REPO_GIT_HTTP_URL}" "${SOURCE_LOCAL_PATH}/Terraform-Pipelines"
        offline_install_template_repo "${CODE_REPO_NAME}" "${CODE_REPO_GIT_HTTP_URL}" "${SOURCE_LOCAL_PATH}/Terraform-Code"
    else
        offline_install_template_repo "${PIPELINE_REPO_NAME}" "${PIPELINE_REPO_GIT_HTTP_URL}" ../../
        offline_install_template_repo "${CODE_REPO_NAME}" "${CODE_REPO_GIT_HTTP_URL}" ../../../Terraform-Code
    fi
else
    import_multi_template_repo "${PIPELINE_REPO_NAME}" "${TEMPLATE_PIPELINE_REPO}"
    import_multi_template_repo "${CODE_REPO_NAME}" "${TEMPLATE_CODE_REPO}"
fi
install_extensions
create_arm_svc_connection
create_azdo_svc_connection
configure_private_cloud
create_variable_groups
create_pr_variable_group
create_and_upload_pr_state_secfile
configure_destroy_full_pipeline
create_pipelines
if [ "${USE_EXISTING_ENVS}" == false ]; then
    create_default_env_files
fi
try_add_users
updateAgentPools
credScanRemovalForAzDoServer
cleanUpPipelineArtifactForAzdoServer
grant_perms_build_svc_account
configure_checkout_template
configure_pr_build_policy
if [ ${INSTALL_TYPE} == 'SERVER' ]; then
    run_env_compile_pipeline # Run the pipeline once in order to generate the build service account role.
fi
grant_perms_build_svc_account_library
run_env_compile_pipeline
grant_perms_build_svc_account_terraform_code_repo
echo ""
_success "**** Successfully Created ${AZDO_PROJECT_NAME} in ${AZDO_ORG_URI}! ****"

if [ $DEBUG_FLAG == false ]; then
    rm -rf ./temp
fi