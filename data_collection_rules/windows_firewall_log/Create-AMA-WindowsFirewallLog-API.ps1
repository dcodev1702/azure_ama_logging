<#
Author: DCODEV1702
Date: 5/3/2024

THE SCRIPT IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SCRIPT OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.


Description:
This script will automate the creation of a custom table (CL), data collection endpoint (DCE) and a data collection rule (DCR) 
in Azure Monitor for a Log Analytics Workspace (LAW) to collect and ingest assessment data from a Windows Firewall Log (C:\Windows\System32\LogFiles\Firewall\pfirewall.log).
The script will create the DCE and DCR if they do not already exist and link them with a LAW.

Usage:
1. Open a PowerShell or Azure Cloud Shell session w/ Az module installed & the appropriate permissions
2. Update the variables in the "CHANGE ME" section below
3. Run the PowerShell script
    . ./Create-AMA-WindowsFirewallLog-API.ps1
    Invoke-WindowsFW-API -Action Provision -ResourceGroup "sec_telem_law_1" -WorkspaceName "aad-telem" -Location "eastus"
    Invoke-WindowsFW-API -Action Delete -ResourceGroup "sec_telem_law_1" -WorkspaceName "aad-telem" -Location "eastus"
#>

function Invoke-WindowsFW-API {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("Provision","Delete")]
        [string]$Action,
        [Parameter(Mandatory=$true)][string]$ResourceGroup,
        [Parameter(Mandatory=$true)][string]$WorkspaceName,
        [Parameter(Mandatory=$true)][string]$Location
    )

    # !!! Location of Windows Firewall Log !!!
    [string]$DCRFilePattern = "C:\\Windows\\System32\\LogFiles\\Firewall\\pfirewall.log"

    # Data Collection Rule, Data Collection Endpoint, and Log Analytics Custom Log (Table)
    [string]$dceName     = "WindowsFWLog-DCE"
    [string]$dcrName     = "WindowsFWLog-DCR"
    [string]$customTable = "WindowsFWLog_CL"

    # Set your Subscription if necessary -> Set-AzContext -Subscription 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'
    [string]$ResourceManagerUrl = (Get-AzContext).Environment.ResourceManagerUrl
    [string]$SubscriptionId     = (Get-AzContext).Subscription.Id
    
    # -----------------------------------------------------------------------------------------
    # REST API calls to validate, provision, and get the status of Azure resources (id's, etc.)
    # -----------------------------------------------------------------------------------------
    [string]$LAW_API     = "$ResourceManagerUrl/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.OperationalInsights/workspaces/${WorkspaceName}?api-version=2023-09-01"
    [string]$LATable_API = "$ResourceManagerUrl/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.OperationalInsights/workspaces/$WorkspaceName/tables/${customTable}?api-version=2022-10-01"
    [string]$DCE_API     = "$ResourceManagerUrl/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.Insights/dataCollectionEndpoints/${dceName}?api-version=2022-06-01"
    [string]$DCR_API     = "$ResourceManagerUrl/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.Insights/dataCollectionRules/${dcrName}?api-version=2022-06-01"

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
                    $VM = Get-AzResource -ResourceGroupName $RGroupName -Name $vmName -ResourceType $RType

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
                        },
                        {
                            "name": "ACTION",
                            "type": "string"
                        },
                        {
                            "name": "PROTOCOL",
                            "type": "string"
                        },
                        {
                            "name": "SRC_IP",
                            "type": "string"
                        },
                        {
                            "name": "DST_IP",
                            "type": "string"
                        },
                        {
                            "name": "SRC_PORT",
                            "type": "string"
                        },
                        {
                            "name": "DST_PORT",
                            "type": "string"
                        },
                        {
                            "name": "SIZE",
                            "type": "string"
                        },
                        {
                            "name": "TCPFLAGS",
                            "type": "string"
                        },
                        {
                            "name": "TCPSYN",
                            "type": "string"
                        },
                        {
                            "name": "TCPACK",
                            "type": "string"
                        },
                        {
                            "name": "TCPWIN",
                            "type": "string"
                        },
                        {
                            "name": "ICMPTYPE",
                            "type": "string"
                        },
                        {
                            "name": "ICMPCODE",
                            "type": "string"
                        },
                        {
                            "name": "INFO",
                            "type": "string"
                        },
                        {
                            "name": "PATH",
                            "type": "string"
                        },
                        {
                            "name": "PID",
                            "type": "string"
                        }
                    ]
                },
                "retentionInDays": 120,
                "totalRetentionInDays": 365
            }
        }
"@

        # Call the helper function to provision Azure resource: LA - Custom Table
        try {
            Set-AzResource -Resource_API $LATable_API -ResourceName $customTable -ResourcePayload $customTablePayload
        } catch {
            Write-Host "An error occurred: `"$customTable`" : $_" -ForegroundColor Red; Exit 1
        }

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

        # Call the helper function to provision Azure resource: Data Collection Endpoint (DCE)
        try {
            Set-AzResource -Resource_API $DCE_API -ResourceName $dceName -ResourcePayload $dcePayload
        } catch {
            Write-Host "An error occurred: `"$dceName`" : $_" -ForegroundColor Red; Exit 1
        }


        # ---------------------------------------------------------------------------------
        # Create the data collection rule (DCR), linking the DCE and the LAW to the DCR
        #   
        # https://learn.microsoft.com/en-us/rest/api/monitor/data-collection-rules/create?view=rest-monitor-2022-06-01&tabs=HTTP
        # ---------------------------------------------------------------------------------
        # Get the DCE Resource Id for DCR association
        $DCEResult   = Invoke-AzRestMethod -Uri ($DCE_API) -Method GET
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
                        "transformKql": "source\n| extend TimeGenerated = now()\n| parse RawData with Date:string ' ' Time:string ' ' ACTION:string ' ' PROTOCOL:string ' ' SRC_IP:string ' ' DST_IP:string ' ' SRC_PORT:string ' ' DST_PORT:string ' ' SIZE:string ' ' TCPFLAGS:string ' ' TCPSYN:string ' ' TCPACK:string ' ' TCPWIN:string ' ' ICMPTYPE:string ' ' ICMPCODE:string ' ' INFO:string ' ' PATH:string ' ' PID:string \n| project TimeGenerated, ACTION, PROTOCOL, SRC_IP, DST_IP, SRC_PORT, DST_PORT, SIZE, TCPFLAGS, TCPSYN, TCPACK, TCPWIN, ICMPTYPE, ICMPCODE, INFO, PATH, PID\n",
                        "outputStream": "Custom-$customTable"
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
