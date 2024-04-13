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
    . ./create-ct-dce-dcr-api.ps1
    Invoke-DCR-API -Action Provision -ResourceGroup "sec_telem_law_1" -WorkspaceName "aad-telem" -Location "eastus"
    Invoke-DCR-API -Action Delete -ResourceGroup "sec_telem_law_1" -WorkspaceName "aad-telem" -Location "eastus"
#>

function Invoke-DCR-API {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("Provision","Delete")]
        [string]$Action,
        [Parameter(Mandatory=$false)][string]$ResourceGroup = "sec_telem_law_1",
        [Parameter(Mandatory=$false)][string]$WorkspaceName = "aad-telem",
        [Parameter(Mandatory=$false)][string]$Location      = "eastus"
    )

    # !!! CHANGE ME !!!
    $DCRFilePattern = "C:\\Assessment\\AAD\\AzureAssessment\\*.assessmentazurerecs"

    # No need to change these variables
    $dceName     = "oda-dcr-endpoint"
    $dcrName     = "oda-dcr-rule"
    $customTable = "ODAStream_CL"

    $ResourceManagerUrl = (Get-AzContext).Environment.ResourceManagerUrl
    $SubscriptionId     = (Get-AzContext).Subscription.Id
    
    # Get the LAW Resource Id
    $LAW_API       = "$ResourceManagerUrl/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.OperationalInsights/workspaces/$WorkspaceName"
    $LAWResult     = Invoke-AzRestMethod ($LAW_API + "?api-version=2023-09-01") -Method GET
    $LAWResourceId = $LAWResult.Content | ConvertFrom-JSON
    Write-Verbose "LAW Resource Id: $($LAWResourceId.id)"

    # ------------------------------------------------------------
    # Create a custom log (table) in a Log Analytics Workspace
    #
    # https://learn.microsoft.com/en-us/rest/api/loganalytics/tables/create-or-update?view=rest-loganalytics-2023-09-01&tabs=HTTP
    # ------------------------------------------------------------
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
    $LATable_API = "$ResourceManagerUrl/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.OperationalInsights/workspaces/$WorkspaceName/tables/$customTable"

    $CTCheck = Invoke-AzRestMethod ($LATable_API + "?api-version=2022-10-01") -Method GET

    if ($CTCheck.StatusCode -eq 200) {
        Write-Host "The Custom Table: `"$customTable`" already exists" -ForegroundColor Green
    }else{
        Write-Host "The Custom Table `"$customTable`" does not exist ..provisioning now!" -ForegroundColor Cyan
        $Result = Invoke-AzRestMethod ($LATable_API + "?api-version=2022-10-01") -Method PUT -Payload $customTablePayload
        if ($Result.StatusCode -in (200, 202)) {
            Write-Host "!!! SUCESSFULLY PROVISIONED -> Custom Table: `"$customTable`" !!!" -ForegroundColor Green
        }else{
            Write-Host "!!! FAILED TO PROVISION -> Custom Table: `"$customTable`" !!!" -ForegroundColor Red
            Exit 1
        }
    }

    Start-Sleep -Seconds 1

    # ------------------------------------------------------------
    # Create the Data Collection Endpoint (DCE)
    # ------------------------------------------------------------
    $dcePayload = @"
    {
        "Location": "$Location",
        "properties": {
            "networkAcls": {
                "publicNetworkAccess": "Enabled"
            }
        }
    }
"@


    # Check to see if DCE already exists. If it does, do nothing. If it does not, create it.
    # https://learn.microsoft.com/en-us/rest/api/monitor/data-collection-endpoints/get?view=rest-monitor-2022-06-01&tabs=HTTP
    $DCE_API   = "$ResourceManagerUrl/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.Insights/dataCollectionEndpoints/$dceName"
    $dceExists = Invoke-AzRestMethod ($DCE_API + "?api-version=2022-06-01") -Method GET

    if ($dceExists.StatusCode -eq 200) {
        Write-Host "Data Collection Endpoint: `"$dceName`" already exists" -ForegroundColor Green
    }else{
        Write-Host "Data Collection Endpoint: `"$dceName`" does not exist ..provisioning now!" -ForegroundColor Cyan
        $Result = Invoke-AzRestMethod ($DCE_API + "?api-version=2022-06-01") -Method PUT -Payload $dcePayload
        if ($Result.StatusCode -eq 200) {
            Write-Host "!!! SUCESSFULLY PROVISIONED -> Data Collection Endpoint: `"$dceName`" !!!" -ForegroundColor Green
        }else{
            Write-Host "!!! FAILED TO PROVISION -> Data Collection Endpoint: `"$dceName`" !!!" -ForegroundColor Red
            Exit 1
        }
    }

    Start-Sleep -Seconds 1


    # ------------------------------------------------------------
    # Get the LAW & DCE Resource Ids
    #
    # https://learn.microsoft.com/en-us/rest/api/loganalytics/workspaces/get?view=rest-loganalytics-2023-09-01&tabs=HTTP
    # ------------------------------------------------------------
    
    # Get the DCE Resource Id
    $DCEResult     = Invoke-AzRestMethod ($DCE_API + "?api-version=2022-06-01") -Method GET
    $DCEResourceId = $DCEResult.Content | ConvertFrom-JSON
    Write-Verbose "DCE Resource Id: $($DCEResourceId.id)"


    # ---------------------------------------------------------------------------------
    # Create the data collection rule (DCR), linking the DCE and the LAW to the DCR
    #   
    # https://learn.microsoft.com/en-us/rest/api/monitor/data-collection-rules/create?view=rest-monitor-2022-06-01&tabs=HTTP
    # ---------------------------------------------------------------------------------
    $dcrPayload = @"
    {
        "Location": "$Location",
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
    $DCR_API   = "$ResourceManagerUrl/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.Insights/dataCollectionRules/$dcrName"
    $dcrExists = Invoke-AzRestMethod ($DCR_API + "?api-version=2022-06-01") -Method GET

    Start-Sleep -Seconds 1

    if ($dcrExists.StatusCode -eq 200) {
        Write-Host "Data Collection Rule: `"$dcrName`" already exists" -ForegroundColor Green
    }else{
        Write-Host "Data Collection Rule `"$dcrName`" does not exist ..provisioning now!" -ForegroundColor Cyan
        $Result = Invoke-AzRestMethod ($DCR_API + "?api-version=2022-06-01") -Method PUT -Payload $dcrPayload
        if ($Result.StatusCode -eq 200) {
            Write-Host "!!! SUCESSFULLY PROVISIONED -> Data Collection Rule: `"$dcrName`" !!!" -ForegroundColor Green
        }else{
            Write-Host "!!! FAILED TO PROVISION -> Data Collection Rule: `"$dcrName`" !!!" -ForegroundColor Red
            Exit 1
        }
    }
}
