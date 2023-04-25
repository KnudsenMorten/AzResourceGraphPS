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



# SIG # Begin signature block
# MIIXHgYJKoZIhvcNAQcCoIIXDzCCFwsCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAV55/sNpGKmVBp
# B/Mdgvy5I3rjOjspvB0Tng2cVivNIaCCE1kwggVyMIIDWqADAgECAhB2U/6sdUZI
# k/Xl10pIOk74MA0GCSqGSIb3DQEBDAUAMFMxCzAJBgNVBAYTAkJFMRkwFwYDVQQK
# ExBHbG9iYWxTaWduIG52LXNhMSkwJwYDVQQDEyBHbG9iYWxTaWduIENvZGUgU2ln
# bmluZyBSb290IFI0NTAeFw0yMDAzMTgwMDAwMDBaFw00NTAzMTgwMDAwMDBaMFMx
# CzAJBgNVBAYTAkJFMRkwFwYDVQQKExBHbG9iYWxTaWduIG52LXNhMSkwJwYDVQQD
# EyBHbG9iYWxTaWduIENvZGUgU2lnbmluZyBSb290IFI0NTCCAiIwDQYJKoZIhvcN
# AQEBBQADggIPADCCAgoCggIBALYtxTDdeuirkD0DcrA6S5kWYbLl/6VnHTcc5X7s
# k4OqhPWjQ5uYRYq4Y1ddmwCIBCXp+GiSS4LYS8lKA/Oof2qPimEnvaFE0P31PyLC
# o0+RjbMFsiiCkV37WYgFC5cGwpj4LKczJO5QOkHM8KCwex1N0qhYOJbp3/kbkbuL
# ECzSx0Mdogl0oYCve+YzCgxZa4689Ktal3t/rlX7hPCA/oRM1+K6vcR1oW+9YRB0
# RLKYB+J0q/9o3GwmPukf5eAEh60w0wyNA3xVuBZwXCR4ICXrZ2eIq7pONJhrcBHe
# OMrUvqHAnOHfHgIB2DvhZ0OEts/8dLcvhKO/ugk3PWdssUVcGWGrQYP1rB3rdw1G
# R3POv72Vle2dK4gQ/vpY6KdX4bPPqFrpByWbEsSegHI9k9yMlN87ROYmgPzSwwPw
# jAzSRdYu54+YnuYE7kJuZ35CFnFi5wT5YMZkobacgSFOK8ZtaJSGxpl0c2cxepHy
# 1Ix5bnymu35Gb03FhRIrz5oiRAiohTfOB2FXBhcSJMDEMXOhmDVXR34QOkXZLaRR
# kJipoAc3xGUaqhxrFnf3p5fsPxkwmW8x++pAsufSxPrJ0PBQdnRZ+o1tFzK++Ol+
# A/Tnh3Wa1EqRLIUDEwIrQoDyiWo2z8hMoM6e+MuNrRan097VmxinxpI68YJj8S4O
# JGTfAgMBAAGjQjBAMA4GA1UdDwEB/wQEAwIBhjAPBgNVHRMBAf8EBTADAQH/MB0G
# A1UdDgQWBBQfAL9GgAr8eDm3pbRD2VZQu86WOzANBgkqhkiG9w0BAQwFAAOCAgEA
# Xiu6dJc0RF92SChAhJPuAW7pobPWgCXme+S8CZE9D/x2rdfUMCC7j2DQkdYc8pzv
# eBorlDICwSSWUlIC0PPR/PKbOW6Z4R+OQ0F9mh5byV2ahPwm5ofzdHImraQb2T07
# alKgPAkeLx57szO0Rcf3rLGvk2Ctdq64shV464Nq6//bRqsk5e4C+pAfWcAvXda3
# XaRcELdyU/hBTsz6eBolSsr+hWJDYcO0N6qB0vTWOg+9jVl+MEfeK2vnIVAzX9Rn
# m9S4Z588J5kD/4VDjnMSyiDN6GHVsWbcF9Y5bQ/bzyM3oYKJThxrP9agzaoHnT5C
# JqrXDO76R78aUn7RdYHTyYpiF21PiKAhoCY+r23ZYjAf6Zgorm6N1Y5McmaTgI0q
# 41XHYGeQQlZcIlEPs9xOOe5N3dkdeBBUO27Ql28DtR6yI3PGErKaZND8lYUkqP/f
# obDckUCu3wkzq7ndkrfxzJF0O2nrZ5cbkL/nx6BvcbtXv7ePWu16QGoWzYCELS/h
# AtQklEOzFfwMKxv9cW/8y7x1Fzpeg9LJsy8b1ZyNf1T+fn7kVqOHp53hWVKUQY9t
# W76GlZr/GnbdQNJRSnC0HzNjI3c/7CceWeQIh+00gkoPP/6gHcH1Z3NFhnj0qinp
# J4fGGdvGExTDOUmHTaCX4GUT9Z13Vunas1jHOvLAzYIwggbmMIIEzqADAgECAhB3
# vQ4DobcI+FSrBnIQ2QRHMA0GCSqGSIb3DQEBCwUAMFMxCzAJBgNVBAYTAkJFMRkw
# FwYDVQQKExBHbG9iYWxTaWduIG52LXNhMSkwJwYDVQQDEyBHbG9iYWxTaWduIENv
# ZGUgU2lnbmluZyBSb290IFI0NTAeFw0yMDA3MjgwMDAwMDBaFw0zMDA3MjgwMDAw
# MDBaMFkxCzAJBgNVBAYTAkJFMRkwFwYDVQQKExBHbG9iYWxTaWduIG52LXNhMS8w
# LQYDVQQDEyZHbG9iYWxTaWduIEdDQyBSNDUgQ29kZVNpZ25pbmcgQ0EgMjAyMDCC
# AiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBANZCTfnjT8Yj9GwdgaYw90g9
# z9DljeUgIpYHRDVdBs8PHXBg5iZU+lMjYAKoXwIC947Jbj2peAW9jvVPGSSZfM8R
# Fpsfe2vSo3toZXer2LEsP9NyBjJcW6xQZywlTVYGNvzBYkx9fYYWlZpdVLpQ0LB/
# okQZ6dZubD4Twp8R1F80W1FoMWMK+FvQ3rpZXzGviWg4QD4I6FNnTmO2IY7v3Y2F
# QVWeHLw33JWgxHGnHxulSW4KIFl+iaNYFZcAJWnf3sJqUGVOU/troZ8YHooOX1Re
# veBbz/IMBNLeCKEQJvey83ouwo6WwT/Opdr0WSiMN2WhMZYLjqR2dxVJhGaCJedD
# CndSsZlRQv+hst2c0twY2cGGqUAdQZdihryo/6LHYxcG/WZ6NpQBIIl4H5D0e6lS
# TmpPVAYqgK+ex1BC+mUK4wH0sW6sDqjjgRmoOMieAyiGpHSnR5V+cloqexVqHMRp
# 5rC+QBmZy9J9VU4inBDgoVvDsy56i8Te8UsfjCh5MEV/bBO2PSz/LUqKKuwoDy3K
# 1JyYikptWjYsL9+6y+JBSgh3GIitNWGUEvOkcuvuNp6nUSeRPPeiGsz8h+WX4VGH
# aekizIPAtw9FbAfhQ0/UjErOz2OxtaQQevkNDCiwazT+IWgnb+z4+iaEW3VCzYkm
# eVmda6tjcWKQJQ0IIPH/AgMBAAGjggGuMIIBqjAOBgNVHQ8BAf8EBAMCAYYwEwYD
# VR0lBAwwCgYIKwYBBQUHAwMwEgYDVR0TAQH/BAgwBgEB/wIBADAdBgNVHQ4EFgQU
# 2rONwCSQo2t30wygWd0hZ2R2C3gwHwYDVR0jBBgwFoAUHwC/RoAK/Hg5t6W0Q9lW
# ULvOljswgZMGCCsGAQUFBwEBBIGGMIGDMDkGCCsGAQUFBzABhi1odHRwOi8vb2Nz
# cC5nbG9iYWxzaWduLmNvbS9jb2Rlc2lnbmluZ3Jvb3RyNDUwRgYIKwYBBQUHMAKG
# Omh0dHA6Ly9zZWN1cmUuZ2xvYmFsc2lnbi5jb20vY2FjZXJ0L2NvZGVzaWduaW5n
# cm9vdHI0NS5jcnQwQQYDVR0fBDowODA2oDSgMoYwaHR0cDovL2NybC5nbG9iYWxz
# aWduLmNvbS9jb2Rlc2lnbmluZ3Jvb3RyNDUuY3JsMFYGA1UdIARPME0wQQYJKwYB
# BAGgMgEyMDQwMgYIKwYBBQUHAgEWJmh0dHBzOi8vd3d3Lmdsb2JhbHNpZ24uY29t
# L3JlcG9zaXRvcnkvMAgGBmeBDAEEATANBgkqhkiG9w0BAQsFAAOCAgEACIhyJsav
# +qxfBsCqjJDa0LLAopf/bhMyFlT9PvQwEZ+PmPmbUt3yohbu2XiVppp8YbgEtfjr
# y/RhETP2ZSW3EUKL2Glux/+VtIFDqX6uv4LWTcwRo4NxahBeGQWn52x/VvSoXMNO
# Ca1Za7j5fqUuuPzeDsKg+7AE1BMbxyepuaotMTvPRkyd60zsvC6c8YejfzhpX0FA
# Z/ZTfepB7449+6nUEThG3zzr9s0ivRPN8OHm5TOgvjzkeNUbzCDyMHOwIhz2hNab
# XAAC4ShSS/8SS0Dq7rAaBgaehObn8NuERvtz2StCtslXNMcWwKbrIbmqDvf+28rr
# vBfLuGfr4z5P26mUhmRVyQkKwNkEcUoRS1pkw7x4eK1MRyZlB5nVzTZgoTNTs/Z7
# KtWJQDxxpav4mVn945uSS90FvQsMeAYrz1PYvRKaWyeGhT+RvuB4gHNU36cdZytq
# tq5NiYAkCFJwUPMB/0SuL5rg4UkI4eFb1zjRngqKnZQnm8qjudviNmrjb7lYYuA2
# eDYB+sGniXomU6Ncu9Ky64rLYwgv/h7zViniNZvY/+mlvW1LWSyJLC9Su7UpkNpD
# R7xy3bzZv4DB3LCrtEsdWDY3ZOub4YUXmimi/eYI0pL/oPh84emn0TCOXyZQK8ei
# 4pd3iu/YTT4m65lAYPM8Zwy2CHIpNVOBNNwwggb1MIIE3aADAgECAgx5Y9ljauM7
# cdkFAm4wDQYJKoZIhvcNAQELBQAwWTELMAkGA1UEBhMCQkUxGTAXBgNVBAoTEEds
# b2JhbFNpZ24gbnYtc2ExLzAtBgNVBAMTJkdsb2JhbFNpZ24gR0NDIFI0NSBDb2Rl
# U2lnbmluZyBDQSAyMDIwMB4XDTIzMDMyNzEwMjEzNFoXDTI2MDMyMzE2MTgxOFow
# YzELMAkGA1UEBhMCREsxEDAOBgNVBAcTB0tvbGRpbmcxEDAOBgNVBAoTBzJsaW5r
# SVQxEDAOBgNVBAMTBzJsaW5rSVQxHjAcBgkqhkiG9w0BCQEWD21va0AybGlua2l0
# Lm5ldDCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAMykjWtM6hY5IRPe
# VIVB+yX+3zcMJQR2gjTZ81LnGVRE94Zk2GLFAwquGYWt1shoTHTV5j6Ef2AXYBDV
# kNruisJVJ17UsMGdsU8upwdZblFbLNzLw+qBXVC/OUVua9M0cub7CfUNkn/Won4D
# 7i41QyuDXdZFOIfRhZ3qnCYCJCSgYLoUXAS6xei2tPkkk1w8aXEFxybyy7eRqQjk
# HqIS5N4qH3YQkz+SbSlz/yj6mD65H5/Ts+lZxX2xL/8lgJItpdaJx+tarprv/tT+
# +n9a13P53YNzCWOmyhd376+7DMXxxSzT24kq13Ks3xnUPGoWUx2UPRnJHjTWoBfg
# Y7Zd3MffrdO0QEoDC9X5F5boh6oankVSOdSPRFns085KI+vkbt3bdG62MIeUbNtS
# v7mZBX8gcYv0szlo0ey7bbOJWoiZFT2fB+pBVvxDhpYP0/3aFveM1wfhshaJBhxx
# /2GCswYYBHH7B3+8j4BT8N8S030q4snys2Qt9tdFIHvSV7lIw/yorT1WM1cr+Lqo
# 74eR+Hi982db0k68p2BGdCOY0QhhaNqxufwbK+gVWrQY57GIX/1cUrBt0akMsli2
# 19xVmUGhIw85ZF7wcQplhslbUxyNUilY+c93q1bsIFjaOnjjvo56g+kyKICm5zsG
# FQLRVaXUSLY+i8NSiH8fd64etaptAgMBAAGjggGxMIIBrTAOBgNVHQ8BAf8EBAMC
# B4AwgZsGCCsGAQUFBwEBBIGOMIGLMEoGCCsGAQUFBzAChj5odHRwOi8vc2VjdXJl
# Lmdsb2JhbHNpZ24uY29tL2NhY2VydC9nc2djY3I0NWNvZGVzaWduY2EyMDIwLmNy
# dDA9BggrBgEFBQcwAYYxaHR0cDovL29jc3AuZ2xvYmFsc2lnbi5jb20vZ3NnY2Ny
# NDVjb2Rlc2lnbmNhMjAyMDBWBgNVHSAETzBNMEEGCSsGAQQBoDIBMjA0MDIGCCsG
# AQUFBwIBFiZodHRwczovL3d3dy5nbG9iYWxzaWduLmNvbS9yZXBvc2l0b3J5LzAI
# BgZngQwBBAEwCQYDVR0TBAIwADBFBgNVHR8EPjA8MDqgOKA2hjRodHRwOi8vY3Js
# Lmdsb2JhbHNpZ24uY29tL2dzZ2NjcjQ1Y29kZXNpZ25jYTIwMjAuY3JsMBMGA1Ud
# JQQMMAoGCCsGAQUFBwMDMB8GA1UdIwQYMBaAFNqzjcAkkKNrd9MMoFndIWdkdgt4
# MB0GA1UdDgQWBBQxxpY2q5yrKa7VFODTZhTfPKmyyTANBgkqhkiG9w0BAQsFAAOC
# AgEAe38NgZR4IV9u264/n/jiWlHbBu847j1vpN6dovxMvdUQZ780eH3JzcvG8fo9
# 1uO1iDIZksSigiB+d8Sj5Yvh+oXlfYEffjIQCwcIlWNciOzWYZzl9qPHXgdTnaIu
# JA5cR846TepQLVMXc1Yb72Z7OGjldmRIxGjRimDsmzY+TdTu15lF4IkUj0VJhr8F
# PYOdEVZVOXHtPmUjPqsq9M7WpALYbc0pUawcy0FOOwXqzaCk7O3vMXej4Oycm6RB
# GfRH3JPOCvH2ddiIfPq2Lce4nhTuLsgumBJE2vOalVddIfTBjE9PpMub15lHyp1m
# fW0ZJvXOghPvRqufMT3SjPTHt6PV8LwhQD8BiGSZ9rp94js4xTnGexSOFKLLMxWE
# PTr5EPe3kmtspGgKCqLEZvsMYz7JlWNuaHBy+vdQZWV3376luwV4IHfGT+1wxe0E
# 90dMRI+9SNIKkVvKV3FUtToZUh3Np4cCIHJLQ1eslXFzIJa6wrjVsnWM/3OyedpQ
# JERGNYXlVmxdgGFjrY1I6UWII0Y1iZW3t+JvhXosUaha8i/YSxaDH+5H/Klad2OZ
# Xq4Eg39QxkCELbmJmSU0sUYNnl0JTEu6jJY9UJMFikzf5s3p2ZuKdyMbRgN5GNNV
# 883meI/X5KVHBJDG1epigMer7fFXMVZUGoI12iIz/gOolQExggMbMIIDFwIBATBp
# MFkxCzAJBgNVBAYTAkJFMRkwFwYDVQQKExBHbG9iYWxTaWduIG52LXNhMS8wLQYD
# VQQDEyZHbG9iYWxTaWduIEdDQyBSNDUgQ29kZVNpZ25pbmcgQ0EgMjAyMAIMeWPZ
# Y2rjO3HZBQJuMA0GCWCGSAFlAwQCAQUAoIGEMBgGCisGAQQBgjcCAQwxCjAIoAKA
# AKECgAAwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwHAYKKwYBBAGCNwIBCzEO
# MAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIJNmVDpQECPHzJ1YDyVyj5qf
# /xP0SNyjfzok28TGLjShMA0GCSqGSIb3DQEBAQUABIICAMCKnlsW6mNn6Ztf3UgV
# JlD00lt7f8phLQy0NxSapVLNgBcZM6yXHxrSqFlGllenM1+WkXZygUP+T7RABjYM
# 4xWpoNaRIbEid69LwP32LTdqJcu1f8/wGWsxaL8saDvYQIhMKpYULBL7+YM7+dfJ
# DAYXweZqd/C7WwPylPoR8itwOnWDcstOI+udNlLS7qqrZfY7TmqWHw0RzPNRwXNW
# pTVJMUjGm0FxiiPehzbbGjMPe+ZLN3gamuN9JDV3oGFnc8c9mAH35PWf4snx7RpE
# wI+1pOi4fg1Iady5lokW+M+HomZ8afZLG0nvwb+pLD4mKtVy2EOjPlow05wTI8K+
# whNPoA8WO1isL3gmHQu4/iPcqrVa909pbDVs/9N4Xx5tmJmX1+H0fj0HGJPQu+JP
# mqfRUyzybweGFWUdOR+MqnITwkcuZ9FPOQgPfToyR1O5VAiIOxLsFvmCDrFsTM2D
# NnHKBaI6hLo0cRBnUybqPWIGFXbcaUZaoqXqDRbGhIXFfVwK/oMsJtQos3JGqYnG
# E/KcfmnIbesHvhsACzd2k4dni1utmPWThMzDmZQQHab75xoerZEUPiDPtHbf8a1V
# b4dcCVDHh6BgSQVjMEO98MRLgsbRETrBDAGNJ6vOT+UbWdmugphDlNkhYmJ+iEy7
# QEY0mvmLzfbYmztU/lX9YzeE
# SIG # End signature block
