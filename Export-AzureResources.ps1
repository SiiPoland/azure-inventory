<# 
.SYNOPSIS
Export-AzureResources.ps1 - Report list of all resources with SKU or VM Size.

.DESCRIPTION
This script generates a report of all resources in selected Azure subscriptions, including SKU and VM size details.

Author: Chris Polewiak
Contact: chris@polewiak.pl

.LINK
GitHub source repository: https://github.com/SiiPoland/azure-inventory

.NOTES
Verification of the possibility of relocation based on the script from Tom FitzMacken (thanks)
https://github.com/tfitzmac/resource-capabilities/blob/master/move-support-resources.csv
#>

[CmdletBinding()]
param (
    [string]$SubscriptionId = "",

    [switch]$with_Tags = $true,

    [int]$Subscription_Limit = 0,

    [switch]$Continue,

    [switch]$DebugMode
)
if ($SubscriptionId) {
    $selected_SubscriptionId = $SubscriptionId
}
else {
    $selected_SubscriptionId = ""
}

# Helper Functions
function Log-Info($msg) {
    Write-Host "[INFO] $msg"
}
function Log-Debug($msg) {
    if ($DebugMode) { Write-Host "[DEBUG] $msg" -ForegroundColor Cyan }
}
function Log-Error($msg) {
    Write-Host "[ERROR] $msg" -ForegroundColor Red
}

# Ensure user is logged in to Azure
if (!(Get-AzContext)) {
    Log-Debug "Logging in to Azure..."
    Login-AzAccount
}

function Main {
    Log-Info "*** Azure Inventory ***"
    Log-Info "==========================================================================="
    Log-Info "Script for preparing a report of all resources in selected subscriptions"
    Log-Info "             Tags Used: $with_Tags"
    Log-Info "            Debug Mode: $DebugMode"
    Log-Info " Selected Subscription: $SubscriptionId"
    Log-Info "    Subscription Limit: $Subscription_Limit"
    Log-Info " Continue previous job: $Continue"
    Log-Info "==========================================================================="

    # Create a folder for the processing
    $workDirectory = Join-Path -Path (Get-Location).Path -ChildPath ".tmpdir"
    Log-Debug "Work Directory: $workDirectory"

    # If new job then remove temporary folder and recreate new one
    if (-not $Continue) {
        Log-Debug "Removing $workDirectory"
        Remove-Item -Path $workDirectory -WarningAction SilentlyContinue -Recurse -Force
    }
    Log-Debug "Creating $workDirectory"
    New-Item -ItemType Directory -Force -Path $workDirectory | Out-Null

    # Import Resource Move to Region Capabilities from GitHub
    Log-Info "Import Resource Move Capabilities Data between Regions"
    $ResourceCapabilitiesData = Import-ResourceMoveCapabilities

    # Define report array
    Class AzureResource {
        [string]$ResourceType
        [string]$ResourceGroup
        [string]$Location
        [string]$Name
        [string]$Kind
        [string]$SkuName
        [string]$SkuSize
        [string]$SkuTier
        [string]$SkuCapacity
        [string]$SkuFamily
        [string]$Type
        [string]$OfferType
        [string]$AccountType
        [string]$IpAddressPublic
        [string]$FQDN
        [string]$StorageSize
        [string]$OsType
        [string]$LicenseType
        [string]$WorkloadProfileName
        [string]$State
        [string]$MoveToResourceGroup
        [string]$MoveToSubscription
        [string]$MoveToRegion
        [string]$SubscriptionId
        [string]$ResourceId
        [string]$ManagedBy
        [string]$Tags
        [string] ToString() {
            return "{0} [{1}] in {2}, {3}" -f $this.Name, $this.ResourceType, $this.ResourceGroup, $this.Location
        }
    }

    $file_SubscriptionList = Join-Path -Path $workDirectory -ChildPath "SubscriptionList.json"
    $subscriptions = Get-AvailableAzureSubscriptions

    # Main Loop
    # Processing subscriptions and resources
    $SubscriptionNumber = 0
    foreach ($Subscription in $subscriptions) {
        $SubscriptionNumber++

        # Skip subscriptions and process only selected one
        if ($selected_SubscriptionId -ne "" -and $Subscription.SubscriptionId -ne $selected_SubscriptionId) {
            Log-Debug "skip subscription: $($Subscription.SubscriptionId)"
            continue
        }

        # Stop processing after defined limit of subscriptions
        if ($Subscription_Limit -gt 0 -and $SubscriptionNumber -gt $Subscription_Limit) {
            Log-Debug "stop after reaching limit of processed subscriptions"
            break
        }

        # Skip already processed subscriptions if job is a continuation
        if ($Continue -and $Subscription.Procesed) {
            Log-Debug "skip already processed subscription"
            continue
        }

        $SubscriptionID = $Subscription.SubscriptionId
        $SubscriptionName = $Subscription.Name

        # Temporary file with Subscription report
        $file_TmpReportFile = Join-Path -Path $workDirectory -ChildPath "report-subscription-$SubscriptionID.json"

        Select-AzSubscription -SubscriptionId $SubscriptionID | Out-Null

        Log-Info "- Get Resources from Subscription ($SubscriptionNumber/$($subscriptions.Count)): '$SubscriptionName' ($SubscriptionID)"
        $handledTypes = $resourceHandlers.Keys
        Log-Debug "- Handled Resource Types: $($handledTypes -join ', ')"
        $AzureResources = Get-AzResource | Where-Object { $handledTypes -contains $_.ResourceType }
        Log-Info "- Found $($AzureResources.Count) resources"

        # Define new Report array
        $report = @()

        $ResourceNumber = 0
        foreach ($resource in $AzureResources) {
            $ResourceNumber++
            Log-Info "- Resource $ResourceNumber / $($AzureResources.Count) (sub: $SubscriptionNumber / $($subscriptions.Count)) : $($resource.ResourceType) : $($resource.Name)"

            try {
                # Create Report Item for Azure Resource
                $reportItem = New-Object AzureResource
                $reportItem.ResourceGroup  = $resource.ResourceGroupName
                $reportItem.ResourceType   = $resource.ResourceType
                $reportItem.Name           = $resource.Name
                $reportItem.Location       = $resource.Location
                $reportItem.SubscriptionId = $SubscriptionID
                $reportItem.ResourceId     = $resource.ResourceId

                if ($resourceHandlers.ContainsKey($resource.ResourceType)) {
                    $functionName = $resourceHandlers[$resource.ResourceType]
                    $reportItem = & $functionName $resource $reportItem
                } else {
                    Write-Verbose "Unknown resource type: $($resource.ResourceType)"
                }

                if ($with_Tags -and $null -ne $resource.Tags) {
                    $reportItem.Tags      = ($resource.Tags | ConvertTo-Json -Compress)
                }

                if ( $ResourceCapabilitiesData[$resource.ResourceType] ) {
                    if ($ResourceCapabilitiesData[$resource.ResourceType]) {
                        $reportItem.MoveToResourceGroup = $ResourceCapabilitiesData[$resource.ResourceType].MoveToResourceGroup
                        $reportItem.MoveToSubscription  = $ResourceCapabilitiesData[$resource.ResourceType].MoveToSubscription
                        $reportItem.MoveToRegion        = $ResourceCapabilitiesData[$resource.ResourceType].MoveToRegion
                    }
                }

                # consolidate Report items
                $report += $reportItem
    
            }
            catch {
                Log-Error "Failed to process resource: $($ResourceItem.Name)"
                Log-Error "  Message : $($_.Exception.Message)"
                Log-Error "  Line    : $($_.InvocationInfo.ScriptLineNumber)"
                Log-Error "  File    : $($_.InvocationInfo.ScriptName)"
                Log-Error "  Code    : $($_.InvocationInfo.Line.Trim())"
                exit 1
            }
        }

        # Update Subscription processed status
        $subscriptions | Where-Object {$_.SubscriptionId -eq $SubscriptionID} | ForEach-Object {
            $_.Procesed = $true
        }
        Out-File -FilePath $file_SubscriptionList -InputObject ($subscriptions | ConvertTo-Json) -Force

        # Save subscription report to the tmp file
        Out-File -FilePath $file_TmpReportFile -InputObject ($report | ConvertTo-Json) -Force

    }

        # Define new Report array
    $report = @()

    Foreach( $subscription in $subscriptions )
    {
        if ($subscription.Procesed)
        {
            $SubscriptionID = $Subscription.SubscriptionID
            $file_TmpReportFile = Join-Path -Path $workDirectory -ChildPath "report-subscription-$SubscriptionID.json"
            $reportPart = Get-Content $file_TmpReportFile | ConvertFrom-Json
            $report += $reportPart
        }
    }

    if ( !$report )
    {
        Log-Error 'No resources found'
    }
    else {
        
        Log-Info "Processing Report Headers"

        # define an array of headers
        $headers = @{}

        foreach ($k in $($report | select-object | Get-Member -MemberType Properties)) {
            if ( $null -eq $headers[$k.Name] ) {
                $headers[$k.Name] = 1
            }
        }

        Export $headers $report
    }
}







#
# Import Resource Move Capabilities
##################################################
function Import-ResourceMoveCapabilities {

    # Import Resource Move Capabilities Data between Regions
    Log-Info "Import Resource Move Capabilities Data between Regions"

    # Check if the file exists, if not download it
    $file_ResourceCapabilities = Join-Path -Path $workDirectory -ChildPath "ResourceCapabilities.csv"
    if (-not (Test-Path -Path $file_ResourceCapabilities)) {
        Log-Debug "- Download Resource Move Capabilities Data between Regions"
        $ResourceCapabilities = ConvertFrom-Csv (Invoke-WebRequest "https://raw.githubusercontent.com/tfitzmac/resource-capabilities/master/move-support-resources-with-regions.csv").Content
        $ResourceCapabilities | ConvertTo-Csv -NoTypeInformation | Out-File -FilePath $file_ResourceCapabilities -Force
    } else {
        Log-Debug "- Read Resource Move Capabilities Data between Regions"
        $ResourceCapabilities = Get-Content -Path $file_ResourceCapabilities | ConvertFrom-Csv
    }

    if ($ResourceCapabilities) {
        # Analyse Resource movement Capabilities
        $ResourceCapabilitiesData = @{}
        foreach ($Resource in $ResourceCapabilities) {
            if (-not $ResourceCapabilitiesData.ContainsKey($Resource.Resource)) {
                $ResourceCapabilitiesData[$Resource.Resource] = @{
                    "MoveToResourceGroup" = $Resource."Move Resource Group"
                    "MoveToSubscription"  = $Resource."Move Subscription"
                    "MoveToRegion"        = $Resource."Move Region"
                }
            } else {
                $ResourceCapabilitiesData[$Resource.Resource].MoveToResourceGroup = $Resource."Move Resource Group"
                $ResourceCapabilitiesData[$Resource.Resource].MoveToSubscription = $Resource."Move Subscription"
                $ResourceCapabilitiesData[$Resource.Resource].MoveToRegion = $Resource."Move Region"
            }
        }
    }
    return $ResourceCapabilitiesData
}

#
# Get Available Azure Subscriptions
##################################################
function Get-AvailableAzureSubscriptions {
    # Get available Azure Subscriptions

    # Define subscriptions array
    $subscriptions = @()

    Class SubscriptionItem {
        [string]$SubscriptionId
        [string]$Name
        [bool]$Procesed
    }

    # Get all available subscriptions
    if (-not $Continue -or -not (Test-Path -Path $file_SubscriptionList)) {
        Log-Info "Get Azure Subscriptions List"
        $subscriptionsList = Get-AzSubscription | Sort-Object Name
        foreach ($subscription in $subscriptionsList) {
            $SubscriptionItem = New-Object SubscriptionItem
            $SubscriptionItem.SubscriptionId = $subscription.Id
            $SubscriptionItem.Name = $subscription.Name
            $SubscriptionItem.Procesed = $false
            $subscriptions += $SubscriptionItem
        }
        $subscriptions | ConvertTo-Json | Out-File -FilePath $file_SubscriptionList -Force
    } else {
        Log-Info "- Read Azure Subscriptions List"
        $subscriptions = Get-Content -Path $file_SubscriptionList | ConvertFrom-Json
    }
    Log-Info "  - Found $($subscriptions.Count) subscriptions"

    # Sort subscriptions by Id
    return $subscriptions | Sort-Object SubscriptionId
}


#
# Output Report
##################################################
function Export {
    param($headers, $report)

    Log-Info "Output Report"

    $headers_array = @()

    foreach ($k in $headers.GetEnumerator() | Sort-Object) {
        $headers_array += $k.Name
    }

    if ( $env:AZUREPS_HOST_ENVIRONMENT -like 'cloud-shell' ) {
        $is_CloudShell = $true
    }
    else {
        $is_CloudShell = $false
    }

    $ReportFileName_csv  = 'AzureResources-Export.csv'
    $ReportFileName_json = 'AzureResources-Export.json'
    if ( $is_CloudShell )
    {
        # Run in Cloud Shell Environment
        $ReportFile_csv  = Join-Path -Path $(Get-CloudDrive).MountPoint -ChildPath $ReportFileName_csv
        $ReportFile_json = Join-Path -Path $(Get-CloudDrive).MountPoint -ChildPath $ReportFileName_json
        $Report_AzureStorageAccount  = $(Get-CloudDrive).Name
        $Report_AzureStorageShare    = $(Get-CloudDrive).FileShareName
    }
    else {
        $ReportFile_csv  = Join-Path -Path (Get-Location).Path -ChildPath $ReportFileName_csv
        $ReportFile_json = Join-Path -Path (Get-Location).Path -ChildPath $ReportFileName_json
        $Report_AzureStorageAccount  = ""
        $Report_AzureStorageShare    = ""
    }
    Log-Debug "Report File CSV: $ReportFile_csv"
    Log-Debug "Report File JSON: $ReportFile_json"

    $report | Select-Object -prop $headers_array | Sort-Object | Export-CSV -NoTypeInformation -Path $ReportFile_csv
    $report | Select-Object -prop $headers_array | Sort-Object | ConvertTo-Json | Out-File $ReportFile_json

    Log-Info "Your report is completed"
    Log-Info "         File Name: " + $ReportFile_csv
    if ( $is_CloudShell ) {
        Log-Info "Azure Storage Account: $Report_AzureStorageAccount"
        Log-Info "File Share: $Report_AzureStorageShare"
    } else {
        Log-Info "Local Path: $ReportFile_csv"
    }
}


# FUNCTIONS
#
# Resource handler map

$resourceHandlers = @{
    'Microsoft.ApiManagement/service'               = 'Get-MicrosoftApiManagement-service'
    'Microsoft.App/containerApps'                   = 'Get-MicrosoftApp-containerApps'
    'Microsoft.Cache/Redis'                         = 'Get-MicrosoftCache-Redis'
    'Microsoft.Cdn/profiles'                        = 'Get-microsoftcdn-profiles'
    'Microsoft.CognitiveServices/accounts'          = 'Get-MicrosoftCognitiveServices-accounts'
    'Microsoft.Compute/disks'                       = 'Get-MicrosoftCompute-disks'
    'Microsoft.Compute/snapshots'                   = 'Get-MicrosoftCompute-snapshots'
    'Microsoft.Compute/virtualMachines'             = 'Get-MicrosoftCompute-virtualMachines'
    'Microsoft.ContainerInstance/containerGroups'   = 'Get-MicrosoftContainerInstance-containerGroups'
    'Microsoft.ContainerRegistry/registries'        = 'Get-MicrosoftContainerRegistry-registries'
    'Microsoft.ContainerService/containerservices'  = 'Get-MicrosoftContainerService-containerservices'
    'Microsoft.Databricks/workspaces'               = 'Get-MicrosoftDatabricks-workspaces'
    'Microsoft.DataFactory/factories'               = 'Get-MicrosoftDataFactory-factories'
    'Microsoft.DBforMariaDB/servers'                = 'Get-MicrosoftDBforMariaDB-servers'
    'Microsoft.DBforMySQL/flexibleServers'          = 'Get-MicrosoftDBforMySQL-flexibleServers'
    'Microsoft.DBforMySQL/servers'                  = 'Get-MicrosoftDBforMySQL-servers'
    'Microsoft.DBforPostgreSQL/flexibleServers'     = 'Get-MicrosoftDBforPostgreSQL-flexibleServers'
    'Microsoft.DBforPostgreSQL/servers'             = 'Get-MicrosoftDBforPostgreSQL-servers'
    'Microsoft.DocumentDb/databaseAccounts'         = 'Get-MicrosoftDocumentDb-databaseAccounts'
    'Microsoft.EventHub/namespaces'                 = 'Get-MicrosoftEventHub-namespaces'
    'Microsoft.Fabric/capacities'                   = 'Get-MicrosoftFabric-capacities'
    'Microsoft.HDInsight/clusters'                  = 'Get-MicrosoftHDInsight-clusters'
    'Microsoft.IoTHub/iothub'                       = 'Get-MicrosoftIoTHub-iothub'   
    'Microsoft.KeyVault/vaults'                     = 'Get-MicrosoftKeyVault-vaults'
    'Microsoft.Kusto/clusters'                      = 'Get-MicrosoftKusto-clusters'
    'Microsoft.Logic/workflows'                     = 'Get-MicrosoftLogic-workflows'
    'Microsoft.MachineLearningServices/workspaces'  = 'Get-MicrosoftMachineLearningServices-workspaces'
    'Microsoft.Network/applicationGateways'         = 'Get-MicrosoftNetwork-applicationGateways'    
    'Microsoft.Network/azureFirewalls'              = 'Get-MicrosoftNetwork-azureFirewalls'
    'Microsoft.Network/bastionHosts'                = 'Get-MicrosoftNetwork-bastionHosts'
    'Microsoft.Network/dnsZones'                    = 'Get-MicrosoftNetwork-dnsZones'
    'Microsoft.Network/firewallPolicies'            = 'Get-MicrosoftNetwork-firewallPolicies'
    'Microsoft.Network/frontdoors'                  = 'Get-MicrosoftNetwork-frontdoors'
    'Microsoft.Network/natGateways'                 = 'Get-MicrosoftNetwork-natGateways'
    'Microsoft.Network/publicIPAddresses'           = 'Get-MicrosoftNetwork-publicIPAddresses'
    'Microsoft.Network/virtualHubs'                 = 'Get-MicrosoftNetwork-virtualHubs'
    'Microsoft.Network/virtualNetworkGateways'      = 'Get-MicrosoftNetwork-virtualNetworkGateways'
    'Microsoft.Network/virtualWans'                 = 'Get-MicrosoftNetwork-virtualWans'
    'Microsoft.Network/vpnGateways'                 = 'Get-MicrosoftNetwork-vpnGateways'
    'Microsoft.Relay/namespaces'                    = 'Get-MicrosoftRelay-namespaces'
    'Microsoft.SaaS/applications'                   = 'Get-MicrosoftSaaS-applications'
    'Microsoft.ServiceBus/namespaces'               = 'Get-MicrosoftServiceBus-namespaces'
    'Microsoft.Sql/managedinstances'                = 'Get-MicrosoftSql-managedinstances'
    'Microsoft.Sql/servers/databases'               = 'Get-MicrosoftSql-servers-databases'
    'Microsoft.Sql/servers/elasticpools'            = 'Get-MicrosoftSql-servers-elasticpools'
    'Microsoft.Storage/storageAccounts'             = 'Get-MicrosoftStorage-storageAccounts'
    'Microsoft.Web/serverFarms'                     = 'Get-MicrosoftWeb-serverFarms'
    'Microsoft.Web/sites'                           = 'Get-MicrosoftWeb-sites'  
}

# Function to get Azure Resource details

function Get-MicrosoftCompute-virtualMachines {
    param($resource, $reportItem)
    $vm = Get-AzVM -ResourceGroupName $resource.ResourceGroupName -Name $resource.Name -WarningAction SilentlyContinue
    $reportItem.LicenseType  = $resource.LicenseType
    $reportItem.SkuSize      = $vm.HardwareProfile.VmSize
    $reportItem.OsType       = $vm.StorageProfile.OsDisk.OsType

    $vm = Get-AzVM -ResourceGroupName $resource.ResourceGroupName -Name $resource.Name -Status -WarningAction SilentlyContinue
    $reportItem.State        = $vm.Statuses[1].DisplayStatus
    return $reportItem
}

function Get-MicrosoftApiManagement-service {
    param($resource, $reportItem)
    $resourceData = Get-AzApiManagement -WarningAction SilentlyContinue -ResourceGroupName $resource.ResourceGroupName -Name $resource.Name
    $reportItem.SkuName = $resourceData.Sku
    $reportItem.SkuCapacity = $resourceData.Capacity
    $reportItem.ManagedBy = $resourceData.ManagedBy
    $reportItem.FQDN = $resourceData.PortalUrl
    return $reportItem
}

function Get-MicrosoftApp-containerApps {
    param($resource, $reportItem)
    $resourceData = Get-AzContainerApp -WarningAction SilentlyContinue -ResourceGroupName $resource.ResourceGroupName -Name $resource.Name
    $reportItem.WorkloadProfileName = $resourceData.WorkloadProfileName
    $reportItem.ManagedBy = $resourceData.ManagedBy
    $reportItem.FQDN = ($resourceData.Configuration | ConvertFrom-Json).ingress.fqdn
    return $reportItem
}

function Get-MicrosoftCache-Redis {
    param($resource, $reportItem)
    $resourceData = Get-AzRedisCache -WarningAction SilentlyContinue -ResourceGroupName $resource.ResourceGroupName -Name $resource.Name
    $reportItem.StorageSize = $resourceData.Size
    $reportItem.SkuName = $resourceData.Sku
    $reportItem.FQDN = $resourceData.HostName
    return $reportItem
}

function Get-microsoftcdn-profiles {
    param($resource, $reportItem)
    $resourceData = Get-AzCdnProfile -WarningAction SilentlyContinue -ResourceGroupName $resource.ResourceGroupName -Name $resource.Name
    $reportItem.SkuName = $resourceData.SkuName
    $reportItem.ManagedBy = $resourceData.FrontDoorId
    return $reportItem
}

function Get-MicrosoftCognitiveServices-accounts {
    param($resource, $reportItem)
    $resourceData = Get-AzCognitiveServicesAccount -WarningAction SilentlyContinue -ResourceGroupName $resource.ResourceGroupName -Name $resource.Name
    $reportItem.SkuName = $resourceData.Sku.Name
    $reportItem.SkuTier = $resourceData.Sku.Tier
    $reportItem.SkuSize = $resourceData.Sku.Size
    $reportItem.SkuFamily = $resourceData.Sku.Family
    $reportItem.SkuCapacity = $resourceData.Sku.Capacity
    $reportItem.AccountType = $resourceData.AccountType
    return $reportItem
}

function Get-MicrosoftCompute-disks {
    param($resource, $reportItem)
    $resourceData = Get-AzDisk -WarningAction SilentlyContinue -ResourceGroupName $resource.ResourceGroupName -DiskName $resource.Name
    $reportItem.OsType = $resourceData.OsType
    $reportItem.StorageSize = $resourceData.DiskSizeGB
    $reportItem.SkuName = $resourceData.Sku.Name
    $reportItem.SkuTier = $resourceData.Sku.Tier
    $reportItem.ManagedBy = $resourceData.ManagedBy
    return $reportItem
}

function Get-MicrosoftCompute-snapshots {
    param($resource, $reportItem)        
    $resourceData = Get-AzSnapshot -WarningAction SilentlyContinue -ResourceGroupName $resource.ResourceGroupName -Name $resource.Name
    $reportItem.OsType = $resourceData.OsType
    $reportItem.StorageSize = $resourceData.DiskSizeGB
    $reportItem.SkuName = $resourceData.Sku.Name
    $reportItem.SkuTier = $resourceData.Sku.Tier
    $reportItem.ManagedBy = $resourceData.ManagedBy
    return $reportItem
}

function Get-MicrosoftContainerInstance-containerGroups {
    param($resource, $reportItem)
    $resourceData = Get-AzContainerGroup -WarningAction SilentlyContinue -ResourceGroupName $resource.ResourceGroupName -Name $resource.Name
    $reportItem.OsType = $resourceData.OsType
    $reportItem.SkuName = $resourceData.Sku
    return $reportItem
}

function Get-MicrosoftContainerRegistry-registries {
    param($resource, $reportItem)
    $resourceData = Get-AzContainerRegistry -WarningAction SilentlyContinue -ResourceGroupName $resource.ResourceGroupName -Name $resource.Name
    $reportItem.SkuName = $resourceData.SkuName
    $reportItem.SkuTier = $resourceData.SkuTier
    $reportItem.FQDN = $resourceData.LoginServer
    return $reportItem
}

function Get-MicrosoftContainerService-containerservices {
    param($resource, $reportItem)
    # $resourceData = Get-AzKubernetesCluster -WarningAction SilentlyContinue -ResourceGroupName $resource.ResourceGroupName -Name $resource.Name
    # Log-Debug "resourceData: $($resourceData | ConvertTo-Json)"
    # exit
    # $reportItem.SkuName = $resourceData.SkuName
    # $reportItem.SkuTier = $resourceData.SkuTier
    # $reportItem.FQDN = $resourceData.Fqdn
    return $reportItem
}

function Get-MicrosoftDatabricks-workspaces {
    param($resource, $reportItem)
    $resourceData = Get-AzDatabricksWorkspace -WarningAction SilentlyContinue -ResourceGroupName $resource.ResourceGroupName -Name $resource.Name
    $reportItem.SkuName = $resourceData.NetworkProfile.IpConfigurations.SkuName
    $reportItem.SkuTier = $resourceData.NetworkProfile.IpConfigurations.SkuTier
    $reportItem.FQDN = $resourceData.Url
    return $reportItem
}

function Get-MicrosoftDataFactory-factories {
    param($resource, $reportItem)
    return $reportItem
}

function Get-MicrosoftDBforMariaDB-servers {
    param($resource, $reportItem)
    $resourceData = Get-AzMariaDBServer -WarningAction SilentlyContinue -ResourceGroupName $resource.ResourceGroupName -Name $resource.Name
    $reportItem.SkuName = $resourceData.SkuName
    $reportItem.SkuTier = $resourceData.SkuTier
    $reportItem.State = $resourceData.State
    $reportItem.StorageSize = $resourceData.StorageSizeGb
    $reportItem.ManagedBy = $resourceData.ManagedBy
    return $reportItem
}

function Get-MicrosoftDBforMySQL-flexibleServers {
    param($resource, $reportItem)
    $resourceData = Get-AzMySqlFlexibleServer -WarningAction SilentlyContinue -ResourceGroupName $resource.ResourceGroupName -Name $resource.Name
    $reportItem.SkuName = $resourceData.SkuName
    $reportItem.SkuTier = $resourceData.SkuTier
    $reportItem.State = $resourceData.State
    $reportItem.StorageSize = $resourceData.StorageSizeGb
    $reportItem.ManagedBy = $resourceData.ManagedBy
    return $reportItem
}

function Get-MicrosoftDBforMySQL-servers {
    param($resource, $reportItem)
    $resourceData = Get-AzMySqlServer -WarningAction SilentlyContinue -ResourceGroupName $resource.ResourceGroupName -Name $resource.Name
    $reportItem.SkuName = $resourceData.SkuName
    $reportItem.SkuTier = $resourceData.SkuTier
    $reportItem.State = $resourceData.State
    $reportItem.StorageSize = $resourceData.StorageSizeGb
    $reportItem.ManagedBy = $resourceData.ManagedBy
    return $reportItem
}

function Get-MicrosoftDBforPostgreSQL-flexibleServers {
    param($resource, $reportItem)
    $resourceData = Get-AzPostgreSqlFlexibleServer -WarningAction SilentlyContinue -ResourceGroupName $resource.ResourceGroupName -Name $resource.Name
    $reportItem.SkuName = $resourceData.SkuName
    $reportItem.SkuTier = $resourceData.SkuTier
    $reportItem.State = $resourceData.State
    $reportItem.StorageSize = $resourceData.StorageSizeGb
    return $reportItem
}

function Get-MicrosoftDBforPostgreSQL-servers {
    param($resource, $reportItem)
    $resourceData = Get-AzPostgreSqlServer -WarningAction SilentlyContinue -ResourceGroupName $resource.ResourceGroupName -Name $resource.Name
    $reportItem.Kind = $resourceData.Kind
    $reportItem.SkuCapacity = $resourceData.SkuCapacity
    $reportItem.SkuFamily = $resourceData.SkuFamily
    $reportItem.SkuName = $resourceData.SkuName
    $reportItem.SkuSize = $resourceData.SkuSize
    $reportItem.SkuTier = $resourceData.SkuTier
    $reportItem.ManagedBy = $resourceData.ManagedBy
    return $reportItem
}

function Get-MicrosoftDocumentDb-databaseAccounts {
    param($resource, $reportItem)
    $resourceData = Get-AzCosmosDBAccount -WarningAction SilentlyContinue -ResourceGroupName $resource.ResourceGroupName -Name $resource.Name
    $reportItem.OfferType = $resourceData.DatabaseAccountOfferType
    $reportItem.Kind = $resourceData.Kind
    $reportItem.ManagedBy = $resourceData.ManagedBy
    $reportItem.FQDN = $resourceData.DocumentEndpoint
    return $reportItem
}

function Get-MicrosoftEventHub-namespaces {
    param($resource, $reportItem)
    $resourceData = Get-AzEventHubNamespace -WarningAction SilentlyContinue -ResourceGroupName $resource.ResourceGroupName -Name $resource.Name
    $reportItem.SkuCapacity = $resourceData.SkuCapacity
    $reportItem.SkuName = $resourceData.SkuName
    $reportItem.SkuTier = $resourceData.SkuTier
    $reportItem.State = $resourceData.Status
    $reportItem.FQDN = $resourceData.ServiceBusEndpoint
    return $reportItem
}

function Get-MicrosoftFabric-capacities {
    param($resource, $reportItem)
#    $resourceData = Get-AzFabricCapacity -WarningAction SilentlyContinue -ResourceGroupName $resource.ResourceGroupName -CapacityName $resource.Name 
    $reportItem.SkuName = $resource.Sku.Name
    $reportItem.SkuTier = $resource.Sku.Tier
    $reportItem.SkuCapacity = $resource.Sku.Capacity
    $reportItem.SkuFamily = $resource.Sku.Family
    return $reportItem
}

function Get-MicrosoftHDInsight-clusters {
    param($resource, $reportItem)
    # $resourceData = Get-AzHDInsightCluster -WarningAction SilentlyContinue -ResourceGroupName $resource.ResourceGroupName -Name $resource.Name
    # Log-Debug "resourceData: $($resourceData | ConvertTo-Json)"
    # exit
    # $reportItem.SkuName = $resourceData.ClusterType
    # $reportItem.SkuTier = $resourceData.SkuTier
    # $reportItem.SkuCapacity = $resourceData.ClusterSizeInNodes
    # $reportItem.FQDN = $resourceData.HostName
    return $reportItem
}

function Get-MicrosoftIoTHub-iothub {
    param($resource, $reportItem)
    # $resourceData = Get-AzIotHub -WarningAction SilentlyContinue -ResourceGroupName $resource.ResourceGroupName -Name $resource.Name
    # Log-Debug "resourceData: $($resourceData | ConvertTo-Json)"
    # exit
    # $reportItem.SkuName = $resourceData.Sku.Name
    # $reportItem.SkuTier = $resourceData.Sku.Tier
    # $reportItem.SkuCapacity = $resourceData.Sku.Capacity
    # $reportItem.FQDN = $resourceData.HostName
    return $reportItem
}

function Get-MicrosoftKeyVault-vaults {
    param($resource, $reportItem)
    $ResourceData = Get-AzKeyVault -WarningAction SilentlyContinue -ResourceGroupName $resource.ResourceGroupName -Name $resource.Name
    $reportItem.SkuName = $ResourceData.Sku
    return $reportItem
}

function Get-MicrosoftKusto-clusters {
    param($resource, $reportItem)
    $resourceData = Get-AzKustoCluster -WarningAction SilentlyContinue -ResourceGroupName $resource.ResourceGroupName -Name $resource.Name
    $reportItem.SkuCapacity = $resourceData.SkuCapacity
    $reportItem.SkuName = $resourceData.SkuName
    $reportItem.SkuTier = $resourceData.SkuTier
    $reportItem.State = $resourceData.State
    return $reportItem
}

function Get-MicrosoftLogic-workflows {
    param($resource, $reportItem)
    return $reportItem
}

function Get-MicrosoftMachineLearningServices-workspaces {
    param($resource, $reportItem)
    $resourceData = Get-AzMlWorkspace -WarningAction SilentlyContinue -ResourceGroupName $resource.ResourceGroupName -Name $resource.Name
    $reportItem.Kind = $resourceData.Kind
    $reportItem.SkuCapacity = $resourceData.SkuCapacity
    $reportItem.SkuFamily = $resourceData.SkuFamily
    $reportItem.SkuName = $resourceData.SkuName
    $reportItem.SkuSize = $resourceData.SkuSize
    $reportItem.SkuTier = $resourceData.SkuTier
    return $reportItem
}

function Get-MicrosoftNetwork-applicationGateways {
    param($resource, $reportItem)
    $resourceData = Get-AzApplicationGateway -WarningAction SilentlyContinue -ResourceGroupName $resource.ResourceGroupName -Name $resource.Name
    $reportItem.SkuName = $resourceData.Sku.Name
    $reportItem.SkuTier = $resourceData.Sku.Tier
    $reportItem.SkuCapacity = $resourceData.Sku.Capacity
    return $reportItem
}

function Get-MicrosoftNetwork-azureFirewalls {
    param($resource, $reportItem)
    $resourceData = Get-AzFirewall -WarningAction SilentlyContinue -ResourceGroupName $resource.ResourceGroupName -Name $resource.Name
    $reportItem.SkuName = $resourceData.Sku.Name
    $reportItem.SkuTier = $resourceData.Sku.Tier
    return $reportItem
}

function Get-MicrosoftNetwork-bastionHosts {
    param($resource, $reportItem)
    $resourceData = Get-AzBastion -WarningAction SilentlyContinue -ResourceGroupName $resource.ResourceGroupName -Name $resource.Name
    $reportItem.FQDN = $resourceData.DnsName
    $reportItem.SkuName = $resourceData.Sku.Name
    $reportItem.SkuCapacity = $resourceData.ScaleUnit
    return $reportItem
}

function Get-MicrosoftNetwork-dnsZones {
    param($resource, $reportItem)
    $resourceData = Get-AzDnsZone -WarningAction SilentlyContinue -ResourceGroupName $resource.ResourceGroupName -Name $resource.Name
    $reportItem.Type = $resourceData.ZoneType
    return $reportItem
}

function Get-MicrosoftNetwork-firewallPolicies {
    param($resource, $reportItem)
    $resourceData = Get-AzFirewallPolicy -WarningAction SilentlyContinue -ResourceGroupName $resource.ResourceGroupName -Name $resource.Name
    $reportItem.SkuTier = $resourceData.Sku.Tier
    return $reportItem
}

function Get-MicrosoftNetwork-frontdoors {
    param($resource, $reportItem)
    return $reportItem
}

function Get-MicrosoftNetwork-natGateways {
    param($resource, $reportItem)
    $resourceData = Get-AzNatGateway -WarningAction SilentlyContinue -ResourceGroupName $resource.ResourceGroupName -Name $resource.Name
    $reportItem.SkuName = $resourceData.Sku.Name
    return $reportItem
}

function Get-MicrosoftNetwork-publicIPAddresses {
    param($resource, $reportItem)
    $resourceData = Get-AzPublicIpAddress -WarningAction SilentlyContinue -ResourceGroupName $resource.ResourceGroupName -Name $resource.Name
    $reportItem.IpAddressPublic = $resourceData.IpAddress
    $reportItem.SkuName = $resourceData.Sku.Name
    $reportItem.SkuTier = $resourceData.Sku.Tier
    return $reportItem
}

function Get-MicrosoftNetwork-virtualHubs {
    param($resource, $reportItem)
    $resourceData = Get-AzVirtualHub -WarningAction SilentlyContinue -ResourceGroupName $resource.ResourceGroupName -Name $resource.Name
    $reportItem.SkuName = $resourceData.Sku
    return $reportItem
}

function Get-MicrosoftNetwork-virtualNetworkGateways {
    param($resource, $reportItem)
    $resourceData = Get-AzVirtualNetworkGateway -WarningAction SilentlyContinue -ResourceGroupName $resource.ResourceGroupName -Name $resource.Name
    $reportItem.Type = $resourceData.VpnType
    $reportItem.SkuCapacity = $resourceData.Sku.Capacity
    $reportItem.SkuName = $resourceData.Sku.Name
    $reportItem.SkuTier = $resourceData.Sku.Tier
    return $reportItem
}

function Get-MicrosoftNetwork-vpnGateways {
    param($resource, $reportItem)
    $resourceData = Get-AzVpnGateway -WarningAction SilentlyContinue -ResourceGroupName $resource.ResourceGroupName -Name $resource.Name
    $reportItem.SkuCapacity = $resourceData.VpnGatewayScaleUnit
    return $reportItem
}

function Get-MicrosoftNetwork-virtualWans {
    param($resource, $reportItem)
    $resourceData = Get-AzVirtualWan -WarningAction SilentlyContinue -ResourceGroupName $resource.ResourceGroupName -Name $resource.Name
    $reportItem.Type = $resourceData.VirtualWanType
    return $reportItem
}

function Get-MicrosoftRelay-namespaces {
    param($resource, $reportItem)
    $resourceData = Get-AzRelayNamespace -WarningAction SilentlyContinue -ResourceGroupName $resource.ResourceGroupName -Name $resource.Name
    $reportItem.SkuName = $resourceData.SkuName
    $reportItem.SkuTier = $resourceData.SkuTier
    $reportItem.State = $resourceData.Status
    return $reportItem
}

function Get-MicrosoftSaaS-applications {
    param($resource, $reportItem)
    # $resourceData = Get-AzSaaSApplication -WarningAction SilentlyContinue -ResourceGroupName $resource.ResourceGroupName -Name $resource.Name
    # Log-Debug "resourceData: $($resourceData | ConvertTo-Json)"
    # exit
    # $reportItem.SkuName = $resourceData.SkuName
    # $reportItem.SkuTier = $resourceData.SkuTier
    # $reportItem.FQDN = $resourceData.Fqdn
    return $reportItem
}

function Get-MicrosoftServiceBus-namespaces {
    param($resource, $reportItem)
    $resourceData = Get-AzServiceBusNamespace -WarningAction SilentlyContinue -ResourceGroupName $resource.ResourceGroupName -Name $resource.Name
    $reportItem.SkuCapacity = $resourceData.SkuCapacity
    $reportItem.SkuName = $resourceData.SkuName
    $reportItem.SkuTier = $resourceData.SkuTier
    return $reportItem
}

function Get-MicrosoftSql-managedinstances {
    param($resource, $reportItem)
    # $resourceData = Get-AzSqlInstance -WarningAction SilentlyContinue -ResourceGroupName $resource.ResourceGroupName -Name $resource.Name
    # Log-Debug "resourceData: $($resourceData | ConvertTo-Json)"
    # exit
    # $reportItem.SkuName = $resourceData.SkuName
    # $reportItem.SkuFamily = $resourceData.SkuFamily
    # $reportItem.SkuCapacity = $resourceData.SkuCapacity
    return $reportItem
}

function Get-MicrosoftSql-servers-databases {
    param($resource, $reportItem)
    $ServerName = $resource.Name.Split("/")[0]
    $DBName = $resource.Name.Split("/")[1]
    $ResourceData = Get-AzSqlDatabase -WarningAction SilentlyContinue -ResourceGroupName $resource.ResourceGroupName -ServerName $ServerName -DatabaseName $DBName
    $reportItem.SkuName = $ResourceData.SkuName
    $reportItem.SkuFamily = $ResourceData.Family
    $reportItem.SkuCapacity = $ResourceData.Capacity
    return $reportItem
}

function Get-MicrosoftSql-servers-elasticpools {
    param($resource, $reportItem)
    $ServerName = $resource.Name.Split("/")[0]
    $ResourceData = Get-AzSqlElasticPool -WarningAction SilentlyContinue -ResourceGroupName $resource.ResourceGroupName -ServerName $ServerName
    $reportItem.SkuName = $ResourceData.SkuName
    $reportItem.SkuFamily = $ResourceData.Edition
    $reportItem.SkuCapacity = $ResourceData.Dtu
    return $reportItem
}

function Get-MicrosoftStorage-storageAccounts {
    param($resource, $reportItem)
    $resourceData = Get-AzStorageAccount -WarningAction SilentlyContinue -ResourceGroupName $resource.ResourceGroupName -Name $resource.Name
    $reportItem.Kind = $ResourceItem.Kind
    $reportItem.SkuName = $ResourceItem.Sku.Name
    $reportItem.SkuTier = $ResourceItem.Sku.Tier
    $reportItem.SkuSize = $ResourceItem.Sku.Size
    return $reportItem
}

function Get-MicrosoftWeb-serverFarms {
    param($resource, $reportItem)
    $resourceData = Get-AzAppServicePlan -WarningAction SilentlyContinue -ResourceGroupName $resource.ResourceGroupName -Name $resource.Name
    $reportItem.SkuName = $resourceData.Sku.Name
    $reportItem.SkuTier = $resourceData.Sku.Tier
    $reportItem.SkuSize = $resourceData.Sku.Size
    $reportItem.SkuFamily = $resourceData.Sku.Family
    $reportItem.SkuCapacity = $resourceData.Sku.Capacity   
    $reportItem.Kind = $resourceData.Kind
    return $reportItem
}   

function Get-MicrosoftWeb-sites {
    param($resource, $reportItem)
    $resourceData = Get-AzWebApp -WarningAction SilentlyContinue -ResourceGroupName $resource.ResourceGroupName -Name $resource.Name
    $reportItem.State = $resourceData.State
    $reportItem.ManagedBy = $resourceData.ServerFarmId
    return $reportItem
}


Main