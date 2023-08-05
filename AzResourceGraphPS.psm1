Function AzAvailabilitySets-Query-AzARG
{
$Query = @"
    resources
    | where type == 'microsoft.compute/availabilitysets'
"@
Return $Query
}


Function AzBackupRecoveryServicesJobs-Query-AzARG
{
$Query = @"
    recoveryservicesresources
    | where type != 'microsoft.recoveryservices/vaults/backupjobs'
"@
Return $Query
}


Function AzBackupRecoveryServicesProtectionItems-Query-AzARG
{
$Query = @"
    recoveryservicesresources
    | where type == 'microsoft.recoveryservices/vaults/backupfabrics/protectioncontainers/protecteditems'
"@
Return $Query
}


Function AzBackupRecoveryServicesVaults-Query-AzARG
{
$Query = @"
    resources
    | where type == 'microsoft.recoveryservices/vaults'
"@
Return $Query
}


Function AzDefenderForCloudDevicesWithoutTVM-Query-AzARG
{
$Query = @"
    securityresources
    | where type == 'microsoft.security/assessments'
    | where name contains 'ffff0522-1e88-47fc-8382-2a80ba848f5d'
"@
Return $Query
}


Function AzDefenderForCloudPlans-Query-AzARG
{
$Query = @"
    securityresources
    | where type == 'microsoft.security/pricings'
    | project DefenderPlan=name
    | distinct DefenderPlan
    | order by DefenderPlan asc
"@
Return $Query
}


Function AzDefenderForCloudPlansStatus-Query-AzARG
{
#--- BEGIN -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
$Query = @"
    securityresources
    | where type == 'microsoft.security/pricings'
    | extend tier = properties.pricingTier
    | project DefenderPlan=name,subscriptionId,Pricing=properties.pricingTier
    | order by DefenderPlan asc
"@
Return $Query
}


Function AzDefenderForCloudRecommendationsSubAssessmentsWithDetailedInfo-Query-AzARG
{
$Query = @"
    SecurityResources
    | where type == 'microsoft.security/assessments/subassessments'
    | extend AssessmentKey = extract('.*assessments/(.+?)/.*',1,  id)
    | project AssessmentKey, subassessmentKey=name, id, parse_json(properties), resourceGroup, subscriptionId, tenantId
    | extend SubAssessDescription = properties.description,
            SubAssessDisplayName = properties.displayName,
            SubAssessResourceId = properties.resourceDetails.id,
            SubAssessResourceSource = properties.resourceDetails.source,
            SubAssessCategory = properties.category,
            SubAssessSeverity = properties.status.severity,
            SubAssessCode = properties.status.code,
            SubAssessTimeGenerated = properties.timeGenerated,
            SubAssessRemediation = properties.remediation,
            SubAssessImpact = properties.impact,
            SubAssessVulnId = properties.id,
            SubAssessMoreInfo = properties.additionalData,
            SubAssessMoreInfoAssessedResourceType = properties.additionalData.assessedResourceType,
            SubAssessMoreInfoData = properties.additionalData.data
    | join kind=leftouter (resourcecontainers | where type=='microsoft.resources/subscriptions' | project SubName=name, subscriptionId) on subscriptionId "
"@
Return $Query
}


Function AzDefenderForCloudRecommendationsWithLink-Query-AzARG
{
$Query = @"
    SecurityResources
    | where type == 'microsoft.security/assessments'
    | mvexpand Category=properties.metadata.categories
    | extend AssessmentId=id,
        AssessmentKey=name,
        ResourceId=properties.resourceDetails.Id,
        ResourceIdsplit = split(properties.resourceDetails.Id,'/'),
	    RecommendationId=name,
	    RecommendationName=properties.displayName,
	    Source=properties.resourceDetails.Source,
	    RecommendationState=properties.status.code,
	    ActionDescription=properties.metadata.description,
	    AssessmentType=properties.metadata.assessmentType,
	    RemediationDescription=properties.metadata.remediationDescription,
	    PolicyDefinitionId=properties.metadata.policyDefinitionId,
	    ImplementationEffort=properties.metadata.implementationEffort,
	    RecommendationSeverity=properties.metadata.severity,
        Threats=properties.metadata.threats,
	    UserImpact=properties.metadata.userImpact,
	    AzPortalLink=properties.links.azurePortal,
	    MoreInfo=properties
    | extend ResourceSubId = tostring(ResourceIdsplit[(2)]),
        ResourceRgName = tostring(ResourceIdsplit[(4)]),
        ResourceType = tostring(ResourceIdsplit[(6)]),
        ResourceName = tostring(ResourceIdsplit[(8)]),
        FirstEvaluationDate = MoreInfo.status.firstEvaluationDate,
        StatusChangeDate = MoreInfo.status.statusChangeDate,
        Status = MoreInfo.status.code
    | join kind=leftouter (resourcecontainers | where type=='microsoft.resources/subscriptions' | project SubName=name, subscriptionId) on subscriptionId
    | where AssessmentType == 'BuiltIn'
    | project-away kind,managedBy,sku,plan,tags,identity,zones,location,ResourceIdsplit,id,name,type,resourceGroup,subscriptionId, extendedLocation,subscriptionId1
    | project SubName, ResourceSubId, ResourceRgName,ResourceType,ResourceName,TenantId=tenantId, RecommendationName, RecommendationId, RecommendationState, RecommendationSeverity, AssessmentType, PolicyDefinitionId, ImplementationEffort, UserImpact, Category, Threats, Source, ActionDescription, RemediationDescription, MoreInfo, ResourceId, AzPortalLink, AssessmentKey
    | where RecommendationState == 'Unhealthy'
"@
Return $Query

}


Function AzDefenderForCloudRecommendationsWithSubAssessments-Query-AzARG
{
$Query = @"
    SecurityResources
    | where type == 'microsoft.security/assessments'
    | mvexpand Category=properties.metadata.categories
    | extend AssessmentId=id,
        AssessmentKey=name,
        ResourceId=properties.resourceDetails.Id,
        ResourceIdsplit = split(properties.resourceDetails.Id,'/'),
	    RecommendationId=name,
	    RecommendationName=properties.displayName,
	    Source=properties.resourceDetails.Source,
	    RecommendationState=properties.status.code,
	    ActionDescription=properties.metadata.description,
	    AssessmentType=properties.metadata.assessmentType,
	    RemediationDescription=properties.metadata.remediationDescription,
	    PolicyDefinitionId=properties.metadata.policyDefinitionId,
	    ImplementationEffort=properties.metadata.implementationEffort,
	    RecommendationSeverity=properties.metadata.severity,
        Threats=properties.metadata.threats,
	    UserImpact=properties.metadata.userImpact,
	    AzPortalLink=properties.links.azurePortal,
	    MoreInfo=properties
    | extend ResourceSubId = tostring(ResourceIdsplit[(2)]),
        ResourceRgName = tostring(ResourceIdsplit[(4)]),
        ResourceType = tostring(ResourceIdsplit[(6)]),
        ResourceName = tostring(ResourceIdsplit[(8)]),
        FirstEvaluationDate = MoreInfo.status.firstEvaluationDate,
        StatusChangeDate = MoreInfo.status.statusChangeDate,
        Status = MoreInfo.status.code
    | join kind=leftouter (resourcecontainers | where type=='microsoft.resources/subscriptions' | project SubName=name, subscriptionId) on subscriptionId
    | where AssessmentType == 'BuiltIn'
    | project-away kind,managedBy,sku,plan,tags,identity,zones,location,ResourceIdsplit,id,name,type,resourceGroup,subscriptionId, extendedLocation,subscriptionId1
    | project SubName, ResourceSubId, ResourceRgName,ResourceType,ResourceName,TenantId=tenantId, RecommendationName, RecommendationId, RecommendationState, RecommendationSeverity, AssessmentType, PolicyDefinitionId, ImplementationEffort, UserImpact, Category, Threats, Source, ActionDescription, RemediationDescription, MoreInfo, ResourceId, AzPortalLink, AssessmentKey
    | where RecommendationState == 'Unhealthy'
    | join kind=leftouter (
	    securityresources
	    | where type == 'microsoft.security/assessments/subassessments'
	    | extend AssessmentKey = extract('.*assessments/(.+?)/.*',1,  id)
            | project AssessmentKey, subassessmentKey=name, id, parse_json(properties), resourceGroup, subscriptionId, tenantId
            | extend SubAssessmentSescription = properties.description,
                SubAssessmentDisplayName = properties.displayName,
                SubAssessmentResourceId = properties.resourceDetails.id,
                SubAssessmentResourceSource = properties.resourceDetails.source,
                SubAssessmentCategory = properties.category,
                SubAssessmentSeverity = properties.status.severity,
                SubAssessmentCode = properties.status.code,
                SubAssessmentTimeGenerated = properties.timeGenerated,
                SubAssessmentRemediation = properties.remediation,
                SubAssessmentImpact = properties.impact,
                SubAssessmentVulnId = properties.id,
                SubAssessmentMoreInfo = properties.additionalData,
                SubAssessmentMoreInfoAssessedResourceType = properties.additionalData.assessedResourceType,
                SubAssessmentMoreInfoData = properties.additionalData.data
    ) on AssessmentKey
"@
Return $Query
}


Function AzExtensionStatus-Query-AzARG
{
$Query = @"
    Resources
    | where (type == 'microsoft.compute/virtualmachines') or (type == 'microsoft.hybridcompute/machines')
    | extend JoinID = toupper(id)
    | join kind=leftouter(
	    Resources
	     | where (type == 'microsoft.compute/virtualmachines/extensions') or (type == 'microsoft.hybridcompute/machines/extensions')
	     | extend VMId = toupper(substring(id, 0, indexof(id, '/extensions')))
         | extend ExtName = name
         | extend ExtprovisioningState = properties.provisioningState
         | extend ExtType = properties.type
         | extend ExtAutoUpgradeMinorVersion = properties.autoUpgradeMinorVersion
         | extend ExtTypeHandlerVersion = properties.typeHandlerVersion
         | extend ExtPublisher = properties.publisher
         | extend ExtSettings = properties.settings
         | extend ExtStatus = properties.instanceView
         | extend ExtStatusMessage = properties.instanceView.status.message
         ) on $left.JoinID == $right.VMId
"@
Return $Query

}


Function AzHybridMachines-Query-AzARG
{
#--- BEGIN -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
$Query = @"
    resources
    | where type == 'microsoft.hybridcompute/machines'
"@
Return $Query

}


Function AzHybridMachinesWithTags-Query-AzARG
{
$Query = @"
    resources
    | where type == 'microsoft.hybridcompute/machines'
    | project id,name,type,location,resourceGroup,subscriptionId,tags,domain=tostring(properties.domainName)
    | mvexpand tags
    | extend tagKey = tostring(bag_keys(tags)[0])
    | extend tagValue = tostring(tags[tagKey])
"@
Return $Query

}


Function AzIPAddressAzNativeVMs-Query-AzARG
{
$Query = @"
    Resources
    | where type =~ 'microsoft.compute/virtualmachines'
    | project id, vmId = tolower(tostring(id)), vmName = name
    | join (Resources
        | where type =~ 'microsoft.network/networkinterfaces'
        | mv-expand ipconfig=properties.ipConfigurations
        | project vmId = tolower(tostring(properties.virtualMachine.id)), privateIp = ipconfig.properties.privateIPAddress, publicIpId = tostring(ipconfig.properties.publicIPAddress.id)
        | join kind=leftouter (Resources
            | where type =~ 'microsoft.network/publicipaddresses'
            | project publicIpId = id, publicIp = properties.ipAddress
        ) on publicIpId
        | project-away publicIpId, publicIpId1
        | summarize privateIps = make_list(privateIp), publicIps = make_list(publicIp) by vmId
    ) on vmId
    | project-away vmId, vmId1
    | sort by vmName asc
"@
Return $Query
}


Function AzMGs-Query-AzARG
{
$Query = @"
    resourcecontainers
    | where type == 'microsoft.management/managementgroups'
"@
Return $Query
}


Function AzMGsWithParentHierarchy-Query-AzARG
{
$Query = @"
    resourcecontainers
    | where type == 'microsoft.management/managementgroups'
    | extend mgParent = properties.details.managementGroupAncestorsChain
    | mv-expand with_itemindex=MGHierarchy mgParent
    | project id, name, properties.displayName, mgParent, MGHierarchy, mgParent.name
    | sort by MGHierarchy asc
"@
Return $Query
}


Function AzMonitorDCEs-Query-AzARG
{
$Query = @"
    Resources
    | where type =~ 'microsoft.insights/datacollectionendpoints'
"@
Return $Query
}


Function AzMonitorDCRs-Query-AzARG
{
$Query = @"
    Resources
    | where type =~ 'microsoft.insights/datacollectionrules'
"@
Return $Query
}


Function AzNativeVMs-Query-AzARG
{
$Query = @"
    Resources
    | where type == 'microsoft.compute/virtualmachines'
    | extend osType = properties.storageProfile.osDisk.osType
    | extend osVersion = properties.extended.instanceView.osVersion
    | extend osName = properties.extended.instanceView.osName
    | extend vmName = properties.osProfile.computerName
    | extend licenseType = properties.licenseType
    | extend PowerState = properties.extended.instanceView.powerState.displayStatus
    | order by id, resourceGroup desc
"@
Return $Query
}


Function AzNativeVMsHybridMachines-Query-AzARG
{
$Query = @"
    Resources
    | where type in ('microsoft.compute/virtualmachines','microsoft.hybridcompute/machines')
    | extend ostype = properties.osType
    | extend provisioningState = properties.provisioningState
    | extend licensetype = properties.licensetype
    | extend displayname = properties.displayName
    | extend status = properties.status
    | extend computerName = properties.osprofile.computerName
    | extend osVersion = properties.osVersion
    | extend osName = properties.osName
    | extend manufacturer = properties.detectedProperties.manufacturer
    | extend model = properties.detectedProperties.model
    | extend lastStatusChange = properties.lastStatusChange
    | extend agentVersion = properties.agentVersion
    | extend machineFqdn = properties.machineFqdn
    | extend domainName = properties.domainName
    | extend dnsFqdn = properties.dnsFqdn
    | extend adFqdn = properties.adFqdn
    | extend osSku = properties.osSku
"@
Return $Query

}


Function AzNativeVMsWithDefenderForCloudPlanEnabled-Query-AzARG
{
$Query = @"
    securityresources
    | where type == 'microsoft.security/pricings'
    | extend tier = properties.pricingTier
    | where ( (name == 'VirtualMachines') and (properties.pricingTier == 'Standard') )
    | project DefenderPlan=name,subscriptionId,Pricing=properties.pricingTier
    | join kind=leftouter (
            resources
            | where type in ('microsoft.compute/virtualmachines','microsoft.hybridcompute/machines')
            | project name, type, subscriptionId, resourceGroup, location
            ) on subscriptionId
    | project DefenderPlan, Pricing, name, type, subscriptionId, resourceGroup, location
    | where name != ""
"@
Return $Query

}


Function AzNativeVMsWithTags-Query-AzARG
{
$Query = @"
    resources
    | where type == 'microsoft.compute/virtualmachines'
    | project id,name,type,location,resourceGroup,subscriptionId,tags
    | mvexpand tags
    | extend tagKey = tostring(bag_keys(tags)[0])
    | extend tagValue = tostring(tags[tagKey])
"@
Return $Query
}


Function AzResources-Query-AzARG
{
$Query = @"
    resources
"@
Return $Query
}


Function AzResourcesWithTags-Query-AzARG
{
$Query = @"
    resources
    | project id,name,type,location,resourceGroup,subscriptionId,tags
    | mvexpand tags
    | extend tagKey = tostring(bag_keys(tags)[0])
    | extend tagValue = tostring(tags[tagKey])
"@
Return $Query
}


Function AzResourceTypes-Query-AzARG
{
$Query = @"
    resources
    | distinct type
"@
Return $Query

}


Function AzRGs-Query-AzARG
{
$Query = @"
    resourcecontainers
    | where type == 'microsoft.resources/subscriptions/resourcegroups'
"@
Return $Query
}


Function AzRGsWithTags-Query-AzARG
{
$Query = @"
    resourcecontainers
    | project id,name,type,location,resourceGroup,subscriptionId,tags
    | mvexpand tags
    | extend tagKey = tostring(bag_keys(tags)[0])
    | extend tagValue = tostring(tags[tagKey])
"@
Return $Query
}


Function AzRoleAssignments-Query-AzARG
{
$Query = @"
    authorizationResources
    | where type == 'microsoft.authorization/roleassignments'
    | extend roleDefinitionIdFull = tostring(properties.roleDefinitionId)
    | extend roleDefinitionIdsplit = split(roleDefinitionIdFull,'/')
    | extend roleDefinitionId = tostring(roleDefinitionIdsplit[(4)])
    | extend roleAssignmentPrincipalType = properties.principalType
    | extend roleAssignmentDescription = properties.description
    | extend roleAssignmentPrincipalId = properties.principalId
    | extend roleAssignmentCreatedOn = properties.createdOn
    | extend roleAssignmentUpdatedOn = properties.updatedOn
    | extend roleAssignmentUpdatedById = properties.updatedBy
    | extend roleAssignmentCreatedById = properties.createdBy
    | extend roleAssignmentScope = properties.scope
    | project-away managedBy,kind,sku,plan,tags,identity,zones,location,resourceGroup,subscriptionId, extendedLocation,tenantId
    | join kind=leftouter (authorizationResources
            | where type == 'microsoft.authorization/roledefinitions'
            | extend roleDefinitionIdFull = tostring(id)
            | extend roleDefinitionIdsplit = split(roleDefinitionIdFull,'/')
            | extend roleDefinitionId = tostring(roleDefinitionIdsplit[(4)])
            | extend description = properties.description
            | extend roleName = properties.roleName
            | extend roleType = properties.type
            | project-away managedBy,kind,sku,plan,tags,identity,zones,location,resourceGroup,subscriptionId, extendedLocation,tenantId)
      on roleDefinitionId
    | project roleDefinitionId,roleName,roleType,roleAssignmentPrincipalType,roleAssignmentPrincipalId,roleAssignmentCreatedOn,roleAssignmentUpdatedOn,roleAssignmentUpdatedById,roleAssignmentCreatedById,roleAssignmentScope
"@
Return $Query
}


Function AzStorageAccounts-Query-AzARG
{
$Query = @"
    resources
    | where type == 'microsoft.storage/storageaccounts'
"@
Return $Query
}


Function AzSubscriptions-Query-AzARG
{
$Query = @"
    ResourceContainers
    | where type =~ 'microsoft.resources/subscriptions'
    | extend status = properties.state
    | project id, subscriptionId, name, status | order by id, subscriptionId desc
"@
Return $Query
}


Function AzSubscriptionsWithTags-Query-AzARG
{
$Query = @"
    resourcecontainers
    | where type == 'microsoft.resources/subscriptions'
    | project id,name,type,location,subscriptionId,tags
    | mvexpand tags
    | extend tagKey = tostring(bag_keys(tags)[0])
    | extend tagValue = tostring(tags[tagKey])
"@
Return $Query
}


Function Query-AzResourceGraph
{
 <#
    .SYNOPSIS
    Runs query against Azure Resource Graph and returns the result

    .DESCRIPTION
    You can run custom query or pre-defined queries against Azure Resource Graph.
    Query can be targetted on Tenant, MG or Subscription scope.

    .PARAMETER Scope
    This parameter defines the scope where necessary PS modules will be installed 
    (if missing). Possible values are AllUsers (default) or CurrentUser

    .PARAMETER Query
    This parameter is the entire Query, which must be run against Azure Resource Graph

    .PARAMETER QueryScope
    You can choose between MG, Tenant or Subscription (or Sub as alias). 
    If you don't choose Scope, then tenant is default.

    .PARAMETER Target
    Syntax if you chose -QueryScope MG
    You will need to define -Target <mg-name> (Ex: -Target mg-2linkit)
    This MG will be the root for query and all sub-MGs will be included
    
    Syntax if you chose -QueryScope SubScription:
    You will need to define -Target <subscription name or id> (Ex: -Target MySub)

    Syntax if you chose -QueryScope Tenant:
    Search will automatically be done in the entire tenant

    .PARAMETER First
    This parameter will take only the first x records

    .PARAMETER Skip
    This parameter will skip x records and then show the remaining

    .PARAMETER SelectQuery
    This switch will list all available queries in a GUI to select from

    .PARAMETER ShowQueryOnly
    This switch will only show the query - not run the query !

    .PARAMETER InstallAutoUpdateCleanupOldVersions
    This switch will install Az.Accounts, Az.ResourceGraph and AzResourceGraphPS (if missing), 
    auto-update PS modules Az.ResourceGraph and AzResourceGraphPS (if updates available) and
    remove older versions of Az.ResourceGraph and AzResourceGraphPS (if found)
    
    NOTE: Parameter will NOT update or remove Az.Accounts-module
    
    .PARAMETER AzAppId
    This is the Azure app id
        
    .PARAMETER AzAppSecret
    This is the secret of the Azure app

    .PARAMETER TenantId
    This is the Azure AD tenant id

    .INPUTS
    Yes, you can pipe query data into function

    .OUTPUTS
    Results from Azure Resource Graph, based on the defined parameters.

    .LINK
    https://github.com/KnudsenMorten/AzResourceGraphPS

    .EXAMPLE
    # Install if missing + Update all modules to latest version + clean-up old modules if found
        Query-AzResourceGraph -InstallAutoUpdateCleanupOldVersions -Scope AllUsers

    # Run pre-defined query against tenant - and output result to screen
        AzMGsWithParentHierarchy-Query-AzARG | Query-AzResourceGraph -QueryScope Tenant

    # Run pre-defined query against MG "2linkit"- and output result to screen
        AzRGs-Query-AzARG | Query-AzResourceGraph -QueryScope MG -Target "2linkit"

    # Run pre-defined query and return result to $Result-variable
        $Result = AzRGs-Query-AzARG | Query-AzResourceGraph -QueryScope MG -Target "2linkit"
        $Result | fl

    # Run Custom Query and return result to $Result-variable
        $Query = @"
            resourcecontainers 
            | where type == 'microsoft.management/managementgroups' 
            | extend mgParent = properties.details.managementGroupAncestorsChain 
            | mv-expand with_itemindex=MGHierarchy mgParent 
            | project id, name, properties.displayName, mgParent, MGHierarchy, mgParent.name 
            | sort by MGHierarchy asc
"@

        $Result = $Query | Query-AzResourceGraph -QueryScope "Tenant"
        $Result | fl
 
    # Show query only
        AzMGsWithParentHierarchy-Query-AzARG | Query-AzResourceGraph -ShowQueryOnly

    # Select from list of pre-defined queries
        Query-AzResourceGraph -SelectQuery

    # Run query using unattended login with AzApp & AzSecret
        # Variables
            $AzAppId     = "xxxx"
            $AzAppSecret = "xxxx"
            $TenantId    = "xxxx"

        # Disconnect existing sessions
            Disconnect-AzAccount

        AzRGs-Query-AzARG | Query-AzResourceGraph -QueryScope "Tenant" -AzAppId $AzAppId `
                                                                       -AzAppSecret $AzAppSecret `
                                                                       -TenantId $TenantID

    # Get all Azure Resource Groups in specific subscription - show only first 2 RGs
        AzRGs-Query-AzARG | Query-AzResourceGraph -QueryScope Subscription `
                                                  -Target "fce4f282-fcc6-43fb-94d8-bf1701b862c3" `
                                                  -First 2
 
    # Get all management groups under management group '2linkit' - skip first 3
        AzMGsWithParentHierarchy-Query-AzARG | Query-AzResourceGraph -QueryScope "MG" `
                                                                        -Target "2linkit" `
                                                                        -Skip 3

 #>

    [CmdletBinding()]
    param(

            [Parameter(ValueFromPipeline)]
                [string]$Query,
            [Parameter()]
                [ValidateSet("Tenant","MG","Subscription")]
                $QueryScope = "Tenant",
            [Parameter()]
                [string]$Target = $null,    # Only needed for MG or Subscription
            [Parameter()]
                [string]$First,
            [Parameter()]
                [string]$Skip,
            [Parameter()]
                [switch]$SelectQuery = $false,
            [Parameter()]
                [switch]$ShowQueryOnly = $false,
            [Parameter()]
                [string]$AzAppId,
            [Parameter()]
                [string]$AzAppSecret,
            [Parameter()]
                [string]$TenantId,
            [Parameter()]
                [switch]$InstallAutoUpdateCleanupOldVersions = $false,
            [Parameter()]
                [ValidateSet("AllUsers","CurrentUser")]
                $Scope = "AllUsers"
         )

    #---------------------------------------------
    # Header
    #---------------------------------------------
    Write-host ""
    Write-host "----------------------------------------------------------------------"
    Write-Host "AzResourceGraphPS | Morten Knudsen, Microsoft MVP (@knudsenmortendk)" -ForegroundColor Green
    Write-Host ""
    Write-host "Github repository: https://github.com/KnudsenMorten/AzResourceGraphPS"
    Write-host "----------------------------------------------------------------------"
    Write-host ""


    #--------------------------------------------------------------------------
    # Check Prereq for PS Module
    #--------------------------------------------------------------------------

        If ($InstallAutoUpdateCleanupOldVersions -eq $true)
            {

                #####################################################################
                # Az.ResourceGraph
                #####################################################################

                $Module = "Az.ResourceGraph"

                $ModuleCheck = Get-Module -Name $Module -ListAvailable -ErrorAction SilentlyContinue
                    If (!($ModuleCheck))
                        {
                            # check for NuGet package provider
                            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

                            Write-host ""
                            Write-host "Checking Powershell PackageProvider NuGet ... Please Wait !"
                                if (Get-PackageProvider -ListAvailable -Name NuGet -ErrorAction SilentlyContinue -WarningAction SilentlyContinue) 
                                    {
                                        Write-Host "OK - PackageProvider NuGet is installed"
                                    } 
                                else 
                                    {
                                        try
                                            {
                                                Write-Host "Installing NuGet package provider .. Please Wait !"
                                                Install-PackageProvider -Name NuGet -Scope $Scope -Confirm:$false -Force
                                            }
                                        catch [Exception] {
                                            $_.message 
                                            exit
                                        }
                                    }

                            Write-host ""
                            Write-host "Installing latest version of $($Module) from PsGallery in scope $($Scope) .... Please Wait !"

                            Install-module -Name $Module -Repository PSGallery -Force -Scope $Scope
                            import-module -Name $Module -Global -force -DisableNameChecking  -WarningAction SilentlyContinue
                        }
                    Else
                        {
                            #####################################
                            # Check for any available updates                    
                            #####################################

                                # Current version
                                $InstalledVersions = Get-module $Module -ListAvailable

                                $LatestVersion = $InstalledVersions | Sort-Object Version -Descending | Select-Object -First 1

                                $CleanupVersions = $InstalledVersions | Where-Object { $_.Version -ne $LatestVersion.Version }

                                # Online version in PSGallery (online)
                                $Online = Find-Module -Name $Module -Repository PSGallery

                                # Compare versions
                                if ( ([version]$Online.Version) -gt ([version]$LatestVersion.Version) ) 
                                    {
                                        Write-host ""
                                        Write-host "Newer version ($($Online.version)) of $($Module) was detected in PSGallery"
                                        Write-host ""
                                        Write-host "Updating to latest version $($Online.version) of $($Module) from PSGallery ... Please Wait !"
                            
                                        remove-module $Module -Force
                                        Update-module $Module -Force
                                    }
                                Else
                                    {
                                        # No new version detected ... continuing !
                                        Write-host ""
                                        Write-host "OK - Running latest version ($($LatestVersion.version)) of $($Module)"
                                    }

                            #####################################
                            # Clean-up older versions, if found
                            #####################################

                                $InstalledVersions = Get-module $Module -ListAvailable
                                $LatestVersion = $InstalledVersions | Sort-Object Version -Descending | Select-Object -First 1
                                $CleanupVersions = $InstalledVersions | Where-Object { $_.Version -ne $LatestVersion.Version }

                                Write-host ""
                                ForEach ($ModuleRemove in $CleanupVersions)
                                    {
                                        Write-Host "Removing older version $($ModuleRemove.Version) of $($ModuleRemove.Name) ... Please Wait !"

                                        Uninstall-module -Name $ModuleRemove.Name -RequiredVersion $ModuleRemove.Version -Force -ErrorAction SilentlyContinue

                                        # Removing left-overs if uninstall doesn't complete task
                                        $ModulePath = (get-item $ModuleRemove.Path -ErrorAction SilentlyContinue).DirectoryName
                                        if ( ($ModulePath) -and (Test-Path $ModulePath) )
                                            {
                                                $Result = takeown /F $ModulePath /A /R
                                                $Result = icacls $modulePath /reset
                                                $Result = icacls $modulePath /grant Administrators:'F' /inheritance:d /T
                                                $Result = Remove-Item -Path $ModulePath -Recurse -Force -Confirm:$false
                                            }
                                    }
                        } #If (!($ModuleCheck))


                #####################################################################
                # Az.Accounts
                #####################################################################
                $Module = "Az.Accounts"

                $ModuleCheck = Get-Module -Name $Module -ListAvailable -ErrorAction SilentlyContinue
                    If (!($ModuleCheck))
                        {
                            Write-host ""
                            Write-host "Installing latest version of $($Module) from PsGallery in scope $($Scope) .... Please Wait !"

                            Install-module -Name $Module -Repository PSGallery -Force -Scope $Scope
                            import-module -Name $Module -Global -force -DisableNameChecking  -WarningAction SilentlyContinue
                        }

                #####################################################################
                # AzResourceGraphPS
                #####################################################################
                $Module = "AzResourceGraphPS"

                $ModuleCheck = Get-Module -Name $Module -ListAvailable -ErrorAction SilentlyContinue
                    If (!($ModuleCheck))
                        {
                            Write-host ""
                            Write-host "Installing latest version of $($Module) from PsGallery in scope $($Scope) .... Please Wait !"

                            Install-module -Name $Module -Repository PSGallery -Force -Scope $Scope
                            import-module -Name $Module -Global -force -DisableNameChecking  -WarningAction SilentlyContinue
                        }
                    Else
                        {
                            #####################################
                            # Check for any available updates                    
                            #####################################

                                # Current version
                                $InstalledVersions = Get-module $Module -ListAvailable

                                $LatestVersion = $InstalledVersions | Sort-Object Version -Descending | Select-Object -First 1

                                $CleanupVersions = $InstalledVersions | Where-Object { $_.Version -ne $LatestVersion.Version }

                                # Online version in PSGallery (online)
                                $Online = Find-Module -Name $Module -Repository PSGallery

                                # Compare versions
                                if ( ([version]$Online.Version) -gt ([version]$LatestVersion.Version) ) 
                                    {
                                        Write-host ""
                                        Write-host "Newer version ($($Online.version)) of $($Module) was detected in PSGallery"
                                        Write-host ""
                                        Write-host "Updating to latest version $($Online.version) of $($Module) from PSGallery ... Please Wait !"
                            
                                        remove-module $Module -Force
                                        Update-module $Module -Force
                                    }
                                Else
                                    {
                                        # No new version detected ... continuing !
                                        Write-host ""
                                        Write-host "OK - Running latest version ($($LatestVersion.version)) of $($Module)"
                                    }

                            #####################################
                            # Clean-up older versions, if found
                            #####################################

                                $InstalledVersions = Get-module $Module -ListAvailable
                                $LatestVersion = $InstalledVersions | Sort-Object Version -Descending | Select-Object -First 1
                                $CleanupVersions = $InstalledVersions | Where-Object { $_.Version -ne $LatestVersion.Version }

                                Write-host ""
                                ForEach ($ModuleRemove in $CleanupVersions)
                                    {
                                        Write-Host "Removing older version $($ModuleRemove.Version) of $($ModuleRemove.Name) ... Please Wait !"

                                        Uninstall-module -Name $ModuleRemove.Name -RequiredVersion $ModuleRemove.Version -Force -ErrorAction SilentlyContinue

                                        # Removing left-overs if uninstall doesn't complete task
                                        $ModulePath = (get-item $ModuleRemove.Path -ErrorAction SilentlyContinue).DirectoryName
                                        if ( ($ModulePath) -and (Test-Path $ModulePath) )
                                            {
                                                $Result = takeown /F $ModulePath /A /R
                                                $Result = icacls $modulePath /reset
                                                $Result = icacls $modulePath /grant Administrators:'F' /inheritance:d /T
                                                $Result = Remove-Item -Path $ModulePath -Recurse -Force -Confirm:$false
                                            }
                                    }

                        } #If (!($ModuleCheck))

        } #If ($InstallAutoUpdateCleanupOldVersions -eq $true)


    #--------------------------------------------------------------------------
    # Checking Prereq for Query
    #--------------------------------------------------------------------------

        If ( ([string]::IsNullOrWhitespace($Query)) -and ([string]::IsNullOrWhitespace($InstallAutoUpdateCleanupOldVersions)) )
            {
                get-help Query-AzResourceGraph -full
                Break
            }

        If ( ($QueryScope -eq "MG") -and (([string]::IsNullOrWhitespace($Target))) )
            {
                Write-host "When -QueryScope is MG, you need to define target using -Target <MG Name>" -ForegroundColor Red
                Break
            }

        If ( ($QueryScope -eq "Subscription") -and (([string]::IsNullOrWhitespace($Target))) )
            {
                Write-host "When -QueryScope is Subscription, you need to define target using -Target <Subscription Name/Id>"  -ForegroundColor Red
                Break
            }

    #--------------------------------------------------------------------------
    # Connection
    #--------------------------------------------------------------------------

        # Check current AzContext
        $AzContext = Get-AzContext

        If ($AzContext -eq $null)  # empty
            {
                If ($AzAppId)
                    {
                        $AzAppSecretSecure = $AzAppSecret | ConvertTo-SecureString -AsPlainText -Force
                        $SecureCreds = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $AzAppId, $AzAppSecretSecure
                        $Context = Connect-AzAccount -ServicePrincipal -Credential $SecureCreds -Tenant $TenantId -WarningAction SilentlyContinue
                    }
                Else
                    {
                        $Context = Connect-AzAccount -WarningAction SilentlyContinue
                    }
            }

    #--------------------------------------------------------------------------
    # Show Query Only
    #--------------------------------------------------------------------------
        If ($ShowQueryOnly)
            {
                Write-host "Query, which will be run against Azure Resource Graph: "
                Write-host ""
                Write-host "$($Query)" -ForegroundColor Yellow
                Write-host ""
                Write-host "---------------------------------------------------------------------"
                Write-host ""
                Break
            }

    #--------------------------------------------------------------------------
    # Select built-in queries using GUI
    #--------------------------------------------------------------------------
        If ($SelectQuery)
            {
                $SelectedQuery = Get-Command -Name "*-Query-AzARG" -ListImported | select Name | Out-GridView -Title 'Choose a predefined query' -PassThru
                Write-host ""
                Write-host "Selected Query:"
                Write-host "    $($SelectedQuery.Name)" -ForegroundColor Yellow
                Write-host ""

                # Run the function
                $Query = & $SelectedQuery.Name
            }

    #--------------------------------------------------------------------------
    # First
    #--------------------------------------------------------------------------


    #--------------------------------------------------------------------------
    # Running Query and returning result
    #--------------------------------------------------------------------------

        $QueryContextAccount = (Get-AzContext).Account
        $QueryContextTenant  = (Get-AzContext).Tenant

        If (!([string]::IsNullOrWhitespace($Query)))
            {
                Write-host "Query Context Account:"
                Write-host "    $($QueryContextAccount)" -ForegroundColor Yellow
                Write-host ""
                Write-host "Query Context Tenant:"
                Write-host "    $($QueryContextTenant)" -ForegroundColor Yellow
                Write-host ""
                Write-host "Query Scope:"
                Write-host "    $($QueryScope)" -ForegroundColor Yellow
                Write-host ""

                # Target defined
                If ($Target)
                    {
                        Write-host "Target:"
                        Write-host "    $($Target)" -ForegroundColor Yellow
                        Write-host ""
                    }

                # First defined
                If ($First)
                    {
                        Write-host "Scoping - Only First Number of Records:"
                        Write-host "    $($First)" -ForegroundColor Yellow
                        Write-host ""
                    }

                # Skip defined
                If ($Skip)
                    {
                        Write-host "Scoping - Skip Number of Records:"
                        Write-host "    $($Skip)" -ForegroundColor Yellow
                        Write-host ""
                    }

                Write-host "Query, which will be run against Azure Resource Graph: "
                Write-host ""
                Write-host "$($Query)" -ForegroundColor Yellow
                Write-host ""
                Write-host "---------------------------------------------------------------------"
                Write-host ""
                Write-host "Running Query against Azure Resource Group ... Please Wait !"

                $ReturnData   = @()
                $pageSize     = 1000
                $iteration    = 0

                $searchParams = @{
                                    Query = $Query
                             
                                    First = $pageSize
                                 }

                If ($QueryScope -eq "MG") # Management group(s) to run query against
                    {
                        do
                            {
                                $iteration         += 1
                                $pageResults       = Search-AzGraph -ManagementGroup $Target @searchParams
                                $searchParams.Skip += $pageResults.Count
                                $ReturnData        += $pageResults
                            } 
                        while ($pageResults.Count -eq $pageSize)
                    }
                ElseIf ($QueryScope -eq "Subscription") # Subscription(s) to run query against
                    {
                        do 
                            {
                                $iteration         += 1
                                $pageResults       = Search-AzGraph -Subscription $Target @searchParams
                                $searchParams.Skip += $pageResults.Count
                                $ReturnData        += $pageResults
                            } 
                        while ($pageResults.Count -eq $pageSize)
                    }
                ElseIf ($QueryScope -eq "Tenant")  # UseTenantScope = Run query across all available subscriptions in the current tenant
                    {
                        do 
                            {
                                $iteration         += 1
                                $pageResults       = Search-AzGraph -UseTenantScope @searchParams
                                $searchParams.Skip += $pageResults.Count
                                $ReturnData        += $pageResults
                            } 
                        while ($pageResults.Count -eq $pageSize)
                    }

                If ($First)
                    {
                        $First = $First - 1 # subtract first record (0)
                        $ReturnData = $ReturnData[0..$First]
                    }
                If ($Skip)
                    {
                        $ReturnDataCount = $ReturnData.count
                        $ReturnData = $ReturnData[$Skip..$ReturnDataCount]
                    }

            #--------------------------------------------------------------------------
            # Return Result
            #--------------------------------------------------------------------------
                Return $ReturnData
        }
}
