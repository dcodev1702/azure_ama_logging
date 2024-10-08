<#
Author: DCODEV1702
Date: 08/21/2024

Cited Source: 
Inspiration, flow & source code for this tool came directly from @markolauren: https://github.com/markolauren/sentinel/blob/main/tableCreator%20tool/tableCreator.ps1

Description:
This script will automate the creation of a custom table (CL) by exporting the schema of a current table directly to a custom table (CL)v2

Usage:
1. Open a PowerShell or Azure Cloud Shell session w/ Az module installed & the appropriate permissions
2. Update the variables in the "CHANGE ME" section below
3. Run the PowerShell script
   ./customTableCreation_tool.ps1
    - Enter existing table to acquire schema from
    - Enter name of the custom table that will inherit the schema
#>
param (
    [string]$tableName = $(Read-Host -Prompt "Enter TableName to get schema from"),
    [string]$newTableName = $(Read-Host -Prompt "Enter new TableName to be created with the same Schema (remember _CL -suffix)")
)

# This script will get the schema of the Syslog table in the specified Log Analytics workspace and exclude specific columns by name
[string]$ResourceManagerUrl = (Get-AzContext).Environment.ResourceManagerUrl
[string]$SubscriptionId     = (Get-AzContext).Subscription.Id

# !!!! CHANGE ME AS REQUIRED !!!!
[string]$ResourceGroup      = "!!! CHANGE ME !!!"
[string]$WorkspaceName      = "!!! CHANGE ME !!!"

[string]$LATable_API = "${ResourceManagerUrl}subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.OperationalInsights/workspaces/$WorkspaceName/tables/${newTableName}?api-version=2022-10-01"
[string]$LAW_API     = "${ResourceManagerUrl}subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.OperationalInsights/workspaces/${WorkspaceName}?api-version=2023-09-01"

# ------------------------------------------------------------
# Get the Log Analytics Workspace (LAW) Customer Id
# ------------------------------------------------------------
$LAWResult   = Invoke-AzRestMethod -Uri ($LAW_API) -Method GET
$LAWResource = $LAWResult.Content | ConvertFrom-JSON

# Construct KQL query to dump the schema of source table ($tableName)
[string]$query  = "$tableName | getschema | project Name=ColumnName, Type=ColumnType"
$tableColumns = (Invoke-AzOperationalInsightsQuery -WorkspaceId $LAWResource.properties.customerId -Query $query).Results | Where-Object { $_.Name -notin @("TenantId", "Type") }

# Modify columns of data type guid [schema dumps guid columns as string but has to be 'guid' in order for DCR to map the data type properly!]
# Satisfies tables: Syslog, SecurityEvent, Event, and others.  Not all tables have been tested. This is a workaround to the issue between
# Azure Monitor - Log Analytics use of the 'guid' datatype and Kusto table specifications which uses 'string' datatype.
foreach ($column in $tableColumns) {
    if ($column.Name -in ("MG", "InterfaceUuid", "LogonGuid", "SourceComputerId", "SubcategoryGuid", "TargetLogonGuid")) { $column.Type = "guid" }
}

#$columns | ConvertTo-Json

# Construct the tableParams
$customTablePayload = [ordered]@{
    "properties" = [ordered]@{
        "schema" = [ordered]@{
            "name" = $newTableName
            "tableType" = "CustomLog"
            "columns" = $tableColumns
        }
        "retentionInDays" = 90
        "totalRetentionInDays" = 90
    }
} | ConvertTo-Json -Depth 10

# Create a file using custom table name and dump the schema
$customTablePayload | Out-File -FilePath "${newTableName}.json"

Get-Content -Path "${newTableName}.json" -Raw

# Check to see if Azure resource already exists. If it does, do nothing. If it does not, create it.    
$ResourceExists = Invoke-AzRestMethod -Uri ($LATable_API) -Method GET

if ($ResourceExists.StatusCode -in (200, 202)) {
    Write-Host "!!! AZURE RESOURCE -> `"$newTableName`" ALREADY EXISTS !!!" -ForegroundColor Yellow
    Exit 0
} else {
    # Ask user if they want to continue with creating the new custom table
    $userChoice = Read-Host "The Azure resource $newTableName does not exist. Do you want to create it? (Y/N)"
    if ($userChoice -eq 'Y' -or $userChoice -eq 'y') {
    # The custom table does not exist in log analytics, create it!
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
    } else {
        Write-Host "!!! USER ABORTED CREATION OF AZURE RESOURCE -> `"$newTableName`" !!!" -ForegroundColor Yellow
        Exit 0
    }
}
