#!/bin/bash -e

set -o errexit
set -o nounset
set -o pipefail

#script variables
ORG=https://dev.azure.com/csedevops
PROJECT=terraform-template

TOOL_VERSIONS_VG_NAME='tool_versions'

TOOL_VERSIONS=$(cat <<EOF
{
    "variables": [
        {
          "name": "terraform",
          "value": "0.12.26"
        },
        {
          "name": "tflint",
          "value": "v0.14.0"
        },
        {
          "name": "goversion",
          "value": "1.13.5"
        },        
        {
          "name": "tflint_sha256",
          "value": "4908d30078ecbd3b732ce5c2caabad77b6b768d46397ae009dd8dab8a1cbf6ac"
        }
    ]
}
EOF
)

# Check if VG exist
VG_EXISTS=`az pipelines variable-group list --org $ORG -p $PROJECT --group-name $TOOL_VERSIONS_VG_NAME -o json | jq '. | length'`

# If exist delete and recreate
if [[ $VG_EXISTS > 0 ]]; then
    echo "${TOOL_VERSIONS_VG_NAME} exists."
    # Get VG Id
    VG_ID=`az pipelines variable-group list --org $ORG -p $PROJECT --group-name $TOOL_VERSIONS_VG_NAME -o json | jq '.[0].id'`

    echo "Dropping variable group ID: ${VG_ID}"
    #Delete VG
    az pipelines variable-group delete --org $ORG -p $PROJECT --group-id $VG_ID --yes
fi
# Build Variables list
VAR_GROUP_LENGTH=`echo $TOOL_VERSIONS | jq '.[] | length'`
VARS=''

for (( i=0; i<$VAR_GROUP_LENGTH; i++ ))
do
    VAR_NAME=`echo $TOOL_VERSIONS | jq .variables[$i].name | sed 's/\"//g'`
    VAR_VALUE=`echo $TOOL_VERSIONS | jq .variables[$i].value | sed 's/\"//g'`
    VARS+=$VAR_NAME=$VAR_VALUE' '
done

#Create VG
echo "Creating variable group: ${TOOL_VERSIONS_VG_NAME}"
az pipelines variable-group create --org $ORG -p $PROJECT --name $TOOL_VERSIONS_VG_NAME --authorize true  --variables $VARS



