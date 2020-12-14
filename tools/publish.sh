#!/bin/bash

set -euo pipefail

usage() {
    echo "Usage: publish.sh -o <AZDO_ORG_NAME> SEE README FOR MORE INFORMATION" 1>&2
    exit 1
}

#Script Parameters (Required)
declare AZDO_ORG_NAME=''
declare AZDO_ORG_URI=''
declare AZDO_PROJECT_NAME='terraform-template-public'
declare REPO_PIPELINE_NAME='Terraform-Pipelines'
declare REPO_CODE_NAME='Terraform-Code'
#LOCALS
WORKING_DIR=~/public_proj_work_dir

# Initialize parameters specified from command line
while getopts ":o:n:p:r:s:" arg; do
    case "${arg}" in
    o)
        AZDO_ORG_NAME=${OPTARG}
        AZDO_ORG_URI="https://dev.azure.com/${OPTARG}"
        ;;
    n)
        AZDO_PROJECT_NAME=${OPTARG}
        ;;        
    esac
done
shift $((OPTIND - 1))

check_input() {
    echo "Validating Inputs..."
    if [ -z "$AZDO_ORG_NAME" ]; then
        echo "Required parameter -o (ORG) not set."
        usage
        return 1
    fi
}

#Main
check_input

#Delete the current public project
PUBLIC_PROJECT_ID=`az devops project show --org ${AZDO_ORG_URI} -p ${AZDO_PROJECT_NAME} --query id -o tsv` && az devops project delete --id $PUBLIC_PROJECT_ID -y --org ${AZDO_ORG_URI} 
echo "Deleted the existing public project"
#Recreate the project
echo "Creating public project"
az devops project create --name ${AZDO_PROJECT_NAME} --org ${AZDO_ORG_URI} --process Agile --source-control git --visibility public

#Create Repos
az repos create --name ${REPO_CODE_NAME} --project ${AZDO_PROJECT_NAME} --org ${AZDO_ORG_URI}
az repos create --name ${REPO_PIPELINE_NAME} --project ${AZDO_PROJECT_NAME} --org ${AZDO_ORG_URI}

if [ -d "$WORKING_DIR" ]; then rm -Rf $WORKING_DIR; fi
mkdir -p $WORKING_DIR

push_repo_to_project(){
    local repoName=$1
    local repoPath=$2
    local repoWorkDir="$WORKING_DIR/$repoName"
    if [ -z "$repoName" ]; then
      echo "Repo name is missing from push repo to project"
    fi

    #create the working directory and scratch directory
    echo "Creating scratch dir and copying content to publish."
    if [ -d "$repoWorkDir" ]; then rm -Rf "repoWorkDir"; fi
    mkdir -p "$repoWorkDir"
    mkdir -p "$repoWorkDir/scratch"

    #clone the new project default repository
    git clone git@ssh.dev.azure.com:v3/${AZDO_ORG_NAME}/${AZDO_PROJECT_NAME}/${repoName} $repoWorkDir/${repoName}

    #copy files to the scratch directory
    rsync -av --progress $repoPath $repoWorkDir/scratch --exclude .git --exclude .DS_Store --exclude dev.env --exclude terraform.tfstate --exclude .terraform --exclude env.sh

    #delete any environments used in development project
    rm -rf $repoWorkDir/scratch/environments

    #switch to cloned repo directory
    pushd $repoWorkDir/${repoName}

        echo "Committing publish commit..."

        #copy scratch into cloned repo
        cp -a ../scratch/. .

        git add .

        #commit the published files
        git commit -m "Initial publish commit"

        git push 

        echo "published to master..."

    popd
    #rm -rf $repoWorkDir
}

push_repo_to_project "$REPO_PIPELINE_NAME" "../"
push_repo_to_project "$REPO_CODE_NAME" "../../Terraform-Code/"

echo "Completed publishing the terraform template..."

#rm -rf $WORKING_DIR
echo "Deleted working directory"

