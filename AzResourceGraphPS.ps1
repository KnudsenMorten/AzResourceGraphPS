Function KQL-ARG-AzRoleAssignments
{
#--- BEGIN -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
$Query = `

"authorizationResources `
| where type == `"microsoft.authorization/roleassignments`" `
| extend roleDefinitionIdFull = tostring(properties.roleDefinitionId) `
| extend roleDefinitionIdsplit = split(roleDefinitionIdFull,'/') `
| extend roleDefinitionId = tostring(roleDefinitionIdsplit[(4)]) `
| extend roleAssignmentPrincipalType = properties.principalType `
| extend roleAssignmentDescription = properties.description `
| extend roleAssignmentPrincipalId = properties.principalId `
| extend roleAssignmentCreatedOn = properties.createdOn `
| extend roleAssignmentUpdatedOn = properties.updatedOn `
| extend roleAssignmentUpdatedById = properties.updatedBy `
| extend roleAssignmentCreatedById = properties.createdBy `
| extend roleAssignmentScope = properties.scope `
| project-away managedBy,kind,sku,plan,tags,identity,zones,location,resourceGroup,subscriptionId, extendedLocation,tenantId `
| join kind=leftouter (authorizationResources `
        | where type == `"microsoft.authorization/roledefinitions`" `
        | extend roleDefinitionIdFull = tostring(id) `
        | extend roleDefinitionIdsplit = split(roleDefinitionIdFull,'/') `
        | extend roleDefinitionId = tostring(roleDefinitionIdsplit[(4)]) `
        | extend description = properties.description `
        | extend roleName = properties.roleName `
        | extend roleType = properties.type `
        | project-away managedBy,kind,sku,plan,tags,identity,zones,location,resourceGroup,subscriptionId, extendedLocation,tenantId) `
  on roleDefinitionId `
| project roleDefinitionId,roleName,roleType,roleAssignmentPrincipalType,roleAssignmentPrincipalId,roleAssignmentCreatedOn,roleAssignmentUpdatedOn,roleAssignmentUpdatedById,roleAssignmentCreatedById,roleAssignmentScope "

#--- END -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Return $Query

}

Function KQL-ARG-AzSubscriptions
{
#--- BEGIN -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
$Query = `

"resourcecontainers `
| where type == 'microsoft.resources/subscriptions' "

# END -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Return $Query

}


Function Query-AzureResourceGraph
{
    [CmdletBinding()]
    param(
            [Parameter(Mandatory,ValueFromPipeline)]
                [string]$Query,
            [Parameter()]
                [string]$Scope,
            [Parameter()]
                [string]$ScopeTarget,
            [Parameter()]
                [string]$First,
            [Parameter()]
                [string]$Skip,
            [Parameter()]
                [boolean]$IncludeScopeRoot = $false
         )

    Write-host "######################################################################"
    Write-host "Running query against Azure Resource Graph ... Please Wait !"
    Write-host ""
    Write-host "$($Query)"
    Write-host ""

    $ReturnData   = @()
    $pageSize     = 1000
    $iteration    = 0

    $searchParams = @{
                        Query = $Query
                             
                        First = $pageSize
                     }

    If ($Scope -eq "MG") # Management group(s) to run query against
        {
            do
                {
                    $iteration         += 1
                    $pageResults       = Search-AzGraph -ManagementGroup $ScopeTarget @searchParams
                    $searchParams.Skip += $pageResults.Count
                    $ReturnData        += $pageResults
                } 
            while ($pageResults.Count -eq $pageSize)
        }
    ElseIf ($Scope -eq "Sub") # Subscription(s) to run query against
        {
            do 
                {
                    $iteration         += 1
                    $pageResults       = Search-AzGraph -Subscription $ScopeTarget @searchParams
                    $searchParams.Skip += $pageResults.Count
                    $ReturnData        += $pageResults
                } 
            while ($pageResults.Count -eq $pageSize)
        }
    ElseIf ( ($Scope -eq "Tenant") -or ($Scope -eq $null) )  # UseTenantScope = Run query across all available subscriptions in the current tenant
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

    Return $ReturnData
}



Connect-AzAccount

# get query into variable $QueryParams
$QueryParams = Get-ARG-AzRoleAssignments

# Query azure Resource Graph (ARG)
Query-AzureResourceGraph -DataType $QueryParams[0] `
                         -Query $QueryParams[1] `
                         -Scope "MG" `
                         -ScopeTarget "mg-2linkit" `
                         -IncludeScopeRoot $IncludeScopeRoot `
                         
# Query azure Resource Graph (ARG) - return first 5
Query-AzureResourceGraph -DataType $QueryParams[0] `
                         -Query $QueryParams[1] `
                         -Scope "MG" `
                         -ScopeTarget "mg-2linkit" `
                         -IncludeScopeRoot $IncludeScopeRoot `
                         -First 5
                          
########################
# UseTenantScope
########################

Get-ARG-AzSubscriptions | Query-AzureResourceGraph -Scope "Tenant" -IncludeScopeRoot $IncludeScopeRoot
                                                       




<#

#####################################################################################################################
# Getting Management groups - using Azure Resource Graph - limited to children under $ManagementGroupName
#
# Output: $AzMGs 
# -------------------------------------------------------------------------------------------------------------------
# Search-AzGraph will only include children objects under the specific management group; not the actual root management
# group. But we need array to include root management group, when checking for orphaned security principels (task 1). 
# Therefore we will build a new Array (AzMGsWithRoot)
#
# Output: $AzMGsWithRoot
#####################################################################################################################

    Write-Output "Getting Management Groups from Azure Resource Graph (root: $($ManagementGroupName))"
    $AzMGs = @()
    $pageSize = 1000
    $iteration = 0
    $searchParams = @{
					    Query = "resourcecontainers `
                        | where type == 'microsoft.management/managementgroups' `
                        | extend mgParent = properties.details.managementGroupAncestorsChain `
                        | mv-expand with_itemindex=MGHierarchy mgParent `
                        | project id, name, properties.displayName, mgParent, MGHierarchy, mgParent.name `
                        | sort by MGHierarchy asc "
					    First = $pageSize
 			            }

    $results = do {
	    $iteration += 1
	            $pageResults = Search-AzGraph  @searchParams -ManagementGroup $ManagementGroupName
	    $searchParams.Skip += $pageResults.Count
	    $AzMGs += $pageResults
    } while ($pageResults.Count -eq $pageSize)

    #------------------------------------------------------------------------------------------------------------------------------------
    # Special for Task #1 - remove orphaned security principals
    # Search-AzGraph will only include children objects under the specific management group - but when using data to
    # remove orphaned objects, we also need to have the actual management group as part of the scope
    # Therefore we will build a new Array $AzMGsWithRoot

        $AzMGWithRoot = @()

        # Getting the root variable
        $AzMGWithRoot_Temp = New-Object PSObject
        $AzMGWithRoot_Temp | Add-Member -MemberType NoteProperty -Name Id -Value ((Get-AzManagementGroup -GroupId $ManagementGroupName -WarningAction SilentlyContinue).id)
        $AzMGWithRoot += $AzMGWithRoot_Temp

        # Now we get the children from AzMGs
        ForEach ($Obj in $AzMGs)
            {
                $AzMGWithRoot_Temp = New-Object PSObject
                $AzMGWithRoot_Temp | Add-Member -MemberType NoteProperty -Name Id -Value $Obj.id
                $AzMGWithRoot += $AzMGWithRoot_Temp
            }

    #------------------------------------------------------------------------------------------------------------------------------------
#>
