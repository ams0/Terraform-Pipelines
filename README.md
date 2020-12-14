# Project Lucidity

---
Project Lucidity allows you to easily deploy infrastructure to [Azure](https://azure.microsoft.com/) using [Terraform.](https://www.terraform.io/) The template enables you to easily create a new Azure DevOps project.

As part of the instlattion, the following will be automatically generated:

A new Azure DevOps Project in your desired organisation which includes:

* A Terraform-Code repository populated with a sample application and terraform code to deploy this app.
* A Terraform-Pipelines repository populated with the Azure Pipelines yaml needed to deploy to multiple environments, perform environment tear-down and also a pull request workflow.
* Azure Pipelines used to deploy environments, teardown environments and handle pull requests.
* Variable Groups used by various pipelines.

---

## Table of Contents

* [Project Installation](./docs/PROJECT_INSTALLATION.md)
* [Project Installation Scenarios](./docs/PROJECT_INSTALLATION_SCENARIOS.md)
* [Install Script Flag Reference](./docs/INSTALL_SCRIPT_FLAGS.md)
* [Infrastructure Pipeline Overview](./docs/INFRASTRUCTUREPIPELINEOVERVIEW.md)
* [Testing Developer Guide](./docs/DEVELOPERGUIDEFORTESTING.md)
* [Directory Structure](./docs/DIRECTORY_STRUCTURE.md)
* [Pipelines](./docs/PIPELINES.md)
* [Testing Terraform Code](./docs/TESTINGTERRAFORMCODE.md)
* [Pipeline Variables](./docs/PIPELINEVARIABLES.md)
* [Infrastructure Pipeline Operations](./docs/INFRASTRUCTUREPIPELINEOPERATIONS.md)
* [Service Connections](./SERVICE_CONNECTIONS.md)

Tools:

* [TF Bundle - Packaging Terraform and Providers](../tools/tf-bundle/README.md)

---

## Contribution Guide

Please see the [Contribution Guide document.](./docs/CONTRIBUTION_GUIDE.md)

---

## LICENSE

This project is under an [MIT License.](./LICENSE)

---

## Microsoft Open Source Code of Conduct

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).

Resources:

* [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/)
* [Microsoft Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/)
* Contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with questions or concerns
