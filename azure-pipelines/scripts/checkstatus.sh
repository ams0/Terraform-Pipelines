#!/usr/bin/env bash

# Input Variables
declare accessToken=""
declare organizationURL=""
declare project=""
declare id=""
declare expireDurationDays=6
declare variableGroupName="pullrequest.state"

# Helper Functions
request_get() {
   request_uri=${1}

   local _response

   _response=$(curl \
     --silent \
     --location \
     --header 'Content-Type: application/json; charset=utf-8' \
     -u ":${accessToken}" \
     --request GET ${request_uri} )

   echo $_response
}

request_put() {
   request_uri=${1}
   payload=${2}

   local _response

   _response=$(curl \
     --silent \
     --location \
     --header 'Content-Type: application/json; charset=utf-8' \
     -u ":${accessToken}" \
     --request PUT ${request_uri} \
     --data-raw "${payload}" \
     --compressed)

   echo $_response
}

initialize() {
  variableGroupName=$PR_VARIABLE_GROUP_NAME
  expireDurationDays=$EXPIRE_DURATION_DAYS
  accessToken=$ACCESS_TOKEN
  organizationURL=$COLLECTION_URL
  project=$TEAM_PROJECT
  echo "** organizationURL: ${organizationURL}  project: ${project} variableGroupName: ${variableGroupName}"
  url="${organizationURL}/${project}/_apis/distributedtask/variablegroups?groupName=${variableGroupName}&api-version=5.0-preview.1"
  echo $url
  response=$(request_get ${url})
  id=$(echo $response | jq '.value[].id')
  echo "** initialize id: ${id}"   
}

getNewExpireDate() {
  current=$(date "+%s")
  newExpireDate=$((current + (3600 * 24 * ${expireDurationDays})))
  echo $newExpireDate
}

updateVariableGroup() {
  initialize
  local pullRequestId=$1
  local status=$2
  newExpireDate=$(getNewExpireDate)
  echo "*** id: ${id}"
  _payload=$(cat "../payloads/template.vg.update.json" | sed 's~__PULL_REQUEST_NUMBER__~'"${pullRequestId}"'~' | sed 's~__EXPIRE_DATE__~'"$(date --date @${newExpireDate} "+%m/%d/%Y %H:%M")"'~' | sed 's~__STATUS__~'"${status}"'~' | sed 's~__VARIABLE_GROUP_NAME__~'"${variableGroupName}"'~' | jq --compact-output --raw-output '.')
  request_put "${organizationURL}/${project}/_apis/distributedtask/variablegroups/${id}?api-version=5.0-preview.1" "${_payload}"
}

# Main
checkPullRequest(){
   local _expireDate=$1
   local _status=$2
   local _pullRequestNumber=$3
   local _pullRequestId=$4

   echo "expireDate: ${_expireDate}, status: ${_status}, pullRequestNumber: ${_pullRequestNumber}, pullRequestId: ${_pullRequestId}"

   # Check if it is expired. 
   expire=$(date -d "${_expireDate}" "+%s")
   current=$(date "+%s")
   delta=$(($expire - $current))
   expireDuration=$((3600 * 24 * ${expireDurationDays}))

   # Logging the condition 
   echo "expire: ${expire}, current: ${current}, delta: ${delta}, expireDuration: ${expireDuration}"

   if [ $delta -lt 0 ] && [ ${_status} != 'Aborted' -a  ${_status} != 'Completed' ]; then 
    echo "Pull Request: State expired: ${_expireDate} Status: Aborted"
    updateVariableGroup "$_pullRequestId" "Aborted"
    exit 1
   else 
    if [ ${_status} == 'Completed' ] || [ ${_status} == 'Aborted' ]; then
      echo "Status: ${_status}"
      updateVariableGroup "$_pullRequestId" "Started"
    else 
      if [ "${_pullRequestId}" == "${_pullRequestNumber}" ]; then
        echo "Status: ${_status}, PullRequestNumber Env: $_pullRequestId Parameter: ${_pullRequestNumber}"
        echo "Skip update State."
      else
         echo "Locked by PullRequest: ${_pullRequestNumber}, Current Status: ${_status} "
         exit 1; 
      fi 
    fi 
   fi
}

# If Running from Pipeline, invoke checkPullRequest
if [ "${FROM_PIPELINE}" == true ]; then
  checkPullRequest "${EXPIRE_DATE}" "${STATUS}" "${PULL_REQUEST_ID}" "${PULL_REQUEST_NUMBER}"
fi