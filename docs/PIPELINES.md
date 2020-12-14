# Pipelines

## Infrastructure pipeline - Overview

The [infrastructure pipeline](../azure-pipelines/pipeline.infrastructure.yml) is used to:

- Standardize continous integration/continous deployment of iac codebase

- Propagate changes between environments from master branch

- Establish a new environment

This pipelines contains:

- Terraform valdiations (tflint, tf validate, credential/secret scanning)

- Terraform plan/apply/ destroy detection

- Run end-to-end, integration test after each layer completes.

- Backup remote state end end of each run.

For more information on infrastructure pipeline see [infrastructure pipeline documentation](./INFRASTRUCTUREPIPELINE.md)

## Storage Init pipeline - Overview

The [storage init pipeline](../azure-pipelines/pipeline.storageinit.yml) is used to deploy the remote storage account for Terraform.  This is a one-time operation done at environment initialization.

## Pull Request Pipeline

This pipeline is used to enforce branch policy that a commit cannot be directly committed to the master branch.  It must be merged after having been approved through an associated pull request.  For more information on how Lucidity supports *Pull Request* see [Pull Request Scenatios](./PRPIPELINESCENARIOS.md).

## Task Specific pipelines

### Remote state backup pipeline

This pipeline is a wrapper for [remote state backup](../azure-pipelines/pipeline.backupremotestate.yml).  It is only a wrapper pipeline for testing.

### Terraform Plan pipeline

This [pipeline](../azure-pipelines/pipeline.tfplan.yml) is a fundamental workflow unit used to run terraform plan for a deployment.  The infrastructure pipeline triggers executions of this pipeline during execution to achieve parralelization within the layers speeding up overall execution time.  This pipeline is fully restartable should an infrastructure deployment as part of PR or environment propagation fail.

### Terraform Apply pipeline

This [pipeline](../azure-pipelines/pipeline.tfapply.yml) is a fundamental workflow unit used to run terraform apply for a deployment.  The infrastructure pipeline triggers executions of this pipeline during execution to achieve parralelization within the layers speeding up overall execution time.  This pipeline is fully restartable should an infrastructure deployment as part of PR or environment propagation fail.

### Terraform Destroy pipeline

This [pipeline](../azure-pipelines/pipeline.tfdestroy.yml) is a fundamental workflow unit used to run terraform destroy for a deployment.  This is a manually triggered pipeline used only when there is a need to destroy an entire deployment or remove a deployment from the infrastructure.  The workflow to delete a deployment is:

- Run [destroy pipeline](../azure-pipelines/pipeline.tfdestroy.yml) to destroy the infrastructure for a deployment.

- Create a branch in github.

- Delete the folder containing the deployment to be destroyed.

- Push the commit as a PR or run infrastructure pipeline.  This will trigger PR pipeline or you can manually run the infrastructure pipeline pointing it at your branch.

- Merge branch.

### PR Pipeline - Full Destroy Pipeline

This pipeline is used as part of a PR Workflow in Lucidity.  It calculates the layers and deployments in reverse order to execute the destroy operations in the correct sequence.  The logic for performing this calculation can be found in the script [generatematrix.sh](../azure-pipelines/scripts/generatematrix.sh).  For more information on how the PR pipeline works navigate to [PR Pipeline Scenarios](./PRPIPELINESCENARIOS.md).

### Compile.env Pipeline

This pipeline has a trigger such that when files in the environments/ directory are merged into master, it runs and merges all the env files for a specific environment into a single env file and uploads it into Azure DevOps secure files.  

There are two steps in this pipeline.  The first step does the compilation and collision detection.  If a collision is detected, the pipeline will fail.  The second step in the pipeline is to upload the compiled .env file to secure files.  The pipeline will upload one file per environment.  This ensures the latest configuration is stored in Secure Files of Azure DevOps.
