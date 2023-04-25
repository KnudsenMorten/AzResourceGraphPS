Function Query-AzureResourceGraph
{
 <#
    .SYNOPSIS
    Runs the query against Azure Resource Graph and returns the result

    .DESCRIPTION
    You will pipe the query into function. Function will then run query against Azure Resource Graph, based on MG, Tenant or Subscription scope.

    .PARAMETER Scope
    You can choose between MG, Tenant or Subscription (or Sub as alias). If you don't choose Scope, then tenant is default.
    If you choose MG, you will define a MG, which will be the root for query and all sub-MGs will be included
    If you choose SUB, you will define a Subscription, which will be queried (only)
    If you choose Tenant, you will search the entire tenant

    .PARAMETER ScopeTarget
    If you choose MG, you will put in the mg-name like mg-2linkit. This MG will be the root for query and all sub-MGs will be included
    If you choose Subscription, you will put in the subscription-name or subscription-id
    If you choose Tenant, you will search the entire tenant and will NOT use ScopeTarget-parameter

    .INPUTS
    Yes, yu can pipe query data into function

    .OUTPUTS
    Results from Azure Resource Graph, based on the defined parameters.

    .LINK
    https://github.com/KnudsenMorten/AzResourceGraphPS

    .EXAMPLE
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


 #>

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
    Write-host "---------------------------------------------------------------------"
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
    ElseIf ( ($Scope -eq "Subscription") -or ($Scope -eq "Sub") ) # Subscription(s) to run query against
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

# SIG # Begin signature block
# MIIRgwYJKoZIhvcNAQcCoIIRdDCCEXACAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQU7wnFj2Ksr1ooifAiCOqtyXEC
# CEuggg3jMIIG5jCCBM6gAwIBAgIQd70OA6G3CPhUqwZyENkERzANBgkqhkiG9w0B
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
# 8N5Pm46XXRX0Y6P2XKH6Ioc90a4wDQYJKoZIhvcNAQEBBQAEggIAyu4GpEjXZzmk
# HeLLOOidAGq53YasPz6xQrDRa9WF4Y23/FMR5JyR3BR+OOHM3JzuxwIPOpRiJY7Y
# SJ/SGRVjpEtsyz0jxO2zBFWeLXGUkp5k9CUu63/WniBQyEMLSrP0xfA9Axuaow9b
# yBZd4iscuzsh6WTObJ/QaE1aPxsdDIVwyQ1pd6Dy6pgn5hxi8OzD0FLn9g6v4oBW
# i/aNnK3pYXjHTM3LjxplnO7zNOb5lmOtxeuRNyKYL8iqr2y5QoWJx2eiWnDL4gOK
# wb496qW07aG2+DSQz+XOTszFX0NavFt65r3Ogi8++NsR1vH/SLNnI0crkj6LV2b0
# 5IR9VZWNEXVqd/DJSmLI5zlwCjwDnbmd7ip8or6sSQ5jFFP6E+QITWaYYo4foQlg
# 1JhYgRMzF5gSAQVDhTMc1/pCCi/RatqPfiBSIN9xhDiUDgG0OBA9l7Lip5G09MAn
# j7m6AcVtum1gOgKmHHWvHk/48LEpCYoqls7Ot6ABf3IqXtuBA8HvMHrtPz3CH/dZ
# 7LqdIE4HB73fJKTHrim9pVkr/LQljF1XxKJfCPZ9a4JrVT+cg590iNbB39vpKMYR
# 6ZtDIlDXghcF3Cd70uSTk80MA5tTd5BYhg3TvfjEPF6d2MuFM/BbnweEz1kVTuUa
# owSqunOz9RwrETV/7DMGZ+62qBR4k3U=
# SIG # End signature block
