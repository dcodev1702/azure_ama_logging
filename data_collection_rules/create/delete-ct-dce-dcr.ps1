<#
Author: DCODEV1702
Date: 04/11/2024

Description:
This script will automate the creation of a custom table (CL), data collection endpoint (DCE) and a data collection rule (DCR) 
in Azure Monitor for a Log Analytics Workspace (LAW) to collect and ingest assessment data from Azure Assessment.
The script will create the DCE and DCR if they do not already exist and link them with a LAW.

Usage:
1. Open a PowerShell or Azure Cloud Shell session w/ Az module installed & the appropriate permissions
2. Update the variables in the "CHANGE ME" section below
3. Run the PowerShell script

#>
# !!! CHANGE ME !!!

$resourceGroup  = "sec_telem_law_1"
$workspaceName  = "aad-telem"

# !!! CHANGE ME !!!


# No need to change these variables
$dceName     = "oda-dcr-endpoint"
$dcrName     = "oda-dcr-rule"
$customTable = "ODAStream_CL"

$ResourceManagerUrl = (Get-AzContext).Environment.ResourceManagerUrl
$SubscriptionId     = (Get-AzContext).Subscription.Id

# Check to see if the custom table already exists. If it does, do nothing. If it does not, create it.
$CreateCustomTable = "$ResourceManagerUrl/subscriptions/$SubscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.OperationalInsights/workspaces/$workspaceName/tables/$customTable"

$CTCheck = Invoke-AzRestMethod ($CreateCustomTable+"?api-version=2022-10-01") -Method GET

if ($CTCheck.StatusCode -eq 200) {
    Write-Host "!!! DELETING -> Custom Table: `"$customTable`" !!!" -ForegroundColor Yellow
    $Result = Invoke-AzRestMethod ($CreateCustomTable+"?api-version=2022-10-01") -Method DELETE
    if ($Result.StatusCode -in (200,202,204)) {
        Write-Host "!!! SUCESSFULLY DELETED -> Custom Table: `"$customTable`" !!!" -ForegroundColor Red
    }
}else{
    Write-Host "The Custom Table `"$customTable`" does not exist ..nothing to delete!" -ForegroundColor Green
}

Start-Sleep -Seconds 1


# ------------------------------------------------------------
# Delete the Data Collection Rule (DCR) if it exists
# ------------------------------------------------------------
$DCRResourceId = "$ResourceManagerUrl/subscriptions/$SubscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.Insights/dataCollectionRules/$dcrName"

$dcrExists = Invoke-AzRestMethod ($DCRResourceId+"?api-version=2022-06-01") -Method GET

Start-Sleep -Seconds 1

if ($dcrExists.StatusCode -eq 200) {
    Write-Host "!!! DELETING -> Data Collection Rule: `"$dcrName`" !!!" -ForegroundColor Yellow
    $Result = Invoke-AzRestMethod ($DCRResourceId+"?api-version=2022-06-01") -Method DELETE
    if ($Result.StatusCode -eq 200) {
        Write-Host "!!! SUCESSFULLY DELETED -> Data Collection Rule: `"$dcrName`" !!!" -ForegroundColor Red
    }
}else{
    Write-Host "Data Collection Rule `"$dcrName`" does not exist ..nothing to delete!" -ForegroundColor Green
}


Start-Sleep -Seconds 1

# ------------------------------------------------------------
# Delete the Data Collection Endpoint (DCE) if it exists
# ------------------------------------------------------------
$DCEResourceId = "$ResourceManagerUrl/subscriptions/$SubscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.Insights/dataCollectionEndpoints/$dceName"

$dceExists = Invoke-AzRestMethod ($DCEResourceId+"?api-version=2022-06-01") -Method GET

if ($dceExists.StatusCode -eq 200) {
    Write-Host "!!! DELETING -> Data Collection Endpoint: `"$dceName`" !!!" -ForegroundColor Yellow
    $Result = Invoke-AzRestMethod ($DCEResourceId+"?api-version=2022-06-01") -Method DELETE
    if ($Result.StatusCode -eq 200) {
        Write-Host "!!! SUCESSFULLY DELETED -> Data Collection Endpoint: `"$dceName`" !!!" -ForegroundColor Red
    }
}else{
    Write-Host "Data Collection Endpoint: `"$dceName`" does not exist ..nothing to delete!" -ForegroundColor Green
}
