#Requires -Version 5.1

<#
    .NAME
    AzResourceGraph-Demo

    .SYNOPSIS
    This script will demonstrate how you can retrieve data from Azure Resource Graph using pre-defined queries.
    
    .AUTHOR
    Morten Knudsen, Microsoft MVP - https://mortenknudsen.net

    .LICENSE
    Licensed under the MIT license.

    .PROJECTURI
    https://github.com/KnudsenMorten/AzResourceGraphPS

    .EXAMPLE

    .WARRANTY
    Use at your own risk, no warranty given!
#>

param(
      [parameter(Mandatory=$false)]
          [ValidateSet("Download","LocalPath","DevMode","PsGallery")]
          [string]$Function = "PsGallery",        # it will default to download if not specified
      [parameter(Mandatory=$false)]
          [ValidateSet("CurrentUser","AllUsers")]
          [string]$Scope = "AllUsers"        # it will default to download if not specified
     )

Write-Output ""
Write-Output "AzResourceGraphPS | DEMO"
Write-Output "Developed by Morten Knudsen, Microsoft MVP"
Write-Output ""
  

############################################################################################################################################
# FUNCTIONS
############################################################################################################################################

    # directory where the script was started
    $ScriptDirectory = $PSScriptRoot

    switch ($Function)
        {   
            "Download"
                {
                    # force download using Github. This is needed for Intune remediations, since the functions library are large, and Intune only support 200 Kb at the moment
                    Write-Output "Downloading latest version of module AzResourceGraphPS from https://github.com/KnudsenMorten/AzResourceGraphPS"
                    Write-Output "into local path $($ScriptDirectory)"

                    # delete existing file if found to download newest version
                    If (Test-Path "$($ScriptDirectory)\AzResourceGraphPS.psm1")
                        {
                            Remove-Item -Path "$($ScriptDirectory)\AzResourceGraphPS.psm1"
                        }

                     # download newest version
                    $Download = (New-Object System.Net.WebClient).DownloadFile("https://raw.githubusercontent.com/KnudsenMorten/AzResourceGraphPS/main/AzResourceGraphPS.psm1", "$($ScriptDirectory)\AzResourceGraphPS.psm1")
                    
                    Start-Sleep -s 3
                    
                    # load file if found - otherwise terminate
                    If (Test-Path "$($ScriptDirectory)\AzResourceGraphPS.psm1")
                        {
                            Import-module "$($ScriptDirectory)\AzResourceGraphPS.psm1" -Global -force -DisableNameChecking  -WarningAction SilentlyContinue
                        }
                    Else
                        {
                            Write-Output "Powershell module AzResourceGraphPS was NOT found .... terminating !"
                            break
                        }
                }

            "PsGallery"
                {
                        #------------------------------------------------------------------------------------------------------
                        # check for AzResourceGraphPS
                            $ModuleCheck = Get-Module -Name AzResourceGraphPS -ListAvailable -ErrorAction SilentlyContinue
                            If (!($ModuleCheck))
                                {
                                    # check for NuGet package provider
                                    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

                                    Write-Output ""
                                    Write-Output "Checking Powershell PackageProvider NuGet ... Please Wait !"
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

                                    Write-Output "Powershell module AzResourceGraphPS was not found !"
                                    Write-Output "Installing latest version from PsGallery in scope $Scope .... Please Wait !"

                                    Install-module -Name AzResourceGraphPS -Repository PSGallery -Force -Scope $Scope
                                    import-module -Name AzResourceGraphPS -Global -force -DisableNameChecking  -WarningAction SilentlyContinue
                                }

                            Elseif ($ModuleCheck)
                                {
                                    # sort to get highest version, if more versions are installed
                                    $ModuleCheck = Sort-Object -Descending -Property Version -InputObject $ModuleCheck
                                    $ModuleCheck = $ModuleCheck[0]

                                    Write-Output "Checking latest version at PsGallery for AzResourceGraphPS module"
                                    $online = Find-Module -Name AzResourceGraphPS -Repository PSGallery

                                    #compare versions
                                    if ( ([version]$online.version) -gt ([version]$ModuleCheck.version) ) 
                                        {
                                            Write-Output "Newer version ($($online.version)) detected"
                                            Write-Output "Updating AzResourceGraphPS module .... Please Wait !"
                                            Update-module -Name AzResourceGraphPS -Force
                                            import-module -Name AzResourceGraphPS -Global -force -DisableNameChecking  -WarningAction SilentlyContinue
                                        }
                                    else
                                        {
                                            # No new version detected ... continuing !
                                            Write-Output "OK - Running latest version"
                                            $UpdateAvailable = $False
                                            import-module -Name AzResourceGraphPS -Global -force -DisableNameChecking  -WarningAction SilentlyContinue
                                        }
                                }

                        #------------------------------------------------------------------------------------------------------
                        # check for Az modules
                            $ModuleCheck = Get-Module -Name Az.* -ListAvailable -ErrorAction SilentlyContinue
                            If (!($ModuleCheck))
                                {
                                    Write-Output "Powershell module Az was not found !"
                                    Write-Output "Installing latest version from PsGallery in scope $Scope .... Please Wait !"

                                    Install-module -Name Az -Repository PSGallery -Force -Scope $Scope
                                    import-module -Name Az -Global -force -DisableNameChecking  -WarningAction SilentlyContinue
                                }

                        #------------------------------------------------------------------------------------------------------
                        # check for Az.ResourceGraph modules
                            $ModuleCheck = Get-Module -Name Az.ResourceGraph -ListAvailable -ErrorAction SilentlyContinue
                            If (!($ModuleCheck))
                                {
                                    Write-Output "Powershell module Az.ResourceGraph was not found !"
                                    Write-Output "Installing latest version from PsGallery in scope $Scope .... Please Wait !"

                                    Install-module -Name Az.ResourceGraph -Repository PSGallery -Force -Scope $Scope
                                    import-module -Name Az.ResourceGraph -Global -force -DisableNameChecking  -WarningAction SilentlyContinue
                                }
                        #------------------------------------------------------------------------------------------------------

                }
            "LocalPath"        # Typicaly used in ConfigMgr environment (or similar) where you run the script locally
                {
                    If (Test-Path "$($ScriptDirectory)\AzResourceGraphPS.psm1")
                        {
                            Write-Output "Using AzResourceGraphPS module from local path $($ScriptDirectory)"
                            Import-module "$($ScriptDirectory)\AzResourceGraphPS.psm1" -Global -force -DisableNameChecking  -WarningAction SilentlyContinue
                        }
                    Else
                        {
                            Write-Output "Required Powershell function was NOT found .... terminating !"
                            Exit
                        }
                }
        }


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

    $Query | Query-AzureResourceGraph -Scope "Tenant"

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

    $Query | Query-AzureResourceGraph -Scope "Tenant"

        #---------------------------------------------------------------------------------------------                          
        # Show query only
        #---------------------------------------------------------------------------------------------                          
            KQL-ARG-AzMGsWithParentHierarchy | Query-AzureResourceGraph -Scope "Tenant" -ShowQueryOnly
    
        #---------------------------------------------------------------------------------------------                          
        # Get all management groups from tenant - Unattended login with AzApp & AzSecret - show only first 5
        #---------------------------------------------------------------------------------------------                          

            # Variables - optional, if you want unattended mode. Alternative script will prompt for login
                $AzAppId     = "xxxx"
                $AzAppSecret = "xxxx"
                $TenantId    = "xxxx"


            # Disconnect existing sessions
                Disconnect-AzAccount

            KQL-ARG-AzMGsWithParentHierarchy | Query-AzureResourceGraph -Scope "Tenant" -AzAppId $AzAppId `
                                                                                        -AzAppSecret $AzAppSecret `
                                                                                        -TenantId $TenantId `
                                                                                        -First 5

        #---------------------------------------------------------------------------------------------                          
        # Get all management groups from tenant - Attended login with Prompt
        #---------------------------------------------------------------------------------------------                          
            # Disconnect existing sessions
            Disconnect-AzAccount

            KQL-ARG-AzMGsWithParentHierarchy | Query-AzureResourceGraph -Scope "Tenant" -First 5


        #---------------------------------------------------------------------------------------------                          
        # Get all management groups from tenant - format table
        #---------------------------------------------------------------------------------------------                          
            $Result = KQL-ARG-AzMGsWithParentHierarchy | Query-AzureResourceGraph -Scope "Tenant"
            $Result
            $Result | ft

        #---------------------------------------------------------------------------------------------                          
        # Get all management groups under management group '2linkit' (including itself)
        #---------------------------------------------------------------------------------------------                          
            KQL-ARG-AzMGsWithParentHierarchy | Query-AzureResourceGraph -Scope "MG" `
                                                                        -ScopeTarget "2linkit"

        #---------------------------------------------------------------------------------------------                          
        # Get all management groups under management group '2linkit' - skip first 3
        #---------------------------------------------------------------------------------------------                          
            KQL-ARG-AzMGsWithParentHierarchy | Query-AzureResourceGraph -Scope "MG" `
                                                                        -ScopeTarget "2linkit" `
                                                                        -Skip 3

        #---------------------------------------------------------------------------------------------                          
        # Get all management groups under management group '2linkit' - only show first 3
        #---------------------------------------------------------------------------------------------                          
            KQL-ARG-AzMGsWithParentHierarchy | Query-AzureResourceGraph -Scope "MG" `
                                                                        -ScopeTarget "2linkit" `
                                                                        -First 3


    #---------------------------------------------------------------------------------------------                          
    # Azure Subscriptions
    #---------------------------------------------------------------------------------------------                          

        #---------------------------------------------------------------------------------------------                          
        # Get all Azure Subscriptions from tenant
        #---------------------------------------------------------------------------------------------                          
            KQL-ARG-AzSubscriptions | Query-AzureResourceGraph -Scope "Tenant" `

        #---------------------------------------------------------------------------------------------                          
        # Get all Azure Subscriptions under management group '2linkit'
        #---------------------------------------------------------------------------------------------                          
            KQL-ARG-AzSubscriptions | Query-AzureResourceGraph -Scope "MG" `
                                                               -ScopeTarget "2linkit" `

    #---------------------------------------------------------------------------------------------                          
    # Azure Role Assignments
    #---------------------------------------------------------------------------------------------                          

        #---------------------------------------------------------------------------------------------                          
        # Get all Azure Role Assignments under management group '2linkit'
        #---------------------------------------------------------------------------------------------                          
            KQL-ARG-AzRoleAssignments | Query-AzureResourceGraph -Scope "MG" `
                                                                 -ScopeTarget "2linkit"

        #---------------------------------------------------------------------------------------------                          
        # Get all Azure Role Assignments under management group '2linkit' - show only first 5
        #---------------------------------------------------------------------------------------------                          
            KQL-ARG-AzRoleAssignments | Query-AzureResourceGraph -Scope "MG" `
                                                                 -ScopeTarget "2linkit" `
                                                                 -First 5

    #---------------------------------------------------------------------------------------------                          
    # Azure Resource Groups
    #---------------------------------------------------------------------------------------------                          

        #---------------------------------------------------------------------------------------------                          
        # Get all Azure Resource Groups in specific subscription - show only first 5 RGs
        #---------------------------------------------------------------------------------------------                          
            KQL-ARG-AzRGs | Query-AzureResourceGraph -Scope "Sub" `
                                                     -ScopeTarget "fce4f282-fcc6-43fb-94d8-bf1701b862c3" `
                                                     -First 5

    #---------------------------------------------------------------------------------------------                          
    # Help from PS-module
    #---------------------------------------------------------------------------------------------                          

        #---------------------------------------------------------------------------------------------                          
        # If you want to see which cmdlets are available by the version of the module, you can run the get-command
        #---------------------------------------------------------------------------------------------                          
            get-command -module AzResourceGraphPS -All

            <#
            CommandType     Name                                               Version    Source                                                   
            -----------     ----                                               -------    ------                                                   
            Function        KQL-ARG-AzAvailabilitySets                         0.5.6      AzResourceGraphPS                                        
            Function        KQL-ARG-AzBackupRecoveryServicesJobs               0.5.6      AzResourceGraphPS                                        
            Function        KQL-ARG-AzBackupRecoveryServicesProtectionItems    0.5.6      AzResourceGraphPS                                        
            Function        KQL-ARG-AzBackupRecoveryServicesVaults             0.5.6      AzResourceGraphPS                                        
            Function        KQL-ARG-AzDefenderForCloudDevicesWithoutTVM        0.5.6      AzResourceGraphPS                                        
            Function        KQL-ARG-AzDefenderForCloudPlans                    0.5.6      AzResourceGraphPS                                        
            Function        KQL-ARG-AzDefenderForCloudPlansStatus              0.5.6      AzResourceGraphPS                                        
            Function        KQL-ARG-AzDefenderForCloudRecommendationsSubAss... 0.5.6      AzResourceGraphPS                                        
            Function        KQL-ARG-AzDefenderForCloudRecommendationsWithLink  0.5.6      AzResourceGraphPS                                        
            Function        KQL-ARG-AzDefenderForCloudRecommendationsWithSu... 0.5.6      AzResourceGraphPS                                        
            Function        KQL-ARG-AzExtensionStatus                          0.5.6      AzResourceGraphPS                                        
            Function        KQL-ARG-AzHybridMachines                           0.5.6      AzResourceGraphPS                                        
            Function        KQL-ARG-AzHybridMachinesWithTags                   0.5.6      AzResourceGraphPS                                        
            Function        KQL-ARG-AzIPAddressAzNativeVMs                     0.5.6      AzResourceGraphPS                                        
            Function        KQL-ARG-AzMGs                                      0.5.6      AzResourceGraphPS                                        
            Function        KQL-ARG-AzMGsWithParentHierarchy                   0.5.6      AzResourceGraphPS                                        
            Function        KQL-ARG-AzMonitorDCEs                              0.5.6      AzResourceGraphPS                                        
            Function        KQL-ARG-AzMonitorDCRs                              0.5.6      AzResourceGraphPS                                        
            Function        KQL-ARG-AzNativeVMs                                0.5.6      AzResourceGraphPS                                        
            Function        KQL-ARG-AzNativeVMsHybridMachines                  0.5.6      AzResourceGraphPS                                        
            Function        KQL-ARG-AzNativeVMsWithDefenderForCloudPlanEnabled 0.5.6      AzResourceGraphPS                                        
            Function        KQL-ARG-AzNativeVMsWithTags                        0.5.6      AzResourceGraphPS                                        
            Function        KQL-ARG-AzResources                                0.5.6      AzResourceGraphPS                                        
            Function        KQL-ARG-AzResourcesWithTags                        0.5.6      AzResourceGraphPS                                        
            Function        KQL-ARG-AzResourceTypes                            0.5.6      AzResourceGraphPS                                        
            Function        KQL-ARG-AzRGs                                      0.5.6      AzResourceGraphPS                                        
            Function        KQL-ARG-AzRGsWithTags                              0.5.6      AzResourceGraphPS                                        
            Function        KQL-ARG-AzRoleAssignments                          0.5.6      AzResourceGraphPS                                        
            Function        KQL-ARG-AzStorageAccounts                          0.5.6      AzResourceGraphPS                                        
            Function        KQL-ARG-AzSubscriptions                            0.5.6      AzResourceGraphPS                                        
            Function        KQL-ARG-AzSubscriptionsWithTags                    0.5.6      AzResourceGraphPS                                        
            Function        Query-AzureResourceGraph                           0.5.6      AzResourceGraphPS  
            #>

        #---------------------------------------------------------------------------------------------                          
        # Get help with a specific cmdlet with the command get-help Query-AzureResourceGraph -full
        #---------------------------------------------------------------------------------------------                          
            get-help Query-AzureResourceGraph -full
