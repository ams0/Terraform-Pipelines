# Sample resources

After you have done with the [project installation](./PROJECT_INSTALLATION.md), sample resources have been deployed into your subscription. The whole example is based on an official Microsoft ASP.NET Core application sample - eShopOnWeb.

## Files structure

All files related to sample resources you can find inside the Terrarform-Code repository with the below paths:

- /apps/eShopOnWeb/\* - source code of the application (version from Sep 14, 2020)
- /environments/dev/staging.layer3.env - variables/configuration for Dev environment.
- /environments/staging/staging.layer3.env - variables/configuration for Staging environment.
- /terraform/02_sql/01_deployment/\* - Terraform code for SQL databases.
- /terraform/03_webapp/01_deployment/\* - Terraform code for Web Application.

## Azure Resources

### 02_sql layer

Terraform deploys a Resource Group with Azure SQL Server instance that contains 2 databases:

- catalogdb
- identitydb

### 03_webapp layer

Terraform deploys a Resource Group with:

- App Service plan
- Web App

In this layer, Terraform will execute 2 bash scripts to seed SQL databases with sample data.

## References

- [Microsoft eShopOnWeb ASP.NET Core Reference Application](https://github.com/dotnet-architecture/eShopOnWeb)
