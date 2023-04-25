install-module AzResourceGraphPS
Update-module AzResourceGraphPS

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
