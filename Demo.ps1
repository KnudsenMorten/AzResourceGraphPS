Write-Output ""
Write-Output "AzResourceGraphPS | DEMO"
Write-Output "Developed by Morten Knudsen, Microsoft MVP"
Write-Output ""
  
############################################################################################################################################
# MAIN PROGRAM
############################################################################################################################################

#---------------------------------------------------------------------------------------------                          
# Azure Management Group - with parent/Hierarchy
#---------------------------------------------------------------------------------------------                          

$Query = @"
    resourcecontainers 
    | where type == 'microsoft.management/managementgroups' 
    | extend mgParent = properties.details.managementGroupAncestorsChain 
    | mv-expand with_itemindex=MGHierarchy mgParent 
    | project id, name, properties.displayName, mgParent, MGHierarchy, mgParent.name 
    | sort by MGHierarchy asc
"@

    $Query | Query-AzResourceGraph -QueryScope "Tenant"

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

    $Query | Query-AzResourceGraph -QueryScope "Tenant"


$Test = AzMGsWithParentHierarchy-Query-AzARG | Query-AzResourceGraph -QueryScope "MG" `
                                                                     -Target "2linkit"
$test | fl

        #---------------------------------------------------------------------------------------------                          
        # Show query only
        #---------------------------------------------------------------------------------------------                          
            AzMGsWithParentHierarchy-Query-AzARG | Query-AzResourceGraph -ShowQueryOnly
    
        #---------------------------------------------------------------------------------------------                          
        # Get RGs from tenant - show only first 5
        #---------------------------------------------------------------------------------------------                          
            AzRGs-Query-AzARG | Query-AzResourceGraph -QueryScope "Tenant" -First 5

        #---------------------------------------------------------------------------------------------                          
        # Get all RGs from tenant - Unattended login with AzApp & AzSecret - show only first 5
        #---------------------------------------------------------------------------------------------                          

            # Variables - optional, if you want unattended mode. Alternative script will prompt for login
                $AzAppId     = "xxxx"
                $AzAppSecret = "xxxx"
                $TenantId    = "xxxx"


            # Disconnect existing sessions
                Disconnect-AzAccount

            AzRGs-Query-AzARG | Query-AzResourceGraph -QueryScope "Tenant" -AzAppId $AzAppId `
                                                                           -AzAppSecret $AzAppSecret `
                                                                           -TenantId $TenantId `
                                                                           -First 5

        #---------------------------------------------------------------------------------------------                          
        # Get all RGs from tenant - First 2
        #---------------------------------------------------------------------------------------------                          
            AzRGs-Query-AzARG | Query-AzResourceGraph -QueryScope "Tenant" -First 2

            AzRGs-Query-AzARG | Query-AzResourceGraph -QueryScope "Tenant" -Skip 3

        #---------------------------------------------------------------------------------------------                          
        # Get all management groups from tenant - format table
        #---------------------------------------------------------------------------------------------                          
            $Result = AzMGsWithParentHierarchy-Query-AzARG | Query-AzResourceGraph -QueryScope "Tenant"
            $Result | ft

        #---------------------------------------------------------------------------------------------                          
        # Get all management groups under management group '2linkit' (including itself)
        #---------------------------------------------------------------------------------------------                          
            AzMGsWithParentHierarchy-Query-AzARG | Query-AzResourceGraph -QueryScope "MG" `
                                                                         -Target "2linkit"

        #---------------------------------------------------------------------------------------------                          
        # Get all management groups under management group '2linkit' - skip first 3
        #---------------------------------------------------------------------------------------------                          
            AzMGsWithParentHierarchy-Query-AzARG | Query-AzResourceGraph -QueryScope "MG" `
                                                                         -Target "2linkit" `
                                                                         -Skip 3

        #---------------------------------------------------------------------------------------------                          
        # Get all management groups under management group '2linkit' - only show first 3
        #---------------------------------------------------------------------------------------------                          
            AzMGsWithParentHierarchy | Query-AzResourceGraph -QueryScope "MG" `
                                                                     -Target "2linkit" `
                                                                     -First 3


    #---------------------------------------------------------------------------------------------                          
    # Azure Subscriptions
    #---------------------------------------------------------------------------------------------                          

        #---------------------------------------------------------------------------------------------                          
        # Get all Azure Subscriptions from tenant
        #---------------------------------------------------------------------------------------------                          
            AzSubscriptions-Query-AzARG | Query-AzResourceGraph -QueryScope "Tenant" `

        #---------------------------------------------------------------------------------------------                          
        # Get all Azure Subscriptions under management group '2linkit'
        #---------------------------------------------------------------------------------------------                          
            AzSubscriptions-Query-AzARG | Query-AzResourceGraph -QueryScope "MG" `
                                                                -Target "2linkit" `

    #---------------------------------------------------------------------------------------------                          
    # Azure Role Assignments
    #---------------------------------------------------------------------------------------------                          

        #---------------------------------------------------------------------------------------------                          
        # Get all Azure Role Assignments under management group '2linkit'
        #---------------------------------------------------------------------------------------------                          
            AzRoleAssignments-Query-AzARG | Query-AzResourceGraph -QueryScope "MG" `
                                                                  -Target "2linkit"

        #---------------------------------------------------------------------------------------------                          
        # Get all Azure Role Assignments under management group '2linkit' - show only first 5
        #---------------------------------------------------------------------------------------------                          
            AzRoleAssignments-Query-AzARG | Query-AzResourceGraph -QueryScope "MG" `
                                                                  -Target "2linkit" `
                                                                  -First 5

    #---------------------------------------------------------------------------------------------                          
    # Azure Resource Groups
    #---------------------------------------------------------------------------------------------                          

        #---------------------------------------------------------------------------------------------                          
        # Get all Azure Resource Groups in specific subscription - show only first 5 RGs
        #---------------------------------------------------------------------------------------------                          
            AzRGs-Query-AzARG | Query-AzResourceGraph -QueryScope "Sub" `
                                                      -Target "fce4f282-fcc6-43fb-94d8-bf1701b862c3" `
                                                      -First 5

    #---------------------------------------------------------------------------------------------                          
    # Help from PS-module
    #---------------------------------------------------------------------------------------------                          

        #---------------------------------------------------------------------------------------------                          
        # If you want to see which cmdlets are available by the version of the module, you can run the get-command
        #---------------------------------------------------------------------------------------------                          
            get-command -module AzResourceGraphPS -All


        #---------------------------------------------------------------------------------------------                          
        # Get help with a specific cmdlet with the command get-help Query-AzResourceGraph -full
        #---------------------------------------------------------------------------------------------                          
            get-help Query-AzResourceGraph -full
