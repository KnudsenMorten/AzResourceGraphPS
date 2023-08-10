################################################################################
# Install-module AzResourceGraphPS
################################################################################

    Install-module AzResourceGraphPS


################################################################################
# Verify Disconnect of any existing logins
################################################################################

    Disconnect-AzAccount


################################################################################
# Show Syntax
################################################################################

    get-help Query-AzResourceGraph

    get-help Query-AzResourceGraph -Full


################################################################################
# Installation | Auto-Update | Clean-up old Modules
################################################################################

    Query-AzResourceGraph -InstallAutoUpdateCleanupOldVersions


################################################################################
# ShowQueryOnly in interactive mode
################################################################################

    Query-AzResourceGraph -ShowQueryOnly

    # we need to login
    # we can now see available pre-defined queries
    # when we chose a query, it will ONLY show the query (not run)


################################################################################
# Run query in interactive mode
################################################################################

    Query-AzResourceGraph

    # we can now see available pre-defined queries and run the query
    # we will notice the QueryName, as we will see how to run in automatic mode

################################################################################
# Run query in automatic mode using pipeline (QueryName)
# Get RGs from tenant
################################################################################

    AzRGs-Query-AzARG | Query-AzResourceGraph -QueryScope "Tenant"


################################################################################
# Run query in automatic mode - output to variable $result
# Get RGs from tenant - show only first 2
################################################################################

    $Result = AzRGs-Query-AzARG | Query-AzResourceGraph -QueryScope "Tenant"

    $Result | ft

################################################################################
# Run query in automatic mode - output to variable $result
# 
# Get RGs from Management Group (MG)
################################################################################

    # We will now see SYNTAX ERROR due to missing -Target <MG name>
    # This is done on-purpose

    AzRGs-Query-AzARG | Query-AzResourceGraph -QueryScope "MG"

################################################################################
# Run query in automatic mode - output to variable $result
# Get RGs from MG "2linkit"
################################################################################

   $Result = AzRGs-Query-AzARG | Query-AzResourceGraph -QueryScope "MG" `
                                                       -Target "2linkit"

   $result | fl

################################################################################
# Get RGs from tenant - show only first 3
################################################################################

    $Result = AzRGs-Query-AzARG | Query-AzResourceGraph -QueryScope "Tenant"
    $Result | ft
    $Result.Count

    AzRGs-Query-AzARG | Query-AzResourceGraph -QueryScope "Tenant" -First 3

################################################################################
# Get RGs from tenant - skip first 5
################################################################################

    $Result = AzRGs-Query-AzARG | Query-AzResourceGraph -QueryScope "Tenant" -skip 5
    $Result.count

################################################################################
# Run Custom Query
################################################################################

$Query = @"
resourcecontainers 
| where type == 'microsoft.management/managementgroups' 
| extend mgParent = properties.details.managementGroupAncestorsChain 
| mv-expand with_itemindex=MGHierarchy mgParent 
| project id, name, properties.displayName, mgParent, MGHierarchy, mgParent.name 
| sort by MGHierarchy asc
"@

  $Query | Query-AzResourceGraph -QueryScope "Tenant"


################################################################################
# Login with Azure App/Secret for unattended mode
# Get RGs in tenant
################################################################################

    # Disconnect existing sessions
        Disconnect-AzAccount

    # Variables - optional, if you want unattended mode. Alternative script will prompt for login
        $AzAppId     = "xxx"
        $AzAppSecret = "xxxx"
        $TenantId    = "xxxx"

    AzRGs-Query-AzARG | Query-AzResourceGraph -QueryScope "Tenant" -AzAppId $AzAppId `
                                                                   -AzAppSecret $AzAppSecret `
                                                                   -TenantId $TenantId `
                                                                   -first 5

################################################################################
# Get all Azure Role Assignments under management group '2linkit'
################################################################################

    $RBAC_Assignments_raw = AzRoleAssignments-Query-AzARG | Query-AzResourceGraph -QueryScope "MG" -Target "2linkit"

    $RBAC_Assignments_raw | fl

    ($RBAC_Assignments_raw | Measure-Object).count

################################################################################
# Enrich Azure Role Assignments with DisplayName from Entra ID
################################################################################

    Connect-MicrosoftGraphPS -AppId $AzAppId `
                             -AppSecret $AzAppSecret `
                             -TenantId $TenantId

    # Get info from Entra ID
        $EntraID_Users             = Get-MgUser-AllProperties-AllUsers

        Write-host "Getting Groups from Entra ID ... Please Wait !"
        $EntraID_Groups            = Get-MgGroup -All:$true

        Write-host "Getting ServicePrincipals from Entra ID ... Please Wait !"
        $EntraID_serviceprincipals = Get-MgServicePrincipal -All:$true

    # loop through all assignments and add DisplayName - using lookup in data-array (users, groups, service principals)
        $AssignmentsCount = ($RBAC_Assignments_raw | Measure-Object).Count
        $ResultModified = @()

        $RBAC_Assignments_raw | ForEach-Object -Begin  {
                $i = 0
        } -Process {

                $DisplayName = $null
                $Entry = $_
                If ($Entry.roleAssignmentPrincipalType -eq "ServicePrincipal")
                    {
                        $Record = $EntraID_serviceprincipals | Where-Object { ($_.Id -eq $Entry.roleAssignmentPrincipalId) -or ($_.AppId -eq $Entry.roleAssignmentPrincipalId) }
                        $DisplayName = $Record.DisplayName
                    }
                ElseIf ($Entry.roleAssignmentPrincipalType -eq "Group")
                    {
                        $Record = $EntraID_Groups | Where-Object { $_.Id -eq $Entry.roleAssignmentPrincipalId }
                        $DisplayName = $Record.DisplayName
                    }
                ElseIf ($Entry.roleAssignmentPrincipalType -eq "User")
                    {
                        $Record = $EntraID_Users | Where-Object { $_.Id -eq $Entry.roleAssignmentPrincipalId }
                        $DisplayName = $Record.DisplayName
                    }

                $Entry | add-member Noteproperty -name roleAssignmentPrincipalDisplayName -Value $DisplayName -force
                $ResultModified += $Entry

                # Increment the $i counter variable which is used to create the progress bar.
                $i = $i+1

                # Determine the completion percentage
                $Completed = ($i/$AssignmentsCount) * 100
                Write-Progress -Activity "Enriching RBAC assignments with DisplayName" -Status "Progress:" -PercentComplete $Completed
        } -End {
            $RBAC_Assignments = $ResultModified
            Write-Progress -Activity "RBAC Assignments Enriched with DisplayName" -Status "Ready" -Completed
        }

    $RBAC_Assignments | Select-Object roleAssignmentScope,roleAssignmentPrincipalDisplayName,roleName,roleType,roleAssignmentCreatedOn | Select-Object -First 5

    $RBAC_Assignments | Select-Object roleAssignmentScope,roleAssignmentPrincipalDisplayName,roleName,roleType,roleAssignmentCreatedOn | Select-Object -First 15 | ft


################################################################################
# FINAL Solution | Enriched Azure Role Assignments (unattended mode)
################################################################################

    # Disconnect existing sessions in Azure
        Disconnect-AzAccount

    # Variables - optional, if you want unattended mode. Alternative script will prompt for login
        $AzAppId     = "7602a1ec-6234-4275-ac96-ce5fa4589d1a"
        $AzAppSecret = "ZrG8Q~nfLRVVMdR34ws4jUV3nYkOwrgkf7iClbUO"
        $TenantId    = "f0fa27a0-8e7c-4f63-9a77-ec94786b7c9e"

    # connect to Microsoft Graph
        Connect-MicrosoftGraphPS -AppId $AzAppId `
                                 -AppSecret $AzAppSecret `
                                 -TenantId $TenantId

    # Get all Azure Role Assignments under management group '2linkit' - incl. login with Azure app
        $RBAC_Assignments_raw = AzRoleAssignments-Query-AzARG | Query-AzResourceGraph -QueryScope "Tenant" `
                                                                                      -AzAppId $AzAppId `
                                                                                      -AzAppSecret $AzAppSecret `
                                                                                      -TenantId $TenantId
        $RBAC_Assignments_raw.count

    # Get info from Entra ID
        $EntraID_Users             = Get-MgUser-AllProperties-AllUsers

        Write-host "Getting Groups from Entra ID ... Please Wait !"
        $EntraID_Groups            = Get-MgGroup -All:$true

        Write-host "Getting ServicePrincipals from Entra ID ... Please Wait !"
        $EntraID_serviceprincipals = Get-MgServicePrincipal -All:$true

    # loop through all assignments and add DisplayName - using lookup in data-array (users, groups, service principals)
        $AssignmentsCount = ($RBAC_Assignments_raw | Measure-Object).Count
        $ResultModified = @()

        $RBAC_Assignments_raw | ForEach-Object -Begin  {
                $i = 0
        } -Process {

                $DisplayName = $null
                $Entry = $_
                If ($Entry.roleAssignmentPrincipalType -eq "ServicePrincipal")
                    {
                        $Record = $EntraID_serviceprincipals | Where-Object { ($_.Id -eq $Entry.roleAssignmentPrincipalId) -or ($_.AppId -eq $Entry.roleAssignmentPrincipalId) }
                        $DisplayName = $Record.DisplayName
                    }
                ElseIf ($Entry.roleAssignmentPrincipalType -eq "Group")
                    {
                        $Record = $EntraID_Groups | Where-Object { $_.Id -eq $Entry.roleAssignmentPrincipalId }
                        $DisplayName = $Record.DisplayName
                    }
                ElseIf ($Entry.roleAssignmentPrincipalType -eq "User")
                    {
                        $Record = $EntraID_Users | Where-Object { $_.Id -eq $Entry.roleAssignmentPrincipalId }
                        $DisplayName = $Record.DisplayName
                    }

                $Entry | add-member Noteproperty -name roleAssignmentPrincipalDisplayName -Value $DisplayName -force
                $ResultModified += $Entry

                # Increment the $i counter variable which is used to create the progress bar.
                $i = $i+1

                # Determine the completion percentage
                $Completed = ($i/$AssignmentsCount) * 100
                Write-Progress -Activity "Enriching RBAC assignments with DisplayName" -Status "Progress:" -PercentComplete $Completed
        } -End {
            $RBAC_Assignments = $ResultModified
            Write-Progress -Activity "RBAC Assignments Enriched with DisplayName" -Status "Ready" -Completed
        }


    $RBAC_Assignments | Select-Object roleAssignmentScope,roleAssignmentPrincipalDisplayName,roleName,roleType,roleAssignmentCreatedOn | Select-Object -First 5

    $RBAC_Assignments | Select-Object roleAssignmentScope,roleAssignmentPrincipalDisplayName,roleName,roleType,roleAssignmentCreatedOn | Select-Object -First 15 | ft

    Write-host "Number of RBAC Role Assignments processed"
    ($RBAC_Assignments | Measure-Object).count

    $RBAC_Assignments | Select-Object roleAssignmentScope,roleAssignmentPrincipalDisplayName,roleName,roleType,roleAssignmentCreatedOn | Select-Object -First 10
