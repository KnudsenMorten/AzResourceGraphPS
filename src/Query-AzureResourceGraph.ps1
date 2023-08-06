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
    You can choose between MG, Tenant or Subscription 
    If you don't choose Scope, then tenant is default.

    .PARAMETER Target
    Syntax if you chose -QueryScope MG
    You will need to define -Target <mg-name> (Ex: -Target mg-2linkit)
    This MG will be the root for query and all sub-MGs will be included
    
    Syntax if you chose -QueryScope SubScription:
    You will need to define -Target <subscription name or id> (Ex: -Target MySub)

    Syntax if you chose -QueryScope Tenant:
    Search will automatically be done in entire tenant, part of context

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


    # Select from list of pre-defined queries - output to $results
        $result = Query-AzResourceGraph -SelectQuery

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

            [Parameter(ValueFromPipeline = $true)]
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
    Write-host "------------------------------------------------------------------------"
    Write-Host "AzResourceGraphPS | Unleash the Power of Azure Resource Graph" -ForegroundColor Green
    Write-host "Developed by Morten Knudsen, Microsoft MVP (@knudsenmortendk)"
    Write-Host ""
    Write-host "Github repository: https://github.com/KnudsenMorten/AzResourceGraphPS"
    Write-host "PS Gallery: https://www.powershellgallery.com/packages/AzResourceGraphPS"
    Write-host "------------------------------------------------------------------------"
    Write-host ""


    #--------------------------------------------------------------------------
    # Check Prereq for PS Module
    #--------------------------------------------------------------------------

        If ($InstallAutoUpdateCleanupOldVersions -eq $true)
            {

                Write-host "Checking PS modules ... Please Wait !"
                Write-host ""

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
                            
                                        Update-module $Module -Force
                                        import-module -Name $Module -Global -force -DisableNameChecking  -WarningAction SilentlyContinue
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
                            
                                        Update-module $Module -Force
                                        import-module -Name $Module -Global -force -DisableNameChecking  -WarningAction SilentlyContinue
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

        If ( ($QueryScope -eq "MG") -and (([string]::IsNullOrWhitespace($Target))) )
            {
                Write-host ""
                Write-host "Syntax Error: When parameter QueryScope is [MG], you also need to define -Target <MG Name>" -ForegroundColor Red
                Break
            }

        If ( ($QueryScope -eq "Subscription") -and (([string]::IsNullOrWhitespace($Target))) )
            {
                Write-host ""
                Write-host "Syntax Error: When parameter QueryScope is [Subscription], you also need to define -Target <Subscription Name/Id>"  -ForegroundColor Red
                Break
            }

    #--------------------------------------------------------------------------
    # Connection
    #--------------------------------------------------------------------------

        # Check current AzContext
        $AzContext = Get-AzContext

        If ([string]::IsNullOrWhitespace($AzContext))
            {
                If ($AzAppId)
                    {
                        $AzAppSecretSecure = $AzAppSecret | ConvertTo-SecureString -AsPlainText -Force
                        $SecureCreds = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $AzAppId, $AzAppSecretSecure
                        Connect-AzAccount -ServicePrincipal -Credential $SecureCreds -Tenant $TenantId -WarningAction SilentlyContinue
                        $AzContext = Get-AzContext
                    }
                Else
                    {
                        Connect-AzAccount -WarningAction SilentlyContinue
                        $AzContext = Get-AzContext
                    }
            }


    #--------------------------------------------------------------------------
    # Select built-in queries using GUI
    #--------------------------------------------------------------------------

        If ( ($InstallAutoUpdateCleanupOldVersions -eq $false) -and ( ($SelectQuery) -or ([string]::IsNullOrWhitespace($Query)) -or ( ($ShowQueryOnly) -and ([string]::IsNullOrWhitespace($Query) ) ) ) )
            {
                $QueryCmdlets = Get-Command -Name "*-Query-AzARG" -ListImported | Sort-Object -Unique
                $QueryCmdletsArray = @()
                
                ForEach ($QueryCmdlet in $QueryCmdlets)
                    {
                        # Run the function
                        $QueryCmdletInfo = & $QueryCmdlet.Name -Details

                        # load cmdlet properties into memory
                        $QueryName       = $QueryCmdlet.Name

                        $Object = New-Object PSObject
                        $Object | add-member Noteproperty -name QueryName -Value $QueryName
                        $Object | add-member Noteproperty -name Query -Value $QueryCmdletInfo[0]
                        $Object | add-member Noteproperty -name QueryDescription -Value $QueryCmdletInfo[1]
                        $Object | add-member Noteproperty -name QueryCategory -Value $QueryCmdletInfo[2]
                        $Object | add-member Noteproperty -name QueryCredit -Value $QueryCmdletInfo[3]
                        $QueryCmdletsArray += $Object
                    }

                $SelectedQuery = $QueryCmdletsArray | select QueryName,QueryDescription,QueryCategory,QueryCredit | Out-GridView -Title 'Choose a predefined query' -PassThru

                If ($SelectedQuery)
                    {
                        Write-host "Selected Query:"
                        Write-host "$($SelectedQuery.QueryName)" -ForegroundColor Yellow
                        Write-host ""
                        Write-host "Query syntax (pipe result to screen):"
                        If ($Target)
                            {
                                Write-host "$($SelectedQuery.QueryName) | Query-AzResourceGraph -QueryScope $($QueryScope) -Target '$($Target)'" -ForegroundColor Yellow
                            }
                        Else
                            {
                                Write-host "$($SelectedQuery.QueryName) | Query-AzResourceGraph -QueryScope $($QueryScope)" -ForegroundColor Yellow
                            }
                        Write-host ""
                        Write-host "  - or -"
                        Write-host ""
                        Write-host "Query syntax (pipe result to variable `$Result):"
                        If ($Target)
                            {
                                Write-host "`$Result = $($SelectedQuery.QueryName) | Query-AzResourceGraph -QueryScope $($QueryScope) -Target '$($Target)'" -ForegroundColor Yellow
                            }
                        Else
                            {
                                Write-host "`$Result = $($SelectedQuery.QueryName) | Query-AzResourceGraph -QueryScope $($QueryScope)" -ForegroundColor Yellow
                            }
                        Write-host ""

                        # Run selected function to load query
                        $Query = & $SelectedQuery.QueryName
                    }
            }


    #--------------------------------------------------------------------------
    # Show Query Only
    #--------------------------------------------------------------------------
        If ( ($ShowQueryOnly) -and ($Query) )
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
    # First
    #--------------------------------------------------------------------------

        If ( ($First) -and ($Query) )
            {
                Write-host ""
                Write-host "Scoping - Only First Number of Records:"
                Write-host "$($First)" -ForegroundColor Yellow
                Write-host ""
            }


    #--------------------------------------------------------------------------
    # Skip
    #--------------------------------------------------------------------------

        If ( ($Skip) -and ($Query) )
            {
                Write-host ""
                Write-host "Scoping - Skip Number of Records:"
                Write-host "$($Skip)" -ForegroundColor Yellow
                Write-host ""
            }

    #--------------------------------------------------------------------------
    # Running Query and returning result
    #--------------------------------------------------------------------------

        If (!([string]::IsNullOrWhitespace($Query)))
            {
                Write-host "Query Scope:"
                Write-host "$($QueryScope)" -ForegroundColor Yellow
                Write-host ""
                If ($Target)
                    {
                        Write-host "Target:"
                        Write-host "$($Target)" -ForegroundColor Yellow
                        Write-host ""
                    }

                Write-host "Context Account:"
                Write-host "$($AzContext.Account)" -ForegroundColor Yellow
                Write-host ""
                Write-host "Context TenantId:"
                Write-host "$($AzContext.Tenant)" -ForegroundColor Yellow
                Write-host ""

                Write-host "Query, which will be run against Azure Resource Graph: "
                Write-host ""
                Write-host "$($Query)" -ForegroundColor Yellow
                Write-host ""
                Write-host "---------------------------------------------------------------------"
                Write-host ""
                Write-host "Running Query against Azure Resource Graph ... Please Wait !"

                $ReturnData   = @()
                $pageSize     = 1000
                $iteration    = 0

                $searchParams = @{
                                    Query = $Query
                             
                                    First = $pageSize
                                 }

                If ( ($QueryScope -eq "MG") -and ($Target) ) # Management group(s) to run query against
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
                ElseIf ( ($QueryScope -eq "Subscription") -and ($Target) ) # Subscription(s) to run query against
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
# MIIRgwYJKoZIhvcNAQcCoIIRdDCCEXACAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUn5ObTo5e4BzA80quRJ/dthE/
# Ww2ggg3jMIIG5jCCBM6gAwIBAgIQd70OA6G3CPhUqwZyENkERzANBgkqhkiG9w0B
# AQsFADBTMQswCQYDVQQGEwJCRTEZMBcGA1UEChMQR2xvYmFsU2lnbiBudi1zYTEp
# MCcGA1UEAxMgR2xvYmFsU2lnbiBDb2RlIFNpZ25pbmcgUm9vdCBSNDUwHhcNMjAw
# NzI4MDAwMDAwWhcNMzAwNzI4MDAwMDAwWjBZMQswCQYDVQQGEwJCRTEZMBcGA1UE
# ChMQR2xvYmFsU2lnbiBudi1zYTEvMC0GA1UEAxMmR2xvYmFsU2lnbiBHQ0MgUjQ1
# IENvZGVTaWduaW5nIENBIDIwMjAwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIK
# AoICAQDWQk3540/GI/RsHYGmMPdIPc/Q5Y3lICKWB0Q1XQbPDx1wYOYmVPpTI2AC
# qF8CAveOyW49qXgFvY71TxkkmXzPERabH3tr0qN7aGV3q9ixLD/TcgYyXFusUGcs
# JU1WBjb8wWJMfX2GFpWaXVS6UNCwf6JEGenWbmw+E8KfEdRfNFtRaDFjCvhb0N66
# WV8xr4loOEA+COhTZ05jtiGO792NhUFVnhy8N9yVoMRxpx8bpUluCiBZfomjWBWX
# ACVp397CalBlTlP7a6GfGB6KDl9UXr3gW8/yDATS3gihECb3svN6LsKOlsE/zqXa
# 9FkojDdloTGWC46kdncVSYRmgiXnQwp3UrGZUUL/obLdnNLcGNnBhqlAHUGXYoa8
# qP+ix2MXBv1mejaUASCJeB+Q9HupUk5qT1QGKoCvnsdQQvplCuMB9LFurA6o44EZ
# qDjIngMohqR0p0eVfnJaKnsVahzEaeawvkAZmcvSfVVOIpwQ4KFbw7MueovE3vFL
# H4woeTBFf2wTtj0s/y1KiirsKA8tytScmIpKbVo2LC/fusviQUoIdxiIrTVhlBLz
# pHLr7jaep1EnkTz3ohrM/Ifll+FRh2npIsyDwLcPRWwH4UNP1IxKzs9jsbWkEHr5
# DQwosGs0/iFoJ2/s+PomhFt1Qs2JJnlZnWurY3FikCUNCCDx/wIDAQABo4IBrjCC
# AaowDgYDVR0PAQH/BAQDAgGGMBMGA1UdJQQMMAoGCCsGAQUFBwMDMBIGA1UdEwEB
# /wQIMAYBAf8CAQAwHQYDVR0OBBYEFNqzjcAkkKNrd9MMoFndIWdkdgt4MB8GA1Ud
# IwQYMBaAFB8Av0aACvx4ObeltEPZVlC7zpY7MIGTBggrBgEFBQcBAQSBhjCBgzA5
# BggrBgEFBQcwAYYtaHR0cDovL29jc3AuZ2xvYmFsc2lnbi5jb20vY29kZXNpZ25p
# bmdyb290cjQ1MEYGCCsGAQUFBzAChjpodHRwOi8vc2VjdXJlLmdsb2JhbHNpZ24u
# Y29tL2NhY2VydC9jb2Rlc2lnbmluZ3Jvb3RyNDUuY3J0MEEGA1UdHwQ6MDgwNqA0
# oDKGMGh0dHA6Ly9jcmwuZ2xvYmFsc2lnbi5jb20vY29kZXNpZ25pbmdyb290cjQ1
# LmNybDBWBgNVHSAETzBNMEEGCSsGAQQBoDIBMjA0MDIGCCsGAQUFBwIBFiZodHRw
# czovL3d3dy5nbG9iYWxzaWduLmNvbS9yZXBvc2l0b3J5LzAIBgZngQwBBAEwDQYJ
# KoZIhvcNAQELBQADggIBAAiIcibGr/qsXwbAqoyQ2tCywKKX/24TMhZU/T70MBGf
# j5j5m1Ld8qIW7tl4laaafGG4BLX468v0YREz9mUltxFCi9hpbsf/lbSBQ6l+rr+C
# 1k3MEaODcWoQXhkFp+dsf1b0qFzDTgmtWWu4+X6lLrj83g7CoPuwBNQTG8cnqbmq
# LTE7z0ZMnetM7LwunPGHo384aV9BQGf2U33qQe+OPfup1BE4Rt886/bNIr0TzfDh
# 5uUzoL485HjVG8wg8jBzsCIc9oTWm1wAAuEoUkv/EktA6u6wGgYGnoTm5/DbhEb7
# c9krQrbJVzTHFsCm6yG5qg73/tvK67wXy7hn6+M+T9uplIZkVckJCsDZBHFKEUta
# ZMO8eHitTEcmZQeZ1c02YKEzU7P2eyrViUA8caWr+JlZ/eObkkvdBb0LDHgGK89T
# 2L0SmlsnhoU/kb7geIBzVN+nHWcrarauTYmAJAhScFDzAf9Eri+a4OFJCOHhW9c4
# 0Z4Kip2UJ5vKo7nb4jZq42+5WGLgNng2AfrBp4l6JlOjXLvSsuuKy2MIL/4e81Yp
# 4jWb2P/ppb1tS1ksiSwvUru1KZDaQ0e8ct282b+Awdywq7RLHVg2N2Trm+GFF5op
# ov3mCNKS/6D4fOHpp9Ewjl8mUCvHouKXd4rv2E0+JuuZQGDzPGcMtghyKTVTgTTc
# MIIG9TCCBN2gAwIBAgIMeWPZY2rjO3HZBQJuMA0GCSqGSIb3DQEBCwUAMFkxCzAJ
# BgNVBAYTAkJFMRkwFwYDVQQKExBHbG9iYWxTaWduIG52LXNhMS8wLQYDVQQDEyZH
# bG9iYWxTaWduIEdDQyBSNDUgQ29kZVNpZ25pbmcgQ0EgMjAyMDAeFw0yMzAzMjcx
# MDIxMzRaFw0yNjAzMjMxNjE4MThaMGMxCzAJBgNVBAYTAkRLMRAwDgYDVQQHEwdL
# b2xkaW5nMRAwDgYDVQQKEwcybGlua0lUMRAwDgYDVQQDEwcybGlua0lUMR4wHAYJ
# KoZIhvcNAQkBFg9tb2tAMmxpbmtpdC5uZXQwggIiMA0GCSqGSIb3DQEBAQUAA4IC
# DwAwggIKAoICAQDMpI1rTOoWOSET3lSFQfsl/t83DCUEdoI02fNS5xlURPeGZNhi
# xQMKrhmFrdbIaEx01eY+hH9gF2AQ1ZDa7orCVSde1LDBnbFPLqcHWW5RWyzcy8Pq
# gV1QvzlFbmvTNHLm+wn1DZJ/1qJ+A+4uNUMrg13WRTiH0YWd6pwmAiQkoGC6FFwE
# usXotrT5JJNcPGlxBccm8su3kakI5B6iEuTeKh92EJM/km0pc/8o+pg+uR+f07Pp
# WcV9sS//JYCSLaXWicfrWq6a7/7U/vp/Wtdz+d2DcwljpsoXd++vuwzF8cUs09uJ
# KtdyrN8Z1DxqFlMdlD0ZyR401qAX4GO2XdzH363TtEBKAwvV+ReW6IeqGp5FUjnU
# j0RZ7NPOSiPr5G7d23RutjCHlGzbUr+5mQV/IHGL9LM5aNHsu22ziVqImRU9nwfq
# QVb8Q4aWD9P92hb3jNcH4bIWiQYccf9hgrMGGARx+wd/vI+AU/DfEtN9KuLJ8rNk
# LfbXRSB70le5SMP8qK09VjNXK/i6qO+Hkfh4vfNnW9JOvKdgRnQjmNEIYWjasbn8
# GyvoFVq0GOexiF/9XFKwbdGpDLJYttfcVZlBoSMPOWRe8HEKZYbJW1McjVIpWPnP
# d6tW7CBY2jp4476OeoPpMiiApuc7BhUC0VWl1Ei2PovDUoh/H3euHrWqbQIDAQAB
# o4IBsTCCAa0wDgYDVR0PAQH/BAQDAgeAMIGbBggrBgEFBQcBAQSBjjCBizBKBggr
# BgEFBQcwAoY+aHR0cDovL3NlY3VyZS5nbG9iYWxzaWduLmNvbS9jYWNlcnQvZ3Nn
# Y2NyNDVjb2Rlc2lnbmNhMjAyMC5jcnQwPQYIKwYBBQUHMAGGMWh0dHA6Ly9vY3Nw
# Lmdsb2JhbHNpZ24uY29tL2dzZ2NjcjQ1Y29kZXNpZ25jYTIwMjAwVgYDVR0gBE8w
# TTBBBgkrBgEEAaAyATIwNDAyBggrBgEFBQcCARYmaHR0cHM6Ly93d3cuZ2xvYmFs
# c2lnbi5jb20vcmVwb3NpdG9yeS8wCAYGZ4EMAQQBMAkGA1UdEwQCMAAwRQYDVR0f
# BD4wPDA6oDigNoY0aHR0cDovL2NybC5nbG9iYWxzaWduLmNvbS9nc2djY3I0NWNv
# ZGVzaWduY2EyMDIwLmNybDATBgNVHSUEDDAKBggrBgEFBQcDAzAfBgNVHSMEGDAW
# gBTas43AJJCja3fTDKBZ3SFnZHYLeDAdBgNVHQ4EFgQUMcaWNqucqymu1RTg02YU
# 3zypsskwDQYJKoZIhvcNAQELBQADggIBAHt/DYGUeCFfbtuuP5/44lpR2wbvOO49
# b6TenaL8TL3VEGe/NHh9yc3LxvH6PdbjtYgyGZLEooIgfnfEo+WL4fqF5X2BH34y
# EAsHCJVjXIjs1mGc5fajx14HU52iLiQOXEfOOk3qUC1TF3NWG+9mezho5XZkSMRo
# 0Ypg7Js2Pk3U7teZReCJFI9FSYa/BT2DnRFWVTlx7T5lIz6rKvTO1qQC2G3NKVGs
# HMtBTjsF6s2gpOzt7zF3o+DsnJukQRn0R9yTzgrx9nXYiHz6ti3HuJ4U7i7ILpgS
# RNrzmpVXXSH0wYxPT6TLm9eZR8qdZn1tGSb1zoIT70arnzE90oz0x7ej1fC8IUA/
# AYhkmfa6feI7OMU5xnsUjhSiyzMVhD06+RD3t5JrbKRoCgqixGb7DGM+yZVjbmhw
# cvr3UGVld9++pbsFeCB3xk/tcMXtBPdHTESPvUjSCpFbyldxVLU6GVIdzaeHAiBy
# S0NXrJVxcyCWusK41bJ1jP9zsnnaUCRERjWF5VZsXYBhY62NSOlFiCNGNYmVt7fi
# b4V6LFGoWvIv2EsWgx/uR/ypWndjmV6uBIN/UMZAhC25iZklNLFGDZ5dCUxLuoyW
# PVCTBYpM3+bN6dmbincjG0YDeRjTVfPN5niP1+SlRwSQxtXqYoDHq+3xVzFWVBqC
# NdoiM/4DqJUBMYIDCjCCAwYCAQEwaTBZMQswCQYDVQQGEwJCRTEZMBcGA1UEChMQ
# R2xvYmFsU2lnbiBudi1zYTEvMC0GA1UEAxMmR2xvYmFsU2lnbiBHQ0MgUjQ1IENv
# ZGVTaWduaW5nIENBIDIwMjACDHlj2WNq4ztx2QUCbjAJBgUrDgMCGgUAoHgwGAYK
# KwYBBAGCNwIBDDEKMAigAoAAoQKAADAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIB
# BDAcBgorBgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQU
# WXocxB8lhp2PgSsaNCawn6c/8gYwDQYJKoZIhvcNAQEBBQAEggIAqLcqkkDE5s6f
# 5S54NLgJzj4cp5zWz9OTbxWsTd5Sr98YXLjzAwVA3Ki4j9MfMRj9FgKRHLNwotk7
# nXWo5K5tTHjjuwDvisYywJldVQmjSdxRe/deN0Vj0tsPHciHNyGyEzgzZAmMxqIH
# PlmaMYj7xTQpfXn/5boC/cN4P+8w1A4uXS2tsWMIwztRYpebJJLxaMyrtxh/kDRD
# XxQhaKpM9QkttXMkzafsPvwqkAVvBQskRnBzEWo7phmIm8wgxOf9YK6euQtZKEpd
# GiywzZoUFAFpB89AdAAbcJ+GAwYzp2WhauPzn+LCW3eXYdaSAJ5KIYj1P9lr22+O
# XZPijVIZhH7dgH4ZDxf9RAMFG1rFhTm+VYCmkSqLKjEThzjWojF9g0+RNmRjDz/O
# Y77T1nnr3ynbL30gdF+wR/1EcG81WT6aLguQh0SVeAbrBr2WBnTU2sEm9fI9r6CG
# 4PRUAEuf0HGU/EapHqjeBNyPd8KdDqEXDnvOtGSP3tWbdjKorBXJSF14syToQx95
# 9cSyRp8BwLdtKeT4Napwt6qOYGDNo/8wNpYj6AW9/vEFnfYrY1oWJqUgFJ1JRQ2s
# R8syf2X2gcScHPW1XUo61GfsI5cYaipQsQ5H1eIw06sDOO6UdJHBP6Mn003x5iJR
# btsr3dUvUmcJ+KOjwWKOv9helRPy/Xo=
# SIG # End signature block
