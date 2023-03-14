<#
Authors: dcodev1702 & my AI Sidekick (ChatGPT)
Date: 11 March 2023

Purpose: Create a Data Collection Endpoint (DCE)
-------------------------------------------------
1.  Checks to see if the user is logged into Azure and which Cloud (AzureCloud or AzureUSGovernment) via the Environment switch (mandatory)   
     -- This will also set the ResourceURL based on your environment
     -- Same Resource URL regardless of Environment: providers/Microsoft.Insights/dataCollectionEndpoints
2.  Checks to see required Az Modules are installed with the -CheckAzModules switch.
3.  Allows the user to name the Data Collection Endpoint ( DCE ) with the -EndpointName switch (mandatory).
4.  Allows the user to specify the operating system
5.  Allows the user to define network access of the endpoint:
      -- Enabled
      -- Disabled
6.  Allows the user to specify the location.
7.  Allows the user to send their DCE to Azure Monitor via REST API.

Usage: 
------
. .\helper_functions.ps1
. .\create_dce.ps1

New-AzDCE -Environment 'AzureCloud' -ResourceGroup 'myRG' -Location 'eastus' `
          -EndpointName 'CLI-UNIQUENAME-DCE' -OperatingSystem 'Linux'

US GOVERNMENT CLOUD:
--------------------
New-AzDCE -Environment 'AzureUSGovernment' -ResourceGroup 'CEF' `
 -Location 'usgovvirginia' -EndpointName 'CLI-W3CIISLogs-ZO-DCE' -OperatingSystem 'Windows' -NetworkIsPublic $true

#>

# This feature requires PS >= 4.0
#Requires -RunAsAdministrator


Function New-AzDCE {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet('AzureCloud','AzureUSGovernment')]
        [string]$Environment,
        [Parameter(Mandatory=$true)]
        [string]$Location,
        [Parameter(Mandatory=$false)]
        [string]$ResourceGroup,
        [Parameter(Mandatory=$true)]
        [string]$EndpointName,
        [Parameter(Mandatory=$true)]
        [bool]$NetworkIsPublic=$true,
        [Parameter(Mandatory=$false)]
        [ValidateSet('Linux','Windows')]
        [string]$OperatingSystem,
        [Parameter(Mandatory=$false)]
        [Switch] $CheckAzModules=$false
    )

    
    # Check if the user has an active Azure session
    # Use a flag -CheckAzModules to enable checking of required modules
    if ($CheckAzModules) { Check-AzModules }

    # Before querying Azure, ensure we are logged in
    $AzContext = Get-AzureSubscription($Environment)
    $SubscriptionId = $AzContext.Subscription.Id

    # Get Azure Access (JWT) Token for API Auth/Access 
    if($AzContext.Environment.Name -eq 'AzureCloud') {
        $resourceUrl = 'https://management.azure.com'
    } else {
        $resourceUrl = 'https://management.usgovcloudapi.net/'
    }

    # API Auth for Invoke-AzRestMethod
    $token = (Get-AzAccessToken -ResourceUrl $resourceUrl).Token
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Authorization","Bearer $token")
    
    # Prompt the user for information
    if (-not $Location) {
        $Location = Read-Host "Enter Endpoint Location"
    }
    if (-not $ResourceGroup) {
        $ResourceGroup = Read-Host "Enter ResourceName"
    }
    if (-not $EndpointName) {
        $EndpointName = Read-Host "Enter name of Endpoint"
    }
    if ($NetworkIsPublic) {
        $NetworkAccess = 'Enabled'
    } else {
        $NetworkAccess = 'Disabled'
    }
   
    # Create JSON structure for the data collection endpoint
    $DCEContent = [ordered]@{
        location = $Location
        properties = [ordered]@{
            networkAcls = [ordered]@{
                publicNetworkAccess = $NetworkAccess
            }
        }
    }
    
    # Radiate information to the user for self validation
    Write-Host "Subscription Id: $SubscriptionId" -ForegroundColor Green
    Write-Host "Resource Group: $ResourceGroup" -ForegroundColor Green
    Write-Host "EndpointName: $EndpointName" -ForegroundColor Green
    Write-Host "Operating System: $OperatingSystem" -ForegroundColor Cyan
    Write-Host "Location: $Location" -ForegroundColor Cyan

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
        $DCE_JSON = ConvertTo-Json -InputObject $DCEContent -Depth 32
        if ($sendTable.ToLower() -eq "y") {
        
            # Need to add check to ensure Access Token is current before calling Invoke-AzRestMethod
            Write-Host "Sending DCE [`"$EndpointName`"] -> [Env]:$Environment[Id]:$SubscriptionId[RG:]$ResourceGroup" -ForegroundColor Yellow
            
            $url_dce = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.Insights/dataCollectionEndpoints/$($EndpointName)"
            Invoke-AzRestMethod -Path ($url_dce+"?api-version=2021-09-01-preview") -Method PUT -Payload $DCE_JSON

            Write-Host "DCE [$EndpointName::$OperatingSystem] created and sent via RESTFul API." -ForegroundColor Green
        } else {
            Write-Host "Data Collection Endpoint:" -ForegroundColor Cyan 
            Write-Host $DCE_JSON
        }
    } catch {
        Write-Host "An error occurred while sending Data Collection Endpoint via the REST API:`n$($_.Exception.Message)" -ForegroundColor Red
    }
}

Function Get-AzDCE {

    # Usage:
    # $DCEResult = Get-AzDCE -Environment AzureCloud -ResourceGroup 'sec_telem_law_1' -EndpointName 'CLI-OGKANSAS-DCE' 

    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet('AzureCloud','AzureUSGovernment')]
        [string]$Environment,
        [Parameter(Mandatory=$true)]
        [string]$ResourceGroup,
        [Parameter(Mandatory=$true)]
        [string]$EndpointName,
        [Parameter(Mandatory=$false)]
        [Switch] $CheckAzModules=$false
    )

    # Before querying Azure, ensure we are logged in
    $AzContext = Get-AzureSubscription($Environment)
    $SubscriptionId = $AzContext.Subscription.Id

    # Get Azure Access (JWT) Token for API Auth/Access 
    if($AzContext.Environment.Name -eq 'AzureCloud') {
        $resourceUrl = 'https://management.azure.com'
    } else {
        $resourceUrl = 'https://management.usgovcloudapi.net/'
    }

    # API Auth for Invoke-AzRestMethod
    $token = (Get-AzAccessToken -ResourceUrl $resourceUrl).Token
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Authorization","Bearer $token")

    $url_get_dce = "$resourceUrl/subscriptions/$($SubscriptionId)/resourceGroups/$($ResourceGroup)/providers/Microsoft.Insights/dataCollectionEndpoints/$($EndpointName)"
    $DCEInfo = Invoke-RestMethod ("$url_get_dce"+"?api-version=2021-09-01-preview") -Method GET -Headers $headers

    Write-Host "Data Collection Endpoint ID: $($DCEInfo.Id)" -ForegroundColor Cyan
    return($DCEInfo)
}