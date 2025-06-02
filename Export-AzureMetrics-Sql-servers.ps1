<# 
.SYNOPSIS
Export-AzureResources.ps1 - Report performance metrics for all SQL Servers Databases in Azure subscription.

.DESCRIPTION
This script will get the performance metrics for all the SQL Servers Databases in the Azure subscription

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
$resourcesList = $data | Where-Object ResourceType -eq 'Microsoft.Sql/servers/databases'

# Parameters
$startTime = (Get-Date -day 1 -Hour 0 -Minute 0 -Second 0).AddMonths(-3)
$endTime   = (Get-Date -day 1 -Hour 0 -Minute 0 -Second 0).AddDays(-1)
$reportFilename = "AzureMetrics-Sql-servers"

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
    [string]$DtuConsumptionPercent_Average
    [string]$DtuConsumptionPercent_Maximum
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

    $metrics = $(get-azmetric -ResourceId $ResourceId -MetricName "cpu_percent" -StartTime $startTime -EndTime $endTime -AggregationType $AggregationType -TimeGrain $TimeGrain -WarningAction SilentlyContinue).Timeseries.Data
    $reportItem.CpuPercentage_Average = $($metrics | Measure-Object -Property average -Average).Average
    $reportItem.CpuPercentage_Maximum = $($metrics | Measure-Object -Property average -Maximum).Maximum
 
    $metrics = $(get-azmetric -ResourceId $ResourceId -MetricName "dtu_consumption_percent" -StartTime $startTime -EndTime $endTime -AggregationType $AggregationType -TimeGrain $TimeGrain -WarningAction SilentlyContinue).Timeseries.Data
    $reportItem.DtuConsumptionPercent_Average = $($metrics | Measure-Object -Property average -Average).Average
    $reportItem.DtuConsumptionPercent_Maximum = $($metrics | Measure-Object -Property average -Maximum).Maximum
    $report += $reportItem
}

# Export the report to a CSV file
$ReportFileName_csv = "$($reportFilename).csv"
$report | Sort-Object | Export-CSV -NoTypeInformation -Path $ReportFileName_csv
