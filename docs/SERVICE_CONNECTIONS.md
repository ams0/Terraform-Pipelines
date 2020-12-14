# Service Connections

## Introduction

As part of project installation the following service connections are created for you. They are both used by Lucidity Pipelines.

## Service Connections

---

### Azure DevOps Service Connection

Name: ***sc-ado***

This is used in Azure Pipelines to communicate with an Azure DevOps project instance.  

*Note: This Service Connection Type is installed by the [Configurable Pipeline Runner Extension](https://marketplace.visualstudio.com/items?itemName=CSE-DevOps.RunPipelines).*

Inputs:

* Organization Url: https://dev.azure.com/[Azure DevOps Org] or Azure DevOps Server URI <br/>
* Release API Url: https://vsrm.dev.azure.com/[Azure DevOps Org] or Azure DevOps Server URI <br/>
    [See Release API docs](https://docs.microsoft.com/rest/api/azure/devops/release/releases/list?view=azure-devops-rest-6.0) <br/>
* Personal Access Token: [Azure DevOps PAT Token](https://docs.microsoft.com/azure/devops/organizations/accounts/use-personal-access-tokens-to-authenticate?view=azure-devops&tabs=preview-page)

---

### Azure Resource Manager

Name: ***sc-azurerm-sp***

Azure Resource Manager using service principal (manual).  This is used to deploy resources to Azure via Terraform.

If there is an issue deploying to Azure, Verifying the service connection in the edit service connection screen is a good way to troubleshoot connectivity as it has a command button to validate the connection and its associated credentials. Also , please review the [install document](./PROJECT_INSTALLATION.md) to ensure that the Service Principal has the correct roles assigned.  [See the Azure RM Service Connection docs](https://docs.microsoft.com/azure/devops/pipelines/library/connect-to-azure?view=azure-devops) for more information.

*NOTE: Please ensure "Grant access permission to all pipelines" is checked.*

Inputs:

* Environment:  Azure Cloud, Azure Stack, or an Azure Government Cloud
* Server Url: If you do not select Azure Cloud, enter the Environment URL. For Azure Stack, this will be similar to <https://management.local.azurestack.external>.
* Scope level: Subscription, Management Group.
* Subscription Id
* Subscription Name
* Service Principal Id
* Service principal key or Certificate (Lucidity uses a key provided during the install process.)
* Tenant ID
