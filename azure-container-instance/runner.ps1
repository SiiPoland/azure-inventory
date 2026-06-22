param(
    [string]$StorageAccountName = $env:STORAGE_ACCOUNT,
    [string]$ScriptContainerName = "scripts",
    [string]$ReportContainerName = "reports",
    [string]$ScriptBillingName = "Export-AzureBilling.ps1",
    [string]$ScriptResourcesName = "Export-AzureResources.ps1",
    [string]$ScriptResourceGroupsName = "Export-AzureResourceGroups.ps1"
)

Write-Output "Downloading script from Azure Storage Account: $StorageAccountName, Container: $ScriptContainerName, Script: $ScriptName"
Write-Output "[$(Get-Date -Format "yyyy-MM-dd HH:mm:ss")] Start..."

# UAMI Auth
Connect-AzAccount -Identity | Out-Null

$ctx = New-AzStorageContext -StorageAccountName $StorageAccountName -UseConnectedAccount

Write-Output "[$(Get-Date -Format "yyyy-MM-dd HH:mm:ss")] Downloading script..."
Get-AzStorageBlobContent -Container $ScriptContainerName -Blob $ScriptBillingName -Destination "/tmp/$ScriptBillingName" -Context $ctx -Force | Out-Null
Get-AzStorageBlobContent -Container $ScriptContainerName -Blob $ScriptResourcesName -Destination "/tmp/$ScriptResourcesName" -Context $ctx -Force | Out-Null
Get-AzStorageBlobContent -Container $ScriptContainerName -Blob $ScriptResourceGroupsName -Destination "/tmp/$ScriptResourceGroupsName" -Context $ctx -Force | Out-Null

# Billing
Write-Output "[$(Get-Date -Format "yyyy-MM-dd HH:mm:ss")] Executing Billing script..."

$lastMonth = (Get-Date).AddMonths(-1)
$dateFrom  = (Get-Date -Year $lastMonth.Year -Month $lastMonth.Month -Day 1).ToString("yyyy-MM")
$lastDay   = [DateTime]::DaysInMonth($lastMonth.Year, $lastMonth.Month)
$dateTo    = (Get-Date -Year $lastMonth.Year -Month $lastMonth.Month -Day $lastDay).ToString("yyyy-MM")

& "/tmp/$ScriptBillingName" -reportDateFrom $dateFrom -reportDateTo $dateTo

# Resource Groups
Write-Output "[$(Get-Date -Format "yyyy-MM-dd HH:mm:ss")] Executing Resource Groups script..."
& "/tmp/$ScriptResourceGroupsName" -o "AzureResourceGroups-$dateTo.csv"

# Resources
Write-Output "[$(Get-Date -Format "yyyy-MM-dd HH:mm:ss")] Executing Resources script..."
& "/tmp/$ScriptResourcesName"
Rename-Item -Path "AzureResources-Export.csv" -NewName "AzureResources-$dateTo.csv"
Rename-Item -Path "AzureResources-Export.json" -NewName "AzureResources-$dateTo.json"


Write-Output "[$(Get-Date -Format "yyyy-MM-dd HH:mm:ss")] Export reports to Blob Storage..."


$csvFiles = Get-ChildItem -Filter "Azure*.csv"

Foreach ($csvFile in $csvFiles) {
    Write-Output "[$(Get-Date -Format "yyyy-MM-dd HH:mm:ss")] Uploading report: $($csvFile.FullName)..."
    Set-AzStorageBlobContent -Container $ReportContainerName -File $csvFile.FullName -Blob $csvFile.Name -Context $ctx -Force
}

Write-Output "[$(Get-Date -Format "yyyy-MM-dd HH:mm:ss")] Done."

