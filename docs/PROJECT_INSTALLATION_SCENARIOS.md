# Install Script Scenarios

## Introduction

The [project installation](./PROJECT_INSTALLATION.md) creates a new Azure DevOps project in your organization and configures all the necessary pieces to have Terraform CI/CD. This includes pipelines, variable groups and a split repo structure.

The installation script can handle several different scenarios depending on the combination of flags and parameters.  This document will outline several types of common installation scenarios.

---

## Scenarios - Azure DevOps Services PAAS (Hosted Service)

|No. | Description |
| --- | ---
| 1. | [Create a new Project and generate a sample application. Targeting Azure Commercial Cloud.](#azure-devops-services-scenario-1) |
| 2. | [Create a new Project and use the sample application template with Debug logs. Targeting Sovereign Cloud](#azure-devops-services-scenario-2) |
| 3. | [Create a new Project in Azure DevOps Services and bring your own code.](#azure-devops-services-scenario-3) |

<br/>

---

## Scenarios - Azure DevOps Server (Installed on VM/Server)

|No. | Description |
| --- | ---
| 1. | [Create a new Project and generate a sample application, targeting Azure Commercial Cloud.](#azure-devops-server-scenario-1) |
| 2. | [Create a new Project and use the sample application template with Debug logs. Targeting Sovereign Cloud](#azure-devops-server-scenario-2) |
| 3. | [Create a new Project in Azure DevOps Services and bring your own code.](#azure-devops-server-scenario-3) |
| 4. | [Deploying an existing Lucidity Project to an Air-Gapped Environment running Azure DevOps Server and Targeting an Azure Private Cloud](#azure-devops-server-scenario-4) |
| 5. | [Updating Terraform-Code and Terraform-Pipelines in an Air-Gapped Environment running Azure DevOps Server with a previously deployed (existing) Azure DevOper Server Project](#azure-devops-server-scenario-5) |

<br/>

---

### Azure DevOps Services Scenario 1

#### Create a new Project and generate a sample application, targeting Azure Commercial Cloud

In this scenario a new Azure DevOps project is created with default values. The sample application project template is deployed to the new project. This is the equivalent of a "File->New" project. Once the project is created, you can then clone the generated repos and start developing your new application

This scenario targets [Azure Commercial cloud.](https://portal.azure.com)

This uses the required minimum number of flags. Please ensure that the following dependencies are met:

* A Personal Access Token was created in your org, with permissions to create projects.
* A Service Principal was created with the required roles.

Please see the [Project Install](./PROJECT_INSTALLATION.md) for instructions on creating these two items.

#### Scenario Steps

* Clone the Lucidity Terraform Pipelines Repo
  <https://dev.azure.com/csedevops/terraform-template-public/_git/Terraform-Pipelines>
* Navigate to the tools/install folder.
* Run the install script:

    ```bash
     ./install.sh \
    -o <Azure DevOps Org Url> \
    -n <Azure DevOps Project Name> \
    -p <PAT> \
    -r <Region> \
    --subName "<Azure Subscription Name>" \
    -s "SP_ID=<Service Principal Client Id> SP_SUBSCRIPTION_ID=<Azure Subscription ID> SP_SECRET=<Serice Principal Secret> SP_TENANT_ID=<Azure Active Directory Tenant Id>" \
    -d
   ```

  **Debugging:** This scenario uses -d to enable debug logging. For a more condensed output log, remove the -d and debug logs will be omitted.

* Delete the Terraform Pipelines repo cloned to your local machine from terraform-template-public that was used to run the installation script. `rm -rf Terraform-Pipelines`
* Navigate to your newly created project and grab the clone urls for **your** Terraform-Code and Terraform-Pipelines.
* Clone Terraform-code and Terraform-Pipelines locally.
* Develop your application and infrastructure. [See Local development setup](LOCAL_DEVELOPER_SETUP.MD)
* Push when ready!

---

### Azure DevOps Services Scenario 2

#### Create a new Project and generate a sample application, targeting Azure Sovereign Cloud

In this scenario a new Azure DevOps project is created with default values. The sample application project template is deployed to the new project. This is the equivalent of a "File->New" project. Once the project is created, you can then clone the generated repos and start developing your new application

This scenario targets [Azure Government Cloud](https://docs.microsoft.com/azure/azure-government/documentation-government-welcome) or any desired Sovereign Cloud. To see a list of available clouds via the `az` cli , invoke ```az cloud list```

Please ensure the Service Principal was created in the target Azure Sovereign Cloud environment.

#### Scenario Steps

* Clone the Lucidity Terraform Pipelines Repo
  <https://dev.azure.com/csedevops/terraform-template-public/_git/Terraform-Pipelines>
* Navigate to the tools/install folder.
* Run the install script:

    ```bash
     ./install.sh \
    -o <Azure DevOps Org Url> \
    -n <Azure DevOps Project Name> \
    -p <PAT> \
    -r <Region> \
    --subName "<Azure Subscription Name>" \
    -s "SP_ID=<Service Principal Client Id> SP_SUBSCRIPTION_ID=<Azure Subscription ID> SP_SECRET=<Serice Principal Secret> SP_TENANT_ID=<Azure Active Directory Tenant Id>" \
    -c AzureUSGovernment \
    --metaDataHost <Meta Data Host URL> \
    -d
   ```

  MetaData Host is the Hostname of the Azure Metadata Service, [used by Terraform to obtain the Cloud Environment when using a Custom Azure Environment.](https://www.terraform.io/docs/providers/azurerm/index.html#metadata_host)

  To get the meta data url:

  * Find the resource manager url for your desired cloud via the `az` cli.

      ```bash
        az cloud show --query '[endpoints.resourceManager]'
      ```

  * Meta Data host is  `https://<resource manager url>/metadata/endpoints?api-version=2020-06-01`

    To get the meta host in a single command:

    ```bash
    echo "$(az cloud show --query '[endpoints.resourceManager][0]' -o tsv)/metadata/endpoints?api-version=2020-06-01"
    ```

* Delete the Terraform Pipelines repo cloned to your local machine from terraform-template-public that was used to run the installation script. `rm -rf Terraform-Pipelines`
* Navigate to your newly created project and grab the clone urls for **your** Terraform-Code and Terraform-Pipelines.
* Clone Terraform-code and Terraform-Pipelines locally.
* Develop your application and infrastructure. [See Local development setup](LOCAL_DEVELOPER_SETUP.MD)
* Push when ready!

---

### Azure DevOps Services Scenario 3

#### Import an existing Terraform Project, targeting Azure Commercial Cloud

This scenario is focused on creating a Lucidity Based Azure DevOps Project and importing in existing code. This is the recommended approach , rather than trying to recreate Lucidity pipelines and features in an existing Azure DevOps Project. The reason for this is because there is a lot of configuration that happens as part of the install process.

#### Scenario Steps

* Clone the Lucidity Terraform Pipelines Repo
  <https://dev.azure.com/csedevops/terraform-template-public/_git/Terraform-Pipelines>
* Navigate to the tools/install folder.
* Run the install script:

    ```bash
     ./install.sh \
    -o <Azure DevOps Org Url> \
    -n <Azure DevOps Project Name> \
    -p <PAT> \
    -r <Region> \
    --subName "<Azure Subscription Name>" \
    -s "SP_ID=<Service Principal Client Id> SP_SUBSCRIPTION_ID=<Azure Subscription ID> SP_SECRET=<Serice Principal Secret> SP_TENANT_ID=<Azure Active Directory Tenant Id>" \
    -c AzureUSGovernment \
    --metaDataHost <Meta Data Host URL> \
    -d
   ```

  MetaData Host is the Hostname of the Azure Metadata Service, [used by Terraform to obtain the Cloud Environment when using a Custom Azure Environment.](https://www.terraform.io/docs/providers/azurerm/index.html#metadata_host)

  To get the meta data url:

  * Find the resource manager url for your desired cloud via the `az` cli.

      ```bash
        az cloud show --query '[endpoints.resourceManager]'
      ```

  * Meta Data host is  `https://<resource manager url>/metadata/endpoints?api-version=2020-06-01`

  To get the meta host in a single command:

  ```bash
   echo "$(az cloud show --query '[endpoints.resourceManager][0]' -o tsv)/metadata/endpoints?api-version=2020-06-01"
  ```

* Delete the Terraform Pipelines repo cloned to your local machine from terraform-template-public that was used to run the installation script. `rm -rf Terraform-Pipelines`
* Navigate to your newly created project and grab the clone urls for **your** Terraform-Code and Terraform-Pipelines.
* Clone Terraform-code and Terraform-Pipelines locally.
* Copy in your terraform code using the [layer/deployment folder structure](DIRECTORY_STRUCTURE.md). This may require some refactoring and adaption.
* Push when ready!

---

### Azure DevOps Server Scenario 1

#### Create a new Project and generate a sample application, targeting Azure Commercial Cloud

This scenario requires that a running installation of Azure DevOps 2020 on a virtual machine. Project Lucidity includes an associated [server deployment project](https://dev.azure.com/csedevops/terraform-template/_git/AzDO-Server-Deployment) that can be used as a starting point. This ARM template based setup can be used to assist with the infrastructure set up and deployment. (Documentation on the Server Deployment project will be available soon.)

In this scenario a new project is created with default values. The sample application project template is deployed to the new project. This is the equivalent of a "File->New" project. Once the project is created, you can then clone the generated repos and start developing your new application. This scenario targets [Azure Commercial cloud.](https://portal.azure.com)

This uses the required minimum number of flags. Please ensure that the following dependencies are met:

* A Personal Access Token was created in your org, with permissions to create projects.
* A Service Principal was created with the required roles.

Please see the [Project Install](./PROJECT_INSTALLATION.md) for instructions on creating these two items.

#### Scenario Steps

* Clone the Lucidity Terraform Pipelines Repo
  <https://dev.azure.com/csedevops/terraform-template-public/_git/Terraform-Pipelines>
* Navigate to the tools/install folder.
* Run the install script:

    ```bash
     ./install.sh \
    -l <Azure DevOps Server Url and Collection> \
    -n <Azure DevOps Project Name> \
    -p <PAT> \
    -r <Region> \
    --subName "<Azure Subscription Name>" \
    -s "SP_ID=<Service Principal Client Id> SP_SUBSCRIPTION_ID=<Azure Subscription ID> SP_SECRET=<Serice Principal Secret> SP_TENANT_ID=<Azure Active Directory Tenant Id>" \
    -d
   ```

  **Note**: -l options requires both a server url and also collection name. (eg. <https://my-server-vm/ProjectCollection>)

* Delete the Terraform Pipelines repo cloned to your local machine from terraform-template-public that was used to run the installation script. `rm -rf Terraform-Pipelines`
* Navigate to your newly created project and grab the clone urls for **your** Terraform-Code and Terraform-Pipelines.
* Clone Terraform-code and Terraform-Pipelines locally.
* Develop your application and infrastructure. [See Local development setup](LOCAL_DEVELOPER_SETUP.MD)
* Push when ready!

---

### Azure DevOps Server Scenario 2

#### Create a new Project and generate a sample application, targeting Azure Sovereign Cloud

This scenario requires that a running installation of Azure DevOps 2020 on a virtual machine. Project Lucidity includes an associated [server deployment project](https://dev.azure.com/csedevops/terraform-template/_git/AzDO-Server-Deployment) that can be used as a starting point.  This ARM template based setup can be used to assist with the infrastructure set up and deployment. (Documentation on the Server Deployment project will be available soon.)

In this scenario a new Azure DevOps project is created with default values. The sample application project template is deployed to the new project. This is the equivalent of a "File->New" project. Once the project is created, you can then clone the generated repos and start developing your new application

This scenario targets [Azure Government Cloud](https://docs.microsoft.com/azure/azure-government/documentation-government-welcome) or any desired Sovereign Cloud. To see a list of available clouds via the `az` cli , invoke ```az cloud list```

Please ensure the Service Principal was created in the target Azure Sovereign Cloud environment.

#### Scenario Steps

* Clone the Lucidity Terraform Pipelines Repo
  <https://dev.azure.com/csedevops/terraform-template-public/_git/Terraform-Pipelines>
* Navigate to the tools/install folder.
* Run the install script:

    ```bash
     ./install.sh \
    -l <Azure DevOps Server Url and Collection> \
    -n <Azure DevOps Project Name> \
    -p <PAT> \
    -r <Region> \
    --subName "<Azure Subscription Name>" \
    -s "SP_ID=<Service Principal Client Id> SP_SUBSCRIPTION_ID=<Azure Subscription ID> SP_SECRET=<Serice Principal Secret> SP_TENANT_ID=<Azure Active Directory Tenant Id>" \
    -c AzureUSGovernment \
    --metaDataHost <Meta Data Host URL> \
    -d
   ```

  **Note**: -l options requires both a server url and also collection name. (eg. <https://my-server-vm/ProjectCollection>)

  MetaData Host is the Hostname of the Azure Metadata Service, [used by Terraform to obtain the Cloud Environment when using a Custom Azure Environment.](https://www.terraform.io/docs/providers/azurerm/index.html#metadata_host)

  To get the meta data url:

  * Find the resource manager url for your desired cloud via the `az` cli.

      ```bash
        az cloud show --query '[endpoints.resourceManager]'
      ```

  * Meta Data host is  `https://<resource manager url>/metadata/endpoints?api-version=2020-06-01`

  To get the meta host in a single command:

  ```bash
   echo "$(az cloud show --query '[endpoints.resourceManager][0]' -o tsv)/metadata/endpoints?api-version=2020-06-01"
  ```

* Delete the Terraform Pipelines repo cloned to your local machine from terraform-template-public that was used to run the installation script. `rm -rf Terraform-Pipelines`
* Navigate to your newly created project and grab the clone urls for **your** Terraform-Code and Terraform-Pipelines.
* Clone Terraform-code and Terraform-Pipelines locally.
* Develop your application and infrastructure. [See Local development setup](LOCAL_DEVELOPER_SETUP.MD)
* Push when ready!

---

### Azure DevOps Server Scenario 3

#### Import an existing Terraform Project, targeting Azure Commercial Cloud

This scenario requires that a running installation of Azure DevOps 2020 on a virtual machine. Project Lucidity includes an associated [server deployment project](https://dev.azure.com/csedevops/terraform-template/_git/AzDO-Server-Deployment) that can be used as a starting point.  This ARM template based setup can be used to assist with the infrastructure set up and deployment. (Documentation on the Server Deployment project will be available soon.)

This scenario is focused on creating a Lucidity Based Azure DevOps Project and importing in existing code. This is the recommended approach , rather than trying to recreate Lucidity pipelines and features in an existing Azure DevOps Project. The reason for this is because there is a lot of configuration that happens as part of the install process.

#### Scenario Steps

* Clone the Lucidity Terraform Pipelines Repo
  <https://dev.azure.com/csedevops/terraform-template-public/_git/Terraform-Pipelines>
* Navigate to the tools/install folder.
* Run the install script:

    ```bash
     ./install.sh \
    -l <Azure DevOps Server Url and Collection> \
    -n <Azure DevOps Project Name> \
    -p <PAT> \
    -r <Region> \
    --subName "<Azure Subscription Name>" \
    -s "SP_ID=<Service Principal Client Id> SP_SUBSCRIPTION_ID=<Azure Subscription ID> SP_SECRET=<Serice Principal Secret> SP_TENANT_ID=<Azure Active Directory Tenant Id>" \
    -c AzureUSGovernment \
    --metaDataHost <Meta Data Host URL> \
    -d
   ```

  **Note**: -l options requires both a server url and also collection name. (eg. <https://my-server-vm/ProjectCollection>)

  MetaData Host is the Hostname of the Azure Metadata Service, [used by Terraform to obtain the Cloud Environment when using a Custom Azure Environment.](https://www.terraform.io/docs/providers/azurerm/index.html#metadata_host)

  To get the meta data url:

  * Find the resource manager url for your desired cloud via the `az` cli.

      ```bash
        az cloud show --query '[endpoints.resourceManager]'
      ```

  * Meta Data host is  `https://<resource manager url>/metadata/endpoints?api-version=2020-06-01`

  To get the meta host in a single command:

  ```bash
   echo "$(az cloud show --query '[endpoints.resourceManager][0]' -o tsv)/metadata/endpoints?api-version=2020-06-01"
  ```

* Delete the Terraform Pipelines repo cloned from terraform-template-public. `rm -rf Terraform-Pipelines`
* Navigate to your newly created project and grab the clone urls for **your** Terraform-Code and Terraform-Pipelines.
* Clone Terraform-code and Terraform-Pipelines locally.
* Copy in your terraform code using the [layer/deployment folder structure](DIRECTORY_STRUCTURE.md). This may require some refactoring and adaption.
* Push when ready!

---

### Azure DevOps Server Scenario 4

#### Deploying an existing Lucidity Project to an Air-Gapped Environment running Azure DevOps Server and Targeting an Azure Private Cloud

This scenario requires that a running installation of Azure DevOps 2020 on a virtual machine. Project Lucidity includes an associated [server deployment project](https://dev.azure.com/csedevops/terraform-template/_git/AzDO-Server-Deployment) that can be used as a starting point.  This ARM template based setup can be used to assist with the infrastructure set up and deployment. (Documentation on the Server Deployment project will be available soon.)

In this scenario a Lucidity based project is developed Azure DevOps Services (PAAS) and deployed to Azure DevOps Server in an air-gapped environment. The expectation here is that the AzDo Server is a deployment target and not a development platform. In order to have full traceability Project Lucidity supports migrating a code repo to ensure git commits are persisted across to the air-gapped environment.

#### Scenario Steps

* Follow the steps in [Create a new Project and generate a sample application. Targeting Azure Commercial Cloud.](#azure-devops-services-scenario-1) to set up a hosted service project.
* Navigate to the tools folder and run create-tar-files.ps1 or create-tar-files.sh. This will create two tar files (terraform-code.tar.gz and terraform-pipelines.tar.gz in either ~/tmp or C:\temp.
* Copy the tar files to your Deployment Server Project and place in the folder src/AzDo-LinuxAgent/dependencies
* Run the Server Deployment to create a new AzDo Server in your air-gapped environment.
* Navigate to the air-gapped environment and ssh to the build agent VM.
* Navigate to the folder ~/tfsource/Terraform-Pipelines/tools/install
* Invoke the install script.

    ```bash
     ./install.sh \
    -l <Azure DevOps Server Url and Collection> \
    -n <Azure DevOps Project Name> \
    -p <PAT> \
    -r <Region> \
    --subName "<Azure Subscription Name>" \
    -s "SP_ID=<Service Principal Client Id> SP_SUBSCRIPTION_ID=<Azure Subscription ID> SP_SECRET=<Serice Principal Secret> SP_TENANT_ID=<Azure Active Directory Tenant Id>" \
    -c AzureUSGovernment \
    --metaDataHost <Meta Data Host URL> \
    --private \
    --offline \
    --useExistingEnvs \
    -d
   ```

The following addition flags are used in this scenario:

--private: This applies changed needed to the Terraform backend configuration. Specifically there is a change required to enable remote state targeting an Azure Storage account on Azure Private Clouds.

--offline: This option imports the Terraform-Code and Terraform-Pipelines repositories from the local disk rather than importing from the public Lucidity project. This is especially important since in an air-gapped environment, external network access may not be available.

--useExistingEnvs: This option allows for reusing values in Terraform-Code/environments. By default the install script created a new environments folder with templated values. Including this flag, skips that process and imports your envs from disk.

---

### Azure DevOps Server Scenario 5

#### Updating Terraform-Code and Terraform-Pipelines in an Air-Gapped Environment running Azure DevOps Server with a previously deployed (existing) Azure DevOper Server Project

In this scenario, an Azure DevOps server VM should be configured and a project has been installed and deployed to that server.

The goal of this scenario is to take updates to Terraform-Code and Terraform-Pipelines from a local development environment and push those changes to the air-gapped Azure DevOps server environment.

In this workflow, development is conducted against a hosted Azure DevOps Service project and deployed to an Azure DeveOps Server in an air-gapped environment.

#### Scenario Steps

* Ensure that the Terraform-Code and Terraform-Pipelines repositories are cloned locally and have all the latest changes pulled down.
* Navigate to the Terraform-Pipelines/tools folder.
* Invoke either `create-tar-files.ps1` or `create-tar-files.sh` to generate two new tar.gz files in either c:\temp or ~/tmp.
* Move these files to the air-gapped environment.
* Open an administrator powershell console and SCP the two .tar.gz files to the agent vm.
* On the Azure DevOps Server , ssh to the agent vm via the link on the desktop.
* Navigate to ~/tfsource/Terraform-Pipelines/tools/install
* Invoke update-code.sh -h and update-pipelines.sh -h
* Invoke update-code-sh and provide the required input options.
* Invoke update-pipelines.sh and provide the required input options.
