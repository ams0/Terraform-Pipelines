# Logger Functions with Azure DevOps Debug and Command statements
# https://docs.microsoft.com/azure/devops/pipelines/scripts/logging-commands?view=azure-devops&tabs=bash

_error() {
    echo "##[error] $@"
}

_debug() {
    if [ $DEBUG_FLAG == true ]; then
        echo "##[debug] $@"
    fi
}

_information() {
    echo "##[command] $@"
}

_success() {
    echo "##[command] $@"
}


