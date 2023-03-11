<#
Author: dcodev1702 & my AI Sidekick (ChatGPT)
Date: 11 March 2023
File: helper_functions.ps1
Purpose: Helper Azure Login and Az Module logic/checks to be 
used with other PowerShell scripts

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
        Write-Host "No active Azure session found. Please run Connect-AzAccount to connect to Azure." -ForegroundColor Red
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
