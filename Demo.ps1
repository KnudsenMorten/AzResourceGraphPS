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

