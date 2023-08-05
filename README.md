# AzResourceGraphPS
I'm really happy to announce my newest PS-module, **AzResourceGraphPS**.

Think of this PS-module as a helper for **Microsoft Graph version-management, connectivity** and **data management** using **Microsoft Graph**. It does also support **generic Microsoft REST API connectivity** and **data management** like https://api.securitycenter.microsoft.com/api/machines. Lastly, it includes new custom cmdlets I use often like Get-MgUser-AllProperties-AllUsers

| Function Name                      | Funtionality                                                 |
| ---------------------------------- | ------------------------------------------------------------ |
| Manage-Version-Microsoft.Graph     | Version management of Microsoft.Graph PS modules<br/>Installing latest version of Microsoft.Graph, if not found<br/>Shows older installed versions of Microsoft.Graph<br/>Checks if newer version if available from PSGallery of Microsoft.Graph<br/>Automatic clean-up old versions of Microsoft.Graph<br/>Update to latest version from PSGallery of Microsoft.Graph<br/>Remove all versions of Microsoft.Graph (complete re-install) |
| InstallUpdate-MicrosoftGraphPS     | Install latest version of MicrosoftGraphPS, if not found<br/>Update to latest version of MicrosoftGraphPS, if switch (-AutoUpdate) is set |
| Connect-MicrosoftGraphPS           | Connect to Microsoft Graph using Azure App & Secret<br/>Connect to Microsoft Graph using Azure App & Certificate Thumprint<br/>Connect to Microsoft Graph using interactive login and scope |
| Invoke-MgGraphRequestPS            | Invoke command with pagination support to get/put/post/patch/delete data using Microsoft Graph REST endpoint. |
| Connect-MicrosoftRestApiEndpointPS | Connect to REST API endpoint like https://api.securitycenter.microsoft.com using Azure App & Secret |
| Invoke-MicrosoftRestApiRequestPS   | Invoke command to get/put/post/patch/delete data using Microsoft REST API endpoint<br/>Get data using Microsoft REST API endpoint like <br/>https://api.securitycenter.microsoft.com/api/machines |
| Get-MgUser-AllProperties-AllUsers  | Get all properties for all users<br/>Expands manager information<br/>Excludes certain properties which cannot be returned within a user collection in bulk retrieval<br/><br/>The following properties are only supported when retrieving a single user: aboutMe, birthday, hireDate, interests, mySite, pastProjects, preferredName, <br/>responsibilities, schools, skills, mailboxSettings, DeviceEnrollmentLimit, print, SignInActivity |



## Download of AzResourceGraphPS

You can [find latest version of AzResourceGraphPS here (Github)](https://raw.githubusercontent.com/KnudsenMorten/AzResourceGraphPS/main/AzResourceGraphPS.psm1) - or from [Powershell Gallery using this link](https://www.powershellgallery.com/packages/AzResourceGraphPS)



#### Initial installation of AzResourceGraphPS

```
install-module AzResourceGraphPS -Scope AllUsers -Force
```



#### Install pre-requisites modules

```
Query-AzResourceGraph -InstallAutoUpdateCleanupOldVersions -Scope AllUsers
```



#### **Update modules to latest versions** & Remove older versions

```
Query-AzResourceGraph -InstallAutoUpdateCleanupOldVersions -Scope AllUsers
```



# Syntax



#### Install if missing + Update all modules to latest version + clean-up old modules if found

```
Query-AzResourceGraph -InstallAutoUpdateCleanupOldVersions -Scope AllUsers
```



#### Run pre-defined query against tenant - and output result to screen

```
AzMGsWithParentHierarchy-Query-AzARG | Query-AzResourceGraph -QueryScope Tenant
```



#### Run pre-defined query against MG "2linkit"- and output result to screen

```
AzRGs-Query-AzARG | Query-AzResourceGraph -QueryScope MG -Target "2linkit"
```



#### Run pre-defined query and return result to $Result-variable

```
$Result = AzRGs-Query-AzARG | Query-AzResourceGraph -QueryScope MG -Target "2linkit"
$Result | fl
```



#### Run Custom Query and return result to $Result-variable

```
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
```



#### Show query only

```
AzMGsWithParentHierarchy-Query-AzARG | Query-AzResourceGraph -ShowQueryOnly
```



#### Select from list of pre-defined queries

```
Query-AzResourceGraph -SelectQuery
```



#### Run query using unattended login with AzApp & AzSecret

```
# Variables
$AzAppId     = "xxxx"
$AzAppSecret = "xxxx"
$TenantId    = "xxxx"

# Disconnect existing sessions
Disconnect-AzAccount

AzRGs-Query-AzARG | Query-AzResourceGraph -QueryScope "Tenant" -AzAppId $AzAppId `
                                                               -AzAppSecret $AzAppSecret `
                                                               -TenantId $TenantId
```



#### Show only first x records

```
# Get all Azure Resource Groups in specific subscription - show only first 2 RGs
AzRGs-Query-AzARG | Query-AzResourceGraph -QueryScope Subscription `
                                          -Target "fce4f282-fcc6-43fb-94d8-bf1701b862c3" `
                                          -First 2
```



#### Skip first x records

```
# Get all management groups under management group '2linkit' - skip first 3
AzMGsWithParentHierarchy-Query-AzARG | Query-AzResourceGraph -QueryScope "MG" `
                                                             -Target "2linkit" `
                                                             -Skip 3
```





# Credits for queries



## Billy York

Github: https://github.com/scautomation/AzureResourceGraph-Examples

Blog: https://www.cloudsma.com/2021/01/azure-resource-graph-examples-repo/



## Wesley Hackman

Github: https://github.com/whaakman/azure-resource-graph-samples



## Wilfried Woivre

Github: https://github.com/wilfriedwoivre/azure-resource-graph-queries

Blog: https://woivre.com/blog/2020/09/azure-resource-graph-community-samples



## Ludovic Alarcon

Blog: https://ludovic-alarcon.com/Resource-Graph-NodePool/



## Microsoft

https://learn.microsoft.com/en-us/azure/governance/resource-graph/samples/samples-by-table
