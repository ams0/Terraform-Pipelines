#!/usr/bin/env bash

source ../install/lib/shell_logger.sh

declare input=$1
declare me=`basename "$0"`

main() {
  case $input in
    create)
      create
      ;;

    -h )
      usage
      exit 0
      ;;
    *)
      _error "Unkown command $input"
      usage
      exit 1      
      ;;
  esac  
}

create() {
  local zipFile=''
  local scriptPath=$(pwd)
  local bundleConfigPath=$scriptPath/terrraform-bundle.hcl 
  local os="linux"
  local arch="amd64"
  local outputFile="terraform-binaries.tar.gz"

  git clone https://github.com/hashicorp/terraform.git

  mkdir -p work_dir

  pushd terraform/tools/terraform-bundle
    go run . package  -os=$os -arch=$arch $bundleConfigPath
    zipFile=$(ls *.zip)
    mv ./$zipFile $scriptPath/work_dir
  popd

  pushd ./work_dir
    #Open Bundle Zip to add older veresion of terraform and custom scripts
    unzip ./$zipFile 
    
    # Add Terrform 0.12.129
    wget https://releases.hashicorp.com/terraform/0.12.29/terraform_0.12.29_linux_amd64.zip
    mkdir tmp
    unzip terraform_0.12.29_linux_amd64.zip -d tmp
    mv tmp/terraform ./terraform0.12.29

    #Cleanup
    rm terraform_0.12.29_linux_amd64.zip
    rm -rf tmp

    #Add Custom Scripts
    cp ../scripts/install.sh .
    chmod +x install.sh

    cp ../scripts/setup_012x.sh plugins
    chmod +x plugins/setup_012x.sh

    rm $zipFile

    # Create the Final Tar file
    tar -czvf ../$outputFile . 
  popd

  # Script Cleanup
  rm -rf ./work_dir

  echo "Terraform Bundle file $outputFile was created!"
}

usage() {
      _helpText="
Usage: $me <command>

commands:
create   - create terraform-bundle binary
help    - show help text (this)

If a command is ommited, it will default to running an install with the default version 0.13.4.

example:
./$me create
"
        
    _information "$_helpText" 1>&2
}

main



