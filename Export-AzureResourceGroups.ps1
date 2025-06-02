<# 
.SYNOPSIS
Export-AzureResourceGroups.ps1 - Report list of all resource groups.

.DESCRIPTION
This script generates a report of all resource groups in selected Azure subscriptions.

Author: Chris Polewiak
Contact: chris@polewiak.pl

.LINK
GitHub source repository: https://github.com/SiiPoland/azure-inventory
#>

param (
    [Alias("s", "SubscriptionId")]
    [string]$selected_SubscriptionId = "",
    [Alias("o", "OutputFile")]
    [string]$OutputFileName = "AzureResourceGroup-Export.csv"
)

# Ensure user is logged in to Azure
if (!(Get-AzContext)) { 
    Write-Output "Logging in to Azure..."
    Login-AzAccount
}

Write-Output "*** Azure Inventory ***"
Write-Output "==========================================================================="
Write-Output "Script for preparing a report of all resources in selected subscriptions"
Write-Output " Selected Subscription: $selected_SubscriptionId"
Write-Output "==========================================================================="

# Define report array
Class AzureResourceGroup {
    [string]$Name
    [string]$Location
    [string]$SubscriptionId
    [string]$SubscriptionName
    [string]$ResourceGroupId
}

$report = @()

# Get subscriptions
$subscriptionsList = Get-AzSubscription | Sort-Object Name
if ($subscriptionsList.Count -eq 0) {
    Write-Output "No subscriptions found."
    Exit
}

$SubscriptionNumber = 0
foreach ($subscription in $subscriptionsList) {
    if ($selected_SubscriptionId -ne "" -and $subscription.Id -ne $selected_SubscriptionId) {
        continue
    }

    $SubscriptionNumber++
    $SubscriptionName = $subscription.Name
    $SubscriptionId = $subscription.Id

    Write-Output "- Getting Resource Groups from Subscription $SubscriptionNumber/$($subscriptionsList.Count): $SubscriptionName ($SubscriptionId)"
    Select-AzSubscription -SubscriptionId $SubscriptionId | Out-Null

    $ResourceGroups = Get-AzResourceGroup
    Write-Output "  - Found $($ResourceGroups.Count) resource groups"

    foreach ($ResourceGroup in $ResourceGroups) {
        # Create Report Item for Azure Resource
        $reportItem = New-Object AzureResourceGroup
        $reportItem.Name = $ResourceGroup.ResourceGroupName
        $reportItem.Location = $ResourceGroup.Location
        $reportItem.SubscriptionID = $SubscriptionId
        $reportItem.SubscriptionName = $SubscriptionName
        $reportItem.ResourceGroupId = $ResourceGroup.ResourceId

        $report += $reportItem
    }
}

# Export report to CSV
$ReportFile_csv = Join-Path -Path (Get-Location).Path -ChildPath $OutputFileName
Write-Output "Exporting report to $ReportFile_csv"
$report | Sort-Object Name | Export-Csv -NoTypeInformation -Path $ReportFile_csv
Write-Output "Report generated successfully."
