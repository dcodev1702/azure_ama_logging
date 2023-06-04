<#
Author: DCODev, Co-Pilot, ChatGPT-4
Date: 4 June 2023
Filename: automated_modify_dcr.ps1

CmdLet:
--------
Invoke-DCRModify -DCR_Action [Get|Set]

End-State:
----------
Automate (ish) the getting and setting of Data Collection Rules so they can be
modified appropriately.  That is all this script aims to accomplish. This script does not
create new DCRs, it does not delete DCRs, and it does not associate DCRs with Resources.

Pre-Condition:
---------------
1. Azure PS Modules are installed or you're in the Cloud Shell (PowerShell)
2. Your Cloud Environment is set to the appropriate cloud (AzureCloud or AzureUSGovernment)
3. Log in to your Azure tenant with the necessary permissions
   Connect-AzAccount -UseDeviceAuthentication -Environment <Your Cloud Env>

TODO:
-----
Very little exception handling exists.  This is a down and dirty PowerShell script designed
to get the job done using GET or SET options supplied to the CmdLet (Invoke-DCRModify). This
script has been slightly refactored, however there is still lot of duplicate code and 
I'm sure, plenty of bugs :|

The intent of the script is to allow you to modify a Data Collection Rule (DCR) that reside
in Azure Monitor via the REST API. That's pretty much the gist of it.
#>

function Invoke-DCRModify {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("Get","Set")]
        [string]$DCR_Action
    )

    
    Begin {

        [string]$resourceGroup = $null
        [string]$DCRName = $null
        $dataCollectionRule = $null

        Write-Host "Welcome to Invoke-DCRModify for your Data Collection Rules (DCR)!" -ForegroundColor Green
        Write-Host "You passed in $DCR_Action`n" -ForegroundColor Green

        # Get the collection of Data Collection Rules
        $dataCollectionRules = (Get-AzDataCollectionRule -WarningAction SilentlyContinue)
        
        # Calculate the length of the highest index for padding purposes
        $idxLen = $dataCollectionRules.Count.ToString().Length

        if ($DCR_Action.ToLower() -eq 'get') {
            
            # Display the resource groups with their index
            for ($i=0; $i -lt $dataCollectionRules.Count; $i++) {

                # Write-Host "$i  $($resourceGroups[$i])"
                $indexFormattedDCRs = "{0,$idxLen} -> {1}" -f $i, $dataCollectionRules[$i].Name
                Write-Host $indexFormattedDCRs
            }

            Write-Host ""
            # Prompt the user to enter an index
            $index = Read-Host -Prompt 'Enter the index of the Data Collection Rule (DCR) you want to select'
            $index = [int]$index.Trim()
            # Check if the entered index is valid
            if ($index -ge 0 -and $index -lt $dataCollectionRules.Count) {
                $dataCollectionRule = $dataCollectionRules[$index]
                $DCRName = $dataCollectionRule.Name
            }else{
                Write-Host "Invalid index entered.  Exiting script." -ForegroundColor Red
                Exit
            }

        }

        if ($DCR_Action.ToLower() -eq 'set') {

            Write-Host "Process Block::DCR Action: $DCR_Action" -ForegroundColor Yellow
            $DCRJsonFiles = (Get-ChildItem -Path .\ -Filter *.json).Name

            $idxLen = $DCRJsonFiles.Count.ToString().Length
            
            # List JSON Files by index and prompt user to select an index
            if ($DCRJsonFiles.Count -gt 1) {
                Write-Host "The following JSON files were found in the current directory:" -ForegroundColor Green
                
                for ($i=0; $i -lt $DCRJsonFiles.Count; $i++) {

                    $indexFormattedDCRJsonFiles = "{0,$idxLen} -> {1}" -f $i, $DCRJsonFiles[$i]
                    Write-Host $indexFormattedDCRJsonFiles
                }
            }else{
                $indexFormattedDCRJsonFiles = "0 -> {0}" -f $DCRJsonFiles
                Write-Host $indexFormattedDCRJsonFiles
            }
           
            # Prompt the user to enter an index
            $index = Read-Host -Prompt 'Enter the index of the modified DCR you want to send to Azure Monitor'
            $index = [int]$index.Trim()

            # Check if the entered index is valid
            if ($index -ge 0 -and $index -lt $DCRJsonFiles.Count) {
                if ($DCRJsonFiles.Count -gt 1) {
                    $DCRJsonFile = $DCRJsonFiles[$index]
                }else{
                    $DCRJsonFile = $DCRJsonFiles
                }
                $UserSelectedDCR = (Get-Item $DCRJsonFile).BaseName
            }else{
                Write-Host "Invalid index entered.  Exiting script." -ForegroundColor Red
                Exit
            }

            # Display the resource groups with their index
            for ($i=0; $i -lt $dataCollectionRules.Count; $i++) {

                if ($dataCollectionRules[$i].Name -eq $UserSelectedDCR) {
                    $dataCollectionRule = $dataCollectionRules[$i]
                    $DCRName = $dataCollectionRules[$i].Name
                    break
                }
            }
        }

    }

    Process {
    
        # Setting up REST API call to Azure Monitor to modify the DCR
        $resourceUrl    = (Get-AzContext).Environment.ResourceManagerUrl
        $subscriptionId = (Get-AzContext).Subscription.Id
        
        # Get the access token
        $token = (Get-AzAccessToken -ResourceUrl $resourceUrl).Token
        $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
        $headers.Add("Authorization","Bearer $token")
        
        
        # Split the string into parts
        $parts = $dataCollectionRule.Id -split '/'

        # Select the resource group part
        $resourceGroup = $parts[4]

        # Output the resource group
        if ($resourceGroup) {
            Write-Host "Resource Group : $resourceGroup" -ForegroundColor Green
        }

        if ($dataCollectionRule) {
            Write-Host "Data Collection Rule : $DCRName`n" -ForegroundColor Green
        }

        if ($DCR_Action.ToLower() -eq 'get') {

            # Construct the URL for the REST API call
            $url_DCRRule = "$resourceUrl/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.Insights/dataCollectionRules/$($DCRName)"

            $confirm = Read-Host "Do you want to make a REST API call to GET `'$DCRName`'? (Y/N)"

            if ($confirm -eq 'Y' -or $confirm -eq 'y') {
                $GOT_DCRContent = Invoke-RestMethod ($url_DCRRule+"?api-version=2021-09-01-preview") -Method GET -Headers $headers
                Sleep 0.5

                if ($GOT_DCRContent) {
                    ConvertTo-JSON -Depth 64 -InputObject $GOT_DCRContent | Out-File "$DCRName.json"
                
                    Write-Host "`nDCR REST API call to Azure Monitor for `'$DCRName`' was successful!`n" -ForegroundColor Green
                    Write-Host "Your DCR `'$DCRName`' is now ready to be modified -> $DCRName.json" -ForegroundColor Yellow
                    Write-Host "Upon completion, you can run Invoke-DCRModify with the `"-DCR_Action Set`" option." -ForegroundColor Yellow
                }else{
                    Write-Host "DCR REST API call to Azure Monitor for $DCRName returned empty (null)" -ForegroundColor Red
                }
            }
            else {
                Write-Host "DCR REST API call to Azure Monitor for $DCRName was cancelled by the user." -ForegroundColor Red
            }
        }

        if ($DCR_Action.ToLower() -eq 'set') {

            # Copy the deserialized JSON DCR to a variable
            $DCRContent = Get-Content ./"$DCRJsonFile" -Raw

            Write-Host "Your modified DCR: $DCRName.json, is now ready to be sent via Azure REST API!`n" -ForegroundColor Yellow
            $confirm = Read-Host "Do you want to send `'$DCRName`' to Azure Monitor via a REST API (PUT)? (Y/N)"

            # Construct the URL for the REST API call
            $url_DCRRule = "$resourceUrl/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.Insights/dataCollectionRules/$($DCRName)"

            if ($confirm -eq 'Y' -or $confirm -eq 'y') {
                $result = Invoke-AzRestMethod ($url_DCRRule+"?api-version=2021-09-01-preview") -Method PUT -Payload $DCRContent
                Sleep 0.5

                # Validate the REST API call was successful ($result)
                if ($result.StatusCode -eq 200) {
                    Write-Host "`nREST API [PUT] to Azure Monitor for $DCRName completed successfully!" -ForegroundColor Green
                    Write-Host "You can now go to Azure Monitor and validate the modification of: $DCRName." -ForegroundColor Green
                } else {
                    Write-Host "`nPUT via REST API call for $DCRName failed!" -ForegroundColor Red
                    Write-Host "Error Message: $($result.Content.message)" -ForegroundColor Red
                }
            } else {
                Write-Host "DCR REST API call to Azure Monitor for $DCRName was cancelled by the user." -ForegroundColor Red
            }
        }      
    }

    End {}
}
