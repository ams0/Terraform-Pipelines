# TF-Bundle

A utility to bundle terraform core and specified providers into a single tar file. This is useful for deploying to Azure Stack and air-gapped environments.

## Run the bundler

`./bundler.sh create`

---

## Configuration

The bundler is primarily driven by [terraform-bundle](https://github.com/hashicorp/terraform/tree/master/tools/terraform-bundle) and is configured via [terraform-bundle.hcl](./terraform-bundle.hcl).

Terraform bundle only supports terraform 0.13.x. To include 0.12.29, the bundler script expands the zip file, adds the legacy version of terraform , and custom scripts, then creates a new tar file. 

---

## Output

The bundler will create a file named terraform-binaries.tar.gz in the tf-bundle folder.  The current primary target is amd64 Linux.

---

## What's in the Bundle

* Terraform CLI 0.13.4
* Terraform CLI 0.12.29
* AzureRM Terraform Provider - 2.23.0
* AzureRM Terraform Provider - 2.8.0
* AzureAD Terraform Provider - 0.7.0
* Null Provider - 3.0.0
