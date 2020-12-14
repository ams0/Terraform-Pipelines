#!/usr/bin/env bash

declare input=$1

main() {
  case $input in

    list)
      echo "0.13.4 (default)"
      echo "0.12.29"
      exit 0
      ;;

    help)
      usage
      exit 0
      ;;

    0.12.29)
      echo "Version $input"
      install ~/terraform/terraform0.12.29      
      ln -sfn ~/terraform/plugins/0.12.29 ~/terraform/providers      
      ;;

    *)
      echo "Version 0.13.4"
      install ~/terraform/terraform
      ln -sfn ~/terraform/plugins ~/terraform/providers
      ;;
  esac  
}

install() {
  local terraformFile=$1
  echo "Installing $terraformFile"
  cp $terraformFile /usr/local/bin/terraform
}


usage() {
    _helpText="
        Usage: install.sh <command>

        commands:
        list    - list supported terraform versions
        help    - show help text (this)
        0.12.29 - install Terraform 0.12.29

        If a command is ommited, it will default to running an install with the default version 0.13.4.
        
        example:
        ./install.sh 0.12.29 
        "
        
    echo "$_helpText" 1>&2
}

main