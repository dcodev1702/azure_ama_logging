<#
Author: dcodev1702 & my AI Sidekick (ChatGPT)
Date: 10 March 2023

Usage: Import-AzLACustomeTable -Environment 'AzureCloud' `
       -ResourceGroup 'myRG' -Workspace 'myWorkspace' `
       -TableName 'Apache2_AccessLog_CL' -SaveFile 'apache2_accesslog_table.json'

#>

# This feature requires PS >= 4.0
#Requires -RunAsAdministrator

function Get-AzureSubscription($Environment) {

    # Test to see if there's an active login session to the Azure tenant
    # Returns null of no login session exists 
    $context = Get-AzContext -ErrorAction SilentlyContinue
    if(!$context) {
        # Check to see if Resource Group specified exists within the provided Azure Subscription
        Write-Host "No active Azure session found. Please run Connect-AzAccount to connect to Azure." -ForegroundColor Magenta
        Write-Host "`r`nYou will be asked to log in to your Azure environment if a session does not already exist. `nGlobal Admin or Security Admin credentials are required. `nThis will allow the script to interact with Azure as required.`r`n" -BackgroundColor Magenta
        Read-Host -Prompt "Press enter to continue or CTRL+C to quit the script"
        $context = Connect-AzAccount -Environment $Environment -UseDeviceAuthentication
     
    } else {
        Write-Host "Active Azure session found." -ForegroundColor Green
    }
    return ($context)
}

function Check-AzModules() {

    # Make sure any modules we depend on are installed
    # Credit to: Koos Goossens @ Wortell.
    $modulesToInstall = @(
        'Az.Accounts',
        'Az.Compute'
    )

    Write-Host "Installing/Importing PowerShell modules..." -ForegroundColor Green
    $modulesToInstall | ForEach-Object {
        if (-not (Get-Module -ListAvailable $_)) {
            Write-Host "  ┖─ Module [$_] not found, installing..." -ForegroundColor Green
            Install-Module $_ -Force
        } else {
            Write-Host "  ┖─ Module [$_] already installed." -ForegroundColor Green
        }
    }

    $modulesToInstall | ForEach-Object {
        if (-not (Get-InstalledModule $_)) {
            Write-Host "  ┖─ Module [$_] not loaded, importing..." -ForegroundColor Green
            Import-Module $_ -Force
        } else {
            Write-Host "  ┖─ Module [$_] already loaded." -ForegroundColor Green
        }
    }
}



Function Import-AzLACustomeTable {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet('AzureCloud','AzureUSGovernment')]
        [string]$Environment,
        [Parameter(Mandatory=$false)]
        [string]$SaveFile=$null,
        [Parameter(Mandatory=$false)]
        [string]$ResourceGroup,
        [Parameter(Mandatory=$false)]
        [string]$Workspace,
        [Parameter(Mandatory=$false)]
        [string]$TableName,
        [Parameter(Mandatory = $false)]
        [Switch] $CheckAzModules = $false
    )

    
    # Check if the user has an active Azure session
    # Use a flag -CheckAzModules to enable checking of required modules
    if ($CheckAzModules) { Check-AzModules }

    # Before querying Azure, ensure we are logged in
    $AzContext = Get-AzureSubscription($Environment)

    # Get Azure Access (JWT) Token for API Auth/Access 
    if($AzContext.Environment.Name -eq 'AzureCloud') {
        $resourceUrl = 'https://management.azure.com'
    } else {
        $resourceUrl = 'https://management.usgovcloudapi.net/'
    }

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

    # Create JSON structure for the custom log (table)
    $tableParams = [ordered]@{
        properties = [ordered]@{
            schema = [ordered]@{
                name = $TableName
                columns = @()
            }
        }
    }
    
    # As per the requirement for a custom log
    # TimeGenerated:dateTime and RawData:string MUST be provided at a minimum
    $timeGenerated_ = [ordered]@{
        name = "TimeGenerated"
        type = "dateTime"
    }
    
    $rawData_ = [ordered]@{
        name = "RawData"
        type = "string"
    }
    
    $tableParams.properties.schema.columns += $timeGenerated_
    $tableParams.properties.schema.columns += $rawData_
    
    Write-Host "The mandatory fields `"TimeGenerated:dateTime`" and `"RawData:string `" have already been added to your custom log (CL)." -ForegroundColor Magenta
    Write-Host "How many columns do you want to add to custom table: `"$TableName`"?" -ForegroundColor Yellow
    $columnCount = Read-Host "value"
    

    for ($i = 1; $i -le $columnCount; $i++) {

        # Define the accepted data types
        $dataTypes = "string", "dynamic", "dateTime", "bool", "float", "int"
        
        Write-Host "Valid datatypes are: string, dynamic, dateTime, bool, float, and int" -ForegroundColor Yellow
        $columnName = Read-Host "Enter the column name for column $i"
        
        # Validate the provided data type(s)
        do {
            $dataType = Read-Host "Enter the column data type for column $i (accepted types: $dataTypes)"
            $isValidType = $dataTypes.Contains($dataType)
            if (-not $isValidType) {
                Write-Host "Invalid column type. Please enter one of the accepted data types."
            }
        } until ($isValidType)
            
        $column = [ordered]@{
            name = $columnName
            type = $dataType
        }
        $tableParams.properties.schema.columns += $column
    }
    
    if ($SaveFile) {
        $tableParams | ConvertTo-Json -Depth 32 | Out-File -FilePath $SaveFile
    }

    # Radiate information to the user for self validation
    Write-Host "Subscription Id: $SubscriptionId" -ForegroundColor Green
    Write-Host "FilePath: $SaveFile" -ForegroundColor Green
    Write-Host "ResourceName: $ResourceGroup" -ForegroundColor Green
    Write-Host "WorkspaceName: $Workspace" -ForegroundColor Green
    Write-Host "TableName: $TableName" -ForegroundColor Green


    $validInput = $false
    while (-not $validInput) {
        Write-Host "Do you want to send your custom table to Log Analytics via API? (Y/N)" -ForegroundColor Red
        $sendTable = Read-Host "Make your selection "
        if ($sendTable.ToLower() -eq "y" -or $sendTable.ToLower() -eq "n") {
            $validInput = $true
        } else {
            Write-Host "Invalid input. Please enter 'Y' or 'N'." -ForegroundColor Red
        }
    }


    try {

        $Table = $tableParams | ConvertTo-JSON -Depth 32
        if ($sendTable.ToLower() -eq "y") {
        
            # Need to add check to ensure Access Token is current before calling Invoke-AzRestMethod
            $subscriptionId = $AzContext.Subscription.Id
            Invoke-AzRestMethod -Path "/subscriptions/$subscriptionId/resourcegroups/$ResourceGroup/providers/microsoft.operationalinsights/workspaces/$Workspace/tables/$($TableName)?api-version=2021-12-01-preview" -Method PUT -payload $Table
            Write-Host "Table `"$TableName`" created and sent via RESTFul API." -ForegroundColor Green
        } else {
            Write-Host "Table `"$TableName`" created and $($pwd)\$SaveFile but not sent via the REST API." -ForegroundColor Yellow
            Write-Output $Table
        }
    } catch {
        Write-Host "An error occurred while sending the table via API call:`n$($_.Exception.Message)" -ForegroundColor Red
    }

}
