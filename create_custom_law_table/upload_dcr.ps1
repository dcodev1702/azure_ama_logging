<#
Authors: dcodev1702 & my AI Sidekick (ChatGPT)
Date: 12 March 2023

Purpose: Upload Data Collection Rule (DCR) to Azure Monitor
-----------------------------------------------------------
1.  Checks to see if the user is logged into Azure and which Cloud (AzureCloud or AzureUSGovernment) via the Environment switch (mandatory)   
        -- This will also set the ResourceURL based on your environment


Usage: 
------
. .\helper_functions.ps1
. .\upload_dcr.ps1

Azure Commercial:
------------------
Upload-AzDataCollectionRule -Environment 'AzureCloud' -ResourceGroup 'sec_telem_law_1' `
-DCRRuleName 'CLI-WHYTHO-DCR' -DCRJSONFile "./CLI-WHYTHO-DCR-Rule.json"

Microsoft Azure Government (MAG):
---------------------------------
Upload-AzDataCollectionRule -Environment 'AzureUSGovernment' -ResourceGroup 'CEF' `
-DCRRuleName 'CLI-W3CIISLogs-ZO-DCE' -DCRJSONFile "./CLI-WHYTHO-DCR-Rule.json"

#>

# This feature requires PS >= 4.0
#Requires -RunAsAdministrator


Function Upload-AzDataCollectionRule {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet('AzureCloud','AzureUSGovernment')]
        [string]$Environment,
        [Parameter(Mandatory=$true)]
        [string]$ResourceGroup,
        [Parameter(Mandatory=$true)]
        [string]$DCRRuleName,
        [Parameter(Mandatory=$true)]
        [string]$DCRJSONFile,
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
    if (-not $DCRRuleName) {
        $DCRRuleName = Read-Host "Enter name of Endpoint"
    }
    
    # Radiate information to the user for self validation
    Write-Host "Subscription Id: $SubscriptionId" -ForegroundColor Green
    Write-Host "Resource Group: $ResourceGroup" -ForegroundColor Green
    Write-Host "EndpointName: $DCRRuleName" -ForegroundColor Green
    

    $validInput = $false
    while (-not $validInput) {
        Write-Host "Do you want to upload your Data Collection Endpoint (DCE) to Azure Monitor via REST API? (Y/N)" -ForegroundColor Red
        $sendTable = Read-Host "Make your selection "
        if ($sendTable.ToLower() -eq "y" -or $sendTable.ToLower() -eq "n") {
            $validInput = $true
        } else {
            Write-Host "Invalid input. Please enter 'Y' or 'N'." -ForegroundColor Red
        }
    }

    try {

        # Deserialize JSON object ($DCEContent) so it can be submitted via REST API 
        #$DCE_JSON = ConvertTo-Json -InputObject $DCEContent -Depth 32
        if ($sendTable.ToLower() -eq "y") {
        
            # Need to add check to ensure Access Token is current before calling Invoke-AzRestMethod
            Write-Host "Sending Modified DCR [`"$DCRRuleName`"] -> [Env]:$Environment[Id]:$SubscriptionId[RG:]$ResourceGroup" -ForegroundColor Yellow
            
            # PUT -- Get Modified JSON to upload to DCR
            $DCR_JSON = Get-Content -Path $DCRJSONFile -Raw
            
            $url_DCRRule = "$resourceUrl/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.Insights/dataCollectionRules/$($DCRRuleName)"
            Invoke-AzRestMethod ($url_DCRRule+"?api-version=2021-09-01-preview") -Method PUT -Payload $DCR_JSON

            Write-Host "DCR [$DCRRuleName] successfully modified and sent via RESTFul API." -ForegroundColor Green
        } else {
            Write-Host "Data Collection Endpoint: $DCRRuleName" -ForegroundColor Cyan 
            Write-Host $DCE_JSON
        }
    } catch {
        Write-Host "An error occurred while sending Data Collection Endpoint via the REST API:`n$($_.Exception.Message)" -ForegroundColor Red
    }
}
