#!/bin/bash

set -euo pipefail

usage() {
    echo "Usage: publish.sh -o <AZDO_ORG_NAME> SEE README FOR MORE INFORMATION" 1>&2
    exit 1
}

#Script Parameters (Required)
declare ORG_NAME=''
declare REPO_PIPELINE_NAME='Terraform-Pipelines'
declare REPO_CODE_NAME='Terraform-Code'
#LOCALS
WORKING_DIR=~/public_proj_work_dir

# Initialize parameters specified from command line
while getopts ":o:n:p:r:s:" arg; do
    case "${arg}" in
    o)
        ORG_NAME=${OPTARG}
        ;;    
    esac
done
shift $((OPTIND - 1))


#Main


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
    echo "Cloning - git@github.com:$ORG_NAME/$REPO_PIPELINE_NAME.git"
    git clone "git@github.com:$ORG_NAME/$REPO_PIPELINE_NAME.git" $repoWorkDir/${repoName}

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
    rm -rf $repoWorkDir
}

push_repo_to_project "$REPO_PIPELINE_NAME" "../"

echo "Completed publishing the terraform template..."

rm -rf $WORKING_DIR
echo "Deleted working directory"

