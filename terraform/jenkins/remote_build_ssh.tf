# SPDX-FileCopyrightText: 2023 Technology Innovation Institute (TII)
#
# SPDX-License-Identifier: Apache-2.0

# Create a ED25519 key, which the jenkins master will use to authenticate with
# builders.
resource "tls_private_key" "ed25519_remote_build" {
  algorithm = "ED25519"
}

# Dump the ed25519 public key to disk
resource "local_file" "ed25519_remote_build_pubkey" {
  filename        = "${path.module}/id_ed25519_remote_build.pub"
  file_permission = "0644"
  content         = tls_private_key.ed25519_remote_build.public_key_openssh
}

# Create an Azure key vault.
resource "azurerm_key_vault" "ssh_remote_build" {
  # this must be globally unique
  name                = "ghaf-ssh-remote-build"
  location            = azurerm_resource_group.default.location
  resource_group_name = azurerm_resource_group.default.name
  sku_name            = "standard"
  #  The Azure Active Directory tenant ID that should be used for authenticating
  # requests to the key vault.
  tenant_id = data.azurerm_client_config.current.tenant_id
}

data "azurerm_client_config" "current" {}

# Put the ed25519 private key used for ssh as a secret.
resource "azurerm_key_vault_secret" "ssh_remote_build" {
  name         = "remote-build-ssh-private-key"
  value        = tls_private_key.ed25519_remote_build.private_key_openssh
  key_vault_id = azurerm_key_vault.ssh_remote_build.id

  # Each of the secrets needs an explicit dependency on the access policy.
  # Otherwise, Terraform may attempt to create the secret before creating the
  # access policy.
  # https://stackoverflow.com/a/74747333
  depends_on = [
    azurerm_key_vault_access_policy.ssh_remote_build_terraform
  ]
}

resource "azurerm_key_vault_access_policy" "ssh_remote_build_terraform" {
  key_vault_id = azurerm_key_vault.ssh_remote_build.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  # TODO: set some common group as object_id?
  object_id = data.azurerm_client_config.current.object_id

  secret_permissions = [
    "Get",
    "List",
    "Set"
  ]
}
