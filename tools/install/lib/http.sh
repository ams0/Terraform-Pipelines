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

verify_response() {
    local _request_uri=$1 
    local _response=$2
    local _token=$3

    if [[ "$_response" == *"innerException"* ]]; then
        echo "----------------------------------------------"
        echo "Inner Exception in Http Response " >> ./temp/http.error.log    
        echo "_request_uri: $_request_uri" >> ./temp/http.error.log    
        echo "_response: " >> ./temp/http.error.log    
        echo $_response >> ./temp/http.error.log    
    fi
    if [[ "$_response" == *"Azure DevOps Services | Sign In"* ]]; then
        echo "----------------------------------------------"
        echo "Azure DevOps Services | Sign In Http Response (html login screen)" >> ./temp/http.error.log        
        echo "_request_uri: $_request_uri" >> ./temp/http.error.log    
        echo "_response: " >> ./temp/http.error.log    
        echo $_response >> ./temp/http.error.log    
    fi
    if [[ "$_response" == *"Access Denied: The Personal Access Token used has expired"* ]]; then
        echo "----------------------------------------------"
        echo "Access Denied: The Personal Access Token used has expired (html screen)" >> ./temp/http.error.log        
        echo "_request_uri: $_request_uri" >> ./temp/http.error.log    
        echo "_response: " >> ./temp/http.error.log    
        echo $_response >> ./temp/http.error.log    
    fi    
}
_debug_log_patch() {
    _debug "REQ - "$1
    _debug "RES - "
    _debug_json "$2"
    _debug "PAYLOAD -"
    _debug_json "$3"
}

request_patch() {
    request_uri=$1
    payload=$2

   if [ $INSTALL_TYPE == 'PAAS ' ]; then
        _token=$(echo -n ":${AZDO_PAT}" | base64)

        _response=$(curl \
            --silent \
            --location \
            --header 'Content-Type: application/json; charset=utf-8' \
            --header "Authorization: Basic ${_token}" \
            --request PATCH ${request_uri} \
            --data-raw "${payload}" \
            --compressed)
    else
        _token=$(echo -n ":${AZDO_PAT}" | base64)
        
        _response=$(curl \
            --silent \
            --location \
            --header 'Content-Type: application/json; charset=utf-8' \
            --header "Authorization: Basic ${_token}" \
            --request PATCH ${request_uri} \
            --data-raw "${payload}" \
            --compressed)
    fi

    verify_response "$request_uri" "$_response" "$_token"
    echo $_response 
}

_debug_log_post() {
    _debug "REQ - " $1
    _debug "RES - "
    _debug_json "$2"
    _debug "PAYLOAD -"
    _debug_json "$3"
}

request_post(){
    request_uri=${1}
    payload=${2}

    if [ $INSTALL_TYPE == 'PAAS ' ]; then
        _token=$(echo -n ":${AZDO_PAT}" | base64)

        _response=$(curl \
            --silent \
            --location \
            --header 'Content-Type: application/json; charset=utf-8' \
            --header "Authorization: Basic ${_token}" \
            --request POST ${request_uri} \
            --data-raw "${payload}")
    else
        _token=$(echo -n ":${AZDO_PAT}" | base64)

        _response=$(curl \
            --silent \
            --location \
            --header 'Content-Type: application/json; charset=utf-8' \
            --header "Authorization: Basic ${_token}" \
            --request POST ${request_uri} \
            --data-raw "${payload}")
    fi

    verify_response "$request_uri" "$_response" "$_token"
    echo $_response 
}

request_put(){
    request_uri=${1}
    payload=${2}

    if [ $INSTALL_TYPE == 'PAAS ' ]; then
        _token=$(echo -n ":${AZDO_PAT}" | base64)

        _response=$(curl \
            --silent \
            --location \
            --header 'Content-Type: application/json; charset=utf-8' \
            --header "Authorization: Basic ${_token}" \
            --request PUT ${request_uri} \
            --data-raw "${payload}")
    else
        _token=$(echo -n ":${AZDO_PAT}" | base64)

        _response=$(curl \
            --silent \
            --location \
            --header 'Content-Type: application/json; charset=utf-8' \
            --header "Authorization: Basic ${_token}" \
            --request PUT ${request_uri} \
            --data-raw "${payload}")
    fi

    verify_response "$request_uri" "$_response" "$_token"
    echo $_response 
}

_debug_log_get() {
    _debug "REQ -" $1
    _debug "RES - "
    _debug_json "$2"
}

request_get(){
    request_uri=${1}

    local _response

    if [ $INSTALL_TYPE == 'PAAS' ]; then
        _token=$(echo -n ":${AZDO_PAT}" | base64)

        _response=$(curl \
            --silent \
            --location \
            --header 'Content-Type: application/json; charset=utf-8' \
            --header "Authorization: Basic ${_token}" \
            --request GET ${request_uri} )
    else
        _token=$(echo -n "${AZDO_PAT}")
        _user=${AZDO_USER}':'${_token}
        _response=$(curl \
            --silent \
            --location \
            --header 'Content-Type: application/json; charset=utf-8' \
            -u  ${_user} \
            --request GET ${request_uri} )
    fi

    verify_response "$request_uri" "$_response" "$_token"
    echo $_response 
}

_debug_log_post_binary() {
    _debug "REQ - "$1
    _debug "RES - "
    _debug_json "$2"
    _debug "FILE_NAME - " $3
}

request_post_binary(){
    request_uri=${1}
    _sec_env_filename=${2}

    if [ $INSTALL_TYPE == 'PAAS ' ]; then
        _token=$(echo -n ":${AZDO_PAT}" | base64)

        _response=$(curl \
            --silent \
            --location \
            --header 'Content-Type: application/octet-stream' \
            --header "Authorization: Basic ${_token}" \
            --request POST ${request_uri} \
            --data-binary "@./${_sec_env_filename}" \
            --compressed)
    else
        _token=$(echo -n ":${AZDO_PAT}" | base64)

        _response=$(curl \
            --silent \
            --location \
            --header 'Content-Type: application/octet-stream' \
            --header "Authorization: Basic ${_token}" \
            --request POST ${request_uri} \
            --data-binary "@./${_sec_env_filename}" \
            --compressed)
    fi

    verify_response "$request_uri" "$_response" "$_token"
    echo $_response 
}
