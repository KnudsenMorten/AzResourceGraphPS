################################################################################
# Install-module Powershell
################################################################################

# Update the list of packages
sudo apt-get update

# Install pre-requisite packages.
sudo apt-get install -y wget apt-transport-https software-properties-common

# Download the Microsoft repository GPG keys
wget -q "https://packages.microsoft.com/config/ubuntu/$(lsb_release -rs)/packages-microsoft-prod.deb"

# Register the Microsoft repository GPG keys
sudo dpkg -i packages-microsoft-prod.deb

# Delete the the Microsoft repository GPG keys file
rm packages-microsoft-prod.deb

# Update the list of packages after we added packages.microsoft.com
sudo apt-get update

# Install PowerShell
sudo apt-get install -y powershell

# Start PowerShell
pwsh

################################################################################
# Install modules
################################################################################

install-module AzResourceGraphPS
install-module Az.ResourceGraph
install-module Az


################################################################################
# Show Ubuntu version info
################################################################################

lsb_release -a


################################################################################
# Check version
################################################################################

Query-AzResourceGraph -InstallAutoUpdateCleanupOldVersions


################################################################################
# Connect with Azure App
################################################################################

$AzAppId     = "xxxx"
$AzAppSecret = "xxxx"
$TenantId    = "xxxx"

AzRGs-Query-AzARG | Query-AzResourceGraph -QueryScope "Tenant" -AzAppId $AzAppId `
                                                               -AzAppSecret $AzAppSecret `
                                                               -TenantId $TenantId


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

  $Query | Query-AzResourceGraph -QueryScope "Tenant" -AzAppId $AzAppId `
                                                      -AzAppSecret $AzAppSecret `
                                                      -TenantId $TenantId

