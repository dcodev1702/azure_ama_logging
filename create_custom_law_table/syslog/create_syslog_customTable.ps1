<#
Author: DCODEV1702
Date: 08/20/2024

Description:
This script will automate the creation of a custom table (CL), data collection endpoint (DCE) and a data collection rule (DCR) 
in Azure Monitor for a Log Analytics Workspace (LAW) to collect and ingest assessment data from Azure Assessment.
The script will create the DCE and DCR if they do not already exist and link them with a LAW.

Usage:
1. Open a PowerShell or Azure Cloud Shell session w/ Az module installed & the appropriate permissions
2. Update the variables in the "CHANGE ME" section below
3. Run the PowerShell script
    . ./create_system_customTable.ps1
    New-CustomSyslogTable -Action Provision -ResourceGroup "sec_telem_law_1" -WorkspaceName "aad-telem" -Location "eastus"
    New-CustomSyslogTable -Action Delete -ResourceGroup "sec_telem_law_1" -WorkspaceName "aad-telem" -Location "eastus"
#>
function New-CustomSyslogTable {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("Provision","Delete")]
        [string]$Action,
        [Parameter(Mandatory=$true)][string]$ResourceGroup,
        [Parameter(Mandatory=$true)][string]$WorkspaceName,
        [Parameter(Mandatory=$true)][string]$Location
    )

    [string]$ResourceManagerUrl = (Get-AzContext).Environment.ResourceManagerUrl
    [string]$SubscriptionId     = (Get-AzContext).Subscription.Id

    # Change these variables as required
    [string]$dceName     = "crane-csyslog-dce"
    [string]$dcrName     = "crane-csyslog-dcr"
    [string]$customTable = "craneSyslog_CL"
    
    # -----------------------------------------------------------------------------------------
    # REST API calls to validate, provision, and get the status of Azure resources (id's, etc.)
    # -----------------------------------------------------------------------------------------
    [string]$LAW_API     = "${ResourceManagerUrl}subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.OperationalInsights/workspaces/${WorkspaceName}?api-version=2023-09-01"
    [string]$LATable_API = "${ResourceManagerUrl}subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.OperationalInsights/workspaces/$WorkspaceName/tables/${customTable}?api-version=2022-10-01"
    [string]$DCE_API     = "${ResourceManagerUrl}subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.Insights/dataCollectionEndpoints/${dceName}?api-version=2022-06-01"
    [string]$DCR_API     = "${ResourceManagerUrl}subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.Insights/dataCollectionRules/${dcrName}?api-version=2022-06-01"
    # -----------------------------------------------------------------------------------------

    # ------------------------------------------------------------
    # Get the Log Analytics Workspace (LAW) Resource Id
    # ------------------------------------------------------------
    $LAWResult   = Invoke-AzRestMethod -Uri ($LAW_API) -Method GET
    $LAWResource = $LAWResult.Content | ConvertFrom-JSON
    Write-Verbose "LAW Resource Id: $($LAWResource.id)"

    # --------------------------------------------------------------------------------------
    # Helper function to check and provision Azure Resources 
    # via REST API: Custom Table, DCE, DCR, etc.
    # --------------------------------------------------------------------------------------
    function Set-AzResource {
        [CmdletBinding()]
        Param(
            [Parameter(Mandatory=$true)]
            [string]$Resource_API,
            [Parameter(Mandatory=$true)]
            [string]$ResourceName,
            [Parameter(Mandatory=$false)]
            [ValidateNotNullOrEmpty()]
            [string]$ResourcePayload
        )

        # Check to see if Azure resource already exists. If it does, do nothing. If it does not, create it.    
        $ResourceExists = Invoke-AzRestMethod -Uri ($Resource_API) -Method GET

        if ($Action -eq "Provision") {
            if ($ResourceExists.StatusCode -in (200, 202)) {
                Write-Host "Azure Resource: `"$ResourceName`" already exists" -ForegroundColor Green
            } else {
                Write-Host "Azure Resource: `"$ResourceName`" does not exist ..provisioning now!" -ForegroundColor Cyan
                $Result = Invoke-AzRestMethod -Uri ($Resource_API) -Method PUT -Payload $ResourcePayload
                if ($Result.StatusCode -in (200, 202)) {
                    Write-Host "!!! SUCCESSFULLY PROVISIONED AZURE RESOURCE -> `"$ResourceName`" !!!" -ForegroundColor Green
                } else {
                    $r = $Result.Content | ConvertFrom-Json
                    Write-Host $r.error.message -ForegroundColor Red
                    Write-host $r.error.details -ForegroundColor Red
                    Write-Host "!!! FAILED TO PROVISION AZURE RESOURCE -> `"$ResourceName`" !!!" -ForegroundColor Red
                    Exit 1
                }
            }
        } elseif ($Action -eq "Delete") {
            if ($ResourceExists.StatusCode -in (200, 202)) {
                Write-Host "!!! DELETING AZURE RESOURCE: `"$ResourceName`" !!!" -ForegroundColor Yellow
                $Result = Invoke-AzRestMethod -Uri ($Resource_API) -Method DELETE
                if ($Result.StatusCode -in (200,202,204)) {
                    Write-Host "!!! SUCESSFULLY DELETED AZURE RESOURCE -> `"$ResourceName`" !!!" -ForegroundColor Red
                }
            } else {
                Write-Host "The Azure Resource: `"$ResourceName`" does not exist ..nothing to delete!" -ForegroundColor Green
            }
        } else {
            Write-Host "!!! INVALID OPTION FOR REST API: `"$ResourcePayload`" !!!" -ForegroundColor Red; Exit 1
        }
        Start-Sleep -Milliseconds 500
    }

    # Delete Azure resources (Custom Table, DCE, & DCR) if the $Action is "Delete"
    if ($Action -eq "Delete") {
        try {
            # Get data collection rule associations
            $VMResources = Get-AzDataCollectionRuleAssociation -DataCollectionRuleName $dcrName -ResourceGroupName $ResourceGroup -ErrorAction SilentlyContinue

            if ($VMResources -eq $null) {
                Write-Host "No data collection rule associations found for DCR: `"$dcrName`" in resource group: `"$ResourceGroup`"" -ForegroundColor Green
            } else {
                foreach ($VMResource in $VMResources) {  
                    $parts = $VMResource.Id -split '/'
                    $RType = "$($parts[6])/$($parts[7])"    
                    $vmName = $parts[8]

                    # Get the VM resource
                    $VM = Get-AzResource -ResourceGroupName $ResourceGroup -Name $vmName -ResourceType $RType

                    if ($vmResource) {
                        # Output the resource id
                        Remove-AzDataCollectionRuleAssociation -AssociationName $VMResource.Name -ResourceUri $VM.Id
                        Write-Host "Removed data collection rule association for VM: `"$vmName`" with resource type: `"$RType`"" -ForegroundColor Red
                    } else {
                        Write-Warning "VM resource '$vmName' with resource type '$RType' not found in resource group '$RGroupName'."
                    }
                }
            }
            
            Set-AzResource -Resource_API $LATable_API -ResourceName $customTable
            Set-AzResource -Resource_API $DCR_API -ResourceName $dcrName
            Set-AzResource -Resource_API $DCE_API -ResourceName $dceName
            return
        } catch {
            Write-Host "An error occurred: $_" -ForegroundColor Red; Exit 1
        }
    }

    # Provision Azure resources (Custom Table, DCE, & DCR) if the $Action is "Provision"
    if ($Action -eq "Provision") {
    
        # ------------------------------------------------------------
        # Bring in schema for the custom log (table) written in JSON
        # Call Set-AzResource with LAW ResourceId, custom table name, and its associated schema (JSON).
        # https://learn.microsoft.com/en-us/rest/api/loganalytics/tables/create-or-update?view=rest-loganalytics-2023-09-01&tabs=HTTP
        # ------------------------------------------------------------
        [string]$customTablePayload = Get-Content -Path "syslog_CL.json" -Raw

        # Call the helper function to provision Azure resource: LA - Custom Table
        try {
            Set-AzResource -Resource_API $LATable_API -ResourceName $customTable -ResourcePayload $customTablePayload
        } catch {
            Write-Host "An error occurred: `"$customTable`" : $_" -ForegroundColor Red; Exit 1
        }

        # ------------------------------------------------------------
        # Create the Data Collection Endpoint (DCE)
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

        # Call the helper function to provision Azure resource: Data Collection Endpoint (DCE)
        <#
        try {
            Set-AzResource -Resource_API $DCE_API -ResourceName $dceName -ResourcePayload $dcePayload
        } catch {
            Write-Host "An error occurred: `"$dceName`" : $_" -ForegroundColor Red; Exit 1
        }
        #>


        # ---------------------------------------------------------------------------------
        # Create the data collection rule (DCR), linking the DCE and the LAW to the DCR
        # https://learn.microsoft.com/en-us/rest/api/monitor/data-collection-rules/create?view=rest-monitor-2022-06-01&tabs=HTTP
        # ---------------------------------------------------------------------------------
        # Get the DCE Resource Id for DCR association
        #$DCEResult   = Invoke-AzRestMethod -Uri ($DCE_API) -Method GET
        #$DCEResource = $DCEResult.Content | ConvertFrom-JSON
        #Write-Verbose "DCE Resource Id: $($DCEResource.id)"
        
        [string]$dcrPayload = @"
        {
            "name": "$dcrName",
            "location": "$Location",
            "kind": "Linux",
            "properties": {
                "dataSources": {
                    "syslog": [
                        {
                            "name": "csyslog",
                            "streams": [
                                "Microsoft-Syslog"
                            ],
                            "facilityNames": [
                                "*"
                            ],
                            "logLevels": [
                                "*"
                            ]
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
                            "Microsoft-Syslog"
                        ],
                        "destinations": [
                            "law-destination"
                        ],
                        "transformKql": "source",
                        "outputStream": "Custom-${customTable}"
                    }
                ]
            }
        }
"@

        # Call the helper function to provision Azure resource: Data Collection Rule (DCR)
        try {
            Set-AzResource -Resource_API $DCR_API -ResourceName $dcrName -ResourcePayload $dcrPayload
        } catch {
            Write-Host "An error occurred: `"$dcrName`" : $_" -ForegroundColor Red; Exit 1
        }
    }
}
