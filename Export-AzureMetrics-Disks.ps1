<#
.SYNOPSIS
Export-AzureMetrics-Disks.ps1 - Report performance metrics for all Managed Disks in Azure subscription.

.DESCRIPTION
This script will get the performance metrics (Disk Bytes/sec, Disk Operations/sec) for all the Managed Disks in the Azure subscription

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
$resourcesList = $data | Where-Object ResourceType -eq 'Microsoft.Compute/disks'

# Parameters
$startTime = (Get-Date -day 1 -Hour 0 -Minute 0 -Second 0).AddMonths(-3)
$endTime = (Get-Date -day 1 -Hour 0 -Minute 0 -Second 0).AddDays(-1)
$reportFilename = "AzureMetrics-Disks"

Write-Host "-------------------------------------------"
Write-Host " Start date: $startTime"
Write-Host " End date: $endTime"
Write-Host "-------------------------------------------"
Write-Host "Total Resources: $($resourcesList.Count)"
Write-Host "-------------------------------------------"
Write-Host " Source: $SourceFile"
Write-Host " Destination: $reportFilename"
Write-Host "-------------------------------------------"

$report = @()

# Define the AzureMetric class
Class AzureMetric
{
    [string]$ResourceId
    [string]$DiskReadBytesSec_Average
    [string]$DiskReadBytesSec_Maximum
    [string]$DiskWriteBytesSec_Average
    [string]$DiskWriteBytesSec_Maximum
    [string]$DiskReadOperationsSec_Average
    [string]$DiskReadOperationsSec_Maximum
    [string]$DiskWriteOperationsSec_Average
    [string]$DiskWriteOperationsSec_Maximum
}

$AggregationType = "Average"
$TimeGrain = "00:05:00"

# Get the metrics for each disk
$counter=0
$resourcesList | ForEach-Object {
    $ResourceId = $_.ResourceId
    $counter++
    Write-Host "Processing $counter of $($resourcesList.Count): $ResourceId"

    $reportItem = New-Object AzureMetric
    $reportItem.ResourceId = $ResourceId

    $metrics = $(get-azmetric -ResourceId $ResourceId -MetricName "Composite Disk Read Bytes/sec" -StartTime $startTime -EndTime $endTime -AggregationType $AggregationType -TimeGrain $TimeGrain -WarningAction SilentlyContinue).Timeseries.Data
    $reportItem.DiskReadBytesSec_Average = $($metrics | Measure-Object -Property average -Average).Average
    $reportItem.DiskReadBytesSec_Maximum = $($metrics | Measure-Object -Property average -Maximum).Maximum

    $metrics = $(get-azmetric -ResourceId $ResourceId -MetricName "Composite Disk Write Bytes/sec" -StartTime $startTime -EndTime $endTime -AggregationType $AggregationType -TimeGrain $TimeGrain -WarningAction SilentlyContinue).Timeseries.Data
    $reportItem.DiskWriteBytesSec_Average = $($metrics | Measure-Object -Property average -Average).Average
    $reportItem.DiskWriteBytesSec_Maximum = $($metrics | Measure-Object -Property average -Maximum).Maximum

    $metrics = $(get-azmetric -ResourceId $ResourceId -MetricName "Composite Disk Read Operations/sec" -StartTime $startTime -EndTime $endTime -AggregationType $AggregationType -TimeGrain $TimeGrain -WarningAction SilentlyContinue).Timeseries.Data
    $reportItem.DiskReadOperationsSec_Average = $($metrics | Measure-Object -Property average -Average).Average
    $reportItem.DiskReadOperationsSec_Maximum = $($metrics | Measure-Object -Property average -Maximum).Maximum

    $metrics = $(get-azmetric -ResourceId $ResourceId -MetricName "Composite Disk Write Operations/sec" -StartTime $startTime -EndTime $endTime -AggregationType $AggregationType -TimeGrain $TimeGrain -WarningAction SilentlyContinue).Timeseries.Data
    $reportItem.DiskWriteOperationsSec_Average = $($metrics | Measure-Object -Property average -Average).Average
    $reportItem.DiskWriteOperationsSec_Maximum = $($metrics | Measure-Object -Property average -Maximum).Maximum

    $report += $reportItem
}

# Export the report to a CSV file
$ReportFileName_csv = "$($reportFilename).csv"
$report | Sort-Object | Export-CSV -NoTypeInformation -Path $ReportFileName_csv
