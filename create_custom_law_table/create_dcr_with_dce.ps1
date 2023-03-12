<#
Authors: dcodev1702 & my AI Sidekick (ChatGPT)
Date: 12 March 2023

Purpose: Create a Data Collection Rule w/ Data Collection Endpoint (DCR / DCE)
----------------------------------------------------------------
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
     -- DCE ResourceId
2. Stream Declarations:
     -- Table Name
     -- Table Structure
3. Data Sources | LogFiles:
     -- Streams: Table Name
     -- FilePatterns: [ "/var/log/apache2/access.log" ]
     -- Format: text
     -- Name (logFile data source)
4. Destinations:
     -- Log Analytics Workspace (assign to destination within DCR)
        ++ Workspace ResourceId
        ++ Workspace Id
        ++ Workspace Name
5. DataFlow:
     -- Streams: Table Name
     -- Destination: Workspace Name
     -- transformKql: "source"

New-AzDCR -Environment 'AzureCloud' -ResourceGroup 'myRG' -Workspace 'myWorkspace' -TableName 'Apache2_AccessLog_CL'

#>

# This feature requires PS >= 4.0
#Requires -RunAsAdministrator

Function New-AzDCR {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet('AzureCloud','AzureUSGovernment')]
        [string]$Environment,
        [Parameter(Mandatory=$false)]
        [string]$ResourceGroup,
        [Parameter(Mandatory=$false)]
        [string]$Workspace,
        [Parameter(Mandatory = $false)]
        [Switch] $CheckAzModules = $false
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
    if (-not $ResourceGroup) {
        $ResourceGroup = Read-Host "Enter ResourceName"
    }
    if (-not $Workspace) {
        $Workspace = Read-Host "Enter WorkspaceName"
    }
    

    # Radiate information to the user for self validation
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
            $url_dcr = "$($resourceUrl)/subscriptions/$($SubscriptionId)/resourcegroups/$ResourceGroup/providers/Microsoft.OperationalInsights/workspaces/$Workspace"
            $WorkspaceContent = Invoke-RestMethod ($url_dcr+"?api-version=2021-12-01-preview") -Method GET -Headers $headers
        
            Write-Host "Workspace `"$Workspace`" recieved via RESTFul API." -ForegroundColor Green
            Write-Host "Workspace Name: $($WorkspaceContent.Name)" -ForegroundColor Cyan
            Write-Host "Workspace ID: $($WorkspaceContent.properties.customerId)" -ForegroundColor Cyan
            Write-Host "Workspace ResourceId: $($WorkspaceContent.Id)" -ForegroundColor Cyan
        } else {
            Write-Output "Did not fetch LA Workspace: $Workspace"
        }
    } catch {
        Write-Host "An error occurred while sending the table via the REST API:`n$($_.Exception.Message)" -ForegroundColor Red
    }
    return ($WorkspaceContent)
}
