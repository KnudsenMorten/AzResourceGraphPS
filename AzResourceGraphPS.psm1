Function AzAKSNodePoolInfo-Query-AzARG
{
$Query = @"
     Resources
     | where type == "microsoft.containerservice/managedclusters"
     | extend properties.agentPoolProfiles
     | project subscriptionId, name, nodePool = properties.agentPoolProfiles
     | mv-expand nodePool
     | project subscriptionId, name, sku = nodePool.vmSize, count = nodePool.['count'], powerState = nodePool.powerState.code 
"@
Return $Query
}


Function AzAppServiceDetailed-Query-AzARG
{
$Query = @"
    resources
    | where type has 'microsoft.web'
               or type =~ 'microsoft.apimanagement/service'
               or type =~ 'microsoft.network/frontdoors'
               or type =~ 'microsoft.network/applicationgateways'
               or type =~ 'microsoft.appconfiguration/configurationstores'
    | extend type = case(
               type == 'microsoft.web/serverfarms', "App Service Plans",
               kind == 'functionapp', "Azure Functions",
               kind == "api", "API Apps",
               type == 'microsoft.web/sites', "App Services",
               type =~ 'microsoft.network/applicationgateways', 'App Gateways',
               type =~ 'microsoft.network/frontdoors', 'Front Door',
               type =~ 'microsoft.apimanagement/service', 'API Management',
               type =~ 'microsoft.web/certificates', 'App Certificates',
               type =~ 'microsoft.appconfiguration/configurationstores', 'App Config Stores',
               strcat("Not Translated: ", type))
    | where type !has "Not Translated"
    | extend Sku = case(
               type =~ 'App Gateways', properties.sku.name,
               type =~ 'Azure Functions', properties.sku,
               type =~ 'API Management', sku.name,
               type =~ 'App Service Plans', sku.name,
               type =~ 'App Services', properties.sku,
               type =~ 'App Config Stores', sku.name,
               ' ')
    | extend State = case(
               type =~ 'App Config Stores', properties.provisioningState,
               type =~ 'App Service Plans', properties.status,
               type =~ 'Azure Functions', properties.enabled,
               type =~ 'App Services', properties.state,
               type =~ 'API Management', properties.provisioningState,
               type =~ 'App Gateways', properties.provisioningState,
               type =~ 'Front Door', properties.provisioningState,
               ' ')
    | mv-expand publicIpId=properties.frontendIPConfigurations
    | mv-expand publicIpId = publicIpId.properties.publicIPAddress.id
    | extend publicIpId = tostring(publicIpId)
               | join kind=leftouter(
                   Resources
                   | where type =~ 'microsoft.network/publicipaddresses'
                   | project publicIpId = id, publicIpAddress = tostring(properties.ipAddress))
                   on publicIpId
    | extend PublicIP = case(
               type =~ 'API Management', properties.publicIPAddresses,
               type =~ 'App Gateways', publicIpAddress,
               ' ')
    | extend Details = pack_all()
    | project Resource=id, type, subscriptionId, Sku, State, PublicIP, Details
"@
Return $Query
}


Function AzAppServicesHttpsOnly-Query-AzARG
{
$Query = @"
    extend httpsOnly = aliases['Microsoft.Web/sites/httpsOnly'] 
    | where type =~'Microsoft.Web/Sites' and httpsOnly =~ 'false' 
    | project AppService=['name'], Kind=['kind'], Subscription=['subscriptionId']
"@
Return $Query
}


Function AzAppServicesPlanBasicInfo-Query-AzARG
{
$Query = @"
    extend sku = aliases['Microsoft.Web/serverfarms/sku.name'] 
    | extend NumberOfApps = aliases['Microsoft.Web/serverFarms/numberOfSites'] 
    | where type=~'Microsoft.Web/serverfarms' 
    | project Name=['name'], sku, NumberOfApps, Location=['location']
"@
Return $Query
}


Function AzAppServicesPlanCount-Query-AzARG
{
$Query = @"
    extend sku = aliases['Microsoft.Web/serverfarms/sku.name'] 
    | where type=~'Microsoft.Web/serverfarms' 
    | summarize count() by tostring(sku) 
    | project sku, total=count_
"@
Return $Query
}


Function AzAppServicesPlansCountByWebApps-Query-AzARG
{
$Query = @"
    extend NumberOfApps = aliases['Microsoft.Web/serverFarms/numberOfSites'] 
    | where type=~'Microsoft.Web/serverfarms'
    | project Name=['name'], NumberOfApps, Location=['location']
"@
Return $Query
}


Function AzAppServicesStopped-Query-AzARG
{
$Query = @"
    extend state = aliases['Microsoft.Web/sites/state'] 
    | where type=~'Microsoft.Web/Sites' and state =~ 'stopped' 
    | project AppService=['name'], Kind=['kind'], State=['state'], Subscription=['subscriptionId']
"@
Return $Query
}


Function AzAppServiceSummaryCount-Query-AzARG
{
$Query = @"
    resources
    | where type has 'microsoft.web'
               or type =~ 'microsoft.apimanagement/service'
               or type =~ 'microsoft.network/frontdoors'
               or type =~ 'microsoft.network/applicationgateways'
               or type =~ 'microsoft.appconfiguration/configurationstores'
    | extend type = case(
               type == 'microsoft.web/serverfarms', "App Service Plans",
               kind == 'functionapp', "Azure Functions",
               kind == "api", "API Apps",
               type == 'microsoft.web/sites', "App Services",
               type =~ 'microsoft.network/applicationgateways', 'App Gateways',
    type =~ 'microsoft.network/frontdoors', 'Front Door',
               type =~ 'microsoft.apimanagement/service', 'API Management',
               type =~ 'microsoft.web/certificates', 'App Certificates',
               type =~ 'microsoft.appconfiguration/configurationstores', 'App Config Stores',
               strcat("Not Translated: ", type))
    | where type !has "Not Translated"
    | summarize count() by type
"@
Return $Query
}


Function AzAutomationLogicDetailed-Query-AzARG
{
$Query = @"
    resources
    | where type has 'microsoft.automation'
               or type has 'microsoft.logic'
               or type has 'microsoft.web/customapis'
    | extend type = case(
               type =~ 'microsoft.automation/automationaccounts', 'Automation Accounts',
               type =~ 'microsoft.web/connections', 'LogicApp Connectors',
               type =~ 'microsoft.web/customapis','LogicApp API Connectors',
               type =~ 'microsoft.logic/workflows','LogicApps',
               type =~ 'microsoft.automation/automationaccounts/runbooks', 'Automation Runbooks',
               type =~ 'microsoft.automation/automationaccounts/configurations', 'Automation Configurations',
               strcat("Not Translated: ", type))
    | extend RunbookType = tostring(properties.runbookType)
    | extend LogicAppTrigger = properties.definition.triggers
    | extend LogicAppTrigger = iif(type =~ 'LogicApps', case(
               LogicAppTrigger has 'manual', tostring(LogicAppTrigger.manual.type),
               LogicAppTrigger has 'Recurrence', tostring(LogicAppTrigger.Recurrence.type),
               strcat("Unknown Trigger type", LogicAppTrigger)), LogicAppTrigger)
    | extend State = case(
               type =~ 'Automation Runbooks', properties.state,
               type =~ 'LogicApps', properties.state,
               type =~ 'Automation Accounts', properties.state,
               type =~ 'Automation Configurations', properties.state,
               ' ')
    | extend CreatedDate = case(
               type =~ 'Automation Runbooks', properties.creationTime,
               type =~ 'LogicApps', properties.createdTime,
               type =~ 'Automation Accounts', properties.creationTime,
               type =~ 'Automation Configurations', properties.creationTime,
               ' ')
    | extend LastModified = case(
               type =~ 'Automation Runbooks', properties.lastModifiedTime,
               type =~ 'LogicApps', properties.changedTime,
               type =~ 'Automation Accounts', properties.lastModifiedTime,
               type =~ 'Automation Configurations', properties.lastModifiedTime,
               ' ')
    | extend Details = pack_all()
    | project Resource=id, subscriptionId, type, resourceGroup, RunbookType, LogicAppTrigger, State, Details
"@
Return $Query
}


Function AzAutomationLogicSummaryCount-Query-AzARG
{
$Query = @"
    resources
    | where type has 'microsoft.automation'
               or type has 'microsoft.logic'
               or type has 'microsoft.web/customapis'
    | extend type = case(
               type =~ 'microsoft.automation/automationaccounts', 'Automation Accounts',
               type == 'microsoft.web/serverfarms', "App Service Plans",
               kind == 'functionapp', "Azure Functions",
               kind == "api", "API Apps",
               type == 'microsoft.web/sites', "App Services",
               type =~ 'microsoft.web/connections', 'LogicApp Connectors',
               type =~ 'microsoft.web/customapis','LogicApp API Connectors',
               type =~ 'microsoft.logic/workflows','LogicApps',
               type =~ 'microsoft.automation/automationaccounts/runbooks', 'Automation Runbooks',
               type =~ 'microsoft.automation/automationaccounts/configurations', 'Automation Configurations',
               strcat("Not Translated: ", type))
    | summarize count() by type
    | where type !has "Not Translated"
"@
Return $Query
}


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


Function AzDisksIllogicalSizes-Query-AzARG
{
$Query = @"
    where type == 'microsoft.compute/disks'
    | where properties.diskSizeGB > 128 
           or properties.diskSizeGB < 126
    | where properties.diskSizeGB > 256 
           or properties.diskSizeGB < 250
    | where properties.diskSizeGB > 512
          or properties.diskSizeGB < 490
    | where properties.diskSizeGB > 1024 
           or properties.diskSizeGB < 1000  
    | where properties.diskSizeGB > 2048
          or properties.diskSizeGB < 2030
    | where properties.diskSizeGB > 4096
          or properties.diskSizeGB < 4090
    | project Name=name, Size=properties.diskSizeGB, ResourceGroup=resourceGroup, Subscription=subscriptionId
"@
Return $Query
}


Function AzEventResourcesDetailed-Query-AzARG
{
$Query = @"
    resources
    | where type has 'microsoft.servicebus'
               or type has 'microsoft.eventhub'
               or type has 'microsoft.eventgrid'
               or type has 'microsoft.relay'
    | extend type = case(
               type == 'microsoft.eventgrid/systemtopics', "EventGrid System Topics",
               type =~ "microsoft.eventgrid/topics", "EventGrid Topics",
               type =~ 'microsoft.eventhub/namespaces', "EventHub Namespaces",
               type =~ 'microsoft.servicebus/namespaces', 'ServiceBus Namespaces',
               type =~ 'microsoft.relay/namespaces', 'Relays',
               strcat("Not Translated: ", type))
    | extend Sku = case(
               type =~ 'Relays', sku.name,
               type =~ 'EventGrid System Topics', properties.sku,
               type =~ 'EventGrid Topics', sku.name,
               type =~ 'EventHub Namespaces', sku.name,
               type =~ 'ServiceBus Namespaces', sku.sku,
               ' ')
    | extend Endpoint = case(
               type =~ 'Relays', properties.serviceBusEndpoint,
               type =~ 'EventGrid Topics', properties.endpoint,
               type =~ 'EventHub Namespaces', properties.serviceBusEndpoint,
               type =~ 'ServiceBus Namespaces', properties.serviceBusEndpoint,
               ' ')
    | extend Status = case(
               type =~ 'Relays', properties.provisioningState,
               type =~ 'EventGrid System Topics', properties.provisioningState,
               type =~ 'EventGrid Topics', properties.publicNetworkAccess,
               type =~ 'EventHub Namespaces', properties.status,
               type =~ 'ServiceBus Namespaces', properties.status,
               ' ')
    | extend Details = pack_all()
    | project Resource=id, subscriptionId, resourceGroup, Sku, Status, Endpoint, Details
"@
Return $Query
}


Function AzEventResourcesSummaryCount-Query-AzARG
{
$Query = @"
    resources
    | where type has 'microsoft.servicebus'
               or type has 'microsoft.eventhub'
               or type has 'microsoft.eventgrid'
               or type has 'microsoft.relay'
    | extend type = case(
               type == 'microsoft.eventgrid/systemtopics', "EventGrid System Topics",
               type =~ "microsoft.eventgrid/topics", "EventGrid Topics",
               type =~ 'microsoft.eventhub/namespaces', "EventHub Namespaces",
               type =~ 'microsoft.servicebus/namespaces', 'ServiceBus Namespaces',
               type =~ 'microsoft.relay/namespaces', 'Relays',
               strcat("Not Translated: ", type))
    | where type !has "Not Translated"
    | summarize count() by type
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


Function AzFrontdoorRoutingRulesAcceptedPorts-Query-AzARG
{
$Query = @"
    resources
    | where type == "microsoft.network/frontdoors"
    | project subscriptionId, frontDoorName=name, routingRules = (properties.routingRules)
    | mv-expand routingRules
    | project subscriptionId, frontDoorName, routingRuleName=routingRules.name, protocols = routingRules.properties.acceptedProtocols
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


Function AzMonResources-Query-AzARG
{
$Query = @"
    AlertsManagementResources
    | extend AlertStatus = properties.essentials.monitorCondition
    | extend AlertState = properties.essentials.alertState
    | extend AlertTime = properties.essentials.startDateTime
    | extend AlertSuppressed = properties.essentials.actionStatus.isSuppressed
    | extend Severity = properties.essentials.severity
    | where AlertStatus == 'Fired'
    | extend Details = pack_all()
    | project id, name, subscriptionId, resourceGroup, AlertStatus, AlertState, AlertTime, AlertSuppressed, Severity, Details
"@
Return $Query
}


Function AzMonAppInsightsDetailed-Query-AzARG
{
$Query = @"
    resources
    | where type =~ 'microsoft.insights/components'
    | extend RetentionInDays = properties.RetentionInDays
    | extend IngestionMode = properties.IngestionMode
    | extend Details = pack_all()
    | project Resource=id, location, resourceGroup, subscriptionId, IngestionMode, RetentionInDays, Details
"@
Return $Query
}


Function AzMonDataCollectionEndpoints-Query-AzARG
{
$Query = @"
    Resources
    | where type =~ 'microsoft.insights/datacollectionendpoints'
"@
Return $Query
}


Function AzMonDataCollectionRules-Query-AzARG
{
$Query = @"
    Resources
    | where type =~ 'microsoft.insights/datacollectionrules'
"@
Return $Query
}


Function AzMonLogAnalyticsDetailed-Query-AzARG
{
$Query = @"
    resources | where type =~ 'microsoft.operationalinsights/workspaces'
    | extend Sku = properties.sku.name
    | extend RetentionInDays = properties.retentionInDays
    | extend Details = pack_all()
    | project Workspace=id, resourceGroup, location, subscriptionId, Sku, RetentionInDays, Details
"@
Return $Query
}


Function AzMonLogAnalyticsWorkspaces-Query-AzARG
{
$Query = @"
    resources
    | where type =~ 'microsoft.operationalinsights/workspaces' or type =~ 'microsoft.insights/components'
    | summarize count() by type
    | extend type = case(
                  type == 'microsoft.insights/components', "Application Insights",
                  type == 'microsoft.operationalinsights/workspaces', "Log Analytics workspaces",
                  strcat(type, type))
"@
Return $Query
}


Function AzMonResources-Query-AzARG
{
$Query = @"
    resources
    | where type has 'microsoft.insights/'
            or type has 'microsoft.alertsmanagement/ smartdetectoralertrules'
            or type has 'microsoft.portal/dashboards'
    | where type != 'microsoft.insights/components'
    | extend type = case(
                  type == 'microsoft.insights/workbooks', "Workbooks",
                  type == 'microsoft.insights/activitylogalerts', "Activity Log Alerts",
                  type == 'microsoft.insights/scheduledqueryrules', "Log Search Alerts",
                  type == 'microsoft.insights/actiongroups', "Action Groups",
                  type == 'microsoft.insights/metricalerts', "Metric Alerts",
                  type =~ 'microsoft.alertsmanagement/smartdetectoralertrules','Smart Detection Rules',
                  type =~ 'microsoft.insights/webtests', 'URL Web Tests',
                  type =~ 'microsoft.portal/dashboards', 'Portal Dashboards',
                  type =~ 'microsoft.insights/datacollectionrules', 'Data Collection Rules',
    strcat("Not Translated: ", type))
    | summarize count() by type
"@
Return $Query
}


Function AzMonResourcesDetailed-Query-AzARG
{
$Query = @"
    resources
    | where type has 'microsoft.insights/'
    or type has 'microsoft.alertsmanagement/smartdetectoralertrules'
    or type has 'microsoft.portal/dashboards'
    | where type != 'microsoft.insights/components' | extend type = case(
    type == 'microsoft.insights/workbooks', "Workbooks",
    type == 'microsoft.insights/activitylogalerts', "Activity Log Alerts",
    type == 'microsoft.insights/scheduledqueryrules', "Log Search Alerts",
    type == 'microsoft.insights/actiongroups', "Action Groups",
    type == 'microsoft.insights/metricalerts', "Metric Alerts",
    type =~ 'microsoft.alertsmanagement/smartdetectoralertrules','Smart Detection Rules',
    type =~ 'microsoft.portal/dashboards', 'Portal Dashboards',
    strcat("Not Translated: ", type))
    | extend Enabled = case(
    type =~ 'Smart Detection Rules', properties.state,
    type != 'Smart Detection Rules', properties.enabled,
    strcat("Not Translated: ", type))
    | extend WorkbookType = iif(type =~ 'Workbooks', properties.category, ' ')
    | extend Details = pack_all()
    | project name, type, subscriptionId, location, resourceGroup, Enabled, WorkbookType, Details
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


Function AzNativeVMsCountByImageOffer-Query-AzARG
{
$Query = @"
    extend OsOffer = aliases['Microsoft.Compute/virtualMachines/storageProfile.imageReference.offer'] 
    | where type =~ 'Microsoft.Compute/virtualmachines' 
    | summarize count() by tostring(OsOffer) 
    | project OsOffer, total=count_
"@
Return $Query
}


Function AzNativeVMsCountByOS-Query-AzARG
{
$Query = @"
    extend Os = aliases['Microsoft.Compute/virtualMachines/storageProfile.osDisk.osType'] 
    | where type =~ 'Microsoft.Compute/virtualmachines' 
    | summarize count() by tostring(Os) 
    | project Os, total=count_
"@
Return $Query
}


Function AzDisksIllogicalSizes-Query-AzARG
{
$Query = @"
    where type == 'microsoft.compute/disks'
    | where properties.diskSizeGB > 128 
           or properties.diskSizeGB < 126
    | where properties.diskSizeGB > 256 
           or properties.diskSizeGB < 250
    | where properties.diskSizeGB > 512
          or properties.diskSizeGB < 490
    | where properties.diskSizeGB > 1024 
           or properties.diskSizeGB < 1000  
    | where properties.diskSizeGB > 2048
          or properties.diskSizeGB < 2030
    | where properties.diskSizeGB > 4096
          or properties.diskSizeGB < 4090
    | project Name=name, Size=properties.diskSizeGB, ResourceGroup=resourceGroup, Subscription=subscriptionId
"@
Return $Query
}


Function AzNativeVMsCountBySizeLocation-Query-AzARG
{
$Query = @"
    Resources
    | where type == "microsoft.compute/virtualmachines"
    | summarize Count=count(properties.hardwareProfile.vmSize) by OS=tostring(properties.storageProfile.osDisk.osType), location, vmSize=tostring(properties.hardwareProfile.vmSize)
"@
Return $Query
}


Function AzNativeVMsDiskSizeSkuByLocation-Query-AzARG
{
$Query = @"
    Resources
    | where type contains "microsoft.compute/disks"
    | summarize DiskSizeGB=sum(toint(properties.diskSizeGB)) by DiskSku=tostring(sku.name), location
"@
Return $Query
}


Function AzNativeVMsDiskSizeTotal-Query-AzARG
{
$Query = @"
    Resources
    | where type contains "microsoft.compute/disks"
    | summarize DiskSizeGB=sum(toint(properties.diskSizeGB))
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


Function AzNativeVMsSizeCount-Query-AzARG
{
$Query = @"
    Resources
    | where type == "microsoft.compute/virtualmachines"
    | summarize Count=count(properties.hardwareProfile.vmSize) by vmSize=tostring(properties.hardwareProfile.vmSize)
"@
Return $Query
}


Function AzNativeVMsStatusCount-Query-AzARG
{
$Query = @"
    Resources | where type == "microsoft.compute/virtualmachines" | extend vmState = tostring(properties.extended.instanceView.powerState.displayStatus) | extend vmState = iif(isempty(vmState), "VM State Unknown", (vmState)) | summarize count() by vmState
"@
Return $Query
}


Function AzNativeVMsStorageAdvProfile-Query-AzARG
{
$Query = @"
    Resources
    | where type == "microsoft.compute/virtualmachines"
    | extend osDiskId= tostring(properties.storageProfile.osDisk.managedDisk.id)
                    | join kind=leftouter(
                        resources
                         | where type =~ 'microsoft.compute/disks'
                         | where properties !has 'Unattached'
                         | where properties has 'osType'
                         | project OS = tostring(properties.osType), osSku = tostring(sku.name), osDiskSizeGB = toint(properties.diskSizeGB), osDiskId=tostring(id))
                        on osDiskId
                    | join kind=leftouter(
                        resources                      | where type =~ 'microsoft.compute/disks'
                         | where properties !has "osType"
                         | where properties !has 'Unattached'
                         | project sku = tostring(sku.name), diskSizeGB = toint(properties.diskSizeGB), id = managedBy
                         | summarize sum(diskSizeGB), count(sku) by id, sku)
                        on id
    | project vmId=id, OS, location, resourceGroup, subscriptionId, osDiskId, osSku, osDiskSizeGB, DataDisksGB=sum_diskSizeGB, diskSkuCount=count_sku
    | sort by diskSkuCount desc
"@
Return $Query
}


Function AzNativeVMsStorageProfile-Query-AzARG
{
$Query = @"
    Resources
    | where type contains "microsoft.compute/disks"
    | project Os=properties.osType,
    DiskSku=sku.name,
    DiskSizeGB=properties.diskSizeGB,
    id = managedBy
    | join (Resources | where type == "microsoft.compute/virtualmachines") on id
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


Function AzNativeVMsWithNICsPublicIP-Query-AzARG
{
$Query = @"
    Resources
    | where type =~ 'microsoft.compute/virtualmachines'
    | extend nics=array_length(properties.networkProfile.networkInterfaces)
    | mv-expand nic=properties.networkProfile.networkInterfaces
    | where nics == 1 or nic.properties.primary =~ 'true' or isempty(nic)
    | project vmId = id, vmName = name, vmSize=tostring(properties.hardwareProfile.vmSize), nicId = tostring(nic.id)
                    | join kind=leftouter (
                        Resources
                         | where type =~ 'microsoft.network/networkinterfaces'
                         | extend ipConfigsCount=array_length(properties.ipConfigurations)
                         | mv-expand ipconfig=properties.ipConfigurations
                         | where ipConfigsCount == 1 or ipconfig.properties.primary =~ 'true'
                         | project nicId = id, privateIP= tostring(ipconfig.properties.privateIPAddress), publicIpId = tostring(ipconfig.properties.publicIPAddress.id), subscriptionId)
                         on nicId
    | project-away nicId1
    | summarize by vmId, vmSize, nicId, privateIP, publicIpId, subscriptionId
                    | join kind=leftouter (
                        Resources
                         | where type =~ 'microsoft.network/publicipaddresses'
                         | project publicIpId = id, publicIpAddress = tostring(properties.ipAddress)) on publicIpId
    | project-away publicIpId1
    | sort by publicIpAddress desc
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


Function AzNetworkNSGRules-Query-AzARG
{
$Query = @"
    Resources
    | where type =~ 'microsoft.network/networksecuritygroups'
    | project id, nsgRules = parse_json(parse_json(properties).securityRules), networksecurityGroupName = name, subscriptionId, resourceGroup , location
    | mvexpand nsgRule = nsgRules
    | project id, location, access=nsgRule.properties.access,protocol=nsgRule.properties.protocol ,direction=nsgRule.properties.direction,provisioningState= nsgRule.properties.provisioningState ,priority=nsgRule.properties.priority,
                    sourceAddressPrefix = nsgRule.properties.sourceAddressPrefix,
                    sourceAddressPrefixes = nsgRule.properties.sourceAddressPrefixes,
                    destinationAddressPrefix = nsgRule.properties.destinationAddressPrefix,
                    destinationAddressPrefixes = nsgRule.properties.destinationAddressPrefixes,
                    networksecurityGroupName, networksecurityRuleName = tostring(nsgRule.name),
                    subscriptionId, resourceGroup,
                    destinationPortRanges = nsgRule.properties.destinationPortRanges,
                    destinationPortRange = nsgRule.properties.destinationPortRange,
                    sourcePortRanges = nsgRule.properties.sourcePortRanges,
                    sourcePortRange = nsgRule.properties.sourcePortRange
    | extend Details = pack_all()
    | project id, location, access, direction, subscriptionId, resourceGroup, Details
"@
Return $Query
}


Function AzNetworkNSGsUnassociated-Query-AzARG
{
$Query = @"
    Resources
    | where type =~ 'microsoft.network/networksecuritygroups' and isnull(properties.networkInterfaces) and isnull(properties.subnets)
    | project Resource=id, resourceGroup, subscriptionId, location
"@
Return $Query
}


Function AzNetworkPublicIPs-Query-AzARG
{
$Query = @"
    Resources
    | where type == "microsoft.network/publicipaddresses"
    | summarize PIPs=count() by IPType=tostring(properties.publicIPAddressVersion)
"@
Return $Query
}


Function AzNetworkResources-Query-AzARG
{
$Query = @"
    resources
    | where type has "microsoft.network"
    | extend type = case(
                  type == 'microsoft.network/networkinterfaces', "NICs",
                  type == 'microsoft.network/networksecuritygroups', "NSGs",
                  type == "microsoft.network/publicipaddresses", "Public IPs",
                  type == 'microsoft.network/virtualnetworks', "vNets",
                  type == 'microsoft.network/networkwatchers/connectionmonitors', "Connection Monitors",
                  type == 'microsoft.network/privatednszones', "Private DNS",
                  type == 'microsoft.network/virtualnetworkgateways', @"vNet Gateways",
                  type == 'microsoft.network/connections', "Connections",
                  type == 'microsoft.network/networkwatchers', "Network Watchers",
                  type == 'microsoft.network/privateendpoints', "Private Endpoints",
                  type == 'microsoft.network/localnetworkgateways', "Local Network Gateways",
                  type == 'microsoft.network/privatednszones/virtualnetworklinks', "vNet Links",
                  type == 'microsoft.network/dnszones', 'DNS Zones',
                  type == 'microsoft.network/networkwatchers/flowlogs', 'Flow Logs',
                  type == 'microsoft.network/routetables', 'Route Tables',
                  type == 'microsoft.network/loadbalancers', 'Load Balancers',
                  strcat("Not Translated: ", type))
    | summarize count() by type
    | where type !has "Not Translated"
"@
Return $Query
}


Function AzNetworkRouteTables-Query-AzARG
{
$Query = @"
    resources
    | where type =~ 'microsoft.network/routetables'
    | project id, routes = parse_json(parse_json(properties).routes), routeTableName = name, subscriptionId, resourceGroup, location
    | mvexpand route = routes
    | project id,
        location,
        addressPrefix=route.properties.addressPrefix,
        nextHopType=route.properties.nextHopType,
        nextHopIpAddress=route.properties.nextHopIpAddress,
        hasBgpOverride=route.properties.hasBgpOverride,
        routeTableName,
        routeName = tostring(route.name),
        subscriptionId,
        resourceGroup
    | extend Details = pack_all()
    | project id, routeTableName, location, addressPrefix, nextHopType, nextHopIpAddress, subscriptionId, resourceGroup, Details
"@
Return $Query
}


Function AzNetworkSubnets-Query-AzARG
{
$Query = @"
    resources
    | where type == "microsoft.network/virtualnetworks"
    | project vnetName = name, subnets = (properties.subnets)
    | mvexpand subnets
    | extend subnetName = (subnets.name)
    | project vnetName, subnetName
"@
Return $Query
}


Function AzNetworkSubnetsAddressSpace-Query-AzARG
{
$Query = @"
    resources
    | where type == "microsoft.network/virtualnetworks"
    | project vnetName = name, subnets = (properties.subnets)
    | mvexpand subnets
    | extend subnetName = (subnets.name)
    | extend mask = split(subnets.properties.addressPrefix, '/', 1)[0]
    | extend usedIp = array_length(subnets.properties.ipConfigurations)
    | extend totalIp = case(mask == 29, 3,
						    mask == 28, 11,
						    mask == 27, 27,
						    mask == 26, 59,
						    mask == 25, 123,
						    mask == 24, 251,
						    mask == 23, 507,
						    mask == 22, 1019,
						    mask == 21, 2043,
						    mask == 20, 4091,
						    mask == 19, 8187,
						    mask == 18, 16379,
						    mask == 17, 32763,
						    mask == 16, 65531,
						    mask == 15, 131067,
						    mask == 14, 262139,
						    mask == 13, 524283,
						    mask == 12, 1048571,
						    mask == 11, 2097147,
						    mask == 10, 4194299,
						    mask == 9, 8388603,
						    mask == 8, 16777211,
						    -1)
    | extend availableIp = totalIp - usedIp
    | project vnetName, subnetName, mask, usedIp, totalIp, availableIp, subnets
    | order by toint(mask) desc
"@
Return $Query
}


Function AzNetworkSubnetsWithDelegations-Query-AzARG
{
$Query = @"
    resources
    | where type == "microsoft.network/virtualnetworks"
    | project vnetName = name, subnets = (properties.subnets)
    | mvexpand subnets
    | extend subnetName = (subnets.name)
    | extend isDelegated = isnotnull(subnets.properties.delegations) and array_length(subnets.properties.delegations) != 0
    | where isDelegated == 1
    | project vnetName, subnetName
"@
Return $Query
}


Function AzNetworkSubnetsWithNSG-Query-AzARG
{
$Query = @"
    resources
    | where type == "microsoft.network/virtualnetworks"
    | project vnetName = name, subnets = (properties.subnets)
    | mvexpand subnets
    | extend subnetName = (subnets.name)
    | extend hasNSG = isnotnull(subnets.properties.networkSecurityGroup)
    | where hasNSG == 1
    | project vnetName, subnetName
"@
Return $Query
}


Function AzNetworkSubnetsWithRouteTable-Query-AzARG
{
$Query = @"
    resources
    | where type == "microsoft.network/virtualnetworks"
    | project vnetName = name, subnets = (properties.subnets)
    | mvexpand subnets
    | extend subnetName = (subnets.name)
    | extend hasRouteTable = isnotnull(subnets.properties.routeTable)
    | where hasRouteTable == 1
    | project vnetName, subnetName
"@
Return $Query
}


Function AzNetworkSubnetsWithServiceEndpoints-Query-AzARG
{
$Query = @"
    resources
    | where type == "microsoft.network/virtualnetworks"
    | project vnetName = name, subnets = (properties.subnets)
    | mvexpand subnets
    | extend subnetName = (subnets.name)
    | extend hasServiceEndpoints = isnotnull(subnets.properties.serviceEndpoints) and array_length(subnets.properties.serviceEndpoints) != 0
    | where hasServiceEndpoints == 1
    | project vnetName, subnetName
"@
Return $Query
}


Function AzOrphanedAvailabilitySets-Query-AzARG
{
$Query = @"
    resources
    | where type =~ 'microsoft.compute/availabilitysets'
    | extend VirtualMachines = array_length(properties.virtualMachines)
    | where VirtualMachines == 0
"@
Return $Query
}


Function AzOrphanedDisks-Query-AzARG
{
$Query = @"
    Resources
    | where type has "microsoft.compute/disks"
    | extend diskState = tostring(properties.diskState)
    | where managedBy == "" and diskState != 'ActiveSAS'
    or diskState == 'Unattached' and diskState != 'ActiveSAS'
    | project id, diskState, resourceGroup, location, subscriptionId
"@
Return $Query
}


Function AzOrphanedNICs-Query-AzARG
{
$Query = @"
    resources
    | where type =~ "microsoft.network/networkinterfaces"
    | join kind=leftouter (resources
    | where type =~ 'microsoft.network/privateendpoints'
    | extend nic = todynamic(properties.networkInterfaces)
    | mv-expand nic
    | project id=tostring(nic.id) ) on id
    | where isempty(id1)
    | where properties !has 'virtualmachine'
    | project id, resourceGroup, location, subscriptionId
"@
Return $Query
}


Function AzOrphanedNSGs-Query-AzARG
{
$Query = @"
    Resources
    | where type =~ 'microsoft.network/networksecuritygroups' and isnull(properties.networkInterfaces) and isnull(properties.subnets)
    | project Resource=id, resourceGroup, subscriptionId, location
"@
Return $Query
}


Function AzOrphanedPublicIPs-Query-AzARG
{
$Query = @"
    resources | where type =~ 'microsoft.network/publicipaddresses' | extend IpConfig = properties.ipConfiguration.id | where isempty(IpConfig) | extend natGateway = properties.natGateway.id | where isempty(natGateway) | order by ['name'] asc
"@
Return $Query
}


Function AzOrphanedWebAPIConnections-Query-AzARG
{
$Query = @"
    resources
    | where type =~ 'Microsoft.Web/connections'
    |project id
    |join kind= leftouter
        (
        resources
        | where type == 'microsoft.logic/workflows'
        |extend propertiesJson=parse_json(properties)
        |extend ConJson=propertiesJson["parameters"]["$connections"]["value"]
        |mvexpand Conn=ConJson
        |where notnull(Conn)
        |extend connectionId=extract(""connectionId":"(.*)"",1,tostring(Conn))
        |project connectionId
        ) on $left.id==$right.connectionId
"@
Return $Query
}


Function AzPolicyAssignmentCountByScope-Query-AzARG
{
$Query = @"
    policyresources
    | where type == "microsoft.authorization/policyassignments"
    | extend scope = tostring(properties.scope)
    | summarize count() by scope
    | order by count_ desc 
"@
Return $Query
}


Function AzPolicyDefinitionsCountByScope-Query-AzARG
{
$Query = @"
    policyresources
    | where type == "microsoft.authorization/policydefinitions"
    | extend policyType = tostring(properties.policyType)
    | where policyType == "Custom"
    | project id
    | extend scope = tostring(split(id, "/providers/Microsoft.Authorization/policyDefinitions/", 0)[0])
    | summarize count() by scope
    | order by count_ desc 
"@
Return $Query
}


Function AzPolicyUnused-Query-AzARG
{
$Query = @"
    policyresources
    | where type == "microsoft.authorization/policydefinitions"
    | extend policyType = tostring(properties.policyType)
    | where policyType == "Custom"
    | join kind=leftouter (
        policyresources
        | where type == "microsoft.authorization/policysetdefinitions"
        | extend policyType = tostring(properties.policyType)
        | extend  policyDefinitions = properties.policyDefinitions
        | where policyType == "Custom"
        | mv-expand policyDefinitions
        | extend policyDefinitionId = tostring(policyDefinitions.policyDefinitionId)
        | project associedIdToInitiative=policyDefinitionId 
        | distinct associedIdToInitiative) on $left.id == $right.associedIdToInitiative
    | where associedIdToInitiative == ""
    | join kind=leftouter(
        policyresources
        | where type == "microsoft.authorization/policyassignments"
        | extend policyDefinitionId = tostring(properties.policyDefinitionId)
        | project associatedDefinitionId=policyDefinitionId 
        | distinct associatedDefinitionId
    ) on $left.id == $right.associatedDefinitionId
    | where associatedDefinitionId == ""
    | extend displayName = tostring(properties.displayName)
    | project id, displayName
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


Function AzSecureScoreByControls-Query-AzARG
{
$Query = @"
    SecurityResources
    | where type == 'microsoft.security/securescores/securescorecontrols'
    | extend SecureControl = properties.displayName, unhealthy = properties.unhealthyResourceCount, currentscore = properties.score.current, maxscore = properties.score.max, subscriptionId
    | project SecureControl , unhealthy, currentscore, maxscore, subscriptionId
"@
Return $Query
}


Function AzSecureScoreSubscription-Query-AzARG
{
$Query = @"
    securityresources
    | where type == "microsoft.security/securescores"
    | extend subscriptionSecureScore = round(100 * bin((todouble(properties.score.current))/ todouble(properties.score.max), 0.001))
    | where subscriptionSecureScore > 0
    | project subscriptionSecureScore, subscriptionId
    | order by subscriptionSecureScore asc
"@
Return $Query
}


Function AzSQLDatabasesByLocation-Query-AzARG
{
$Query = @"
    where type=~ 'Microsoft.DBforMySQL/servers' 
    or type=~'Microsoft.SQL/servers/databases' 
    or type=~'Microsoft.DBforPostgreSQL/servers' 
    or type=~'Microsoft.DBforMariaDB/servers'
    | summarize count() by location 
    | project location, total=count_ 
    | order by total desc
"@
Return $Query
}


Function AzSQLDatabasesOverview-Query-AzARG
{
$Query = @"
    where type=~ 'Microsoft.DBforMySQL/servers' 
    or type=~'Microsoft.SQL/servers/databases' 
    or type=~'Microsoft.DBforPostgreSQL/servers' 
    or type=~'Microsoft.DBforMariaDB/servers'
    | project name, type, location, subscriptionId
"@
Return $Query
}


Function AzSQLDetailed-Query-AzARG
{
$Query = @"
    resources
    | where type =~ 'microsoft.documentdb/databaseaccounts'
             or type =~ 'microsoft.sql/servers/databases'
             or type =~ 'microsoft.dbformysql/servers'
             or type =~ 'microsoft.sql/servers'
    | extend type = case(
                 type =~ 'microsoft.documentdb/databaseaccounts', 'CosmosDB',
                 type =~ 'microsoft.sql/servers/databases', 'SQL DBs',
                 type =~ 'microsoft.dbformysql/servers', 'MySQL',
                 type =~ 'microsoft.sql/servers', 'SQL Servers',
                 strcat("Not Translated: ", type))
    | extend Sku = case(
                 type =~ 'CosmosDB', properties.databaseAccountOfferType,
                 type =~ 'SQL DBs', sku.name,
                 type =~ 'MySQL', sku.name,
                 ' ')
    | extend Status = case(
                 type =~ 'CosmosDB', properties.provisioningState,
                 type =~ 'SQL DBs', properties.status,
                 type =~ 'MySQL', properties.userVisibleState,
                 ' ')
    | extend Endpoint = case(
                 type =~ 'MySQL', properties.fullyQualifiedDomainName,
                 type =~ 'SQL Servers', properties.fullyQualifiedDomainName,
                 type =~ 'CosmosDB', properties.documentEndpoint,
                 ' ')
    | extend maxSizeGB = todouble(case(
                 type =~ 'SQL DBs', properties.maxSizeBytes,
                 type =~ 'MySQL', properties.storageProfile.storageMB,
                 ' '))
    | extend maxSizeGB = iif(type has 'SQL DBs', maxSizeGB /1000 /1000, maxSizeGB)
    | extend Details = pack_all()
    | project Resource=id, resourceGroup, subscriptionId, type, Sku, Status, Endpoint, maxSizeGB, Details
"@
Return $Query
}


Function AzSQLPaaSCountByType-Query-AzARG
{
$Query = @"
    where type=~ 'Microsoft.DBforMySQL/servers' 
    or type=~'Microsoft.SQL/servers/databases' 
    or type=~'Microsoft.DBforPostgreSQL/servers' 
    or type=~'Microsoft.DBforMariaDB/servers' 
    | summarize count() by type 
    | project type, total=count_ 
    | order by total desc
"@
Return $Query
}


Function AzSQLSummaryCount-Query-AzARG
{
$Query = @"
    resources
    | where type =~ 'microsoft.documentdb/databaseaccounts'
            or type =~ 'microsoft.sql/servers/databases'
            or type =~ 'microsoft.dbformysql/servers'
            or type =~ 'microsoft.sql/servers'
    | extend type = case(
                  type =~ 'microsoft.documentdb/databaseaccounts', 'CosmosDB',
                  type =~ 'microsoft.sql/servers/databases', 'SQL DBs',
                  type =~ 'microsoft.dbformysql/servers', 'MySQL',
                  type =~ 'microsoft.sql/servers', 'SQL Servers',
                  strcat("Not Translated: ", type))
    | where type !has "Not Translated"
    | summarize count() by type
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


Function AzStorageAccountsByLocation-Query-AzARG
{
$Query = @"
    where type =~ 'microsoft.storage/storageaccounts' 
    | summarize count() by location| project Location=['location'], Total=count_
"@
Return $Query
}


Function AzStorageAccountsHttpsOnlyCountBySubscription-Query-AzARG
{
$Query = @"
    extend HTTPSOnly = aliases['Microsoft.Storage/storageAccounts/supportsHttpsTrafficOnly'] 
    | where type =~ 'microsoft.storage/storageaccounts' and HTTPSOnly =~ 'false' 
    | summarize count() by subscriptionId 
    | project subscriptionId, Total=count_
"@
Return $Query
}


Function AzStorageAccountsOverview-Query-AzARG
{
$Query = @"
    extend HTTPSOnly = aliases['Microsoft.Storage/storageAccounts/supportsHttpsTrafficOnly'] 
    | extend 
    Type = aliases['Microsoft.Storage/storageAccounts/accountType'], 
    BlobEncryption = aliases['Microsoft.Storage/storageAccounts/enableBlobEncryption'],
    FileEncryption = aliases['Microsoft.Storage/storageAccounts/enableFileEncryption']
    | where type =~ 'microsoft.storage/storageaccounts'
    | project Name=['name'], Kind=['kind'], Type, HTTPSOnly, BlobEncryption, FileEncryption, Location=['location'], SubscriptionID=['subscriptionId']
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


Function AzSubscriptionsCountByMG-Query-AzARG
{
$Query = @"
    resourcecontainers
    | where type == 'microsoft.resources/subscriptions'
    | project subscriptionName = name, managementgroups = (properties.managementGroupAncestorsChain)
    | mv-expand managementgroups
    | summarize count() by tostring(managementgroups.displayName)
    | order by count_ desc 
"@
Return $Query
}


Function AzSubscriptionsCountByResourceType-Query-AzARG
{
$Query = @"
    resources
    | join kind=leftouter 
        (resourcecontainers
        | where type == 'microsoft.resources/subscriptions'
        | project subscriptionName=name, subscriptionId) on subscriptionId
    | where subscriptionName  != ""
    | summarize count() by type, subscriptionName
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


Function AzTagsKeyValuePairs-Query-AzARG
{
$Query = @"
    resources 
    | where isnotempty(tags)
    | where tags !has "hidden-"
    | mv-expand tags
    | extend tagName = tostring(bag_keys(tags)[0])
    | extend tagValue = tostring(tags[tagName])
"@
Return $Query
}


Function AzTagsResourcesCountByTagName-Query-AzARG
{
$Query = @"
    resources 
    | where isnotempty(tags)
    | where tags !has "hidden-"
    | mv-expand tags
    | extend tagName = tostring(bag_keys(tags)[0])
    | extend tagValue = tostring(tags[tagName])
    | summarize count() by tagName
    | order by ['count_'] desc
"@
Return $Query
}


Function AzTagsResourcesCountByTagNameValue-Query-AzARG
{
$Query = @"
    resources 
    | where isnotempty(tags)
    | where tags !has "hidden-"
    | mv-expand tags
    | extend tagName = tostring(bag_keys(tags)[0])
    | extend tagValue = tostring(tags[tagName])
    | summarize count() by tagName, tagValue
    | order by ['count_'] desc
"@
Return $Query
}


Function AzTagsResourceTypesCountByTagNameValue-Query-AzARG
{
$Query = @"
    resources 
    | where isnotempty(tags)
    | where tags !has "hidden-"
    | mv-expand tags
    | extend tagName = tostring(bag_keys(tags)[0])
    | extend tagValue = tostring(tags[tagName])
    | summarize count() by type, tagName, tagValue 
    | order by ['count_'] desc
"@
Return $Query
}


Function AzUmcAvailableUpdatesByUpdateCategory-Query-AzARG
{
$Query = @"
    patchassessmentresources
    | where type !has "softwarepatches"
    | extend prop = parse_json(properties)
    | extend lastTime = properties.lastModifiedDateTime
    | extend updateRollupCount = prop.availablePatchCountByClassification.updateRollup, featurePackCount = prop.availablePatchCountByClassification.featurePack, servicePackCount = prop.availablePatchCountByClassification.servicePack, definitionCount = prop.availablePatchCountByClassification.definition, securityCount = prop.availablePatchCountByClassification.security, criticalCount = prop.availablePatchCountByClassification.critical, updatesCount = prop.availablePatchCountByClassification.updates, toolsCount = prop.availablePatchCountByClassification.tools, otherCount = prop.availablePatchCountByClassification.other, OS = prop.osType
    | project lastTime, id, OS, updateRollupCount, featurePackCount, servicePackCount, definitionCount, securityCount, criticalCount, updatesCount, toolsCount, otherCount
"@
Return $Query
}


Function AzUmcInstallationsCount-Query-AzARG
{
$Query = @"
    patchinstallationresources
    | where type !has "softwarepatches"
    | extend machineName = tostring(split(id, "/", 8)), resourceType = tostring(split(type, "/", 0)), tostring(rgName = split(id, "/", 4))
    | extend prop = parse_json(properties)
    | extend lTime = todatetime(prop.lastModifiedDateTime), OS = tostring(prop.osType), installedPatchCount = tostring(prop.installedPatchCount), failedPatchCount = tostring(prop.failedPatchCount), pendingPatchCount = tostring(prop.pendingPatchCount), excludedPatchCount = tostring(prop.excludedPatchCount), notSelectedPatchCount = tostring(prop.notSelectedPatchCount)
    | where lTime > ago(7d)
    | project lTime, RunID=name,machineName, rgName, resourceType, OS, installedPatchCount, failedPatchCount, pendingPatchCount, excludedPatchCount, notSelectedPatchCount
"@
Return $Query
}


Function AzUmcMaintenanceRunVM-Query-AzARG
{
$Query = @"
    maintenanceresources 
    | where ['id'] contains "/subscriptions/<subscription-id>/resourcegroups/<resource-group>/providers/microsoft.compute/virtualmachines/<vm-name>" //VM Id here
    | where ['type'] == "microsoft.maintenance/applyupdates" 
    | where properties.maintenanceScope == "InGuestPatch"
"@
Return $Query
}


Function AzUmcPatchInstallationsLinuxOS
{
$Query = @"
    patchinstallationresources
    | where type has "softwarepatches" and properties has "version"
    | extend machineName = tostring(split(id, "/", 8)), resourceType = tostring(split(type, "/", 0)), tostring(rgName = split(id, "/", 4)), tostring(RunID = split(id, "/", 10))
    | extend prop = parse_json(properties)
    | extend lTime = todatetime(prop.lastModifiedDateTime), patchName = tostring(prop.patchName), version = tostring(prop.version), installationState = tostring(prop.installationState), classifications = tostring(prop.classifications)
    | where lTime > ago(7d)
    | project lTime, RunID, machineName, rgName, resourceType, patchName, version, classifications, installationState
    | sort by RunID
"@
Return $Query
}


Function AzUmcPatchInstallationsWindowsOS-Query-AzARG
{
$Query = @"
    patchinstallationresources
    | where type has "softwarepatches" and properties !has "version"
    | extend machineName = tostring(split(id, "/", 8)), resourceType = tostring(split(type, "/", 0)), tostring(rgName = split(id, "/", 4)), tostring(RunID = split(id, "/", 10))
    | extend prop = parse_json(properties)
    | extend lTime = todatetime(prop.lastModifiedDateTime), patchName = tostring(prop.patchName), kbId = tostring(prop.kbId), installationState = tostring(prop.installationState), classifications = tostring(prop.classifications)
    | where lTime > ago(7d)
    | project lTime, RunID, machineName, rgName, resourceType, patchName, kbId, classifications, installationState
    | sort by RunID
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
    This switch will install Az, Az.ResourceGraph and AzResourceGraphPS (if missing), 
    auto-update PS modules Az.ResourceGraph and AzResourceGraphPS (if updates available) and
    remove older versions of Az.ResourceGraph and AzResourceGraphPS (if found)
    
    NOTE: Parameter will NOT update or remove Az-module
    
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
                                                                       -TenantId $TenantId `

    # Get all Azure Resource Groups in specific subscription - show only first 2 RGs
        AzRGs-Query-AzARG | Query-AzResourceGraph -QueryScope Subscription `
                                                  -Target "fce4f282-fcc6-43fb-94d8-bf1701b862c3" `
                                                  -First 2
 
    # Get all management groups under management group '2linkit' - skip first 3
        AzMGsWithParentHierarchy-Query-AzARG | Query-AzResourceGraph -QueryScope "MG" `
                                                                        -Target "2linkit" `
                                                                        -Skip 3

    # Get all management groups under management group '2linkit' - only show first 3
        AzMGsWithParentHierarchy | Query-AzResourceGraph -QueryScope "MG" `
                                                         -Target "2linkit" `
                                                         -First 3
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
                                $OnlineVersion = Find-Module -Name $Module -Repository PSGallery

                                # Compare versions
                                if ( ([version]$Online.Version) -gt ([version]$LatestVersion.Version) ) 
                                    {
                                        Write-host ""
                                        Write-host "Newer version ($($Online.version)) of $($Module) was detected in PSGallery"
                                        Write-host ""
                                        Write-host "Updating to latest version $($Online.version) of $($Module) from PSGallery ... Please Wait !"
                            
                                        Update-module Az.ResourceGraph -Force
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
                # Az
                #####################################################################
                $Module = "Az"

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
                                $OnlineVersion = Find-Module -Name $Module -Repository PSGallery

                                # Compare versions
                                if ( ([version]$Online.Version) -gt ([version]$LatestVersion.Version) ) 
                                    {
                                        Write-host ""
                                        Write-host "Newer version ($($Online.version)) of $($Module) was detected in PSGallery"
                                        Write-host ""
                                        Write-host "Updating to latest version $($Online.version) of $($Module) from PSGallery ... Please Wait !"
                            
                                        Update-module Az.ResourceGraph -Force
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
                        Connect-AzAccount -ServicePrincipal -Credential $SecureCreds -Tenant $TenantId -WarningAction SilentlyContinue
                    }
                Else
                    {
                        Connect-AzAccount -WarningAction SilentlyContinue
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

        If ($First)
            {
                Write-host ""
                Write-host "Scoping - Only First Number of Records:"
                Write-host "    $($First)" -ForegroundColor Yellow
                Write-host ""
            }


    #--------------------------------------------------------------------------
    # Skip
    #--------------------------------------------------------------------------

        If ($Skip)
            {
                Write-host ""
                Write-host "Scoping - Skip Number of Records:"
                Write-host "    $($Skip)" -ForegroundColor Yellow
                Write-host ""
            }

    #--------------------------------------------------------------------------
    # Running Query and returning result
    #--------------------------------------------------------------------------

        If (!([string]::IsNullOrWhitespace($Query)))
            {
                Write-host "Query Scope:"
                Write-host "    $($QueryScope)" -ForegroundColor Yellow
                Write-host ""
                If ($Target)
                    {
                        Write-host "Target:"
                        Write-host "    $($Target)" -ForegroundColor Yellow
                        Write-host ""
                    }
                Write-host "Query, which will be run against Azure Resource Graph: "
                Write-host ""
                Write-host "$($Query)" -ForegroundColor Yellow
                Write-host ""
                Write-host "---------------------------------------------------------------------"
                Write-host ""
                Write-host "Running Query against Azure Resource Group ..."

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



# SIG # Begin signature block
# MIIXHgYJKoZIhvcNAQcCoIIXDzCCFwsCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCB7bHftRq8TM4zj
# W5hZ0EoFJ5FNlqLH80J8MHk4RDCyTKCCE1kwggVyMIIDWqADAgECAhB2U/6sdUZI
# k/Xl10pIOk74MA0GCSqGSIb3DQEBDAUAMFMxCzAJBgNVBAYTAkJFMRkwFwYDVQQK
# ExBHbG9iYWxTaWduIG52LXNhMSkwJwYDVQQDEyBHbG9iYWxTaWduIENvZGUgU2ln
# bmluZyBSb290IFI0NTAeFw0yMDAzMTgwMDAwMDBaFw00NTAzMTgwMDAwMDBaMFMx
# CzAJBgNVBAYTAkJFMRkwFwYDVQQKExBHbG9iYWxTaWduIG52LXNhMSkwJwYDVQQD
# EyBHbG9iYWxTaWduIENvZGUgU2lnbmluZyBSb290IFI0NTCCAiIwDQYJKoZIhvcN
# AQEBBQADggIPADCCAgoCggIBALYtxTDdeuirkD0DcrA6S5kWYbLl/6VnHTcc5X7s
# k4OqhPWjQ5uYRYq4Y1ddmwCIBCXp+GiSS4LYS8lKA/Oof2qPimEnvaFE0P31PyLC
# o0+RjbMFsiiCkV37WYgFC5cGwpj4LKczJO5QOkHM8KCwex1N0qhYOJbp3/kbkbuL
# ECzSx0Mdogl0oYCve+YzCgxZa4689Ktal3t/rlX7hPCA/oRM1+K6vcR1oW+9YRB0
# RLKYB+J0q/9o3GwmPukf5eAEh60w0wyNA3xVuBZwXCR4ICXrZ2eIq7pONJhrcBHe
# OMrUvqHAnOHfHgIB2DvhZ0OEts/8dLcvhKO/ugk3PWdssUVcGWGrQYP1rB3rdw1G
# R3POv72Vle2dK4gQ/vpY6KdX4bPPqFrpByWbEsSegHI9k9yMlN87ROYmgPzSwwPw
# jAzSRdYu54+YnuYE7kJuZ35CFnFi5wT5YMZkobacgSFOK8ZtaJSGxpl0c2cxepHy
# 1Ix5bnymu35Gb03FhRIrz5oiRAiohTfOB2FXBhcSJMDEMXOhmDVXR34QOkXZLaRR
# kJipoAc3xGUaqhxrFnf3p5fsPxkwmW8x++pAsufSxPrJ0PBQdnRZ+o1tFzK++Ol+
# A/Tnh3Wa1EqRLIUDEwIrQoDyiWo2z8hMoM6e+MuNrRan097VmxinxpI68YJj8S4O
# JGTfAgMBAAGjQjBAMA4GA1UdDwEB/wQEAwIBhjAPBgNVHRMBAf8EBTADAQH/MB0G
# A1UdDgQWBBQfAL9GgAr8eDm3pbRD2VZQu86WOzANBgkqhkiG9w0BAQwFAAOCAgEA
# Xiu6dJc0RF92SChAhJPuAW7pobPWgCXme+S8CZE9D/x2rdfUMCC7j2DQkdYc8pzv
# eBorlDICwSSWUlIC0PPR/PKbOW6Z4R+OQ0F9mh5byV2ahPwm5ofzdHImraQb2T07
# alKgPAkeLx57szO0Rcf3rLGvk2Ctdq64shV464Nq6//bRqsk5e4C+pAfWcAvXda3
# XaRcELdyU/hBTsz6eBolSsr+hWJDYcO0N6qB0vTWOg+9jVl+MEfeK2vnIVAzX9Rn
# m9S4Z588J5kD/4VDjnMSyiDN6GHVsWbcF9Y5bQ/bzyM3oYKJThxrP9agzaoHnT5C
# JqrXDO76R78aUn7RdYHTyYpiF21PiKAhoCY+r23ZYjAf6Zgorm6N1Y5McmaTgI0q
# 41XHYGeQQlZcIlEPs9xOOe5N3dkdeBBUO27Ql28DtR6yI3PGErKaZND8lYUkqP/f
# obDckUCu3wkzq7ndkrfxzJF0O2nrZ5cbkL/nx6BvcbtXv7ePWu16QGoWzYCELS/h
# AtQklEOzFfwMKxv9cW/8y7x1Fzpeg9LJsy8b1ZyNf1T+fn7kVqOHp53hWVKUQY9t
# W76GlZr/GnbdQNJRSnC0HzNjI3c/7CceWeQIh+00gkoPP/6gHcH1Z3NFhnj0qinp
# J4fGGdvGExTDOUmHTaCX4GUT9Z13Vunas1jHOvLAzYIwggbmMIIEzqADAgECAhB3
# vQ4DobcI+FSrBnIQ2QRHMA0GCSqGSIb3DQEBCwUAMFMxCzAJBgNVBAYTAkJFMRkw
# FwYDVQQKExBHbG9iYWxTaWduIG52LXNhMSkwJwYDVQQDEyBHbG9iYWxTaWduIENv
# ZGUgU2lnbmluZyBSb290IFI0NTAeFw0yMDA3MjgwMDAwMDBaFw0zMDA3MjgwMDAw
# MDBaMFkxCzAJBgNVBAYTAkJFMRkwFwYDVQQKExBHbG9iYWxTaWduIG52LXNhMS8w
# LQYDVQQDEyZHbG9iYWxTaWduIEdDQyBSNDUgQ29kZVNpZ25pbmcgQ0EgMjAyMDCC
# AiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBANZCTfnjT8Yj9GwdgaYw90g9
# z9DljeUgIpYHRDVdBs8PHXBg5iZU+lMjYAKoXwIC947Jbj2peAW9jvVPGSSZfM8R
# Fpsfe2vSo3toZXer2LEsP9NyBjJcW6xQZywlTVYGNvzBYkx9fYYWlZpdVLpQ0LB/
# okQZ6dZubD4Twp8R1F80W1FoMWMK+FvQ3rpZXzGviWg4QD4I6FNnTmO2IY7v3Y2F
# QVWeHLw33JWgxHGnHxulSW4KIFl+iaNYFZcAJWnf3sJqUGVOU/troZ8YHooOX1Re
# veBbz/IMBNLeCKEQJvey83ouwo6WwT/Opdr0WSiMN2WhMZYLjqR2dxVJhGaCJedD
# CndSsZlRQv+hst2c0twY2cGGqUAdQZdihryo/6LHYxcG/WZ6NpQBIIl4H5D0e6lS
# TmpPVAYqgK+ex1BC+mUK4wH0sW6sDqjjgRmoOMieAyiGpHSnR5V+cloqexVqHMRp
# 5rC+QBmZy9J9VU4inBDgoVvDsy56i8Te8UsfjCh5MEV/bBO2PSz/LUqKKuwoDy3K
# 1JyYikptWjYsL9+6y+JBSgh3GIitNWGUEvOkcuvuNp6nUSeRPPeiGsz8h+WX4VGH
# aekizIPAtw9FbAfhQ0/UjErOz2OxtaQQevkNDCiwazT+IWgnb+z4+iaEW3VCzYkm
# eVmda6tjcWKQJQ0IIPH/AgMBAAGjggGuMIIBqjAOBgNVHQ8BAf8EBAMCAYYwEwYD
# VR0lBAwwCgYIKwYBBQUHAwMwEgYDVR0TAQH/BAgwBgEB/wIBADAdBgNVHQ4EFgQU
# 2rONwCSQo2t30wygWd0hZ2R2C3gwHwYDVR0jBBgwFoAUHwC/RoAK/Hg5t6W0Q9lW
# ULvOljswgZMGCCsGAQUFBwEBBIGGMIGDMDkGCCsGAQUFBzABhi1odHRwOi8vb2Nz
# cC5nbG9iYWxzaWduLmNvbS9jb2Rlc2lnbmluZ3Jvb3RyNDUwRgYIKwYBBQUHMAKG
# Omh0dHA6Ly9zZWN1cmUuZ2xvYmFsc2lnbi5jb20vY2FjZXJ0L2NvZGVzaWduaW5n
# cm9vdHI0NS5jcnQwQQYDVR0fBDowODA2oDSgMoYwaHR0cDovL2NybC5nbG9iYWxz
# aWduLmNvbS9jb2Rlc2lnbmluZ3Jvb3RyNDUuY3JsMFYGA1UdIARPME0wQQYJKwYB
# BAGgMgEyMDQwMgYIKwYBBQUHAgEWJmh0dHBzOi8vd3d3Lmdsb2JhbHNpZ24uY29t
# L3JlcG9zaXRvcnkvMAgGBmeBDAEEATANBgkqhkiG9w0BAQsFAAOCAgEACIhyJsav
# +qxfBsCqjJDa0LLAopf/bhMyFlT9PvQwEZ+PmPmbUt3yohbu2XiVppp8YbgEtfjr
# y/RhETP2ZSW3EUKL2Glux/+VtIFDqX6uv4LWTcwRo4NxahBeGQWn52x/VvSoXMNO
# Ca1Za7j5fqUuuPzeDsKg+7AE1BMbxyepuaotMTvPRkyd60zsvC6c8YejfzhpX0FA
# Z/ZTfepB7449+6nUEThG3zzr9s0ivRPN8OHm5TOgvjzkeNUbzCDyMHOwIhz2hNab
# XAAC4ShSS/8SS0Dq7rAaBgaehObn8NuERvtz2StCtslXNMcWwKbrIbmqDvf+28rr
# vBfLuGfr4z5P26mUhmRVyQkKwNkEcUoRS1pkw7x4eK1MRyZlB5nVzTZgoTNTs/Z7
# KtWJQDxxpav4mVn945uSS90FvQsMeAYrz1PYvRKaWyeGhT+RvuB4gHNU36cdZytq
# tq5NiYAkCFJwUPMB/0SuL5rg4UkI4eFb1zjRngqKnZQnm8qjudviNmrjb7lYYuA2
# eDYB+sGniXomU6Ncu9Ky64rLYwgv/h7zViniNZvY/+mlvW1LWSyJLC9Su7UpkNpD
# R7xy3bzZv4DB3LCrtEsdWDY3ZOub4YUXmimi/eYI0pL/oPh84emn0TCOXyZQK8ei
# 4pd3iu/YTT4m65lAYPM8Zwy2CHIpNVOBNNwwggb1MIIE3aADAgECAgx5Y9ljauM7
# cdkFAm4wDQYJKoZIhvcNAQELBQAwWTELMAkGA1UEBhMCQkUxGTAXBgNVBAoTEEds
# b2JhbFNpZ24gbnYtc2ExLzAtBgNVBAMTJkdsb2JhbFNpZ24gR0NDIFI0NSBDb2Rl
# U2lnbmluZyBDQSAyMDIwMB4XDTIzMDMyNzEwMjEzNFoXDTI2MDMyMzE2MTgxOFow
# YzELMAkGA1UEBhMCREsxEDAOBgNVBAcTB0tvbGRpbmcxEDAOBgNVBAoTBzJsaW5r
# SVQxEDAOBgNVBAMTBzJsaW5rSVQxHjAcBgkqhkiG9w0BCQEWD21va0AybGlua2l0
# Lm5ldDCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAMykjWtM6hY5IRPe
# VIVB+yX+3zcMJQR2gjTZ81LnGVRE94Zk2GLFAwquGYWt1shoTHTV5j6Ef2AXYBDV
# kNruisJVJ17UsMGdsU8upwdZblFbLNzLw+qBXVC/OUVua9M0cub7CfUNkn/Won4D
# 7i41QyuDXdZFOIfRhZ3qnCYCJCSgYLoUXAS6xei2tPkkk1w8aXEFxybyy7eRqQjk
# HqIS5N4qH3YQkz+SbSlz/yj6mD65H5/Ts+lZxX2xL/8lgJItpdaJx+tarprv/tT+
# +n9a13P53YNzCWOmyhd376+7DMXxxSzT24kq13Ks3xnUPGoWUx2UPRnJHjTWoBfg
# Y7Zd3MffrdO0QEoDC9X5F5boh6oankVSOdSPRFns085KI+vkbt3bdG62MIeUbNtS
# v7mZBX8gcYv0szlo0ey7bbOJWoiZFT2fB+pBVvxDhpYP0/3aFveM1wfhshaJBhxx
# /2GCswYYBHH7B3+8j4BT8N8S030q4snys2Qt9tdFIHvSV7lIw/yorT1WM1cr+Lqo
# 74eR+Hi982db0k68p2BGdCOY0QhhaNqxufwbK+gVWrQY57GIX/1cUrBt0akMsli2
# 19xVmUGhIw85ZF7wcQplhslbUxyNUilY+c93q1bsIFjaOnjjvo56g+kyKICm5zsG
# FQLRVaXUSLY+i8NSiH8fd64etaptAgMBAAGjggGxMIIBrTAOBgNVHQ8BAf8EBAMC
# B4AwgZsGCCsGAQUFBwEBBIGOMIGLMEoGCCsGAQUFBzAChj5odHRwOi8vc2VjdXJl
# Lmdsb2JhbHNpZ24uY29tL2NhY2VydC9nc2djY3I0NWNvZGVzaWduY2EyMDIwLmNy
# dDA9BggrBgEFBQcwAYYxaHR0cDovL29jc3AuZ2xvYmFsc2lnbi5jb20vZ3NnY2Ny
# NDVjb2Rlc2lnbmNhMjAyMDBWBgNVHSAETzBNMEEGCSsGAQQBoDIBMjA0MDIGCCsG
# AQUFBwIBFiZodHRwczovL3d3dy5nbG9iYWxzaWduLmNvbS9yZXBvc2l0b3J5LzAI
# BgZngQwBBAEwCQYDVR0TBAIwADBFBgNVHR8EPjA8MDqgOKA2hjRodHRwOi8vY3Js
# Lmdsb2JhbHNpZ24uY29tL2dzZ2NjcjQ1Y29kZXNpZ25jYTIwMjAuY3JsMBMGA1Ud
# JQQMMAoGCCsGAQUFBwMDMB8GA1UdIwQYMBaAFNqzjcAkkKNrd9MMoFndIWdkdgt4
# MB0GA1UdDgQWBBQxxpY2q5yrKa7VFODTZhTfPKmyyTANBgkqhkiG9w0BAQsFAAOC
# AgEAe38NgZR4IV9u264/n/jiWlHbBu847j1vpN6dovxMvdUQZ780eH3JzcvG8fo9
# 1uO1iDIZksSigiB+d8Sj5Yvh+oXlfYEffjIQCwcIlWNciOzWYZzl9qPHXgdTnaIu
# JA5cR846TepQLVMXc1Yb72Z7OGjldmRIxGjRimDsmzY+TdTu15lF4IkUj0VJhr8F
# PYOdEVZVOXHtPmUjPqsq9M7WpALYbc0pUawcy0FOOwXqzaCk7O3vMXej4Oycm6RB
# GfRH3JPOCvH2ddiIfPq2Lce4nhTuLsgumBJE2vOalVddIfTBjE9PpMub15lHyp1m
# fW0ZJvXOghPvRqufMT3SjPTHt6PV8LwhQD8BiGSZ9rp94js4xTnGexSOFKLLMxWE
# PTr5EPe3kmtspGgKCqLEZvsMYz7JlWNuaHBy+vdQZWV3376luwV4IHfGT+1wxe0E
# 90dMRI+9SNIKkVvKV3FUtToZUh3Np4cCIHJLQ1eslXFzIJa6wrjVsnWM/3OyedpQ
# JERGNYXlVmxdgGFjrY1I6UWII0Y1iZW3t+JvhXosUaha8i/YSxaDH+5H/Klad2OZ
# Xq4Eg39QxkCELbmJmSU0sUYNnl0JTEu6jJY9UJMFikzf5s3p2ZuKdyMbRgN5GNNV
# 883meI/X5KVHBJDG1epigMer7fFXMVZUGoI12iIz/gOolQExggMbMIIDFwIBATBp
# MFkxCzAJBgNVBAYTAkJFMRkwFwYDVQQKExBHbG9iYWxTaWduIG52LXNhMS8wLQYD
# VQQDEyZHbG9iYWxTaWduIEdDQyBSNDUgQ29kZVNpZ25pbmcgQ0EgMjAyMAIMeWPZ
# Y2rjO3HZBQJuMA0GCWCGSAFlAwQCAQUAoIGEMBgGCisGAQQBgjcCAQwxCjAIoAKA
# AKECgAAwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwHAYKKwYBBAGCNwIBCzEO
# MAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIHR1h51o+L7rFYgn1rwUGvE8
# eKn4FLP+QXEs5X1WMg7ZMA0GCSqGSIb3DQEBAQUABIICALXQu+8LadB7lNzaQKsC
# vF14tvb9QTtLr6pfGQv+aYPZUTE2lJO/e0x0FOTaokXONIv063COIqJeh56QgvHm
# 0qMsg8wfyLeHViWooFEpZvdYNYv8Yc2hx8St79z9cmK1e1e+EvzcV8yyn3AlkrIj
# jbOtJt2+aVScAVMBWKc85/GvT+qCXoglfqmKEA2M5em/C9Ul4EpIyj3/Ls9l5g/8
# S4NlmKJ5mdZBlJxF0TgaCy49FhLHsV+0fd/plKU46rlfHw1Fhc25DPE3Uffvowaq
# Y6AbE67Q9Tn7VpwIjGXjxKrBb/qfGR9waOt2Z3iXMvgfGNSnPGmdvJxTcWyXsHSJ
# QKbzZwGGHpiycyEJdc9Ih0JQ5Sc2CVLYKkzsJcK5g/R0LEIGFz15UO0TbpaoGzcO
# PW6C9OIbPaNfipKg2jOcws/QnknnDX3+sJUEQ+fR6oX8Tf4ZbzZTgDi4YE5P0w5Z
# QDETYu8B2YyqK0F7hlCp9oZtwxUUbmFgif1l0kLtkVBurHmyqnD+n+VlSk4Bs5Hq
# M44XfVayeqiUX4wEVWYhDfqZYGPNpNs7GyqPoP+cuDfVPcEmPsq8sMU6WnvuVRLu
# IWI2LNPUIUPkVWKlcj7pR3pI1anxTNSKBi3uHnDRZDJxdy9+kEdhi0AT8DSzjtX9
# /OEgHVbfyWEt9g2dyFZ1Cf3u
# SIG # End signature block
