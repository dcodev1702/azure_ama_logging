<#
Author: dcodev1702 & my AI Sidekick (ChatGPT)
Date: 10 March 2023

Usage: Import-AzLACustomTable -Environment 'AzureCloud' `
       -ResourceGroup 'myRG' -Workspace 'myWorkspace' `
       -TableName 'Apache2_AccessLog_CL' -SaveFile 'apache2_accesslog_table.json'

#>

Function Import-AzLACustomTable {
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
        [string]$TableName
    )

    # Check if the user has an active Azure session
    if(Get-AzContext -ErrorAction SilentlyContinue){
        Write-Host "Active Azure session found." -ForegroundColor Green
        $SubscriptionId = (Get-AzContext).Subscription.Id
    } else {
        Write-Host "No active Azure session found. Please run Connect-AzAccount to connect to Azure." -ForegroundColor Red
        Connect-AzAccount -Environment $Environment -UseDeviceAuthentication
        $SubscriptionId = (Get-AzContext).Subscription.Id
    }

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
    $TimeGenerated_ = [ordered]@{
        name = "TimeGenerated"
        type = "dateTime"
    }
    
    $RawData_ = [ordered]@{
        name = "RawData"
        type = "string"
    }
    
    $tableParams.properties.schema.columns += $timeGenerated_
    $tableParams.properties.schema.columns += $rawData_
    
    Write-Host "The mandatory fields `"TimeGenerated:dateTime`" and `"RawData:string `" have been added to your custom log (CL)." -ForegroundColor Magenta
    Write-Host "How many columns would you like to add to your custom table: `"$TableName`"?" -ForegroundColor Yellow
    $columnCount = Read-Host "value"
    
    # Define the accepted data types
    $dataTypes = "string", "dynamic", "dateTime", "bool", "float", "int"
    
    for ($i = 1; $i -le $columnCount; $i++) {
        
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
        Write-Host "Do you want to send your custom table to Log Analytics via the API? (Y/N)" -ForegroundColor Red
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
        
            Invoke-AzRestMethod -Path "/subscriptions/$subscriptionId/resourcegroups/$ResourceGroup/providers/microsoft.operationalinsights/workspaces/$Workspace/tables/$($TableName)?api-version=2021-12-01-preview" -Method PUT -payload $Table
            Write-Host "Table `"$TableName`" created and sent via REST API." -ForegroundColor Green
        } else {
            Write-Host "Table `"$TableName`" created and $($pwd)\$SaveFile but not sent via the REST API." -ForegroundColor Yellow
            Write-Output $Table
        }
    } catch {
        Write-Host "An error occurred while sending the table via API call:`n$($_.Exception.Message)" -ForegroundColor Red
    }

}
