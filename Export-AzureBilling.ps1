# Install CostManagement Module
# Install-Module Az.CostManagement
$moduleName = "Az.CostManagement"
if (-not (Get-Module -ListAvailable -Name $moduleName)) {
    Install-Module -Name $moduleName -Repository PSGallery -Scope CurrentUser -Force
}
Import-Module $moduleName

param (
    [Parameter(Mandatory,
    HelpMessage="Add start date of Billing report in format YYYY-MM-DD")]
    [Alias("datefrom")]
    [DateTime]$reportDateFrom = (Get-Date -day 1),

    [Parameter(Mandatory,
    HelpMessage="Add end date of Billing report in format YYYY-MM-DD")]
    [Alias("dateto")]
    [DateTime]$reportDateTo = (Get-Date -day 1),

    [Alias("s")]
    [string]$subscriptionId = $null,

    [Alias("t")]
    [ValidateSet("Usage", "ActualCost", "AmortizedCost")]
    [string]$type = "Usage",

    [Alias("outfile")]
    [string]$outFilename = $null
)

if ( $subscriptionId ) {
    $subscriptions = Get-AzSubscription -SubscriptionId $subscriptionId
} else {
    $subscriptions = @()
    $subscriptions += Get-AzSubscription
}

function Safe-Log {
    param([string]$Message)
    if ($Message -and $Message.Trim() -ne "") {
        Write-Host $Message
    }
}

Class AzureBilling {
    [string]$SubscriptionId
    [string]$SubscriptionName
    [string]$BillingMonth
    [string]$ResourceId
    [string]$ServiceName
    [string]$ServiceTier
    [string]$Meter
    [string]$BillingQuotation
    [string]$BillingCurrency
}

if ( ! $(Get-AzContext) ) { 
    Login-AzAccount
}

$startDate = (Get-Date -day 1 -Month $reportDateFrom.Month -Year $reportDateFrom.Year )
$endDate   = (Get-Date -day 1 -Month $reportDateTo.Month -Year $reportDateTo.Year ).AddMonths(+1).AddDays(-1)
$months = 0
while($startDate.AddMonths($months) -le $endDate)
{
    $months = $months + 1
}
#$months = $months - 1

$filenameDateString = "AzureBilling-$type"
if ( $months -gt 1 ) {
    $startDate = $startDate.ToString("yyyy-MM-dd")
    $endDate   = $endDate.ToString("yyyy-MM-dd")
    $filenameDateString += "-$startDate-to-$endDate"
}
elseif ( $reportDateFrom ) {
    $startDate = $startDate.ToString("yyyy-MM-dd")
    $endDate   = $endDate.ToString("yyyy-MM-dd")
    $filenameDateString += "-$startDate-to-$endDate"
}
if ( $subscriptionId ) {
    $filenameDateString += "-for-$subscriptionId"
}
$filenameDateString += ".csv"

if ( $outFilename ) {
    $filenameDateString = $outFilename
}

Write-Host "-------------------------------------------"
Write-Host "   Start date: $startDate"
Write-Host "     End date: $endDate"
Write-Host "Subscriptions: $($subscriptions.Count)"
Write-Host "  Report type: $type"
Write-Host "  Destination: $filenameDateString"
Write-Host "-------------------------------------------"

$report = @()
$counter = 0
Foreach( $subscription in $subscriptions ) {

    $counter++

    $subscriptionId = $subscription.Id
    $subscriptionName = $subscription.Name

    for ($monthNumber = 0; $monthNumber -lt $months; $monthNumber++) {
        $startDate = (Get-Date -day 1 -Month $reportDateFrom.Month -Year $reportDateFrom.Year ).AddMonths($monthNumber)
        $endDate   = (Get-Date -day 1 -Month $reportDateFrom.Month -Year $reportDateFrom.Year ).AddMonths($monthNumber+1).AddDays(-1)
        $startDate = $startDate.ToString("yyyy-MM-dd")
        $endDate   = $endDate.ToString("yyyy-MM-dd")
        # Invoke Cost Management Query
        Write-Host "$counter of $($subscriptions.Count) Subscription: $subscriptionId ($subscriptionName) $startDate to $endDate" 

        # Create dataset to query all by the service name
        $DatasetAggregation = @{
            "PreTaxCost" = @{
                "name" = "PreTaxCost";
                "function" = "Sum"
            }
        }
        $DatasetGrouping = @(
            @{
                "type" = "Dimension";
                "name" = "ResourceId"
            },
            @{
                "type" = "Dimension";
                "name" = "ServiceName"
            },
            # @{
            #     "type" = "Dimension";
            #     "name" = "ServiceTier"
            # },
            @{
                "type" = "Dimension";
                "name" = "Meter"
            }
        );

        # Type = Usage, ActualCost, AmortizedCost

        $maxRetries = 5
        $retryDelay = 5
        $retryCount = 0
        $result = $null
        do {
            try {
                Write-Host "... attempt $($retryCount+1) " -NoNewline
                $result = Invoke-AzCostManagementQuery -Scope "/subscriptions/$subscriptionId" `
                    -Type $Type `
                    -Timeframe Custom `
                    -TimePeriodFrom $startDate `
                    -TimePeriodTo $endDate `
                    -DatasetAggregation $DatasetAggregation `
                    -DatasetGrouping $DatasetGrouping `
                    -DatasetGranularity Monthly `
                    -ErrorAction SilentlyContinue `
                    -ErrorVariable error 6> $null
                Write-Host "found $($result.Row.Count) rows"
            }
            catch {
                Write-Warning "Query failed for $subscriptionId (attempt $($retryCount + 1))"
            }

            if (-not $result -or -not $result.Row.Count) {
                Start-Sleep -Seconds $retryDelay
                $retryCount++
            }

        } while ((-not $result -or -not $result.Row.Count) -and $retryCount -lt $maxRetries)

        if (-not $result -or -not $result.Row.Count) {
            Write-Warning "No results for subscription $subscriptionId after $maxRetries attempts"
        }
        else {
            for ($index = 0; $index -lt $result.Row.Count; $index++) {

                $BillingQuotation = $result.Row[$index][0]
                $BillingMonth = $([DateTime]$result.Row[$index][1]).ToString("yyyy-MM")
                $ResourceId = $result.Row[$index][2]
                $ServiceName = $result.Row[$index][3]
                $ServiceTier = $result.Row[$index][4]
                $Meter = $result.Row[$index][5]
                $BillingCurrency = $result.Row[$index][6]

                # Write-Host ".. Billing Month: $BillingMonth Resource: $ResourceId Quotation: $BillingQuotation Currency: $BillingCurrency"

                $BillingItem = New-Object AzureBilling
                $BillingItem.SubscriptionId = $subscription.Id
                $BillingItem.SubscriptionName = $subscription.Name
                $BillingItem.BillingMonth = $BillingMonth
                $BillingItem.ResourceId = $ResourceId
                $BillingItem.ServiceName = $ServiceName
                $BillingItem.ServiceTier = $ServiceTier
                $BillingItem.Meter = $Meter
                $BillingItem.BillingQuotation = $BillingQuotation
                $BillingItem.BillingCurrency = $BillingCurrency
                $report += $BillingItem
            }
        }

    }
}   
Write-Host "-------------------------------------------"
Write-Host " Total subscriptions: $($subscriptions.Count)"
Write-Host "       Total records: $($report.Count)"
Write-Host "-------------------------------------------"
# # Export to CSV
$report | Export-Csv -Path $filenameDateString -NoTypeInformation -Encoding UTF8
