<#
Author: DCODEV1702
Date: 08/20/2024

Cited Source: 
Inspiration for this tool came directly from @markolauren: https://github.com/markolauren/sentinel/blob/main/tableCreator%20tool/tableCreator.ps1

Description:
This script will automate the creation of a custom table (CL), data collection endpoint (DCE) and a data collection rule (DCR) 
in Azure Monitor for a Log Analytics Workspace (LAW) to collect and ingest assessment data from Azure Assessment.
The script will create the DCE and DCR if they do not already exist and link them with a LAW.

Usage:
1. Open a PowerShell or Azure Cloud Shell session w/ Az module installed & the appropriate permissions
2. Update the variables in the "CHANGE ME" section below
3. Run the PowerShell script
    . ./create_customTable.ps1
    New-CustomSyslogTable -Action Provision -ResourceGroup "sec_telem_law_1" -WorkspaceName "aad-telem" -Location "eastus"
    New-CustomSyslogTable -Action Delete -ResourceGroup "sec_telem_law_1" -WorkspaceName "aad-telem" -Location "eastus"
#>

param (
    [string]$tableName = $(Read-Host -Prompt "Enter TableName to get schema from"),
    [string]$newTableName = $(Read-Host -Prompt "Enter new TableName to be created with the same Schema (remember _CL -suffix)")
)

# This script will get the schema of the Syslog table in the specified Log Analytics workspace and exclude specific columns by name
[string]$ResourceManagerUrl = (Get-AzContext).Environment.ResourceManagerUrl
[string]$SubscriptionId     = (Get-AzContext).Subscription.Id
[string]$ResourceGroup      = "sec_telem_law_1"
[string]$WorkspaceName      = "aad-telem"

$workspaceId = 'c4186dce-d540-4c9d-84ed-01e02cc92506'

$query = "$tableName | getschema | project name=ColumnName, type=ColumnType"

$result = Invoke-AzOperationalInsightsQuery -WorkspaceId $workspaceId -Query $query

$columns = $result.Results | Where-Object { $_.name -notin @("TenantId", "Type") }

# Modify the type of 'MG' column
foreach ($column in $columns) {
    if ($column.name -eq "MG") {
        $column.type = "guid"
    }
}

#$columns | ConvertTo-Json

# Construct the tableParams
$customTablePayload = [ordered]@{
    "properties" = [ordered]@{
        "schema" = [ordered]@{
            "name" = $newTableName
            "tableType" = "CustomLog"
            "columns" = $columns
        }
        "retentionInDays" = 90
        "totalRetentionInDays" = 90
    }
} | ConvertTo-Json -Depth 10

$customTablePayload | Out-File -FilePath "${newTableName}.json"


Get-Content -Path "${newTableName}.json" -Raw

[string]$LATable_API = "${ResourceManagerUrl}subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.OperationalInsights/workspaces/$WorkspaceName/tables/${newTableName}?api-version=2022-10-01"

# Create the new custom table in log analytics
$sol = Invoke-AzRestMethod -Uri $LATable_API -Method PUT -Payload $customTablePayload

if ($sol.StatusCode -in (200, 202)) {
    Write-Host "!!! SUCCESSFULLY PROVISIONED AZURE RESOURCE -> `"$newTableName`" !!!" -ForegroundColor Green
} else {
    $r = $sol.Content | ConvertFrom-Json
    Write-Host $r.error.message -ForegroundColor Red
    Write-host $r.error.details -ForegroundColor Red
    Write-Host "!!! FAILED TO PROVISION AZURE RESOURCE -> `"$newTableName`" !!!" -ForegroundColor Red
    Exit 1
}
