terraform {
  # Version of Terraform to include in the bundle. An exact version number
  # is required.
  version = "0.13.4"
}

# Define which provider plugins are to be included
providers {
  # Include the newest "aws" provider version in the 1.0 series.
    azurerm = {
      versions = ["~> 2.23.0","=2.8.0"]
    }

  # Include both the newest 1.0 and 2.0 versions of the "google" provider.
  # Each item in these lists allows a distinct version to be added. If the
  # two expressions match different versions then _both_ are included in
  # the bundle archive.
  azuread = {
    versions = ["=0.7"]
  }

  null = {
     versions = ["=3.0.0"]
  }
}
