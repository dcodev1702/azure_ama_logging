<#
Authors: dcodev1702 & my AI Sidekick (ChatGPT)
Date: 12 March 2023

Purpose: Create a Data Collection Rule w/ Data Collection Endpoint (DCR / DCE)
------------------------------------------------------------------------------
1.  Checks to see if the user is logged into Azure and which Cloud (AzureCloud or AzureUSGovernment) via the Environment switch (mandatory)   
     -- This will also set the ResourceURL based on your environment
     -- AzureCloud: 'https://management.azure.com'
     -- AzureUSGov: 'https://management.usgovcloudapi.net/'
2.  Checks to see required Az Modules are installed with the -CheckAzModules switch.
3.  Will save the custom table in JSON if the SaveFile switch is used.
4.  Allows the user to name your Custom Log ( CL ) with the -TableName switch (mandatory) and saves it to the table in JSON.
5.  Allows the user to specify the number of columns and corresponding data types for their CL.
6.  Automatically includes the 2 required columns for all Tables
        TimeGenerated:dateTime
        RawData:string
7.  Provides the user the ability to send their Custom Log to a specified Log A via REST API.

Usage: 
------
. .\helper_functions.ps1
. .\create_custom_table.ps1

Order to make this work, three objects have to be fetched from Azure.
   a. Data Collection Endpoint (DCE - ResourceId) that you want to assign to the DCR
   b. The Log Analytics Table you want to assign to the DCR
   c. Log Analytics Workspace that you want to assign to the DCR

1. Details about the Data Collection Endpoint (assign to DCR)
   [X]  -- CMD: $DCEResults = Get-AzDCE -Environment AzureCloud -ResourceGroup 'sec_telem_law_1' -EndpointName 'CLI-OGKANSAS-DCE' 
   [X]  -- DCE ResourceId -> $DCEResults.Id
2. Stream Declarations:
   [X]  -- INFO: This table needs to match parameters coming from the logging source (e.g. AMA, Logstash, NXLog, Filebeats, etc)
   [_]  -- CMD: N/A
   [X]  -- $TableName
   [X]  -- Table Structure
3. Data Sources | LogFiles:
   [X]  -- Streams: Custom-$TableName
   [X]  -- FilePatterns: [ "/var/lib/docker/volumes/apache2-web_apache2log-volume/_data/access.log" ]
   [X]  -- Format: text
   [X]  -- Name (logFile data source)
4. Destinations:
     -- Log Analytics Workspace (assign to destination within DCR)
     -- CMD: $LAResult = New-AzDCR -Environment AzureCloud -ResourceGroup 'sec_telem_law_1' -Workspace 'aad-telem'
   [X]  -- $LAResult.Id (ResourceId)
   [X]  -- $LAResult.properties.customerId (Workspace Id)
   [X]  -- $LAResult.Name
5. DataFlow:
   [X]  -- Streams: Custom-$TableName
   [X]  -- Destination: Workspace Name [$LAResult.Name]
   [X]  -- transformKql: "source"
   [X]  -- outputStream: Custom-$TableName

COMMAND:
---------
New-AzDCR -Environment 'AzureCloud' -ResourceGroup 'sec_telem_law_1' -Workspace 'aad-telem' `
          -EndpointName 'CLI-APACHE2-AL-DCE' -SaveTable DCR_TABLE.json -TableName 'Apache2_AccessLog_CL' `
          -LogSource '/var/log/secure'

New-AzDCR -Environment 'AzureUSGovernment' -ResourceGroup 'CEF `
-Workspace 'sentinel-law' -EndpointName 'CLI-OGKANSAS-DCE' -SaveTable CLI-APACHE2-AL-DCR.json

NOTES:
------
When creating a NEW DCR, only essential fields are filled in the during creation
From there, it's required pull down (GET) the newly created DCR Rule, MODIFY the 
newly created DCR rule and then push (PUT) the modifications via the REST API.

1. Create a new data collection rule
2. Modify the newly created data collection rule
3. Uploaded the modified DCR via JSON using the REST API

#>

# This feature requires PS >= 4.0
#Requires -RunAsAdministrator

Function New-AzDCR {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet('AzureCloud','AzureUSGovernment')]
        [string]$Environment,
        [Parameter(Mandatory=$true)]
        [string]$ResourceGroup,
        [Parameter(Mandatory=$true)]
        [string]$Workspace,
        [Parameter(Mandatory=$false)]
        [string]$TableName=$null,
        [Parameter(Mandatory=$false)]
        [string]$TableProvided=$null,
        [Parameter(Mandatory=$false)]
        [string]$SaveTable=$null,
        [Parameter(Mandatory=$false)]
        [string]$LogSource=$null,
        [Parameter(Mandatory=$true)]
        [string]$EndpointName,
        [Parameter(Mandatory=$false)]
        [Switch] $CheckAzModules=$false
    )

    
    # Check if the user has an active Azure session
    # Use a flag -CheckAzModules to enable checking of required modules
    if ($CheckAzModules) { Check-AzModules }

    # Before querying Azure, ensure we are logged in
    $AzContext = Get-AzureSubscription($Environment)
    $SubscriptionId = $AzContext.Subscription.Id

    # Get the correct REST API Endpoint for Resource Management
    $resourceUrl = (Get-AzContext).Environment.ResourceManagerUrl

    # API Auth for Invoke-AzRestMethod
    $token = (Get-AzAccessToken -ResourceUrl $resourceUrl).Token
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Authorization","Bearer $token")
    

    # Prompt the user for information
    if (-not $ResourceGroup) {
        $ResourceGroup = Read-Host "Enter ResourceName"
    }
    if (-not $Workspace) {
        $Workspace = Read-Host "Enter WorkspaceName"
    }
    if (-not $TableName) {
        $TableName = Read-Host "Enter TableName"
    }

    # Fetch the specified Log Analytics Workspace
    Write-Host "Fetching -> $Workspace"
    $url_law = "$($resourceUrl)/subscriptions/$($SubscriptionId)/resourcegroups/$ResourceGroup/providers/Microsoft.OperationalInsights/workspaces/$Workspace"
    $WorkspaceContent = Invoke-RestMethod ($url_law+"?api-version=2021-12-01-preview") -Method GET -Headers $headers

    # Make Get-AzDCE Call here!! (e.g. 'CLI-OGKANSAS-DCE')
    Write-Host "Fetching -> $EndpointName"
    $DCEResults = Get-AzDCE -Environment AzureCloud -ResourceGroup 'sec_telem_law_1' -EndpointName $EndpointName


    # Create JSON structure for the custom log (table)
    $tableParams = [ordered]@{
        properties = [ordered]@{
            dataCollectionEndpointId = $DCEResults.id
            streamDeclarations = [ordered]@{
                "Custom-$TableName" = [ordered]@{
                    columns = @(
                        [ordered]@{
                            name = "TimeGenerated"
                            type = "datetime"
                        }
                        [ordered]@{
                            name = "RawData"
                            type = "string"
                        }
                    )
                }
            }
            dataSources = [ordered]@{
                logFiles = @(
                    [ordered]@{
                        streams = @(
                            "Custom-$TableName"
                        )
                        filePatterns = @(
                            $LogSource
                        )
                        format = "text"
                        settings = [ordered]@{
                            text = [ordered]@{
                                recordStartTimestampFormat = "ISO 8601"
                            }
                        }
                        name = $TableName
                    }
                )
            }
            destinations = [ordered]@{
                logAnalytics = @(
                    [ordered]@{
                        workspaceResourceId = $WorkspaceContent.Id
                        workspaceId = $WorkspaceContent.properties.customerId
                        name = $WorkspaceContent.Name
                    }
                )
            }
            dataFlows = @(
                [ordered]@{
                    streams = @(
                        "Custom-$TableName"
                    )
                    destinations = @(
                        $WorkspaceContent.Name
                    )
                    transformKql = "source | project TimeGenerated, RawData"
                    outputStream = "Custom-$TableName"
                }
            )
        }
        location = $DCEResults.location
    }

    # Now execute the command below.  This will create the DCR in AzureUSGovernment.
    # $DCR_JSON = Get-Content -Path "./NEWDCR.json" -Raw 
    
    # $url_newDCR = "$resourceUrl/subscriptions/$($SubscriptionId)/resourceGroups/$($ResourceGroup)/providers/Microsoft.Insights/dataCollectionRules/$($dataCollectionRuleName)”
    # Invoke-AzRestMethod ($url_newDCR+"?api-version=2019-11-01-preview") -Method PUT -Payload $DCR_JSON


    # Deserialize JSON object ($DCEContent) so it can be submitted via REST API 
    $DCR_JSON = ConvertTo-Json -InputObject $tableParams -Depth 32
    Write-Output "Current Structure of your DCR:"
    Write-Output $DCR_JSON


    if ($SaveTable) {
        $tableParams | ConvertTo-Json -Depth 32 | Out-File -FilePath $SaveTable
    }
    

    # Radiate information to the user for self validation
    Write-Host "Resource Management Url: $resourceUrl" -ForegroundColor Green
    Write-Host "Subscription Id: $SubscriptionId" -ForegroundColor Green
    Write-Host "ResourceName: $ResourceGroup" -ForegroundColor Green
    Write-Host "WorkspaceName: $Workspace" -ForegroundColor Green


    $validInput = $false
    while (-not $validInput) {
        Write-Host "Do you want to get Log Analytics Workspace -> [$Workspace] via REST API? (Y/N)" -ForegroundColor Red
        $sendTable = Read-Host "Make your selection "
        if ($sendTable.ToLower() -eq "y" -or $sendTable.ToLower() -eq "n") {
            $validInput = $true
        } else {
            Write-Host "Invalid input. Please enter 'Y' or 'N'." -ForegroundColor Red
        }
    }


    try {

        if ($sendTable.ToLower() -eq "y") {
        
            # Need to add check to ensure Access Token is current before calling Invoke-AzRestMethod
            Write-Host "Getting Workspace [`"$Workspace`"] -> [Env]:$Environment[Id]:$SubscriptionId[RG:]$ResourceGroup" -ForegroundColor Yellow
            #$url_dcr = "$($resourceUrl)/subscriptions/$($SubscriptionId)/resourcegroups/$ResourceGroup/providers/Microsoft.OperationalInsights/workspaces/$Workspace"
            #$WorkspaceContent = Invoke-RestMethod ($url_dcr+"?api-version=2021-12-01-preview") -Method GET -Headers $headers
            $DCRRuleName = Read-Host "Enter a name for your Data Collection Rule (DCR)"
            New-AzDataCollectionRule -Location $DCEResults.location -ResourceGroupName $ResourceGroup -RuleName $DCRRuleName  -RuleFile $SaveTable
            
            
            Write-Host "Workspace `"$Workspace`" recieved via RESTFul API." -ForegroundColor Green
            Write-Host "Workspace Name: $($WorkspaceContent.Name)" -ForegroundColor Cyan
            Write-Host "Workspace ID: $($WorkspaceContent.properties.customerId)" -ForegroundColor Cyan
            Write-Host "Workspace ResourceId: $($WorkspaceContent.Id)" -ForegroundColor Cyan
        
            # HAVE TO CREATE NEW DCR, THEN DOWNLOAD IT, CHANGE IT, AND UPLOAD IT.
            #Write-Host "Sleeping for 20 seconds..." -ForegroundColor Red
            #Start-Sleep -Seconds 20
            
        } else {
            Write-Output "Did not create Data Collection Rule: $DCRRuleName"
        }
    } catch {
        Write-Host "An error occurred while sending the table via the REST API:`n$($_.Exception.Message)" -ForegroundColor Red
    }
    #return ($WorkspaceContent)

    # GET DCR
    $url_DCRRule = "$resourceUrl/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.Insights/dataCollectionRules/$($DCRRuleName)"
    $GOT_DCRContent = Invoke-RestMethod ($url_DCRRule+"?api-version=2021-09-01-preview") -Method GET -Headers $headers

    # Serialized JSON ..modify in place ..then dump the contents to a file and send (PUT) the modified JSON via REST API call.
    $DCRContentJSON = ConvertTo-JSON -Depth 32 -InputObject $GOT_DCRContent | Out-File "$DCRRuleName.json"
    #$DCRContentJSON | Out-File "$($DCRRuleName)-$(Get-Date -Format yyyyMMddTHHmmssffffZ)-Rule.json"

    Write-Host "Just printing to print so I have a line of code before the break point!" -ForegroundColor Red

    <#
    MODIFY THE DOWNLOADED DCR in order to add the following logic to the DCR:
    1. DCE ResourceId
    2. Custom Table via StreamDeclarations
    3. Add logFiles :: DataSources (the whole thing!)
        -- Prompt the user to add their own data source collection path (e.g. /var/log/secure)

    # Copy the modified Data Collection Rule (DCR) to a variable ($DCRRuleName) and call REST API IOT send (PUT) the modified DCR to Azure.
    $GOT_DCRContent = Get-Content ./"$DCRRuleName.json" -Raw
    $url_DCRRule = "$resourceURL/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.Insights/dataCollectionRules/$($DCRRuleName)"
    Invoke-AzRestMethod ($url_DCRRule+"?api-version=2021-09-01-preview") -Method PUT -Payload $GOT_DCRContent
    
    #>
}
