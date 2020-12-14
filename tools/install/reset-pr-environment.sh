#!/usr/bin/env bash

# Includes
source lib/http.sh
source lib/logger.sh


declare DEBUG_FLAG=false

declare AZURE_DEVOPS_EXT_PAT=$SYSTEM_ACCESSTOKEN
declare VARIABLE_GROUP_NAME="pullrequest.state"
declare EXISTING_SECURE_FILE_LIST
declare TF_STATE_FILE_PATH=pr.storage.init.state

main() {

  mkdir temp

  removeLayerResourceGroups 
  removeTFStateResourceGroups
  waitForResourecGroupDeletions
  
  local variableGroupId=`getVariableGroupId $VARIABLE_GROUP_NAME`
  resetVariableGroup "$VARIABLE_GROUP_NAME" "$variableGroupId"

  resetSecureFileTFState

  rm -rf temp
}

resetSecureFileTFState(){
  list_secure_files
  check_if_file_exist_and_delete "$TF_STATE_FILE_PATH"
  touch $TF_STATE_FILE_PATH
  upload_secfile "$TF_STATE_FILE_PATH"
}

removeLayerResourceGroups() {
  resourceGroups=$(az group list --output tsv --query "[?contains(name, 'pr-')].name")
  for group in $resourceGroups
  do
    echo "az group delete -n $group --yes --no-wait"
    az group delete -n $group --yes  --no-wait
  done  
}

removeTFStateResourceGroups() {
  echo "az group delete -n tf-remote-state-pr --yes --no-wait"
  az group delete -n tf-remote-state-pr --yes --no-wait

  echo "az group delete -n tf-remote-state-backup-pr --yes --no-wait"
  az group delete -n tf-remote-state-backup-pr --yes --no-wait
}

waitForResourecGroupDeletions() {
  declare i=0
  declare stateRGStatusLen=1
  declare layerRGStatusLen=1
  declare maxRetry=100

  _information "Waiting for Resource Groups to be deleted"
  while [ "$stateRGStatusLen" -ne 0 ] || [ "$layerRGStatusLen" -ne 0 ]; do 
    
    _debug "Checking Resource Groups - Attempt# $i"
    stateResourceGroupStatus=(`az group list --query "[?contains(name, '-pr')]" | jq -r '.[].properties.provisioningState | @sh' | sed "s|'||g"`)
    stateRGStatusLen=${#stateResourceGroupStatus[@]}
    _debug "Fetched stateResourceGroupStatus: $stateResourceGroupStatus  stateRGStatusLen:$stateRGStatusLen"

    layerResourceGroupStatus=(`az group list --query "[?contains(name, 'pr-')]" | jq -r '.[].properties.provisioningState | @sh' | sed "s|'||g"`)
    layerRGStatusLen=${#layerResourceGroupStatus[@]}
    _debug "Fetched stateResourceGroupStatus: $layerResourceGroupStatus  layerRGStatusLen:$layerRGStatusLen"


    sleep 10s
    i=$((i+1))
    if [ $i == $maxRetry ]; then
      echo "##[error]Reached maximum number of retries $maxRetry. "
      exit 1
    fi
  done
}

resetVariableGroup() {
  # POST https://dev.azure.com/{organization}/{project}/_apis/distributedtask/variablegroups?api-version=5.1-preview.1
  local _vgName=$1
  local _vgId=$2
  local _cloudConfigPayload=""
   
  _information "Resetting PR Variable Group - $_vgName Id: $_vgId"
 
  _payload=$(cat "payloads/template.vg.pr.json" | sed 's~__VG_NAME__~'"${_vgName}"'~')
  echo $_payload > temp/vg.payload.json
  _uri="${AZDO_ORG_URI}/${AZDO_PROJECT_NAME}/_apis/distributedtask/variablegroups/${_vgId}?api-version=5.1-preview.1"
  _response=$( request_put \
                  "${_uri}" \
                  "${_payload}" 
              )  
  echo $_response > ./temp/cprvg.json
  _debug_log_post "$_uri" "$_response" "$_payload"
      
  _createVgTypeKey=$(cat ./temp/cprvg.json | jq -r '.typeKey')
  if [ "$_createVgTypeKey" == "VariableGroupExistsException" ]; then
      _error "can't add variable group ${_vgName}. Variable group exists"
  fi
}

getVariableGroupId() {
  # GET https://dev.azure.com/{organization}/{project}/_apis/distributedtask/variablegroups?api-version=5.1-preview.1
  local _vgName=$1
  
  local _uri="${AZDO_ORG_URI}/${AZDO_PROJECT_NAME}/_apis/distributedtask/variablegroups?api-version=5.1-preview.1"
  local _id=$(request_get $_uri | jq '.value[] |  select(.name == "pullrequest.state") | .id')

  echo $_id
}

check_if_file_exist_and_delete() {
    local fileName=$1
    local baseFileName=`basename $fileName`
    local existingFile

    for existingFile in "${EXISTING_SECURE_FILE_LIST[@]}"
    do
        _debug "Checking file: ${baseFileName} equals ${existingFile}" 
        if [ "${existingFile}" == "${baseFileName}" ]; then
            _information "Match Found!  Deleting file ${existingFile} in secure files."
            id=$(cat ./temp/secure_file_list.json | jq '.value[] | select( .name | contains("'"${existingFile}"'")) | .id | @sh' | sed "s|'||g" | sed 's|"||g')
            _debug "Secure File Id: ${id}"
            
            _uri="${AZDO_ORG_URI}/${AZDO_PROJECT_NAME}/_apis/distributedtask/securefiles/${id}?api-version=5.1-preview.1"
            _response=$(delete_secure_file "${_uri}")
            break
        fi 
    done

}

list_secure_files() {
    _uri="${AZDO_ORG_URI}/${AZDO_PROJECT_NAME}/_apis/distributedtask/securefiles?api-version=5.1-preview.1"

    _response=$(request_get "${_uri}")

    _debug_log_get $_uri $_response

    echo $_response > ./temp/secure_file_list.json 

    EXISTING_SECURE_FILE_LIST=($(cat ./temp/secure_file_list.json | jq -r '.value[].name | @sh' | sed "s|'||g"))

    _debug "Existing Secure File List:"
    _debug "${EXISTING_SECURE_FILE_LIST[*]}"
}

delete_secure_file(){
    request_uri=$1

    _response=$(curl \
        --silent \
        --location \
        --header 'Content-Type: application/json; charset=utf-8' \
        -u ":${AZURE_DEVOPS_EXT_PAT}" \
        --request DELETE ${request_uri} \
        --data-raw '')

    echo $_response 
}

upload_secfile() {
    local envFileName=$1
    local baseFileName=`basename $envFileName`
    # POST https://dev.azure.com/{organization}/{project}/_apis/distributedtask/securefiles?api-version=6.0-preview.1&name={fileName}
    _information "Uploading Sec File: ${envFileName} baseFileName:${envFileName}"

    _uri="${AZDO_ORG_URI}/${AZDO_PROJECT_NAME}/_apis/distributedtask/securefiles?name=${baseFileName}&api-version=5.1-preview.1"
    _response=$(request_post_binary "${_uri}" "${envFileName}")

    _debug_log_post_binary "$_uri" "$_response" "${envFileName}"

    echo $_response > ./temp/usf.json

    _id=$(cat ./temp/usf.json | jq -c -r '.id')

    _debug "Secure File ID: ${_id}"

    # PATCH https://dev.azure.com/{organization}/{project}/_apis/build/authorizedresources?api-version=5.1-preview.1
    _uri="${AZDO_ORG_URI}/${AZDO_PROJECT_NAME}/_apis/build/authorizedresources?api-version=5.1-preview.1"
    _payload="[{\"authorized\":true,\"id\":\"${_id}\",\"name\":\"${envFileName}\",\"type\":\"securefile\"}]"

    _response=$( request_patch \
    "${_uri}" \
    "${_payload}"
    )

    _debug_log_patch $_uri $_response $_payload

    _information "File upload complete for ${baseFileName}"
}

saveSecureFileTFState() {
  mkdir temp
  
  local stateFilePath=$1
  local securePath=./temp/pr.storage.init.state
  cp $stateFilePath $securePath
  list_secure_files
  check_if_file_exist_and_delete "$securePath"
  upload_secfile "$securePath"

  rm -rf temp
}

#Main
if [ "${FROM_PIPELINE}" == true ]; then
  case ${SCRIPT_COMMAND} in

    reset)
      main
      ;;

    save)
      _information "Saving file ${STATE_FILE}"
      saveSecureFileTFState "${STATE_FILE}"
      ;;

    *)
      _information "Warning: Unknown script command ${SCRIPT_COMMAND}. "
      ;;
  esac
fi
