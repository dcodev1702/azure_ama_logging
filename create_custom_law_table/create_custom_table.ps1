<#
Author: dcodev1702
Date: 10 March 2023

Usage: Import-AzLACustomeTable -Environment AzureCloud `
       -ResourceGroup 'myRG' -Workspace 'myWorkspace' `
       -TableName 'Apache2_AccessLog_CL' -SaveFile 'apache2_accesslog_table.json'

#>

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

    

    <#
    $TimeGenerated_ = @{
        name = "TimeGenerated"
        type = "DateTime"
    }
    
    $RawData_ = @{
        name = "RawData"
        type = "String"
    }

    $PID_ = @{
        name = "PID"
        type = "dynamic"
    }
    
    $Filename_ = @{
        name = "Filename"
        type = "dynamic"
    }
    
    $RemoteIP_ = @{
        name = "RemoteIP"
        type = "dynamic"
    }
    
    $Server_ = @{
        name = "Server"
        type = "dynamic"
    }
    
    $Request_ = @{
        name = "Request"
        type = "dynamic"
    }
    
    $Method_ = @{
        name = "Method"
        type = "dynamic"
    }
    
    $Status_ = @{
        name = "Status"
        type = "dynamic"
    }
    
    $BytesSent_ = @{
        name = "BytesSent"
        type = "dynamic"
    }
    
    $UserAgent_ = @{
        name = "UserAgent"
        type = "dynamic"
    }
    
    $Referer_ = @{
        name = "Referer"
        type = "dynamic"
    }
    
    $columns = @(
        $TimeGenerated_,
        $RawData_,
        $PID_,
        $Filename_,
        $RemoteIP_,
        $Server_,
        $Request_,
        $Method_,
        $Status_,
        $BytesSent_,
        $UserAgent_,
        $Referer_
    )
    
    $schema = @{
        name = $TableName
        columns = $columns
    }

    $properties = @{
        schema = $schema
    }

    $table = @{
        properties = $properties
    }
#>
    $tableParams = [ordered]@{
        properties = [ordered]@{
            schema = [ordered]@{
                name = $TableName
                columns = @()
            }
        }
    }
    
    $TimeGenerated_ = @{
        name = "TimeGenerated"
        type = "dateTime"
    }
    
    $RawData_ = @{
        name = "RawData"
        type = "string"
    }
    
    $tableParams.properties.schema.columns += $timeGenerated_
    $tableParams.properties.schema.columns += $rawData_
    
    Write-Host "The mandatory fields `"TimeGenerated:dateTime`" and `"RawData:string `" have already been added to your custom log (CL)." -ForegroundColor Magenta
    Write-Host "How many columns do you want to add to custom table: `"$TableName`"?" -ForegroundColor Yellow
    $columnCount = Read-Host "value"
    
    # Define the accepted data types
    $dataTypes = "string", "dynamic", "dateTime", "bool", "float", "int"

    Write-Host "Valid datatypes are: string, dynamic, dateTime, bool, float, and int" -ForegroundColor Yellow
    for ($i = 1; $i -le $columnCount; $i++) {
        $columnName = Read-Host "Enter the column name for column $i"
        #$dataType = Read-Host "Enter the column datatype for column $columnName"
        
        # Validate the column type
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

    $Table = $tableParams | ConvertTo-JSON -Depth 32

    # Do something with the input parameters
    Write-Host "Subscription Id: $SubscriptionId" -ForegroundColor Green
    Write-Host "FilePath: $SaveFile" -ForegroundColor Green
    Write-Host "ResourceName: $ResourceGroup" -ForegroundColor Green
    Write-Host "WorkspaceName: $Workspace" -ForegroundColor Green
    Write-Host "TableName: $TableName" -ForegroundColor Green

    Write-Host "Do you want to send your custom table to Log Analytics via API? (Y/N)" -ForegroundColor Red
    $sendTable = Read-Host "Selection "

    if ($sendTable.ToLower() -eq "y") {
        Invoke-AzRestMethod -Path "/subscriptions/$subscriptionId/resourcegroups/$ResourceGroup/providers/microsoft.operationalinsights/workspaces/$Workspace/tables/$($TableName)?api-version=2021-12-01-preview" -Method PUT -payload $Table
        Write-Host "Table `"$TableName`" created and sent via RESTFul API." -ForegroundColor Green
    } else {
        Write-Host "Table `"$TableName`" created and $($pwd)\$SaveFile but not sent via the REST API." -ForegroundColor Yellow
        Write-Output $Table
    }

}
