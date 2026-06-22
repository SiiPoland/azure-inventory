#!/bin/bash

AciName="aci-finops-563242"
StorageAccountName="stfinops563242"

AciCmdLine="Connect-AzAccount -Identity; \
\$ctx = New-AzStorageContext -StorageAccountName \$env:STORAGE_ACCOUNT -UseConnectedAccount; \
Get-AzStorageBlobContent -Container 'scripts' -Blob 'runner.ps1' -Destination '/tmp/runner.ps1' -Context \$ctx -Force; \
& '/tmp/runner.ps1'"

az container create \
  --resource-group rg-plz-gwc-finops \
  --name ${AciName} \
  --image mcr.microsoft.com/azure-powershell:latest \
  --cpu 1 \
  --memory 1.5 \
  --os-type Linux \
  --assign-identity \
  --environment-variables "STORAGE_ACCOUNT=${StorageAccountName}" \
  --command-line "pwsh -Command \"${AciCmdLine}\"" \
  --restart-policy Never \
  --location germanywestcentral
