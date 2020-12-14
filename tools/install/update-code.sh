
#!/usr/bin/env bash
me=`basename "$0"`
_error() {
    printf "\e[31mERROR: $@\n\e[0m"
}

_debug() {
    #Only print debug lines if debugging is turned on.
    if [ "$DEBUG_FLAG" == true ]; then
        msg="$@"
        LIGHT_CYAN='\033[0;35m'
        NC='\033[0m'
        printf "DEBUG: ${NC} %s ${NC}\n" "${msg}"
    fi
}

_information() {
    printf "\e[36m$@\n\e[0m"
}

_success() {
    printf "\e[32m$@\n\e[0m"
}

usage() {
    _helpText="    Usage: $me
        -l | --server <Azure DevOps Server and Collection> (Ex. server/collectionName)
            Must specify the server and collection name
            Must also use -u parameter to specify the user 
        -n | --name <AZDO_PROJECT_NAME>        
        -p | --pat <AZDO_PAT>
        -t | --tarFilePath <Path to .tar.gz file>
        -d | --debug Turn debug logging on
        -h | --help Show the usuage help (this.)"
        
    _information "$_helpText" 1>&2
    exit 1
}

_set_api_version(){
    uri=$1
    paas_version=$2
    server_version=$3
    
    if [ "$INSTALL_TYPE" == "PAAS" ]; then
        echo "$1$2"
    else
        echo "$1$3"
    fi
}

request_get(){
    request_uri=${1}

    local _response

    _token=$(echo -n "${AZDO_PAT}")
    _user=${AZDO_USER}':'${_token}
    _response=$(curl \
        --silent \
        --location \
        --header 'Content-Type: application/json; charset=utf-8' \
        -u  ${_user} \
        --request GET ${request_uri} )
  
    echo $_response 
}

#Script Parameters (Required)
declare AZDO_ORG_NAME=''
declare AZDO_PROJECT_NAME=''
declare AZDO_ORG_URI=''
declare AZDO_PAT=''
declare REPO_BASE=''
declare AZDO_PROJECT_ID=''
declare CODE_REPO_NAME='Terraform-Code'
declare INSTALL_TYPE='PAAS'
declare CODE_REPO_GIT_HTTP_URL=''
declare CODE_REPO_ID=''
declare WORK_DIR=~/work
declare PATH_TO_TAR_FILE=''
declare DEBUG_FLAG=false

# Initialize parameters specified from command line
while [[ "$#" -gt 0 ]]
do
  case $1 in
    -l | --server )
        # Azure DevOps Server
        AZDO_ORG_NAME=$2
        AZDO_ORG_URI="https://$2"    
        INSTALL_TYPE='SERVER'    
        ;;  
    -n | --name )
        AZDO_PROJECT_NAME=$2
        ;;  
    -h | --help)
        usage
        exit 0
        ;;
    -p | --pat )
        AZDO_PAT=$2
        ;;
    -t | --tarFilePath )
        PATH_TO_TAR_FILE=$2
        ;;
    -d | --debug )             
        DEBUG_FLAG=true
        ;;         
  esac  
  shift
done

checkInputParameters(){
    if [ ! -f "$PATH_TO_TAR_FILE" ]; then
        _error "${PATH_TO_TAR_FILE} does not exist. Please provide a complete path to the tar file with the update to Terraform-Code."
        exit 1
    fi
}

getProjectId(){
    _information "Fetching Project id for ${AZDO_PROJECT_NAME}"
    _uri="${AZDO_ORG_URI}/_apis/projects?api-version=5.0"
    _response=$(request_get $_uri)
    AZDO_PROJECT_ID=$(echo $_response | jq -r '.value[] | select (.name == "'"${AZDO_PROJECT_NAME}"'") | .id')    
    _information "Project Id: ${AZDO_PROJECT_ID}"
}

getCodeRepoGitUri(){
    _uri=$(_set_api_version "${AZDO_ORG_URI}/${AZDO_PROJECT_NAME}/_apis/git/repositories/${CODE_REPO_NAME}?api-version=" '5.1' '5.1')
    _debug "Fetching ${CODE_REPO_NAME} repository information"
    _response=$( request_get ${_uri}) 
    CODE_REPO_GIT_HTTP_URL=$(echo $_response | jq -c -r '.remoteUrl')
    CODE_REPO_ID=$(echo $_response | jq -c -r '.id')
    _debug "CODE_REPO_GIT_HTTP_URL: $CODE_REPO_GIT_HTTP_URL"
    _debug "CODE_REPO_ID: $CODE_REPO_ID"
    _information "${CODE_REPO_NAME} Git Repo remote URL: "$CODE_REPO_GIT_HTTP_URL
}

syncCodeRepo(){
    mkdir -p ${WORK_DIR}
    _token=$(echo -n ":${AZDO_PAT}" | base64)
    local tarFlags="-zxf"
    local gitVerbosity="-q"
    if [ "${DEBUG_FLAG}" == true ]; then
        tarFlags="-zxvf"
        gitVerbosity="-v"
    fi

    tar ${tarFlags} ${PATH_TO_TAR_FILE} -C ${WORK_DIR}
    cd ${WORK_DIR}/Terraform-Code
    git remote set-url origin ${CODE_REPO_GIT_HTTP_URL} 
    
    git -c http.extraHeader="Authorization: Basic ${_token}" pull ${gitVerbosity}
    git -c http.extraHeader="Authorization: Basic ${_token}" fetch ${gitVerbosity}
    git -c http.extraHeader="Authorization: Basic ${_token}" push -u origin --all  ${gitVerbosity}
}

cleanUp(){
    _information "Deleting work dir ${WORK_DIR}"
    rm -rf ${WORK_DIR}
}
#trap 'cleanUp' EXIT

checkInputParameters
getProjectId
getCodeRepoGitUri
syncCodeRepo


