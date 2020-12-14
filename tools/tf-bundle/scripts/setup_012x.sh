#!/usr/bin/env bash

echo "Starting configuration of plugin folder structure for Terraform 0.12.x"

declare targetFolder=./0.12.29

echo "Creating Folder $targetFolder"
mkdir -p $targetFolder

echo "Copying Azure RM v2.23.0"
cp registry.terraform.io/hashicorp/azurerm/2.23.0/linux_amd64/terraform-provider-azurerm_v2.23.0_x5  $targetFolder

echo "Copying Azure RM v2.8.0"
cp registry.terraform.io/hashicorp/azurerm/2.8.0/linux_amd64/terraform-provider-azurerm_v2.8.0_x5  $targetFolder

echo "Copying AzureAD v0.7.0"
cp registry.terraform.io/hashicorp/azuread/0.7.0/linux_amd64/terraform-provider-azuread_v0.7.0_x4 $targetFolder

echo "Copying Null Provider v3.0.0"
cp registry.terraform.io/hashicorp/null/3.0.0/linux_amd64/terraform-provider-null_v3.0.0_x5 $targetFolder

echo "Plugin Path for Terraform 0.12.x: $(pwd)/$targetFolder"
echo "Local Providers configured for Terraform 0.12.x!"
