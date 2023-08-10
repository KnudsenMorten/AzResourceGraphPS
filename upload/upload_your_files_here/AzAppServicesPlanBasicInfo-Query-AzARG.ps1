Function AzAppServicesPlanBasicInfo-Query-AzARG
{
  [CmdletBinding()]
  param(

          [Parameter()]
            [switch]$Details = $false
       )

$Query = @"
resources
| where type=~'Microsoft.Web/serverfarms' 
| extend NumberOfApps = properties.numberOfSites
| extend sku = sku.name
| project Name=['name'], sku, NumberOfApps, Location=['location']
"@

$Description = "App Service Plans Basic Information"
$Category    = "Configuration"
$Credit      = "Wesley Haakman (@whaakman)"

If ($Details)
    {
        Return $Query, $Description, $Category, $Credit
    }
Else
    {
        # only return Query
        Return $Query
    }
}
