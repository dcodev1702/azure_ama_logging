<#
Author: DCODEV1702
Date: 04/10/2024

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
$location       = "eastus"
$DCRFilePattern = "C:\\Assessment\\AAD\\AzureAssessment\\*.assessmentazurerecs"

# !!! CHANGE ME !!!


# No need to change these variables
$dceName     = "oda-dcr-endpoint"
$dcrName     = "oda-dcr-rule"
$customTable = "ODAStream_CL"

# Create a custom log table in the LAW
$customTablePayload = @"
{
    "properties": {
        "schema" : {
            "name": "$customTable",
            "tableType": "CustomLog",
            "columns": [
                {
                    "name": "TimeGenerated",
                    "type": "datetime"
                },
                {
                    "name": "RawData",
                    "type": "string"
                }
            ]
        },
        "retentionInDays": 90,
        "totalRetentionInDays": 90
    }
}
"@

# Check to see if the custom table already exists. If it does, do nothing. If it does not, create it.
# https://learn.microsoft.com/en-us/rest/api/loganalytics/tables/create-or-update?view=rest-loganalytics-2023-09-01&tabs=HTTP
$CreateCustomTable = "$((Get-AzContext).Environment.ResourceManagerUrl)/subscriptions/$((Get-AzContext).Subscription.Id)/resourceGroups/$resourceGroup/providers/Microsoft.OperationalInsights/workspaces/$workspaceName/tables/$customTable"
$CTCheck = Invoke-AzRestMethod ($CreateCustomTable+"?api-version=2022-10-01") -Method GET

if ($CTCheck.StatusCode -eq 200) {
    Write-Host "The Custom Table: `"$customTable`" already exists" -ForegroundColor Green
}else{
    Write-Host "The Custom Table `"$customTable`" does not exist ..creating now!" -ForegroundColor Cyan
    Invoke-AzRestMethod ($CreateCustomTable+"?api-version=2022-10-01") -Method PUT -Payload $customTablePayload | Out-Null
}

Start-Sleep -Seconds 1

# Create the Data Collection Endpoint (DCE)
$dcePayload = @"
{
    "location": "$location",
    "properties": {
        "networkAcls": {
            "publicNetworkAccess": "Enabled"
        }
    }
}
"@


# Check to see if DCE already exists. If it does, do nothing. If it does not, create it.
# https://learn.microsoft.com/en-us/rest/api/monitor/data-collection-endpoints/get?view=rest-monitor-2022-06-01&tabs=HTTP
$DCEResourceId = "$((Get-AzContext).Environment.ResourceManagerUrl)/subscriptions/$((Get-AzContext).Subscription.Id)/resourceGroups/$resourceGroup/providers/Microsoft.Insights/dataCollectionEndpoints/$dceName"
$dceExists = Invoke-AzRestMethod ($DCEResourceId+"?api-version=2022-06-01") -Method GET

if ($dceExists.StatusCode -eq 200) {
    Write-Host "Data Collection Endpoint: `"$dceName`" already exists" -ForegroundColor Green
}else{
    Write-Host "Data Collection Endpoint: `"$dceName`" does not exist ..creating now!" -ForegroundColor Cyan
    Invoke-AzRestMethod ($DCEResourceId+"?api-version=2022-06-01") -Method PUT -Payload $dcePayload | Out-Null
}

Start-Sleep -Seconds 1


# Get Log Analytics Workspace Resource Id
# https://learn.microsoft.com/en-us/rest/api/loganalytics/workspaces/get?view=rest-loganalytics-2023-09-01&tabs=HTTP
$LAWResourceId = "$((Get-AzContext).Environment.ResourceManagerUrl)/subscriptions/$((Get-AzContext).Subscription.Id)/resourceGroups/$resourceGroup/providers/Microsoft.OperationalInsights/workspaces/$workspaceName"
$LAWResult = Invoke-AzRestMethod ($LAWResourceId+"?api-version=2023-09-01") -Method GET

# Get the LAW Resource Id
$LAWResourceID = $LAWResult.Content | ConvertFrom-JSON
Write-Host "LAW Resource Id: $($LAWResourceId.id)" -ForegroundColor Yellow


# Get the DCE Resource Id
$DCEResult = Invoke-AzRestMethod ($DCEResourceId+"?api-version=2022-06-01") -Method GET

$DCEResourceID = $DCEResult.Content | ConvertFrom-JSON
Write-Host "DCE Resource Id: $($DCEResourceId.id)" -ForegroundColor Yellow

# Create the data collection rule (DCR), linking the DCE and the LAW to the DCR
$dcrPayload = @"
{
    "location": "$location",
    "kind": "Windows",
    "properties": {
        "dataCollectionEndpointId": "$($DCEResourceId.id)",
        "streamDeclarations": {
            "Custom-$customTable": {
                "columns": [
                    {
                        "name": "TimeGenerated",
                        "type": "datetime"
                    },
                    {
                        "name": "RawData",
                        "type": "string"
                    }
                ]
            }
        },
        "dataSources": {
            "logFiles": [
                {
                    "streams": [
                        "Custom-$customTable"
                    ],
                    "filePatterns": [
                        "$DCRFilePattern"
                    ],
                    "format": "text",
                    "settings": {
                        "text": {
                            "recordStartTimestampFormat": "ISO 8601"
                        }
                    },
                    "name": "myLogFileFormat-Windows"
                }
            ]
        },
        "destinations": {
            "logAnalytics": [
                {
                    "workspaceResourceId": "$($LAWResourceId.id)",
                    "name": "law-destination"
                }
            ]
        },
        "dataFlows": [
            {
                "streams": [
                    "Custom-$customTable"
                ],
                "destinations": [
                    "law-destination"
                ],
                "transformKql": "source | extend rowData = split(parse_json(RawData),\"\t\") | project SourceSystem = tostring(rowData[2]) , AssessmentId = toguid(rowData[3]) , AssessmentName ='Azure', RecommendationId = toguid(rowData[4]) , Recommendation = tostring(rowData[5]) , Description = tostring(rowData[6]) , RecommendationResult = tostring(rowData[7]) , TimeGenerated = todatetime(rowData[8]) , FocusAreaId = toguid(rowData[9]) , FocusArea = tostring(rowData[10]) , ActionAreaId = toguid(rowData[11]) , ActionArea = tostring(rowData[12]) , RecommendationScore = toreal(rowData[13]) , RecommendationWeight = toreal(rowData[14]) , Computer = tostring(rowData[15]) , AffectedObjectType = tostring(rowData[17]) , AffectedObjectName = tostring(rowData[19]), AffectedObjectUniqueName = tostring(rowData[20]) , AffectedObjectDetails = tostring(rowData[22]) , AADTenantName = tostring(rowData[24]) , AADTenantId = tostring(rowData[25]) , AADTenantDomain = tostring(rowData[26]) , Resource = tostring(rowData[27]) , Technology = tostring(rowData[28]) , CustomData = tostring(rowData[23])",
                "outputStream": "Microsoft-AzureAssessmentRecommendation"
            }
        ]
    }
}
"@

# Check to see if DCR already exists. If it does, do nothing. If it does not, create it.
# https://learn.microsoft.com/en-us/rest/api/monitor/data-collection-rules/create?view=rest-monitor-2022-06-01&tabs=HTTP
$DCRResourceId = "$((Get-AzContext).Environment.ResourceManagerUrl)/subscriptions/$((Get-AzContext).Subscription.Id)/resourceGroups/$resourceGroup/providers/Microsoft.Insights/dataCollectionRules/$dcrName"
$dcrExists = Invoke-AzRestMethod ($DCRResourceId+"?api-version=2022-06-01") -Method GET

Start-Sleep -Seconds 1

if ($dcrExists.StatusCode -eq 200) {
    Write-Host "Data Collection Rule: `"$dcrName`" already exists" -ForegroundColor Green
}else{
    Write-Host "Data Collection Rule `"$dcrName`" does not exist ..creating now!" -ForegroundColor Cyan
    Invoke-AzRestMethod ($DCRResourceId+"?api-version=2022-06-01") -Method PUT -Payload $dcrPayload | Out-Null
}
