<# 
.SYNOPSIS
Export-AzureResources.ps1 - Report CPU metrics for all App Service Plans in Azure subscription.

.DESCRIPTION
This script will get the CPU metrics for all the App Service Plans in the Azure subscription

Author: Chris Polewiak
Contact: chris@polewiak.pl

.LINK
GitHub source repository: https://github.com/SiiPoland/azure-inventory

#>
param (
    [Alias("source")]
    [string]$SourceFile = "AzureResources-Export.csv"
)
# Import the CSV file
$data = Import-Csv -Path $SourceFile -Delimiter ','
$resourcesList = $data | Where-Object ResourceType -eq 'Microsoft.Web/serverFarms'

# Parameters
$startTime = (Get-Date -day 1 -Hour 0 -Minute 0 -Second 0).AddMonths(-3)
$endTime   = (Get-Date -day 1 -Hour 0 -Minute 0 -Second 0).AddDays(-1)
$reportFilename = "AzureMetrics-Web-serverFarms"

Write-Host "-------------------------------------------"
Write-Host "     Start date: $startTime"
Write-Host "       End date: $endTime"
Write-Host "-------------------------------------------"
Write-Host "Total Resources: $($resourcesList.Count)"
Write-Host "-------------------------------------------"
Write-Host "         Source: $SourceFile"
Write-Host "    Destination: $reportFilename"
Write-Host "-------------------------------------------" 

$report = @()

# Define the AzureMetric class
Class AzureMetric
{
    [string]$ResourceId
    [string]$CpuPercentage_Average
    [string]$CpuPercentage_Maximum
}

$AggregationType = "Average"
$TimeGrain = "00:05:00"

# Get the metrics for each VM
$counter=0
$resourcesList | ForEach-Object {
    $ResourceId = $_.ResourceId
    
    $counter++
    Write-Host "Processing $counter of $($resourcesList.Count): $ResourceId"

    $reportItem = New-Object AzureMetric
    $reportItem.ResourceId = $ResourceId

    $metrics = $(get-azmetric -ResourceId $ResourceId -MetricName "CpuPercentage" -StartTime $startTime -EndTime $endTime -AggregationType $AggregationType -TimeGrain $TimeGrain -WarningAction SilentlyContinue -ErrorAction SilentlyContinue ).Timeseries.Data
    $reportItem.CpuPercentage_Average = $($metrics | Measure-Object -Property average -Average).Average
    $reportItem.CpuPercentage_Maximum = $($metrics | Measure-Object -Property average -Maximum).Maximum

    $report += $reportItem
}

# Export the report to a CSV file
$ReportFileName_csv = "$($reportFilename).csv"
$report | Sort-Object | Export-CSV -NoTypeInformation -Path $ReportFileName_csv
