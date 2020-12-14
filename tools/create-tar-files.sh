
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
        -s | --sourcePath <Root folder that contains Terraform-Code and Terraform-Pipelines>. 
               Default: If not specified , it's assumed that the current folder is Terraform-Pipelines/tools
        -o | --outputPath <Path to place the generated tar files. Default to ./output>        
        -d | --debug Turn debug logging on
        -h | --help Show the usuage help (this.)"
        
    _information "$_helpText" 1>&2
    exit 1
}


#Script Parameters (Required)
declare SOURCE_PATH='../..'
declare OUTPUT_PATH='/tmp/lucidity/output'
declare DEBUG_FLAG=false

# Initialize parameters specified from command line
while [[ "$#" -gt 0 ]]
do
  case $1 in
    -s | --sourcePath )
        SOURCE_PATH=$2
        ;;  
    -o | --outputPath )
        OUTPUT_PATH=$2
        ;;  
    -h | --help)
        usage
        exit 0
        ;;
    -d | --debug )             
        DEBUG_FLAG=true
        ;;         
  esac  
  shift
done

_debug "Creating output folder: ${OUTPUT_PATH}"
mkdir -p ${OUTPUT_PATH}
tarFlags="-czf"
if [ "${DEBUG_FLAG}" == true ]; then 
  tarFlags="-czvf"
fi

_information "Generating $OUTPUT_PATH/terraform-pipelines.tar.gz"
tar $tarFlags $OUTPUT_PATH/terraform-pipelines.tar.gz -C $SOURCE_PATH Terraform-Pipelines


_information "Generating $OUTPUT_PATH/terraform-code.tar.gz"
tar $tarFlags $OUTPUT_PATH/terraform-code.tar.gz -C $SOURCE_PATH Terraform-Code

cleanUp(){
    _information "TAR file generation is Complete!"
}
trap 'cleanUp' EXIT

