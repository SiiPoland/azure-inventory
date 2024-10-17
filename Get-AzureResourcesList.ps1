<#

.SYNOPSIS
Get-AzureResourceList.ps1 - Report list of all resources with SKU or VM Size

.DESCRIPTION
Script for prepare report of all resources in selected subscription


.NOTES
Written By: Chris Polewiak
Verification of the possibility of relocation based on the script from Tom FitzMacken (thanks)
https://github.com/tfitzmac/resource-capabilities/blob/master/move-support-resources.csv
#>


param (
    [Alias("s","SubscriptionId")]
    [string]$selected_SubscriptionId = "",

    [Alias("wt","tags")]
    [bool]$with_Tags = $false,

    [Alias("sl","SubscriptionLimit")]
    [int]$Subscription_Limit = 0,

    [bool]$Debug = $false
)

if ( ! $(Get-AzContext) ) { 
    Login-AzAccount
}

Write-Output $('Azure Inventory')
Write-Output $('===========================================================================')
Write-Output $('Script for prepare report of all resources in selected subscriptions')
Write-Output $('             Tags Used: ' + $with_Tags)
Write-Output $('            Debug Mode: ' + $Debug)
Write-Output $(' Selected Subscription: ' + $selected_SubscriptionId)
Write-Output $('    Subscription Limit: ' + $Subscription_Limit)
Write-Output $('===========================================================================')



# Import Resource Move to Region Capabilities from GitHub
Write-Output '- Fetching Resource Move Capabilities Data between Regions'
$ResourceCapabilities = ConvertFrom-Csv $(Invoke-WebRequest "https://raw.githubusercontent.com/tfitzmac/resource-capabilities/master/move-support-resources-with-regions.csv")
$ResourceCapabilitiesData = @{}
Foreach( $Resource in $ResourceCapabilities) {
    # Update an List of resources
    if ( $null -eq $ResourceCapabilitiesData[ $Resource.Resource ] ) {
        $ResourceCapabilitiesData.add( $Resource.Resource, @{
            'MoveToResourceGroup' = $Resource.'Move Resource Group'
            'MoveToSubscription' = $Resource.'Move Subscription'
            'MoveToRegion' = $Resource.'Move Region'
        })
    }
    else {
        $ResourceCapabilitiesData[ $Resource.Resource ].MoveToResourceGroup = $Resource.'Move Resource Group'
        $ResourceCapabilitiesData[ $Resource.Resource ].MoveToSubscription = $Resource.'Move Subscription'
        $ResourceCapabilitiesData[ $Resource.Resource ].MoveToRegion = $Resource.'Move Region'
    }
}

$report = @()

Class AzureResource
{
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
    [string]$SkuModel
    [string]$VMSize
    [string]$Type
    [string]$OfferType
    [string]$AccountType
    [string]$IpAddressPrivate
    [string]$IpAddressPublic
    [string]$FQDN
    [string]$NSGName
    [string]$StorageSize
    [string]$OsType
    [string]$OsName
    [string]$OsVersion
    [string]$LicenseType
    [string]$DBName
    [string]$HostedOn
    [string]$WorkloadProfileName
    [string]$State
    [string]$MoveToResourceGroup
    [string]$MoveToSubscription
    [string]$MoveToRegion
    [string]$SubscriptionId
    [string]$ResourceId
}
# define an array of additional headers
$headers = @{}

#
# Get available Azure Subscriptions
##################################################
Write-Output '- Get Azure Subscriptions List'
$Subscriptions = Get-AzSubscription | Sort-Object Name
Write-Output $('  - Found ' + $Subscriptions.Count + ' subscriptions')

$SubscriptionNumber = 0
Foreach( $Subscription in $Subscriptions ) {
    $SubscriptionNumber++

    if ( $selected_SubscriptionId -ne "" -and $Subscription.Id -ne $selected_SubscriptionId ) {
        continue
    }
    if ( $Subscription_Limit -gt 0 -and $SubscriptionNumber -gt $Subscription_Limit ) {
        break
    }

    $SubscriptionID = $Subscription.Id
    $SubscriptionName = $Subscription.Name
    Select-AzSubscription -SubscriptionId $SubscriptionID | Out-Null

    Write-Output $('- Get Resources from Subscription (' + $SubscriptionNumber + '): ''' + $SubscriptionName + ''' (' + $SubscriptionID + ')')
    $AzureResources = Get-AzResource 
    Write-Output $('  - Found ' + $AzureResources.Count + ' resources') 

    $ResourceNumber = 0
    Foreach( $ResourceItem in $AzureResources) {
        $ResourceNumber++
        if ($Debug) { Write-Output $('  - ' + $ResourceNumber + ' : ' + $ResourceItem.ResourceType + ' : ' + $ResourceItem.Name) }

        $reportItem = New-Object AzureResource

        $reportItem.ResourceGroup = $ResourceItem.ResourceGroupName
        $reportItem.ResourceType = $ResourceItem.ResourceType
        $reportItem.Name = $ResourceItem.Name
        $reportItem.Location = $ResourceItem.Location

        #
        # Get additional Data from resources
        ##################################################
        switch( $ResourceItem.ResourceType ) {
            'Microsoft.AAD/domainservices' {}
            'microsoft.aadiam/diagnosticsettings' {}
            'microsoft.aadiam/diagnosticsettingscategories' {}
            'microsoft.aadiam/privatelinkforazuread' {}
            'microsoft.aadiam/tenants' {}
            'Microsoft.Addons/supportproviders' {}
            'Microsoft.ADHybridHealthService/aadsupportcases' {}
            'Microsoft.ADHybridHealthService/addsservices' {}
            'Microsoft.ADHybridHealthService/agents' {}
            'Microsoft.ADHybridHealthService/anonymousapiusers' {}
            'Microsoft.ADHybridHealthService/configuration' {}
            'Microsoft.ADHybridHealthService/logs' {}
            'Microsoft.ADHybridHealthService/reports' {}
            'Microsoft.ADHybridHealthService/servicehealthmetrics' {}
            'Microsoft.ADHybridHealthService/services' {}
            'Microsoft.Advisor/configurations' {}
            'Microsoft.Advisor/generaterecommendations' {}
            'Microsoft.Advisor/metadata' {}
            'Microsoft.Advisor/recommendations' {}
            'Microsoft.Advisor/suppressions' {}
            'Microsoft.AlertsManagement/actionRules' {}
            'Microsoft.AlertsManagement/alerts' {}
            'Microsoft.AlertsManagement/alertslist' {}
            'Microsoft.AlertsManagement/alertsmetadata' {}
            'Microsoft.AlertsManagement/alertssummary' {}
            'Microsoft.AlertsManagement/alertssummarylist' {}
            'Microsoft.AlertsManagement/smartDetectorAlertRules' {}
            'Microsoft.AlertsManagement/smartgroups' {}
            'Microsoft.AnalysisServices/servers' {}
            'Microsoft.ApiManagement/reportfeedback' {}
            'Microsoft.ApiManagement/service' {
                $resourceData = Get-AzApiManagement -WarningAction SilentlyContinue -ResourceGroupName $ResourceItem.ResourceGroupName -Name $ResourceItem.Name
                $reportItem.SkuName = $resourceData.Sku
                $reportItem.SkuCapacity = $resourceData.Capacity
            }
            'Microsoft.App/containerApps' {

                $resourceData = Get-AzContainerApp -WarningAction SilentlyContinue -ResourceGroupName $ResourceItem.ResourceGroupName -Name $ResourceItem.Name

                $reportItem.WorkloadProfileName = $resourceData.WorkloadProfileName
            }
            'Microsoft.App/jobs' {}
            'Microsoft.App/managedEnvironments' {}
            'Microsoft.App/managedEnvironments/certificates' {}
            'Microsoft.AppConfiguration/configurationStores' {}
            'Microsoft.AppConfiguration/configurationstores/eventgridfilters' {}
            'Microsoft.AppPlatform/spring' {}
            'Microsoft.AppService/apiapps' {}
            'Microsoft.AppService/appidentities' {}
            'Microsoft.AppService/gateways' {}
            'Microsoft.Attestation/attestationproviders' {}
            'Microsoft.Authorization/classicadministrators' {}
            'Microsoft.Authorization/dataaliases' {}
            'Microsoft.Authorization/denyassignments' {}
            'Microsoft.Authorization/elevateaccess' {}
            'Microsoft.Authorization/findorphanroleassignments' {}
            'Microsoft.Authorization/locks' {}
            'Microsoft.Authorization/permissions' {}
            'Microsoft.Authorization/policyassignments' {}
            'Microsoft.Authorization/policydefinitions' {}
            'Microsoft.Authorization/policysetdefinitions' {}
            'Microsoft.Authorization/privatelinkassociations' {}
            'Microsoft.Authorization/resourcemanagementprivatelinks' {}
            'Microsoft.Authorization/roleassignments' {}
            'Microsoft.Authorization/roleassignmentsusagemetrics' {}
            'Microsoft.Authorization/roledefinitions' {}
            'Microsoft.Automation/automationAccounts' {}
            'Microsoft.Automation/automationaccounts/configurations' {}
            'Microsoft.Automation/automationAccounts/runbooks' {}
            'Microsoft.AVS/privateclouds' {}
            'Microsoft.AzureActiveDirectory/b2cdirectories' {}
            'Microsoft.AzureActiveDirectory/b2ctenants' {}
            'Microsoft.AzureArcData/SqlServerInstances' {}
            'Microsoft.AzureData/datacontrollers' {}
            'Microsoft.AzureData/hybriddatamanagers' {}
            'Microsoft.AzureData/postgresinstances' {}
            'Microsoft.AzureData/sqlinstances' {}
            'Microsoft.AzureData/sqlmanagedinstances' {}
            'Microsoft.AzureData/sqlserverinstances' {}
            'Microsoft.AzureData/sqlserverregistrations' {}
            'Microsoft.AzureStack/cloudmanifestfiles' {}
            'Microsoft.AzureStack/registrations' {}
            'microsoft.azurestackhci/clusters' {}
            'microsoft.azurestackhci/logicalNetworks' {}
            'microsoft.azurestackhci/marketplaceGalleryImages' {}
            'Microsoft.AzureStackHCI/networkInterfaces' {}
            'Microsoft.AzureStackHCI/storageContainers' {}
            'Microsoft.AzureStackHCI/virtualHardDisks' {}
            'Microsoft.Batch/batchaccounts' {}
            'Microsoft.Billing/billingaccounts' {}
            'Microsoft.Billing/billingperiods' {}
            'Microsoft.Billing/billingpermissions' {}
            'Microsoft.Billing/billingproperty' {}
            'Microsoft.Billing/billingroleassignments' {}
            'Microsoft.Billing/billingroledefinitions' {}
            'Microsoft.Billing/departments' {}
            'Microsoft.Billing/enrollmentaccounts' {}
            'Microsoft.Billing/invoices' {}
            'Microsoft.Billing/transfers' {}
            'Microsoft.Bing/accounts' {}
            'Microsoft.BingMaps/mapapis' {}
            'Microsoft.BizTalkServices/biztalk' {}
            'Microsoft.Blockchain/blockchainmembers' {}
            'Microsoft.Blockchain/cordamembers' {}
            'Microsoft.Blockchain/watchers' {}
            'Microsoft.BlockchainTokens/tokenservices' {}
            'Microsoft.Blueprint/blueprintassignments' {}
            'Microsoft.Blueprint/blueprints' {}
            'Microsoft.BotService/botServices' {}
            'Microsoft.Cache/Redis' {

                $resourceData = Get-AzRedisCache -WarningAction SilentlyContinue -ResourceGroupName $ResourceItem.ResourceGroupName -Name $ResourceItem.Name

                $reportItem.StorageSize = $resourceData.Size
                $reportItem.SkuName = $resourceData.Sku
            }
            'Microsoft.Cache/redisenterprise' {}
            'Microsoft.Capacity/appliedreservations' {}
            'Microsoft.Capacity/calculateexchange' {}
            'Microsoft.Capacity/calculateprice' {}
            'Microsoft.Capacity/calculatepurchaseprice' {}
            'Microsoft.Capacity/catalogs' {}
            'Microsoft.Capacity/commercialreservationorders' {}
            'Microsoft.Capacity/exchange' {}
            'Microsoft.Capacity/reservationorders' {}
            'Microsoft.Capacity/reservations' {}
            'Microsoft.Capacity/resources' {}
            'Microsoft.Capacity/validatereservationorder' {}
            'Microsoft.Cdn/cdnwebapplicationfirewallmanagedrulesets' {}
            'Microsoft.Cdn/cdnwebapplicationfirewallpolicies' {}
            'Microsoft.Cdn/edgenodes' {}
            'microsoft.cdn/profiles' {

                $resourceData = Get-AzCdnProfile -WarningAction SilentlyContinue -ResourceGroupName $ResourceItem.ResourceGroupName -Name $ResourceItem.Name
                
                $reportItem.SkuName = $resourceData.SkuName
            }
            'microsoft.cdn/profiles/endpoints' {}
            'Microsoft.CertificateRegistration/certificateOrders' {}
            'Microsoft.ClassicCompute/capabilities' {}
            'Microsoft.ClassicCompute/domainnames' {}
            'Microsoft.ClassicCompute/quotas' {}
            'Microsoft.ClassicCompute/resourcetypes' {}
            'Microsoft.ClassicCompute/validatesubscriptionmoveavailability' {}
            'Microsoft.ClassicCompute/virtualmachines' {}
            'Microsoft.ClassicInfrastructureMigrate/classicinfrastructureresources' {}
            'Microsoft.ClassicNetwork/capabilities' {}
            'Microsoft.ClassicNetwork/expressroutecrossconnections' {}
            'Microsoft.ClassicNetwork/expressroutecrossconnections/peerings' {}
            'Microsoft.ClassicNetwork/gatewaysupporteddevices' {}
            'Microsoft.ClassicNetwork/networksecuritygroups' {}
            'Microsoft.ClassicNetwork/quotas' {}
            'Microsoft.ClassicNetwork/reservedips' {}
            'Microsoft.ClassicNetwork/virtualnetworks' {}
            'Microsoft.ClassicStorage/disks' {}
            'Microsoft.ClassicStorage/images' {}
            'Microsoft.ClassicStorage/osimages' {}
            'Microsoft.ClassicStorage/osplatformimages' {}
            'Microsoft.ClassicStorage/publicimages' {}
            'Microsoft.ClassicStorage/quotas' {}
            'Microsoft.ClassicStorage/storageaccounts' {}
            'Microsoft.ClassicStorage/vmimages' {}
            'Microsoft.ClassicSubscription/operations' {}
            'Microsoft.CognitiveServices/accounts' {

                $resourceData = Get-AzCognitiveServicesAccount -WarningAction SilentlyContinue -ResourceGroupName $ResourceItem.ResourceGroupName -Name $ResourceItem.Name

                $reportItem.SkuName = $resourceData.Sku.Name
                $reportItem.SkuTier = $resourceData.Sku.Tier
                $reportItem.SkuSize = $resourceData.Sku.Size
                $reportItem.SkuFamily = $resourceData.Sku.Family
                $reportItem.SkuCapacity = $resourceData.Sku.Capacity
                $reportItem.AccountType = $resourceData.AccountType
            }
            'Microsoft.CognitiveServices/CognitiveSearch' {}
            'Microsoft.Commerce/ratecard' {}
            'Microsoft.Commerce/usageaggregates' {}
            'Microsoft.Communication/CommunicationServices' {}
            'Microsoft.Communication/EmailServices' {}
            'Microsoft.Communication/EmailServices/Domains' {}
            'Microsoft.Compute/availabilitySets' {}
            'Microsoft.Compute/diskaccesses' {}
            'Microsoft.Compute/diskencryptionsets' {}
            'Microsoft.Compute/disks' {
                
                $resourceData = Get-AzDisk -WarningAction SilentlyContinue -ResourceGroupName $ResourceItem.ResourceGroupName -DiskName $ResourceItem.Name

                $reportItem.OsType = $resourceData.OsType
                $reportItem.StorageSize = $resourceData.DiskSizeGB
                $reportItem.SkuName = $resourceData.Sku.Name
                $reportItem.SkuTier = $resourceData.Sku.Tier
            }
            'Microsoft.Compute/galleries' {}
            'Microsoft.Compute/galleries/images' {}
            'Microsoft.Compute/galleries/images/versions' {}
            'Microsoft.Compute/hostgroups' {}
            'Microsoft.Compute/hostgroups/hosts' {}
            'Microsoft.Compute/images' {}
            'Microsoft.Compute/proximityplacementgroups' {}
            'Microsoft.Compute/restorePointCollections' {}
            'Microsoft.Compute/restorepointcollections/restorepoints' {}
            'Microsoft.Compute/sharedvmextensions' {}
            'Microsoft.Compute/sharedvmimages' {}
            'Microsoft.Compute/sharedvmimages/versions' {}
            'Microsoft.Compute/snapshots' {

                $resourceData = Get-AzSnapshot -WarningAction SilentlyContinue -ResourceGroupName $ResourceItem.ResourceGroupName -Name $ResourceItem.Name

                $reportItem.OsType = $resourceData.OsType
                $reportItem.StorageSize = $resourceData.DiskSizeGB
                $reportItem.SkuName = $resourceData.Sku.Name
                $reportItem.SkuTier = $resourceData.Sku.Tier
            }
            'Microsoft.Compute/sshPublicKeys' {}
            'Microsoft.Compute/virtualMachines' {

                $resourceData = Get-AzVM -WarningAction SilentlyContinue -ResourceGroupName $ResourceItem.ResourceGroupName -Name $ResourceItem.Name

                $resourceItem_NetworkProfile = Get-AzResource -ResourceId $resourceData.NetworkProfile.NetworkInterfaces[0].id
                $resourceData_NetworkProfile = Get-AzNetworkInterface -WarningAction SilentlyContinue -ResourceGroupName $resourceItem_NetworkProfile.ResourceGroupName -Name $resourceItem_NetworkProfile.Name

                $reportItem.IpAddressPrivate = $resourceData_NetworkProfile.IpConfigurations.PrivateIpAddress

                if ( $null -ne $resourceData_NetworkProfile.NetworkSecurityGroup.id ) {
                    $resourceItem_NetworkSecurityGroup = Get-AzResource -ResourceId $resourceData_NetworkProfile.NetworkSecurityGroup.id
                    $resourceData_NetworkSecurityGroup = Get-AzNetworkSecurityGroup -WarningAction SilentlyContinue -ResourceGroupName $resourceItem_NetworkSecurityGroup.ResourceGroupName -Name $resourceItem_NetworkSecurityGroup.Name
                }

                $reportItem.NSGName = $resourceData_NetworkSecurityGroup.Name

                if ( $null -ne $resourceData_NetworkProfile.IpConfigurations.PublicIpAddress ) {
                    $resourceItem_PublicIpAddress = Get-AzResource -ResourceId $resourceData_NetworkProfile.IpConfigurations.PublicIpAddress[0].Id
                    $resourceData_PublicIpAddress = Get-AzPublicIpAddress -WarningAction SilentlyContinue -ResourceGroupName $resourceItem_PublicIpAddress.ResourceGroupName -Name $resourceItem_PublicIpAddress.Name

                    $reportItem.IpAddressPublic = $resourceData_PublicIpAddress.IpAddress
                    $reportItem.FQDN = $resourceData_PublicIpAddress.DnsSettingsText
                }

                $reportItem.LicenseType = $resourceData.LicenseType
                $reportItem.State = $resourceData.StatusCode
                $reportItem.VMSize = $resourceData.VmSize
                $reportItem.OsName = $resourceData.OsName
                $reportItem.OsVersion = $resourceData.OsVersion
            }
            'Microsoft.Compute/virtualMachines/extensions' {}
            'Microsoft.Compute/virtualMachineScaleSets' {}
            'Microsoft.Compute/capabilities' {}
            'Microsoft.Compute/domainnames' {}
            'Microsoft.Compute/quotas' {}
            'Microsoft.Compute/resourcetypes' {}
            'Microsoft.Compute/validatesubscriptionmoveavailability' {}
            'Microsoft.Compute/virtualmachines' {}
            'Microsoft.Confluent/organizations' {}
            'Microsoft.Consumption/aggregatedcost' {}
            'Microsoft.Consumption/balances' {}
            'Microsoft.Consumption/budgets' {}
            'Microsoft.Consumption/charges' {}
            'Microsoft.Consumption/costtags' {}
            'Microsoft.Consumption/credits' {}
            'Microsoft.Consumption/events' {}
            'Microsoft.Consumption/forecasts' {}
            'Microsoft.Consumption/lots' {}
            'Microsoft.Consumption/marketplaces' {}
            'Microsoft.Consumption/pricesheets' {}
            'Microsoft.Consumption/products' {}
            'Microsoft.Consumption/reservationdetails' {}
            'Microsoft.Consumption/reservationrecommendationdetails' {}
            'Microsoft.Consumption/reservationrecommendations' {}
            'Microsoft.Consumption/reservationsummaries' {}
            'Microsoft.Consumption/reservationtransactions' {}
            'Microsoft.Consumption/tags' {}
            'Microsoft.Consumption/tenants' {}
            'Microsoft.Consumption/terms' {}
            'Microsoft.Consumption/usagedetails' {}
            'Microsoft.ContainerInstance/containerGroups' {

                $resourceData = Get-AzContainerGroup -WarningAction SilentlyContinue -ResourceGroupName $ResourceItem.ResourceGroupName -Name $ResourceItem.Name

                $reportItem.OsType = $resourceData.OsType
                $reportItem.SkuName = $resourceData.Sku
            }
            'Microsoft.ContainerInstance/serviceassociationlinks' {}
            'Microsoft.ContainerRegistry/registries' {

                $resourceData = Get-AzContainerRegistry -WarningAction SilentlyContinue -ResourceGroupName $ResourceItem.ResourceGroupName -Name $ResourceItem.Name

                $reportItem.SkuName = $resourceData.SkuName
                $reportItem.SkuTier = $resourceData.SkuTier
            }
            'Microsoft.ContainerRegistry/registries/agentpools' {}
            'Microsoft.ContainerRegistry/registries/buildtasks' {}
            'Microsoft.ContainerRegistry/registries/replications' {}
            'Microsoft.ContainerRegistry/registries/tasks' {}
            'Microsoft.ContainerRegistry/registries/webhooks' {}
            'Microsoft.ContainerService/containerservices' {}
            'Microsoft.ContainerService/managedClusters' {}
            'Microsoft.ContainerService/openshiftmanagedclusters' {}
            'Microsoft.ContentModerator/applications' {}
            'Microsoft.CortanaAnalytics/accounts' {}
            'Microsoft.CostManagement/alerts' {}
            'Microsoft.CostManagement/billingaccounts' {}
            'Microsoft.CostManagement/budgets' {}
            'Microsoft.CostManagement/cloudconnectors' {}
            'Microsoft.CostManagement/connectors' {}
            'Microsoft.CostManagement/departments' {}
            'Microsoft.CostManagement/dimensions' {}
            'Microsoft.CostManagement/enrollmentaccounts' {}
            'Microsoft.CostManagement/exports' {}
            'Microsoft.CostManagement/externalbillingaccounts' {}
            'Microsoft.CostManagement/forecast' {}
            'Microsoft.CostManagement/query' {}
            'Microsoft.CostManagement/register' {}
            'Microsoft.CostManagement/reportconfigs' {}
            'Microsoft.CostManagement/reports' {}
            'Microsoft.CostManagement/settings' {}
            'Microsoft.CostManagement/showbackrules' {}
            'Microsoft.CostManagement/views' {}
            'Microsoft.CustomerInsights/hubs' {}
            'Microsoft.CustomerLockbox/requests' {}
            'Microsoft.CustomProviders/associations' {}
            'Microsoft.CustomProviders/resourceproviders' {}
            'Microsoft.DataBox/jobs' {}
            'Microsoft.DataBoxEdge/availableskus' {}
            'Microsoft.DataBoxEdge/databoxedgedevices' {}
            'Microsoft.Databricks/workspaces' {

                $resourceData = Get-AzDatabricksWorkspace -WarningAction SilentlyContinue -ResourceGroupName $ResourceItem.ResourceGroupName -Name $ResourceItem.Name

                $reportItem.SkuName = $resourceData_NetworkProfile.IpConfigurations.SkuName
                $reportItem.SkuTier = $resourceData_NetworkProfile.IpConfigurations.SkuTier
            }
            'Microsoft.DataCatalog/catalogs' {}
            'Microsoft.DataCatalog/datacatalogs' {}
            'Microsoft.DataConnect/connectionmanagers' {}
            'Microsoft.DataExchange/packages' {}
            'Microsoft.DataExchange/plans' {}
            'Microsoft.DataFactory/datafactories' {}
            'Microsoft.DataFactory/factories' {}
            'Microsoft.DataLake/datalakeaccounts' {}
            'Microsoft.DataLakeAnalytics/accounts' {}
            'Microsoft.DataLakeStore/accounts' {}
            'Microsoft.DataMigration/services' {}
            'Microsoft.DataMigration/services/projects' {}
            'Microsoft.DataMigration/slots' {}
            'Microsoft.DataMigration/sqlmigrationservices' {}
            'Microsoft.DataProtection/BackupVaults' {}
            'Microsoft.DataReplication/replicationVaults' {}
            'Microsoft.DataShare/accounts' {}
            'Microsoft.DBforMariaDB/servers' {}
            'Microsoft.DBforMySQL/flexibleServers' {}
            'Microsoft.DBforMySQL/servers' {}
            'Microsoft.DBforPostgreSQL/flexibleServers' {

                $resourceData = Get-AzPostgreSqlFlexibleServer -WarningAction SilentlyContinue -ResourceGroupName $ResourceItem.ResourceGroupName -Name $ResourceItem.Name

                $reportItem.SkuName = $resourceData.SkuName
                $reportItem.SkuTier = $resourceData.SkuTier
                $reportItem.State = $resourceData.State
                $reportItem.StorageSize = $resourceData.StorageSizeGb
            }
            'Microsoft.DBforPostgreSQL/servers' {

                $resourceData = Get-AzPostgreSqlServer -WarningAction SilentlyContinue -ResourceGroupName $ResourceItem.ResourceGroupName -Name $ResourceItem.Name

                $reportItem.Kind = $resourceData.Kind
                $reportItem.SkuCapacity = $resourceData.SkuCapacity
                $reportItem.SkuFamily = $resourceData.SkuFamily
                $reportItem.SkuName = $resourceData.SkuName
                $reportItem.SkuSize = $resourceData.SkuSize
                $reportItem.SkuTier = $resourceData.SkuTier
            }
            'Microsoft.DBforPostgreSQL/servergroups' {}
            'Microsoft.DBforPostgreSQL/serversv2' {}
            'Microsoft.DeploymentManager/artifactsources' {}
            'Microsoft.DeploymentManager/rollouts' {}
            'Microsoft.DeploymentManager/servicetopologies' {}
            'Microsoft.DeploymentManager/servicetopologies/services' {}
            'Microsoft.DeploymentManager/servicetopologies/services/serviceunits' {}
            'Microsoft.DeploymentManager/steps' {}
            'Microsoft.DesktopVirtualization/applicationgroups' {}
            'Microsoft.DesktopVirtualization/hostpools' {}
            'Microsoft.DesktopVirtualization/scalingplans' {}
            'Microsoft.DesktopVirtualization/workspaces' {}
            'Microsoft.Devices/elasticpools' {}
            'Microsoft.Devices/elasticpools/iothubtenants' {}
            'Microsoft.Devices/iothubs' {}
            'Microsoft.Devices/provisioningservices' {}
            'Microsoft.DevOps/pipelines' {}
            'Microsoft.DevOps/controllers' {}
            'Microsoft.DevSpaces/controllers' {}
            'Microsoft.DevSpaces/AKScluster' {}
            'Microsoft.DevTestLab/labcenters' {}
            'Microsoft.DevTestLab/labs' {}
            'Microsoft.DevTestLab/labs/environments' {}
            'Microsoft.DevTestLab/labs/servicerunners' {}
            'Microsoft.DevTestLab/labs/virtualmachines' {}
            'Microsoft.DevTestLab/schedules' {}
            'Microsoft.DigitalTwins/digitaltwinsinstances' {}
            'Microsoft.DocumentDb/databaseAccounts' {

                $resourceData = Get-AzCosmosDBAccount -WarningAction SilentlyContinue -ResourceGroupName $ResourceItem.ResourceGroupName -Name $ResourceItem.Name
                
                $reportItem.OfferType = $resourceData.DatabaseAccountOfferType
                $reportItem.Kind = $resourceData.Kind
            }
            'Microsoft.DomainRegistration/domains' {}
            'Microsoft.DomainRegistration/generatessorequest' {}
            'Microsoft.DomainRegistration/topleveldomains' {}
            'Microsoft.DomainRegistration/validatedomainregistrationinformation' {}
            'Microsoft.Elastic/monitors' {}
            'Microsoft.EnterpriseKnowledgeGraph/services' {}
            'Microsoft.EventGrid/domains' {}
            'Microsoft.EventGrid/eventsubscriptions' {}
            'Microsoft.EventGrid/extensiontopics' {}
            'Microsoft.EventGrid/partnernamespaces' {}
            'Microsoft.EventGrid/partnerregistrations' {}
            'Microsoft.EventGrid/partnertopics' {}
            'Microsoft.EventGrid/systemTopics' {}
            'Microsoft.EventGrid/topics' {}
            'Microsoft.EventGrid/topictypes' {}
            'Microsoft.EventHub/clusters' {}
            'Microsoft.EventHub/namespaces' {

                $resourceData = Get-AzEventHubNamespace -WarningAction SilentlyContinue -ResourceGroupName $ResourceItem.ResourceGroupName -Name $ResourceItem.Name

                $reportItem.SkuCapacity = $resourceData.SkuCapacity
                $reportItem.SkuName = $resourceData.SkuName
                $reportItem.SkuTier = $resourceData.SkuTier
                $reportItem.State = $resourceData.Status
            }
            'Microsoft.EventHub/sku' {}
            'Microsoft.Experimentation/experimentworkspaces' {}
            'Microsoft.ExtendedLocation/customLocations' {}
            'Microsoft.Falcon/namespaces' {}
            'Microsoft.Features/featureproviders' {}
            'Microsoft.Features/features' {}
            'Microsoft.Features/providers' {}
            'Microsoft.Features/subscriptionfeatureregistrations' {}
            'Microsoft.Genomics/accounts' {}
            'Microsoft.GuestConfiguration/automanagedaccounts' {}
            'Microsoft.GuestConfiguration/automanagedvmconfigurationprofiles' {}
            'Microsoft.GuestConfiguration/guestconfigurationassignments' {}
            'Microsoft.GuestConfiguration/software' {}
            'Microsoft.GuestConfiguration/softwareupdateprofile' {}
            'Microsoft.GuestConfiguration/softwareupdates' {}
            'Microsoft.HanaOnAzure/hanainstances' {}
            'Microsoft.HanaOnAzure/sapmonitors' {}
            'Microsoft.HardwareSecurityModules/dedicatedhsms' {}
            'Microsoft.HDInsight/clusters' {}
            'Microsoft.HealthcareApis/services' {}
            'Microsoft.HybridCompute/machines' {}
            'Microsoft.HybridCompute/machines/extensions' {}
            'Microsoft.HybridData/datamanagers' {}
            'Microsoft.HybridNetwork/devices' {}
            'Microsoft.HybridNetwork/vnfs' {}
            'Microsoft.Hydra/components' {}
            'Microsoft.Hydra/networkscopes' {}
            'Microsoft.ImportExport/jobs' {}
            'Microsoft.Insights/accounts' {}
            'microsoft.insights/actiongroups' {}
            'Microsoft.Insights/activityLogAlerts' {}
            'Microsoft.Insights/alertrules' {}
            'microsoft.insights/autoscalesettings' {}
            'Microsoft.Insights/baseline' {}
            'microsoft.insights/components' {}
            'Microsoft.Insights/dataCollectionEndpoints' {}
            'Microsoft.Insights/dataCollectionRules' {}
            'Microsoft.Insights/diagnosticsettings' {}
            'Microsoft.Insights/diagnosticsettingscategories' {}
            'Microsoft.Insights/eventcategories' {}
            'Microsoft.Insights/eventtypes' {}
            'Microsoft.Insights/extendeddiagnosticsettings' {}
            'Microsoft.Insights/guestdiagnosticsettings' {}
            'Microsoft.Insights/listmigrationdate' {}
            'Microsoft.Insights/logdefinitions' {}
            'Microsoft.Insights/logprofiles' {}
            'Microsoft.Insights/logs' {}
            'Microsoft.Insights/metricalerts' {}
            'Microsoft.Insights/metricbaselines' {}
            'Microsoft.Insights/metricbatch' {}
            'Microsoft.Insights/metricdefinitions' {}
            'Microsoft.Insights/metricnamespaces' {}
            'Microsoft.Insights/metrics' {}
            'Microsoft.Insights/migratealertrules' {}
            'Microsoft.Insights/migratetonewpricingmodel' {}
            'Microsoft.Insights/myworkbooks' {}
            'Microsoft.Insights/notificationgroups' {}
            'Microsoft.Insights/privatelinkscopes' {}
            'Microsoft.Insights/rollbacktolegacypricingmodel' {}
            'microsoft.insights/scheduledqueryrules' {}
            'Microsoft.Insights/topology' {}
            'Microsoft.Insights/transactions' {}
            'Microsoft.Insights/vminsightsonboardingstatuses' {}
            'microsoft.insights/webtests' {}
            'Microsoft.Insights/webtests/gettestresultfile' {}
            'microsoft.insights/workbooks' {}
            'Microsoft.Insights/workbooktemplates' {}
            'Microsoft.IoTCentral/apptemplates' {}
            'Microsoft.IoTCentral/iotapps' {}
            'Microsoft.IoTHub/iothub' {}
            'Microsoft.IoTSpaces/graph' {}
            'Microsoft.KeyVault/deletedvaults' {}
            'Microsoft.KeyVault/hsmpools' {}
            'Microsoft.KeyVault/managedhsms' {}
            'Microsoft.KeyVault/vaults' {

                $ResourceData = Get-AzKeyVault -WarningAction SilentlyContinue -ResourceGroupName $ResourceItem.ResourceGroupName -Name $ResourceItem.Name

                $reportItem.SkuName = $ResourceData.Sku
            }
            'Microsoft.Kubernetes/connectedclusters' {}
            'Microsoft.Kubernetes/registeredsubscriptions' {}
            'Microsoft.KubernetesConfiguration/privateLinkScopes' {}
            'Microsoft.KubernetesConfiguration/sourcecontrolconfigurations' {}
            'Microsoft.Kusto/clusters' {

                $resourceData = Get-AzKustoCluster -WarningAction SilentlyContinue -ResourceGroupName $ResourceItem.ResourceGroupName -Name $ResourceItem.Name

                $reportItem.SkuCapacity = $resourceData.SkuCapacity
                $reportItem.SkuName = $resourceData.SkuName
                $reportItem.SkuTier = $resourceData.SkuTier
                $reportItem.State = $resourceData.State
            }
            'Microsoft.LabServices/labaccounts' {}
            'Microsoft.LabServices/users' {}
            'Microsoft.LoadTestService/loadtests' {}
            'Microsoft.LocationBasedServices/accounts' {}
            'Microsoft.LocationServices/accounts' {}
            'Microsoft.Logic/hostingenvironments' {}
            'Microsoft.Logic/integrationaccounts' {}
            'Microsoft.Logic/integrationserviceenvironments' {}
            'Microsoft.Logic/integrationserviceenvironments/managedapis' {}
            'Microsoft.Logic/isolatedenvironments' {}
            'Microsoft.Logic/workflows' {}
            'Microsoft.MachineLearning/commitmentplans' {}
            'Microsoft.MachineLearning/webservices' {}
            'Microsoft.MachineLearning/workspaces' {}
            'Microsoft.MachineLearningCompute/operationalizationclusters' {}
            'Microsoft.MachineLearningExperimentation/accounts' {}
            'Microsoft.MachineLearningExperimentation/teamaccounts' {}
            'Microsoft.MachineLearningModelManagement/accounts' {}
            'Microsoft.MachineLearningServices/workspaces' {

                $resourceData = Get-AzMlWorkspace -WarningAction SilentlyContinue -ResourceGroupName $ResourceItem.ResourceGroupName -Name $ResourceItem.Name

                $reportItem.Kind = $resourceData.Kind
                $reportItem.SkuCapacity = $resourceData.SkuCapacity
                $reportItem.SkuFamily = $resourceData.SkuFamily
                $reportItem.SkuName = $resourceData.SkuName
                $reportItem.SkuSize = $resourceData.SkuSize
                $reportItem.SkuTier = $resourceData.SkuTier
            }
            'Microsoft.Maintenance/configurationassignments' {}
            'Microsoft.Maintenance/maintenanceConfigurations' {}
            'Microsoft.Maintenance/updates' {}
            'Microsoft.ManagedIdentity/identities' {}
            'Microsoft.ManagedIdentity/userAssignedIdentities' {}
            'Microsoft.ManagedNetwork/managednetworks' {}
            'Microsoft.ManagedNetwork/managednetworks/managednetworkgroups' {}
            'Microsoft.ManagedNetwork/managednetworks/managednetworkpeeringpolicies' {}
            'Microsoft.ManagedNetwork/notification' {}
            'Microsoft.ManagedServices/marketplaceregistrationdefinitions' {}
            'Microsoft.ManagedServices/registrationassignments' {}
            'Microsoft.ManagedServices/registrationdefinitions' {}
            'Microsoft.Management/getentities' {}
            'Microsoft.Management/managementgroups' {}
            'Microsoft.Management/managementgroups/settings' {}
            'Microsoft.Management/resources' {}
            'Microsoft.Management/starttenantbackfill' {}
            'Microsoft.Management/tenantbackfillstatus' {}
            'Microsoft.Maps/accounts' {}
            'Microsoft.Maps/accounts/privateatlases' {}
            'Microsoft.Marketplace/offers' {}
            'Microsoft.Marketplace/offertypes' {}
            'Microsoft.Marketplace/privategalleryitems' {}
            'Microsoft.Marketplace/privatestoreclient' {}
            'Microsoft.Marketplace/privatestores' {}
            'Microsoft.Marketplace/products' {}
            'Microsoft.Marketplace/publishers' {}
            'Microsoft.Marketplace/register' {}
            'Microsoft.MarketplaceApps/classicdevservices' {}
            'Microsoft.MarketplaceOrdering/agreements' {}
            'Microsoft.MarketplaceOrdering/offertypes' {}
            'Microsoft.Media/mediaservices' {}
            'Microsoft.Media/mediaservices/liveEvents' {}
            'Microsoft.Media/mediaservices/streamingEndpoints' {}
            'Microsoft.Microservices4Spring/appclusters' {}
            'Microsoft.Migrate/assessmentProjects' {}
            'Microsoft.Migrate/migrateprojects' {}
            'Microsoft.Migrate/modernizeProjects' {}
            'Microsoft.Migrate/movecollections' {}
            'Microsoft.Migrate/projects' {}
            'Microsoft.MixedReality/objectunderstandingaccounts' {}
            'Microsoft.MixedReality/remoterenderingaccounts' {}
            'Microsoft.MixedReality/spatialanchorsaccounts' {}
            'Microsoft.MobileNetwork/mobileNetworks' {}
            'Microsoft.MobileNetwork/mobileNetworks/dataNetworks' {}
            'Microsoft.MobileNetwork/mobileNetworks/simPolicies' {}
            'Microsoft.MobileNetwork/mobileNetworks/sites' {}
            'Microsoft.MobileNetwork/mobileNetworks/slices' {}
            'Microsoft.MobileNetwork/packetCoreControlPlanes' {}
            'Microsoft.MobileNetwork/packetCoreControlPlanes/packetCoreDataPlanes' {}
            'Microsoft.MobileNetwork/packetCoreControlPlanes/packetCoreDataPlanes/attachedDataNetworks' {}
            'Microsoft.MobileNetwork/sims' {}
            'Microsoft.MobileNetwork/simGroups' {}
            'Microsoft.MobileNetwork/simGroups/sims' {}
            'Microsoft.MobileNetwork/packetCoreControlPlaneVersions' {}
            'Microsoft.NetApp/netappaccounts' {}
            'Microsoft.NetApp/netappaccounts/capacitypools' {}
            'Microsoft.NetApp/netappaccounts/capacitypools/volumes' {}
            'Microsoft.NetApp/netappaccounts/capacitypools/volumes/mounttargets' {}
            'Microsoft.NetApp/netappaccounts/capacitypools/volumes/snapshots' {}
            'Microsoft.Network/applicationGateways' {

                $resourceData = Get-AzApplicationGateway -WarningAction SilentlyContinue -ResourceGroupName $ResourceItem.ResourceGroupName -Name $ResourceItem.Name

                $reportItem.SkuName = $resourceData.Sku.Name
                $reportItem.SkuTier = $resourceData.Sku.Tier
                $reportItem.SkuCapacity = $resourceData.Sku.Capacity
            }
            'Microsoft.Network/applicationGatewayWebApplicationFirewallPolicies' {}
            'Microsoft.Network/applicationSecurityGroups' {}
            'Microsoft.Network/azureFirewalls' {

                $resourceData = Get-AzFirewall -WarningAction SilentlyContinue -ResourceGroupName $ResourceItem.ResourceGroupName -Name $ResourceItem.Name

                $reportItem.SkuName = $resourceData.Sku.Name
                $reportItem.SkuTier = $resourceData.Sku.Tier
            }
            'Microsoft.Network/bastionHosts' {}
            'Microsoft.Network/bgpservicecommunities' {}
            'Microsoft.Network/connections' {}
            'Microsoft.Network/connectionMonitors' {}
            'Microsoft.Network/ddoscustompolicies' {}
            'Microsoft.Network/ddosProtectionPlans' {}
            'Microsoft.Network/dnsResolvers' {}
            'Microsoft.Network/dnsResolvers/inboundEndpoints' {}
            'Microsoft.Network/dnsResolvers/outboundEndpoints' {}
            'Microsoft.Network/dnsZones' {}
            'Microsoft.Network/expressRouteCircuits' {}
            'Microsoft.Network/expressroutegateways' {}
            'Microsoft.Network/expressrouteserviceproviders' {}
            'Microsoft.Network/firewallPolicies' {

                $resourceData = Get-AzFirewallPolicy -WarningAction SilentlyContinue -ResourceGroupName $ResourceItem.ResourceGroupName -Name $ResourceItem.Name

                $reportItem.SkuTier = $resourceData.Sku.Tier
            }
            'Microsoft.Network/frontdoors' {}
            'Microsoft.Network/ipallocations' {}
            'Microsoft.Network/ipGroups' {}
            'Microsoft.Network/loadBalancers' {}
            'Microsoft.Network/localNetworkGateways' {}
            'Microsoft.Network/natGateways' {

                $resourceData = Get-AzNatGateway -WarningAction SilentlyContinue -ResourceGroupName $ResourceItem.ResourceGroupName -Name $ResourceItem.Name

                $reportItem.SkuName = $resourceData.Sku.Name
            }
            'Microsoft.Network/networkexperimentprofiles' {}
            'Microsoft.Network/networkIntentPolicies' {}
            'Microsoft.Network/networkInterfaces' {}
            'Microsoft.Network/networkprofiles' {}
            'Microsoft.Network/networkSecurityGroups' {}
            'Microsoft.Network/networkWatchers' {}
            'Microsoft.Network/networkWatchers/connectionMonitors' {}
            'microsoft.network/networkWatchers/flowLogs' {}
            'Microsoft.Network/networkwatchers/pingmeshes' {}
            'Microsoft.Network/p2svpngateways' {}
            'Microsoft.Network/privateDnsZones' {}
            'Microsoft.Network/privateDnsZones/virtualNetworkLinks' {}
            'Microsoft.Network/privatednszonesinternal' {}
            'Microsoft.Network/privateendpointredirectmaps' {}
            'Microsoft.Network/privateEndpoints' {}
            'Microsoft.Network/privatelinkservices' {}
            'Microsoft.Network/publicIPAddresses' {

                $resourceData = Get-AzPublicIpAddress -WarningAction SilentlyContinue -ResourceGroupName $ResourceItem.ResourceGroupName -Name $ResourceItem.Name

                $reportItem.IpAddressPublic = $resourceData.IpAddress
                $reportItem.SkuName = $resourceData.Sku.Name
                $reportItem.SkuTier = $resourceData.Sku.Tier
            }
            'Microsoft.Network/publicIPPrefixes' {}
            'Microsoft.Network/routefilters' {}
            'Microsoft.Network/routeTables' {}
            'Microsoft.Network/securitypartnerproviders' {}
            'Microsoft.Network/serviceendpointpolicies' {}
            'Microsoft.Network/trafficmanagergeographichierarchies' {}
            'Microsoft.Network/trafficmanagerprofiles' {}
            'Microsoft.Network/trafficmanagerprofiles/heatmaps' {}
            'Microsoft.Network/trafficmanagerusermetricskeys' {}
            'Microsoft.Network/virtualHubs' {

                $resourceData = Get-AzVirtualHub -WarningAction SilentlyContinue -ResourceGroupName $ResourceItem.ResourceGroupName -Name $ResourceItem.Name

                $reportItem.SkuName = $resourceData.Sku
            }
            'Microsoft.Network/virtualNetworkGateways' {

                $resourceData = Get-AzVirtualNetworkGateway -WarningAction SilentlyContinue -ResourceGroupName $ResourceItem.ResourceGroupName -Name $ResourceItem.Name

                $reportItem.Type = $resourceData.VpnType
                $reportItem.SkuCapacity = $resourceData.Sku.Capacity
                $reportItem.SkuName = $resourceData.Sku.Name
                $reportItem.SkuTier = $resourceData.Sku.Tier
            }
            'Microsoft.Network/virtualNetworks' {}
            'Microsoft.Network/virtualnetworktaps' {}
            'Microsoft.Network/virtualrouters' {}
            'Microsoft.Network/virtualWans' {

                $resourceData = Get-AzVirtualWan -WarningAction SilentlyContinue -ResourceGroupName $ResourceItem.ResourceGroupName -Name $ResourceItem.Name

                $reportItem.Type = $resourceData.VirtualWanType
            }
            'Microsoft.Network/vpnGateways' {}
            'Microsoft.Network/vpnserverconfigurations' {}
            'Microsoft.Network/vpnSites' {}
            'Microsoft.NotificationHubs/namespaces' {}
            'Microsoft.NotificationHubs/namespaces/notificationHubs' {}
            'Microsoft.ObjectStore/osnamespaces' {}
            'Microsoft.OffAzure/hypervsites' {}
            'Microsoft.OffAzure/importsites' {}
            'Microsoft.OffAzure/MasterSites' {}
            'Microsoft.OffAzure/ServerSites' {}
            'Microsoft.OffAzure/VMwareSites' {}
            'Microsoft.OperationalInsights/clusters' {}
            'Microsoft.OperationalInsights/deletedworkspaces' {}
            'Microsoft.OperationalInsights/linktargets' {}
            'microsoft.operationalInsights/querypacks' {}
            'Microsoft.OperationalInsights/storageinsightconfigs' {}
            'Microsoft.OperationalInsights/workspaces' {}
            'Microsoft.OperationsManagement/managementassociations' {}
            'Microsoft.OperationsManagement/managementconfigurations' {}
            'Microsoft.OperationsManagement/solutions' {}
            'Microsoft.OperationsManagement/views' {}
            'Microsoft.Peering/legacypeerings' {}
            'Microsoft.Peering/peerasns' {}
            'Microsoft.Peering/peeringlocations' {}
            'Microsoft.Peering/peerings' {}
            'Microsoft.Peering/peeringservicecountries' {}
            'Microsoft.Peering/peeringservicelocations' {}
            'Microsoft.Peering/peeringserviceproviders' {}
            'Microsoft.Peering/peeringservices' {}
            'Microsoft.PolicyInsights/policyevents' {}
            'Microsoft.PolicyInsights/policystates' {}
            'Microsoft.PolicyInsights/policytrackedresources' {}
            'Microsoft.PolicyInsights/remediations' {}
            'Microsoft.Portal/consoles' {}
            'Microsoft.Portal/dashboards' {}
            'Microsoft.Portal/usersettings' {}
            'Microsoft.PowerBI/workspacecollections' {}
            'Microsoft.PowerBIDedicated/capacities' {}
            'Microsoft.ProjectBabylon/accounts' {}
            'Microsoft.Purview/accounts' {}
            'Microsoft.ProviderHub/availableaccounts' {}
            'Microsoft.ProviderHub/providerregistrations' {}
            'Microsoft.ProviderHub/rollouts' {}
            'Microsoft.Quantum/workspaces' {}
            'Microsoft.RecoveryServices/replicationeligibilityresults' {}
            'Microsoft.RecoveryServices/vaults' {}
            'Microsoft.RedHatOpenShift/openshiftclusters' {}
            'Microsoft.Relay/namespaces' {

                $resourceData = Get-AzRelayNamespace -WarningAction SilentlyContinue -ResourceGroupName $ResourceItem.ResourceGroupName -Name $ResourceItem.Name

                $reportItem.SkuName = $resourceData.SkuName
                $reportItem.SkuTier = $resourceData.SkuTier
                $reportItem.State = $resourceData.Status
            }
            'Microsoft.ResourceConnector/appliances' {}
            'Microsoft.ResourceGraph/queries' {}
            'Microsoft.ResourceGraph/resourcechangedetails' {}
            'Microsoft.ResourceGraph/resourcechanges' {}
            'Microsoft.ResourceGraph/resources' {}
            'Microsoft.ResourceGraph/resourceshistory' {}
            'Microsoft.ResourceGraph/subscriptionsstatus' {}
            'Microsoft.ResourceHealth/childresources' {}
            'Microsoft.ResourceHealth/emergingissues' {}
            'Microsoft.ResourceHealth/events' {}
            'Microsoft.ResourceHealth/metadata' {}
            'Microsoft.ResourceHealth/notifications' {}
            'Microsoft.Resources/deployments' {}
            'Microsoft.Resources/deploymentscripts' {}
            'Microsoft.Resources/deploymentscripts/logs' {}
            'Microsoft.Resources/links' {}
            'Microsoft.Resources/providers' {}
            'Microsoft.Resources/resourcegroups' {}
            'Microsoft.Resources/resources' {}
            'Microsoft.Resources/subscriptions' {}
            'Microsoft.Resources/tags' {}
            'Microsoft.Resources/templatespecs' {}
            'Microsoft.Resources/templatespecs/versions' {}
            'Microsoft.Resources/tenants' {}
            'Microsoft.SaaS/applications' {}
            'Microsoft.SaaS/resources' {}
            'Microsoft.SaaS/saasresources' {}
            'Microsoft.Search/resourcehealthmetadata' {}
            'Microsoft.Search/searchservices' {}
            'Microsoft.Security/adaptivenetworkhardenings' {}
            'Microsoft.Security/advancedthreatprotectionsettings' {}
            'Microsoft.Security/alerts' {}
            'Microsoft.Security/allowedconnections' {}
            'Microsoft.Security/applicationwhitelistings' {}
            'Microsoft.Security/assessmentmetadata' {}
            'Microsoft.Security/assessments' {}
            'Microsoft.Security/assignments' {}
            'Microsoft.Security/autodismissalertsrules' {}
            'Microsoft.Security/automations' {}
            'Microsoft.Security/autoprovisioningsettings' {}
            'Microsoft.Security/complianceresults' {}
            'Microsoft.Security/compliances' {}
            'Microsoft.Security/datacollectionagents' {}
            'Microsoft.Security/devicesecuritygroups' {}
            'Microsoft.Security/discoveredsecuritysolutions' {}
            'Microsoft.Security/externalsecuritysolutions' {}
            'Microsoft.Security/informationprotectionpolicies' {}
            'Microsoft.Security/iotsecuritysolutions' {}
            'Microsoft.Security/iotsecuritysolutions/analyticsmodels' {}
            'Microsoft.Security/iotsecuritysolutions/analyticsmodels/aggregatedalerts' {}
            'Microsoft.Security/iotsecuritysolutions/analyticsmodels/aggregatedrecommendations' {}
            'Microsoft.Security/jitnetworkaccesspolicies' {}
            'Microsoft.Security/policies' {}
            'Microsoft.Security/pricings' {}
            'Microsoft.Security/regulatorycompliancestandards' {}
            'Microsoft.Security/regulatorycompliancestandards/regulatorycompliancecontrols' {}
            'Microsoft.Security/regulatorycompliancestandards/regulatorycompliancecontrols/regulatorycomplianceassessments' {}
            'Microsoft.Security/securityConnectors' {}
            'Microsoft.Security/securitycontacts' {}
            'Microsoft.Security/securitysolutions' {}
            'Microsoft.Security/securitysolutionsreferencedata' {}
            'Microsoft.Security/securitystatuses' {}
            'Microsoft.Security/securitystatusessummaries' {}
            'Microsoft.Security/servervulnerabilityassessments' {}
            'Microsoft.Security/settings' {}
            'Microsoft.Security/subassessments' {}
            'Microsoft.Security/tasks' {}
            'Microsoft.Security/topologies' {}
            'Microsoft.Security/workspacesettings' {}
            'Microsoft.SecurityInsights/aggregations' {}
            'Microsoft.SecurityInsights/alertrules' {}
            'Microsoft.SecurityInsights/alertruletemplates' {}
            'Microsoft.SecurityInsights/automationrules' {}
            'Microsoft.SecurityInsights/bookmarks' {}
            'Microsoft.SecurityInsights/cases' {}
            'Microsoft.SecurityInsights/dataconnectors' {}
            'Microsoft.SecurityInsights/entities' {}
            'Microsoft.SecurityInsights/entityqueries' {}
            'Microsoft.SecurityInsights/incidents' {}
            'Microsoft.SecurityInsights/officeconsents' {}
            'Microsoft.SecurityInsights/settings' {}
            'Microsoft.SecurityInsights/threatintelligence' {}
            'Microsoft.SerialConsole/consoleservices' {}
            'Microsoft.ServerManagement/gateways' {}
            'Microsoft.ServerManagement/nodes' {}
            'Microsoft.ServiceBus/namespaces' {

                $resourceData = Get-AzServiceBusNamespace -WarningAction SilentlyContinue -ResourceGroupName $ResourceItem.ResourceGroupName -Name $ResourceItem.Name

                $reportItem.SkuCapacity = $resourceData.SkuCapacity
                $reportItem.SkuName = $resourceData.SkuName
                $reportItem.SkuTier = $resourceData.SkuTier
            }
            'Microsoft.ServiceBus/premiummessagingregions' {}
            'Microsoft.ServiceBus/sku' {}
            'Microsoft.ServiceFabric/applications' {}
            'Microsoft.ServiceFabric/clusters' {}
            'Microsoft.ServiceFabric/containergroups' {}
            'Microsoft.ServiceFabric/containergroupsets' {}
            'Microsoft.ServiceFabric/edgeclusters' {}
            'Microsoft.ServiceFabric/managedclusters' {}
            'Microsoft.ServiceFabric/networks' {}
            'Microsoft.ServiceFabric/secretstores' {}
            'Microsoft.ServiceFabric/volumes' {}
            'Microsoft.ServiceFabricMesh/applications' {}
            'Microsoft.ServiceFabricMesh/containergroups' {}
            'Microsoft.ServiceFabricMesh/gateways' {}
            'Microsoft.ServiceFabricMesh/networks' {}
            'Microsoft.ServiceFabricMesh/secrets' {}
            'Microsoft.ServiceFabricMesh/volumes' {}
            'Microsoft.ServiceNetworking/trafficcontrollers' {}
            'Microsoft.ServiceNetworking/associations' {}
            'Microsoft.ServiceNetworking/frontends' {}
            'Microsoft.Services/rollouts' {}
            'Microsoft.SignalRService/signalr' {}
            'Microsoft.SoftwarePlan/hybridusebenefits' {}
            'Microsoft.Solutions/applicationdefinitions' {}
            'Microsoft.Solutions/applications' {}
            'Microsoft.Solutions/jitrequests' {}
            'Microsoft.Sql/instancepools' {}
            'Microsoft.Sql/locations' {}
            'Microsoft.Sql/managedinstances' {}
            'Microsoft.Sql/managedinstances/databases' {}
            'Microsoft.Sql/servers' {}
            'Microsoft.Sql/servers/databases' {

                if ( $ResourceItem.ManagedBy ) {
                    $resourceItem_server = Get-AzResource -ResourceId $ResourceItem.ManagedBy
                    $resourceData_server = Get-AzSqlServer -WarningAction SilentlyContinue -ResourceGroupName $resourceItem_server.ResourceGroupName -ServerName $resourceItem_server.Name

                    $reportItem.HostedOn = $resourceData_server.ServerName

                    $resourceData = Get-AzSqlDatabase -WarningAction SilentlyContinue -ResourceGroupName $ResourceItem.ResourceGroupName -ServerName $resourceData_server.ServerName 

                    Foreach ($dbname in $resourceData ) {
                        if ( $dbname.DatabaseName -eq $($resourceData_server.ServerName + '/master') ) {
                            $reportItem.DBName = $dbname.SkuName
                            $reportItem.SkuName = $dbname.SkuName
                            $reportItem.SkuFamily = $dbname.Family
                            $reportItem.SkuCapacity = $dbname.Capacity
                        }
                    }
                }
            }
            'Microsoft.Sql/servers/databases/backuplongtermretentionpolicies' {}
            'Microsoft.Sql/servers/elasticpools' {}
            'Microsoft.Sql/servers/jobaccounts' {}
            'Microsoft.Sql/servers/jobagents' {}
            'Microsoft.Sql/virtualclusters' {}
            'Microsoft.SqlVirtualMachine/SqlVirtualMachineGroups' {}
            'Microsoft.SqlVirtualMachine/SqlVirtualMachines' {}
            'Microsoft.Storage/storageAccounts' {

                $resourceData = Get-AzStorageAccount -WarningAction SilentlyContinue -ResourceGroupName $ResourceItem.ResourceGroupName -Name $ResourceItem.Name

                $reportItem.Kind = $ResourceItem.Kind
                $reportItem.SkuName = $ResourceItem.Sku.Name
                $reportItem.SkuTier = $ResourceItem.Sku.Tier
                $reportItem.SkuSize = $ResourceItem.Sku.Size
                $reportItem.SkuFamily = $ResourceItem.Sku.Family
                $reportItem.SkuModel = $ResourceItem.Sku.Model
                $reportItem.SkuCapacity = $ResourceItem.Sku.Capacity
            }
            'Microsoft.StorageCache/caches' {}
            'Microsoft.StorageSync/storageSyncServices' {}
            'Microsoft.StorageSyncDev/storagesyncservices' {}
            'Microsoft.StorageSyncInt/storagesyncservices' {}
            'Microsoft.StorSimple/managers' {}
            'Microsoft.StreamAnalytics/clusters' {}
            'Microsoft.StreamAnalytics/streamingjobs' {}
            'Microsoft.StreamAnalyticsExplorer/environments' {}
            'Microsoft.StreamAnalyticsExplorer/instances' {}
            'Microsoft.Subscription/subscriptions' {}
            'Microsoft.Support/services' {}
            'Microsoft.Support/supporttickets' {}
            'Microsoft.Synapse/workspaces' {}
            'Microsoft.Synapse/workspaces/bigDataPools' {}
            'Microsoft.Synapse/workspaces/sqlpools' {}
            'Microsoft.Syntex/documentProcessors' {}
            'Microsoft.TimeSeriesInsights/environments' {}
            'Microsoft.TimeSeriesInsights/environments/eventsources' {}
            'Microsoft.TimeSeriesInsights/environments/referencedatasets' {}
            'Microsoft.Token/stores' {}
            'Microsoft.VirtualMachineImages/imageTemplates' {}
            'microsoft.visualstudio/account' {}
            'Microsoft.VisualStudio/account/extension' {}
            'Microsoft.VisualStudio/account/project' {}
            'Microsoft.VMware/arczones' {}
            'Microsoft.VMware/resourcepools' {}
            'Microsoft.VMware/vcenters' {}
            'Microsoft.VMware/virtualmachines' {}
            'Microsoft.VMware/virtualmachinetemplates' {}
            'Microsoft.VMware/virtualnetworks' {}
            'Microsoft.VMwareCloudSimple/dedicatedcloudnodes' {}
            'Microsoft.VMwareCloudSimple/dedicatedcloudservices' {}
            'Microsoft.VMwareCloudSimple/virtualmachines' {}
            'Microsoft.VnfManager/devices' {}
            'Microsoft.VnfManager/vnfs' {}
            'Microsoft.VSOnline/accounts' {}
            'Microsoft.VSOnline/plans' {}
            'Microsoft.VSOnline/registeredsubscriptions' {}
            'Microsoft.Web/availablestacks' {}
            'Microsoft.Web/billingmeters' {}
            'Microsoft.Web/certificates' {}
            'Microsoft.Web/connectionGateways' {}
            'Microsoft.Web/connections' {}
            'Microsoft.Web/customApis' {}
            'Microsoft.Web/deletedsites' {}
            'Microsoft.Web/deploymentlocations' {}
            'Microsoft.Web/georegions' {}
            'Microsoft.Web/hostingenvironments' {}
            'Microsoft.Web/kubeenvironments' {}
            'Microsoft.Web/publishingusers' {}
            'Microsoft.Web/recommendations' {}
            'Microsoft.Web/resourcehealthmetadata' {}
            'Microsoft.Web/runtimes' {}
            'Microsoft.Web/serverFarms' {

                $resourceData = Get-AzAppServicePlan -WarningAction SilentlyContinue -ResourceGroupName $ResourceItem.ResourceGroupName -Name $ResourceItem.Name

                $reportItem.SkuName = $resourceData.Sku.Name
                $reportItem.SkuTier = $resourceData.Sku.Tier
                $reportItem.SkuSize = $resourceData.Sku.Size
                $reportItem.SkuFamily = $resourceData.Sku.Family
                $reportItem.SkuCapacity = $resourceData.Sku.Capacity    
            }
            'Microsoft.Web/serverfarms/eventgridfilters' {}
            'Microsoft.Web/sites' {

                $resourceData = Get-AzWebApp -WarningAction SilentlyContinue -ResourceGroupName $ResourceItem.ResourceGroupName -Name $ResourceItem.Name

                $reportItem.State = $resourceData.State

                # ADD SERVER FARM SIZE
                $resourceItem_ASP = Get-AzResource -ResourceId $resourceData.ServerFarmId
                $resourceData_ASP = Get-AzAppServicePlan -WarningAction SilentlyContinue -ResourceGroupName $resourceItem_ASP.ResourceGroupName -Name $resourceItem_ASP.Name

                $reportItem.HostedOn = $resourceData_ASP.Name
                $reportItem.SkuName = $resourceData_ASP.Sku.Name
                $reportItem.SkuTier = $resourceData_ASP.Sku.Tier
                $reportItem.SkuSize = $resourceData_ASP.Sku.Size
                $reportItem.SkuFamily = $resourceData_ASP.Sku.Family
                $reportItem.SkuCapacity = $resourceData_ASP.Sku.Capacity
            }
            'Microsoft.Web/sites/premieraddons' {}
            'Microsoft.Web/sites/slots' {}
            'Microsoft.Web/sourcecontrols' {}
            'Microsoft.Web/staticsites' {}
            'Microsoft.WindowsESU/multipleactivationkeys' {}
            'Microsoft.WindowsIoT/deviceservices' {}
            'Microsoft.WorkloadBuilder/workloads' {}
            'Microsoft.WorkloadMonitor/components' {}
            'Microsoft.WorkloadMonitor/componentssummary' {}
            'Microsoft.WorkloadMonitor/monitorinstances' {}
            'Microsoft.WorkloadMonitor/monitorinstancessummary' {}
            'Microsoft.WorkloadMonitor/monitors' {}

            default {
                Write-Output $('Resource Type not defined: ' + $ResourceItem.ResourceType)
                # exit
            }
        }

        #
        # Get Tags
        ##################################################
        if ( $with_Tags ) {
            if ( $null -ne $ResourceItem.Tags ) {
                Foreach( $tag in $ResourceItem.Tags.GetEnumerator() ) {
                    if ( $tag.Key -like 'hidden-*' ) {
                        continue
                    }
                    if ( $tag.Key -like 'link:*' ) {
                        continue
                    }
                    if ( $tag.Key -like 'aks-managed*' ) {
                        continue
                    }
                    if ( $tag.Key -like 'ms-resource*' ) {
                        continue
                    }
                    if ( $tag.Key -like 'k8s-*' ) {
                        continue
                    }
                    if ( $tag.Key -like 'ms.*' ) {
                        continue
                    }
                    if ( $tag.Key -like 'kubernetes.io*' ) {
                        continue
                    }
                    if ( $tag.Key -like 'AzHydration-*' ) {
                        continue
                    }
                    if ( $tag.Key -like 'aca-managed*' ) {
                        continue
                    }
                    if ( $tag.Key -like 'APIKey' ) {
                        continue
                    }
                    if ( $tag.Key -like 'RSVaultBackup*' ) {
                        continue
                    }

                    $property_name = 'Tag_' + $tag.Key
                    if ($Debug) { Write-Output $('   - Tag: ' + $property_name + ' = ' + $tag.Value) }
                    if ( $null -eq $reportItem[$property_name] ) {
                        # Remove ending line characters from $tag.Value
                        $property_value = $tag.Value -replace "`r`n", ""
                        $reportItem | Add-Member -MemberType NoteProperty -Name $property_name -Value $property_value
                        $headers[$property_name] = 1
                    }
                    else {
                        $reportItem[$property_name] = $tag.value
                    }
                }
            }
        }


        if ( $ResourceCapabilitiesData[ $ResourceItem.ResourceType ] ) {
            $reportItem.MoveToResourceGroup = $ResourceCapabilitiesData[ $ResourceItem.ResourceType ].MoveToResourceGroup
            $reportItem.MoveToSubscription = $ResourceCapabilitiesData[ $ResourceItem.ResourceType ].MoveToSubscription
            $reportItem.MoveToRegion = $ResourceCapabilitiesData[ $ResourceItem.ResourceType ].MoveToRegion
        }
        $reportItem.SubscriptionId = $SubscriptionID
        $reportItem.ResourceId = $ResourceItem.ResourceId

        $report += $reportItem

    }
}

if ($Debug) {
    Write-Output $headers
}

#
# Output Report
##################################################
Write-Output '- Output Report'

if ($report.Count -eq 0) {
    Write-Output 'No resources found'
    exit
}
$headers_array = @()
foreach ($k in $($report | select-object | Get-Member -MemberType Properties)) {
    $headers_array += $k.Name
}
foreach ($k in $headers.GetEnumerator()) {
    $headers_array += $k.Name
}

if ( $env:AZUREPS_HOST_ENVIRONMENT -like 'cloud-shell' )
{
    # Run in Cloud Shell Environment
    $ReportFileName_csv = 'AzureResourcesExport-' + $(Get-Date -format 'yyyy-MM-dd-HHmmss') + '.csv'
    $ReportFile_csv = $( $(Get-CloudDrive).MountPoint + '\' + $ReportFileName_csv )
    $report | Select-Object $headers_array | ConvertTo-Csv -NoTypeInformation | Out-File $ReportFile_csv

    $ReportFileName_json = 'AzureResourcesExport-' + $(Get-Date -format 'yyyy-MM-dd-HHmmss') + '.json'
    $ReportFile_json = $( $(Get-CloudDrive).MountPoint + '\' + $ReportFileName_json )
    $report | Select-Object $headers_array | ConvertTo-Json | Out-File $ReportFile_json

    Write-Output $('- Your report is completed' )
    Write-Output $('   Storage Account: ' + $(Get-CloudDrive).Name )
    Write-Output $('    FileShare Name: ' + $(Get-CloudDrive).FileShareName )
    Write-Output $('         File Name: ' + $ReportFileName_csv )
    Write-Output $('         File Name: ' + $ReportFileName_json )
}
else {
    # Run in Local Environment
    $ReportFileName_csv = 'AzureResourcesExport-' + $(Get-Date -format 'yyyy-MM-dd-HHmmss') + '.csv'
    $ReportFile_csv = $( $(Get-Location).Path + '\' + $ReportFileName_csv );
    $report | Select-Object $headers_array | Export-CSV -NoTypeInformation -Path $ReportFile_csv
    
    $ReportFileName_json = 'AzureResourcesExport-' + $(Get-Date -format 'yyyy-MM-dd-HHmmss') + '.json'
    $ReportFile_json = $( $(Get-Location).Path + '\' + $ReportFileName_json);
    $report | Select-Object $headers_array | ConvertTo-Json | Out-File $ReportFile_json
    
    Write-Output $('- Your report is completed' )
    Write-Output $('         File Name: ' + $ReportFile_csv )
    Write-Output $('         File Name: ' + $ReportFile_json )
}
