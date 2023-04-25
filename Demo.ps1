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
          [string]$Scope = "CurrentUser"        # it will default to download if not specified
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


############################################################################################################################################
# MAIN PROGRAM
############################################################################################################################################

Connect-AzAccount

#---------------------------------------------------------------------------------------------                          
# Azure Management Group - with parent/Hierarchy
#---------------------------------------------------------------------------------------------                          
    
    # Get all management groups from tenant
    KQL-ARG-AzMGsWithParentHierarchy | Query-AzureResourceGraph -Scope "Tenant"

    # Get all management groups from tenant - only show first 3
    KQL-ARG-AzMGsWithParentHierarchy | Query-AzureResourceGraph -Scope "Tenant" `
                                                                -First 3


    # Get all management groups from tenant - format table
    $Result = KQL-ARG-AzMGsWithParentHierarchy | Query-AzureResourceGraph -Scope "Tenant"
    $Result | ft


    # Get all management groups under management group '2linkit' (including itself)
    KQL-ARG-AzMGsWithParentHierarchy | Query-AzureResourceGraph -Scope "MG" `
                                                                -ScopeTarget "2linkit"

    # Get all management groups under management group '2linkit' - skip first 3
    KQL-ARG-AzMGsWithParentHierarchy | Query-AzureResourceGraph -Scope "MG" `
                                                                -ScopeTarget "2linkit" `
                                                                -Skip 3

    # Get all management groups under management group '2linkit' - only show first 3
    KQL-ARG-AzMGsWithParentHierarchy | Query-AzureResourceGraph -Scope "MG" `
                                                                -ScopeTarget "2linkit" `
                                                                -First 3


#---------------------------------------------------------------------------------------------                          
# Azure Subscriptions
#---------------------------------------------------------------------------------------------                          
    KQL-ARG-AzSubscriptions | Query-AzureResourceGraph -Scope "Tenant" `

    KQL-ARG-AzSubscriptions | Query-AzureResourceGraph -Scope "MG" `
                                                       -ScopeTarget "2linkit" `

#---------------------------------------------------------------------------------------------                          
# AzRoleAssignments (Role Assignments)
#---------------------------------------------------------------------------------------------                          
    KQL-ARG-AzRoleAssignments | Query-AzureResourceGraph -Scope "MG" `
                                                         -ScopeTarget "2linkit"

    KQL-ARG-AzRoleAssignments | Query-AzureResourceGraph -Scope "MG" `
                                                         -ScopeTarget "2linkit" `
                                                         -First 5
