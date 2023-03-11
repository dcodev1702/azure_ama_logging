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
        Write-Output "Active Azure session found."
        $SubscriptionId = (Get-AzContext).Subscription.Id
    } else {
        Write-Output "No active Azure session found. Please run Connect-AzAccount to connect to Azure."
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

    
    # LA Custom Table Creation (LA -eq Log Analytics)
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

    if ($SaveFile) {
        $table | ConvertTo-Json -Depth 32 | Out-File -FilePath $SaveFile
    }

    $TableParams = $table | ConvertTo-JSON -Depth 32

    # Do something with the input parameters
    Write-Host "Subscription Id: $SubscriptionId" -ForegroundColor Green
    Write-Host "FilePath: $SaveFile" -ForegroundColor Green
    Write-Host "ResourceName: $ResourceGroup" -ForegroundColor Green
    Write-Host "WorkspaceName: $Workspace" -ForegroundColor Green
    Write-Host "TableName: $TableName" -ForegroundColor Green

    Write-Host "Do you want to send the table via API call? (Y/N)" -ForegroundColor Red
    $sendTable = Read-Host 

    if ($sendTable.ToLower() -eq "y") {
        Invoke-AzRestMethod -Path "/subscriptions/$subscriptionId/resourcegroups/$ResourceGroup/providers/microsoft.operationalinsights/workspaces/$Workspace/tables/$($TableName)?api-version=2021-12-01-preview" -Method PUT -payload $TableParams
        Write-Host "Table `"$TableName`" created and sent via RESTFul API." -ForegroundColor Green
    } else {
        Write-Host "Table `"$TableName`" created and $SaveFile but not sent via API call." -ForegroundColor Yellow
        Write-Output $TableParams
    }

}
