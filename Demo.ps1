#Requires -Version 5.1

<#
    .NAME
    ClientInspector

    .SYNOPSIS
    This script will collect lots of information from the client - and send the data Azure LogAnalytics Custom Tables.
    The upload happens via Log Ingestion API, Azure Data Collection Rules (DCR) and Azure Data Collection Endpoints.
    
    The script collects the following information (settings, information, configuration, state):
        (1)   User Logged On to Client
        (2)   Computer information - bios, processor, hardware info, Windows OS info, OS information, last restart
        (3)   Installed applications, both using WMI and registry
        (4)   Antivirus Security Center from Windows - default antivirus, state, configuration
        (5)   Microsoft Defender Antivirus - all settings including ASR, exclusions, realtime protection, etc
        (6)   Office - version, update channel config, SKUs
        (7)   VPN client - version, product
        (8)   LAPS - version
        (9)   Admin By Request (3rd party) - version
        (10)  Windows Update - last result (when), windows update source information (where), pending updates, last installations (what)
        (11)  Bitlocker - configuration
        (12)  Eventlog - look for specific events including logon events, blue screens, etc.
        (13)  Network adapters - configuration, installed adapters
        (14)  IP information for all adapters
        (15)  Local administrators group membership
        (16)  Windows firewall - settings for all 3 modes
        (17)  Group Policy - last refresh
        (18)  TPM information - relavant to detect machines with/without TPM
    
    .AUTHOR
    Morten Knudsen, Microsoft MVP - https://mortenknudsen.net

    .LICENSE
    Licensed under the MIT license.

    .PROJECTURI
    https://github.com/KnudsenMorten/ClientInspectorV2

    .EXAMPLE
    .\ClientInspector.ps1 -function:localpath

    .EXAMPLE
    .\ClientInspector.ps1 -function:download

    .EXAMPLE
    .\ClientInspector.ps1 -function:localpath -verbose:$true

    .EXAMPLE
    .\ClientInspector.ps1 -verbose:$false -function:psgallery -Scope:currentuser

    .WARRANTY
    Use at your own risk, no warranty given!
#>

param(
      [parameter(Mandatory=$false)]
          [ValidateSet("Download","LocalPath","DevMode","PsGallery")]
          [string]$Function = "PsGallery",        # it will default to download if not specified
      [parameter(Mandatory=$false)]
          [ValidateSet("CurrentUser","AllUsers")]
          [string]$Scope = "CurrentUser"        # it will default to download if not specified
     )

Write-Output ""
Write-Output "ClientInspector | Inventory of Operational & Security-related information"
Write-Output "Developed by Morten Knudsen, Microsoft MVP"
Write-Output ""
  

############################################################################################################################################
# FUNCTIONS
############################################################################################################################################

    $PowershellVersion  = [version]$PSVersionTable.PSVersion
    If ([Version]$PowershellVersion -ge "5.1")
        {
            $PS_WMF_Compliant  = $true
            $EnableUploadViaLogHub  = $false
        }
    Else
        {
            $PS_WMF_Compliant  = $false
            $EnableUploadViaLogHub  = $true
            Import-module "$($LogHubPsModulePath)\AzResourceGraphPS.psm1" -Global -force -DisableNameChecking  -WarningAction SilentlyContinue
        }

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
                }
            "LocalPath"        # Typucaly used in ConfigMgr environment (or similar) where you run the script locally
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
                         -First 5
                          

# AzSubscriptions (Subscriptions)
    KQL-ARG-AzSubscriptions | Query-AzureResourceGraph -Scope "Tenant" `

    KQL-ARG-AzSubscriptions | Query-AzureResourceGraph -Scope "MG" `
                                                       -ScopeTarget "2linkit" `

# AzRoleAssignments (Role Assignments)
    KQL-ARG-AzRoleAssignments | Query-AzureResourceGraph -Scope "MG" `
                                                         -ScopeTarget "2linkit"

# AzMGsWithParentHierarchy (Management Group)
    KQL-ARG-AzMGsWithParentHierarchy | Query-AzureResourceGraph -Scope "MG" `
                                                                -ScopeTarget "2linkit" `
                                                                -Skip 3

    KQL-ARG-AzMGsWithParentHierarchy | Query-AzureResourceGraph -Scope "MG" `
                                                                -ScopeTarget "2linkit" `
                                                                -First 3

    KQL-ARG-AzMGsWithParentHierarchy | Query-AzureResourceGraph -Scope "MG" `
                                                                -ScopeTarget "2linkit"

    KQL-ARG-AzMGsWithParentHierarchy | Query-AzureResourceGraph -Scope "Tenant"

