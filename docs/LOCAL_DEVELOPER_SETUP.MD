# Local Development Guide

### Introduction

The focus of this guide is enable local development of infrastructure code that will be executed in Azure DevOps using the Project Lucidity template. This will allow for changes to Terraform Code and tests to be executed locally for development, before being pushes to Azure DevOps.

## Project Set up

* Create a new project folder for local development `mkdir -p ~/work/project1/`
* Navigate to the project1 folder `cd ~/work/projects`
* Clone the Lucidity Terraform-Pipelines Repo from the public project. `git clone git@ssh.dev.azure.com:v3/csedevops/terraform-template-public/Terraform-Pipelines`
* Clone the Lucidity Terraform-Code Repo from the public project. `git clone git@ssh.dev.azure.com:v3/csedevops/terraform-template-public/Terraform-Code`
* Navigate to the Terraform-Pipelines/tools/install folder `cd Terraform-Pipelines/tools/install/`
* Follow the [Project Installation Guide](./PROJECT_INSTALLATION.md)
* Navigate to the Azure DevOps organization specified in the install script and verify the following items in your project:
  * Go to the Pipelines page and ensure the env.compile pipeline ran successfully.
  * Ensure that you have three Repos under the Repositories section. The drop down at the top should show a default repo, Terraform-Pipelines and Terraform-Code.

## Configure Remote Storage

* Navigate to the Pipelines section of your project and run the dev.storageinit pipeline to configure an Azure Storage account for Terraform remote storage.

## Clone Project Repos
* At this point We need to clone your newly created repos. While you do have the original repos created in ~/work from the Lucidity public project, it's recommended you clone from the repos that were created as part of the install script. The reason is that there are transformations applied to the repo as 
part of the project install. (Another option is to change your remote and pull down changes).

### Cloning Your newly Created Repos:
* Navigate to ~/work
* Delete the previous repos cloned from terraform-template-public.
  * `rm -rf Terraform-Pipelines`
  * `rm -rf Terraform-Code`
* Clone your two newly created repos.
  * The url can be found in the repos section of your azure devops project.
    * `git clone https://<your_org_name>@dev.azure.com/<your_org_name>/<your_project_name>/_git/Terraform-Code` 
    * `git clone https://<your_org_name>@dev.azure.com/<your_org_name>/<your_project_name>/_git/Terraform-Pipelines` 

## Development Workflow
Once the new repos are cloned, you can now being to to set up and work on each layer/deployment. Every deployment can be treated as a separate terraform module. There is no root terraform module as the layers and their order of execution is controlled by pipelines. Locally you would have to run the layers in the correct numbered sequence. 

The overall workflow for each layer is as follows:
* Set up a backend.hcl file in each deployment.
* terraform init with the backend.hcl 
* Load the combined .env file for the target environment.
* terraform plan. 
* terraform apply.

The following will illustrate how to do this for the 02_sql/01_deployment. (Note the same steps will have to be applied for other layers/deployment or new deployments you create)

## Set up Remote Backend
 Navigate to ~/work/Terraform-Code/terraform. Under this folder will be all your layers. Please see the [directory structure document](DIRECTORY_STRUCTURE.md).
* Go to the 01_deployment of the 02_sql layer `cd 02_sql/01_deployment`
* Create a file named backend.hcl. This is used for the remote state configuration. There needs be one file in every deployment folder.  The file should contain configurations value from various sources.
  * The key property is the folder path under the terraform folder for each deployment. For example: for terraform/02_sql/01_deployment; the key would be 02_sql/01_deployment.
  * The SP Client Id and Secret should be the same as what was previously used in the install script.
  * The  remaining values should use the same remote state storage account information. This configuration is applied and saved in a the dev.remotestate.env file. The file is located in ~/work/Terraform-Code/environments/dev/dev.remotestate.env (note for other environments, please use the corresponding folder/<env>.remotestate.env file). In the template flow values beginning with with TF_VAR can be found in the dev.remotestate.en file.

  backend.hcl
   ```
  storage_account_name  = "<-- TF_VAR_BACKEND_STORAGE_ACCOUNT_NAME -->" 
  container_name        = "<-- TF_VAR_BACKEND_CONTAINER_NAME -->" 
  key                   = "02_sql/01_deployment" 
  resource_group_name   = "<-- TF_VAR_BACKEND_RESOURCE_GROUP_NAME -->"  
  arm_subscription_id   = "<-- TF_VAR_SUBSCRIPTION_ID -->" 
  arm_tenant_id         = "<-- TF_VAR_TENANT_ID -->" 
  arm_client_id         = "<-- Client ID -->" 
  arm_client_secret     = "<-- Client SEcrets -->" 
  ```

* Invoke terraform init via `terraform init -backend-config=backend.hcl`

## Load Environment Variables
Environment variables for lucidity are stored in .env files under Terraform-Code/environments. There are multiple files in each folder for each layer. Included in the project is a script you can run to compile them into a single file. (This is the process used by the env.compile pipeline.) To combine and load the environment variables follow these steps:
* In the current deployment folder create a directory called config `mkdir config`
* Invoke the [compile.env.sh]() script via `~/work/Terraform-Code/scripts/env/compile.env.sh -s ~/work/Terraform-Code/environments/ -o ./config -c -w`
  
  Note: (You can run the script with -h to see a detailed usage of each flag)
* Navigate to the config folder `cd config`
* Execute the following toe load the dev.compiled.env file `set -o allexport && . dev.compiled.env && set +o allexport`
* Navigate back to the deployment folder (1 folder up) `cd ..`

## Plan and Apply
* `terraform plan -out=plan.tfplan` (If this steps prompts you for a variable, then environment variables were not loaded correctly. It should proceed with the plan without prompting for any variables since they are loaded form .env files)
* `terraform apply "plan.tfplan`


