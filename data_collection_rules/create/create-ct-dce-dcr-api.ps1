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
        [Parameter(Mandatory=$true)][string]$ResourceGroup,
        [Parameter(Mandatory=$true)][string]$WorkspaceName,
        [Parameter(Mandatory=$true)][string]$Location
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


    # --------------------------------------------------------------------------------------
    # Helper function to check and provision Azure Resources 
    # via REST API: Custom Table, DCE, DCR, etc.
    # --------------------------------------------------------------------------------------
    function CNP-AzResource {
        param(
            [Parameter(Mandatory=$true)][string]$Resource_API,
            [Parameter(Mandatory=$true)][string]$ResourceName,
            [Parameter(Mandatory=$false)][string]$ResourcePayload
        )

        # Check to see if Azure resource already exists. If it does, do nothing. If it does not, create it.    
        $ResourceExists = Invoke-AzRestMethod -Uri $Resource_API -Method GET

        if ($Action -eq "Provision") {
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
        } elseif ($Action -eq "Delete") {
            if ($ResourceExists.StatusCode -in (200, 202)) {
                Write-Host "!!! DELETING AZURE RESOURCE: `"$ResourceName`" !!!" -ForegroundColor Yellow
                $Result = Invoke-AzRestMethod ($Resource_API) -Method DELETE
                if ($Result.StatusCode -in (200,202,204)) {
                    Write-Host "!!! SUCESSFULLY DELETED AZURE RESOURCE -> `"$ResourceName`" !!!" -ForegroundColor Red
                }
            }else{
                Write-Host "The Azure Resource: `"$ResourceName`" does not exist ..nothing to delete!" -ForegroundColor Green
            }
        }
        Start-Sleep -Milliseconds 500
    }

    # Delete Azure resources (Custom Table, DCE, & DCR) if the action is "Delete"
    if ($Action -eq "Delete") {
        CNP-AzResource -Resource_API $LATable_API -ResourceName $customTable
        CNP-AzResource -Resource_API $DCR_API -ResourceName $dcrName
        CNP-AzResource -Resource_API $DCE_API -ResourceName $dceName
        exit 0
    }


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

    # Call the helper function with the parameters
    CNP-AzResource -Resource_API $DCE_API -ResourceName $dceName -ResourcePayload $dcePayload


    # ---------------------------------------------------------------------------------
    # Create the data collection rule (DCR), linking the DCE and the LAW to the DCR
    #   
    # https://learn.microsoft.com/en-us/rest/api/monitor/data-collection-rules/create?view=rest-monitor-2022-06-01&tabs=HTTP
    # ---------------------------------------------------------------------------------
    # Get the DCE Resource Id for the DCR payload
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

    # Call the helper function with the parameters
    CNP-AzResource -Resource_API $DCR_API -ResourceName $dcrName -ResourcePayload $dcrPayload
}
