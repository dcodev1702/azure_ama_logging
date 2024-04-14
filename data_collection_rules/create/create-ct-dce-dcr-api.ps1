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
    [string]$DCRFilePattern = "C:\\Assessment\\AAD\\AzureAssessment\\*.assessmentazurerecs"

    # No need to change these variables
    [string]$dceName     = "oda-dcr-endpoint"
    [string]$dcrName     = "oda-dcr-rule"
    [string]$customTable = "ODAStream_CL"

    [string]$ResourceManagerUrl = (Get-AzContext).Environment.ResourceManagerUrl
    [string]$SubscriptionId     = (Get-AzContext).Subscription.Id
    
    # -------------------------------------------------------------------------------
    # API's to validate, provision, and get the status of the resources (id's, etc.)
    # -------------------------------------------------------------------------------
    [string]$LAW_API     = "$ResourceManagerUrl/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.OperationalInsights/workspaces/${WorkspaceName}?api-version=2023-09-01"
    [string]$LATable_API = "$ResourceManagerUrl/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.OperationalInsights/workspaces/$WorkspaceName/tables/${customTable}?api-version=2022-10-01"
    [string]$DCE_API     = "$ResourceManagerUrl/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.Insights/dataCollectionEndpoints/${dceName}?api-version=2022-06-01"
    [string]$DCR_API     = "$ResourceManagerUrl/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.Insights/dataCollectionRules/${dcrName}?api-version=2022-06-01"

    # ------------------------------------------------------------
    # Get the Log Analytics Workspace (LAW) Resource Id
    # ------------------------------------------------------------
    $LAWResult   = Invoke-AzRestMethod ($LAW_API) -Method GET
    $LAWResource = $LAWResult.Content | ConvertFrom-JSON
    Write-Verbose "LAW Resource Id: $($LAWResource.id)"


    # ------------------------------------------------------------
    # Create a custom log (table) in a Log Analytics Workspace
    #
    # https://learn.microsoft.com/en-us/rest/api/loganalytics/tables/create-or-update?view=rest-loganalytics-2023-09-01&tabs=HTTP
    # ------------------------------------------------------------
    [string]$customTablePayload = @"
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

    <#
    # Check to see if the custom table already exists. If it does, do nothing. If it does not, create it.

    $CTCheck = Invoke-AzRestMethod ($LATable_API) -Method GET
    #$CTCheck = Invoke-AzRestMethod ($LATable_API + "?api-version=2022-10-01") -Method GET

    if ($CTCheck.StatusCode -eq 200) {
        Write-Host "The Custom Table: `"$customTable`" already exists" -ForegroundColor Green
    }else{
        Write-Host "The Custom Table `"$customTable`" does not exist ..provisioning now!" -ForegroundColor Cyan
        $Result = Invoke-AzRestMethod ($LATable_API) -Method PUT -Payload $customTablePayload
        if ($Result.StatusCode -in (200, 202)) {
            Write-Host "!!! SUCESSFULLY PROVISIONED -> Custom Table: `"$customTable`" !!!" -ForegroundColor Green
        }else{
            Write-Host "!!! FAILED TO PROVISION -> Custom Table: `"$customTable`" !!!" -ForegroundColor Red
            Exit 1
        }
    }
    #>

    # Helper function to manage the Data Collection Endpoint
    function CNP-AzResource {
        param(
            [string]$Resource_API,
            [string]$ResourceName,
            [string]$ResourcePayload
        )

        # Check to see if DCE already exists. If it does, do nothing. If it does not, create it.    
        $ResourceExists = Invoke-AzRestMethod -Uri $Resource_API -Method GET

        if ($ResourceExists.StatusCode -in (200, 202)) {
            Write-Host "Azure Resource: `"$ResourceName`" already exists" -ForegroundColor Green
        } else {
            Write-Host "Azure Resource: `"$ResourceName`" does not exist ..provisioning now!" -ForegroundColor Cyan
            $Result = Invoke-AzRestMethod -Uri $Resource_API -Method PUT -Payload $ResourcePayload
            if ($Result.StatusCode -in (200, 202)) {
                Write-Host "!!! SUCCESSFULLY PROVISIONED AZURE RESOURCE -> `"$ResourceName`" !!!" -ForegroundColor Green
            } else {
                Write-Host "!!! FAILED TO PROVISION AZURE RESOURCE -> `"$ResourceName`" !!!" -ForegroundColor Red
                Exit 1
            }
        }
        Start-Sleep -Milliseconds 500
    }

    # Call the helper function with the parameters
    CNP-AzResource -Resource_API $LATable_API -ResourceName $customTable -ResourcePayload $customTablePayload

    # ------------------------------------------------------------
    # Create the Data Collection Endpoint (DCE)
    #
    # https://learn.microsoft.com/en-us/rest/api/monitor/data-collection-endpoints/create?view=rest-monitor-2022-06-01&tabs=HTTP
    # ------------------------------------------------------------
    [string]$dcePayload = @"
    {
        "Location": "$Location",
        "properties": {
            "networkAcls": {
                "publicNetworkAccess": "Enabled"
            }
        }
    }
"@

    <#
    # Check to see if DCE already exists. If it does, do nothing. If it does not, create it.    
    $dceExists = Invoke-AzRestMethod ($DCE_API) -Method GET

    if ($dceExists.StatusCode -eq 200) {
        Write-Host "Data Collection Endpoint: `"$dceName`" already exists" -ForegroundColor Green
    }else{
        Write-Host "Data Collection Endpoint: `"$dceName`" does not exist ..provisioning now!" -ForegroundColor Cyan
        $Result = Invoke-AzRestMethod ($DCE_API) -Method PUT -Payload $dcePayload
        if ($Result.StatusCode -eq 200) {
            Write-Host "!!! SUCESSFULLY PROVISIONED -> Data Collection Endpoint: `"$dceName`" !!!" -ForegroundColor Green
        }else{
            Write-Host "!!! FAILED TO PROVISION -> Data Collection Endpoint: `"$dceName`" !!!" -ForegroundColor Red
            Exit 1
        }
    }
    #>

    # Call the helper function with the parameters
    CNP-AzResource -Resource_API $DCE_API -ResourceName $dceName -ResourcePayload $dcePayload

    #Start-Sleep -Seconds 1

    # ---------------------------------------------------------------------------------
    # Create the data collection rule (DCR), linking the DCE and the LAW to the DCR
    #   
    # https://learn.microsoft.com/en-us/rest/api/monitor/data-collection-rules/create?view=rest-monitor-2022-06-01&tabs=HTTP
    # ---------------------------------------------------------------------------------
    # Get the DCE Resource Id
    $DCEResult   = Invoke-AzRestMethod ($DCE_API) -Method GET
    $DCEResource = $DCEResult.Content | ConvertFrom-JSON
    Write-Verbose "DCE Resource Id: $($DCEResource.id)"
    
    [string]$dcrPayload = @"
    {
        "Location": "$Location",
        "kind": "Windows",
        "properties": {
            "dataCollectionEndpointId": "$($DCEResource.id)",
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
                        "workspaceResourceId": "$($LAWResource.id)",
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

    <#
    # Check to see if DCR already exists. If it does, do nothing. If it does not, create it.
    $dcrExists = Invoke-AzRestMethod ($DCR_API) -Method GET

    Start-Sleep -Seconds 1

    if ($dcrExists.StatusCode -eq 200) {
        Write-Host "Data Collection Rule: `"$dcrName`" already exists" -ForegroundColor Green
    }else{
        Write-Host "Data Collection Rule `"$dcrName`" does not exist ..provisioning now!" -ForegroundColor Cyan
        $Result = Invoke-AzRestMethod ($DCR_API) -Method PUT -Payload $dcrPayload
        if ($Result.StatusCode -eq 200) {
            Write-Host "!!! SUCESSFULLY PROVISIONED -> Data Collection Rule: `"$dcrName`" !!!" -ForegroundColor Green
        }else{
            Write-Host "!!! FAILED TO PROVISION -> Data Collection Rule: `"$dcrName`" !!!" -ForegroundColor Red
            Exit 1
        }
    }
    #>

    # Call the helper function with the parameters
    CNP-AzResource -Resource_API $DCR_API -ResourceName $dcrName -ResourcePayload $dcrPayload
}
