# Pipeline variables

Each pipeline contains some variables for input, some are mandatory (with default values), others are optional configuration values. In this document, you can find details about each pipeline inputs.

<br/>
---
## Pull Request Environment Pipelines
---

### pr
#### Pipeline that runs as part of a  Pull Request.

| Name              | Description                                                                                           | Example             | Default             | Settable at Runtime |
| ----------------- | ----------------------------------------------------------------------------------------------------- | ------------------- | ------------------- | ------------------- |
| tfCodeBranch      | Branch of Terraform-Code that will be used for this deployment                                        | master              | master              | ✓ |
| DEPLOYMENT_DIR    | Directory to deploy. Used to execute only a single deployment in a layer.                             | 02_net/01_dep       |                     | ✓ |
| gitDiffBaseBranch | Name of the base branch to compare                                                                    | master              | master              | ✓ |
| environment       | Name of the Environment.                                                                              | pr                  | pr                  | ✗ |
| FULL_DEPLOYMENT   | If this variable is detected by gitDiff to be present, gitDiff will return all layers and deployments | false               | false               | ✗ | 
| azureSubscription | Name of the AzureRM service connection .                                                              | sc-azurerm-sp       | sc-azurerm-sp       | ✗ |
| INSTALL_TYPE      | SERVER or PAAS. Indicates if this instance is running on AzDo Services (PAAS) or Server               | SERVER              | PAAS                | ✗ |
| autoDestroy       | This setting allows you to persist the pr environment even after the PR pipeline completes. Setting to false will ensure the pr environment is not removed at the end of the PR.        | false               | false               | ✗ |

### pr.infrastructure
#### Infrastructure deployment for Pull Requests.

<br/>

| Name                 | Description                                                                                           | Example             | Default                  | Settable at Runtime |
| -----------------    | ----------------------------------------------------------------------------------------------------- | ------------------- | -------------------      | ------------------- |
| tfCodeBranch         | Branch of Terraform-Code that will be used for this deployment                                        | master              | master                   | ✓ |
| DEPLOYMENT_DIR       | Directory to deploy. Used to execute only a single deployment in a layer.                             | 02_net/01_dep       |                          | ✓ |
| FULL_DEPLOYMENT      | If this variable is detected by gitDiff to be present, gitDiff will return all layers and deployments | false               | false                    | ✓ |
| gitDiffBaseBranch    | Name of the base branch to compare                                                                    | master              | master                   | ✓ | 
| gitDiffCompareBranch | Name of the incoming feature branch to compare                                                        | feature1            | $\(Build.SourceBranch\)  | ✓ | 
| environment          | Name of the Environment.                                                                              | pr                  | pr                       | ✗ |
| INSTALL_TYPE         | SERVER or PAAS. Indicates if this instance is running on AzDo Services (PAAS) or Server               | SERVER              | PAAS                     | ✗ |
| azureSubscription    | Name of the AzureRM service connection .                                                              | sc-azurerm-sp       | sc-azurerm-sp            | ✗ |

### pr.storageinit
#### Configure PR pr environment remote storage

<br/>

| Name                  | Description                                                                                           | Example             | Default             | Settable at Runtime |
| -----------------     | ----------------------------------------------------------------------------------------------------- | ------------------- | ------------------- | ------------------- |
| tfCodeBranch          | Branch of Terraform-Code that will be used for this deployment                                        | master              | master              | ✓ |
| resetTFStateContainer | If set to true, this performs a hard reset of the PR pipeline remote state.                           | true                | false               | ✓ |
| environment           | Name of the Environment.                                                                              | pr                  | pr                  | ✗ |
| INSTALL_TYPE          | SERVER or PAAS. Indicates if this instance is running on AzDo Services (PAAS) or Server               | SERVER              | PAAS                | ✗ |
| azureSubscription     | Name of the AzureRM service connection .                                                              | sc-azurerm-sp       | sc-azurerm-sp       | ✗ |

<br/>

### pr.backupremotestate

| Name                  | Description                                                                                           | Example             | Default             | Settable at Runtime |
| -----------------     | ----------------------------------------------------------------------------------------------------- | ------------------- | ------------------- | ------------------- |
| environment           | Name of the Environment.                                                                              | pr                  | pr                  | ✗ |
| INSTALL_TYPE          | SERVER or PAAS. Indicates if this instance is running on AzDo Services (PAAS) or Server               | SERVER              | PAAS                | ✗ |
| azureSubscription     | Name of the AzureRM service connection .                                                              | sc-azurerm-sp       | sc-azurerm-sp       | ✗ |

<br/>
---
## Dev Environment Pipelines
---

<br/>

### dev.infrastructure
#### Infrastructure deployment for dev environment.

| Name                 | Description                                                                                           | Example             | Default                  | Settable at Runtime |
| -----------------    | ----------------------------------------------------------------------------------------------------- | ------------------- | -------------------      | ------------------- |
| tfCodeBranch         | Branch of Terraform-Code that will be used for this deployment                                        | master              | master                   | ✓ |
| DEPLOYMENT_DIR       | Directory to deploy. Used to execute only a single deployment in a layer.                             | 02_net/01_dep       |                          | ✓ |
| FULL_DEPLOYMENT      | If this variable is detected by gitDiff to be present, gitDiff will return all layers and deployments | false               | false                    | ✓ |
| gitDiffBaseBranch    | Name of the base branch to compare                                                                    | master              | master                   | ✓ | 
| gitDiffCompareBranch | Name of the incoming feature branch to compare                                                        | feature1            | $\(Build.SourceBranch\)  | ✓ | 
| environment          | Name of the Environment.                                                                              | dev                 | dev                      | ✗ |
| INSTALL_TYPE         | SERVER or PAAS. Indicates if this instance is running on AzDo Services (PAAS) or Server               | SERVER              | PAAS                     | ✗ |
| azureSubscription    | Name of the AzureRM service connection .                                                              | sc-azurerm-sp       | sc-azurerm-sp            | ✗ |

<br/>

### dev.storageinit
#### Configure dev pr environment remote storage

| Name                  | Description                                                                                           | Example             | Default             | Settable at Runtime |
| -----------------     | ----------------------------------------------------------------------------------------------------- | ------------------- | ------------------- | ------------------- |
| tfCodeBranch          | Branch of Terraform-Code that will be used for this deployment                                        | master              | master              | ✓ |
| environment           | Name of the Environment.                                                                              | dev                 | dev                 | ✗ |
| INSTALL_TYPE          | SERVER or PAAS. Indicates if this instance is running on AzDo Services (PAAS) or Server               | SERVER              | PAAS                | ✗ |
| azureSubscription     | Name of the AzureRM service connection .                                                              | sc-azurerm-sp       | sc-azurerm-sp       | ✗ |

<br/>

### dev.backupremotestate

| Name                  | Description                                                                                           | Example             | Default             | Settable at Runtime |
| -----------------     | ----------------------------------------------------------------------------------------------------- | ------------------- | ------------------- | ------------------- |
| environment           | Name of the Environment.                                                                              | dev                 | dev                 | ✗ |
| INSTALL_TYPE          | SERVER or PAAS. Indicates if this instance is running on AzDo Services (PAAS) or Server               | SERVER              | PAAS                | ✗ |
| azureSubscription     | Name of the AzureRM service connection .                                                              | sc-azurerm-sp       | sc-azurerm-sp       | ✗ |


<br/>
---
## Prod Environment Pipelines
---

### prod.infrastructure
#### Infrastructure deployment for prod environment.

| Name                 | Description                                                                                           | Example             | Default                  | Settable at Runtime |
| -----------------    | ----------------------------------------------------------------------------------------------------- | ------------------- | -------------------      | ------------------- |
| tfCodeBranch         | Branch of Terraform-Code that will be used for this deployment                                        | master              | master                   | ✓ |
| DEPLOYMENT_DIR       | Directory to deploy. Used to execute only a single deployment in a layer.                             | 02_net/01_dep       |                          | ✓ |
| FULL_DEPLOYMENT      | If this variable is detected by gitDiff to be present, gitDiff will return all layers and deployments | false               | false                    | ✓ |
| gitDiffBaseBranch    | Name of the base branch to compare                                                                    | master              | master                   | ✓ | 
| gitDiffCompareBranch | Name of the incoming feature branch to compare                                                        | feature1            | $\(Build.SourceBranch\)  | ✓ | 
| environment          | Name of the Environment.                                                                              | prod                | prod                       | ✗ |
| INSTALL_TYPE         | SERVER or PAAS. Indicates if this instance is running on AzDo Services (PAAS) or Server               | SERVER              | PAAS                     | ✗ |
| azureSubscription    | Name of the AzureRM service connection .                                                              | sc-azurerm-sp       | sc-azurerm-sp            | ✗ |

<br/>

### prod.storageinit
#### Configure prod prod environment remote storage

| Name                  | Description                                                                                           | Example             | Default             | Settable at Runtime |
| -----------------     | ----------------------------------------------------------------------------------------------------- | ------------------- | ------------------- | ------------------- |
| tfCodeBranch          | Branch of Terraform-Code that will be used for this deployment                                        | master              | master              | ✓ |
| environment           | Name of the Environment.                                                                              | prod                | prod                | ✗ |
| INSTALL_TYPE          | SERVER or PAAS. Indicates if this instance is running on AzDo Services (PAAS) or Server               | SERVER              | PAAS                | ✗ |
| azureSubscription     | Name of the AzureRM service connection .                                                              | sc-azurerm-sp       | sc-azurerm-sp       | ✗ |

<br/>

### prod.backupremotestate

| Name                  | Description                                                                                           | Example             | Default             | Settable at Runtime |
| -----------------     | ----------------------------------------------------------------------------------------------------- | ------------------- | ------------------- | ------------------- |
| environment           | Name of the Environment.                                                                              | prod                | prod                | ✗ |
| INSTALL_TYPE          | SERVER or PAAS. Indicates if this instance is running on AzDo Services (PAAS) or Server               | SERVER              | PAAS                | ✗ |
| azureSubscription     | Name of the AzureRM service connection .                                                              | sc-azurerm-sp       | sc-azurerm-sp       | ✗ |

<br/>
---
## Shared Pipelines
---

###  env.compile
#### Combine env files per environment into a single file and upload to secure files.

| Name                  | Description                                                                                           | Example             | Default             | Settable at Runtime |
| -----------------     | ----------------------------------------------------------------------------------------------------- | ------------------- | ------------------- | ------------------- |
| tfCodeBranch          | Branch of Terraform-Code that will be used for this deployment                                        | master              | master              | ✓ |
| environment           | Name of the Environment.                                                                              | pr                  | pr                  |  ✓ |
| INSTALL_TYPE          | SERVER or PAAS. Indicates if this instance is running on AzDo Services (PAAS) or Server               | SERVER              | PAAS                | ✗ |

<br/>

### tfapply
#### Run terraform apply (called by all infrastructure pipelines)

| Name                  | Description                                                                                           | Example             | Default             | Settable at Runtime |
| -----------------     | ----------------------------------------------------------------------------------------------------- | ------------------- | ------------------- | ------------------- |
| environment          | Name of the Environment.                                                                              | pr                  | dev                      | ✓ |
| tfCodeBranch         | Branch of Terraform-Code that will be used for this deployment                                        | master              | master                   | ✓ |
| azureSubscription    | Name of the AzureRM service connection .                                                              | sc-azurerm-sp       | sc-azurerm-sp            | ✓ |
| DEPLOYMENT_DIR       | Directory to deploy. Used to execute only a single deployment in a layer.                             | 02_net/01_dep       |                          | ✓ |
| INSTALL_TYPE         | SERVER or PAAS. Indicates if this instance is running on AzDo Services (PAAS) or Server               | SERVER              | PAAS                     | ✗ |

<br/>

### tfplan
#### Run terraform plan (called by all infrastructure pipelines)

| Name                  | Description                                                                                           | Example             | Default             | Settable at Runtime |
| -----------------     | ----------------------------------------------------------------------------------------------------- | ------------------- | ------------------- | ------------------- |
| environment          | Name of the Environment.                                                                              | pr                  | dev                      | ✓ |
| tfCodeBranch         | Branch of Terraform-Code that will be used for this deployment                                        | master              | master                   | ✓ |
| azureSubscription    | Name of the AzureRM service connection .                                                              | sc-azurerm-sp       | sc-azurerm-sp            | ✓ |
| DEPLOYMENT_DIR       | Directory to deploy. Used to execute only a single deployment in a layer.                             | 02_net/01_dep       |                          | ✓ |
| INSTALL_TYPE         | SERVER or PAAS. Indicates if this instance is running on AzDo Services (PAAS) or Server               | SERVER              | PAAS                     | ✗ |

<br/>

### tfdestroy 
#### Remove a single deployment.

| Name                  | Description                                                                                           | Example             | Default             | Settable at Runtime |
| -----------------     | ----------------------------------------------------------------------------------------------------- | ------------------- | ------------------- | ------------------- |
| environment          | Name of the Environment.                                                                              | pr                  | dev                      | ✓ |
| tfCodeBranch         | Branch of Terraform-Code that will be used for this deployment                                        | master              | master                   | ✓ |
| azureSubscription    | Name of the AzureRM service connection .                                                              | sc-azurerm-sp       | sc-azurerm-sp            | ✓ |
| DEPLOYMENT_DIR       | Directory to deploy. Used to execute only a single deployment in a layer.                             | 02_net/01_dep       |                          | ✓ |
| INSTALL_TYPE         | SERVER or PAAS. Indicates if this instance is running on AzDo Services (PAAS) or Server               | SERVER              | PAAS                     | ✗ |

<br/>

### tfdestroy.full
#### Destroy all layers.

| Name                  | Description                                                                                           | Example             | Default             | Settable at Runtime |
| -----------------     | ----------------------------------------------------------------------------------------------------- | ------------------- | ------------------- | ------------------- |
| environment          | Name of the Environment.                                                                              | pr                  | dev                      | ✓ |
| tfCodeBranch         | Branch of Terraform-Code that will be used for this deployment                                        | master              | master                   | ✓ |
| azureSubscription    | Name of the AzureRM service connection .                                                              | sc-azurerm-sp       | sc-azurerm-sp            | ✓ |
| DEPLOYMENT_DIR       | Directory to deploy. Used to execute only a single deployment in a layer.                             | 02_net/01_dep       |                          | ✓ |
| INSTALL_TYPE         | SERVER or PAAS. Indicates if this instance is running on AzDo Services (PAAS) or Server               | SERVER              | PAAS                     | ✗ |

### generate.tfdestroy.full
#### Generate destroy all pipleines by scanning terraform folder and building layer matrix.

| Name                  | Description                                                                                           | Example             | Default             | Settable at Runtime |
| -----------------     | ----------------------------------------------------------------------------------------------------- | ------------------- | ------------------- | ------------------- |
| environment          | Name of the Environment.                                                                              | pr                  | dev                      | ✓ |
| tfCodeBranch         | Branch of Terraform-Code that will be used for this deployment                                        | master              | master                   | ✓ |
| azureSubscription    | Name of the AzureRM service connection .                                                              | sc-azurerm-sp       | sc-azurerm-sp            | ✓ |
| DEPLOYMENT_DIR       | Directory to deploy. Used to execute only a single deployment in a layer.                             | 02_net/01_dep       |                          | ✓ |
| INSTALL_TYPE         | SERVER or PAAS. Indicates if this instance is running on AzDo Services (PAAS) or Server               | SERVER              | PAAS                     | ✗ |

