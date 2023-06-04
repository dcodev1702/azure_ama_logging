<#
Author: Lorenzo J. Ireland, Co-Pilot, ChatGPT-4
Date: 4 June 2023

CmdLet:
--------
Invoke-DCRModify -DCR_Action [Get|Set]

End-State:
----------
Automate (ish) the modifying of Data Collection Rules.

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
script is not been refactored so there is a lot of duplicate code, it's also 2 AM! ;)
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
        $dataCollectionRule = $null

        Write-Host "Welcome to Invoke-DCRModify for your Data Collection Rules (DCR)!" -ForegroundColor Green
        Write-Host "You passed in $DCR_Action" -ForegroundColor Green

        if ($DCR_Action.ToLower() -eq 'get') {
            
            $dataCollectionRules = (Get-AzDataCollectionRule -WarningAction SilentlyContinue)

            # Calculate the length of the highest index for padding purposes
            $idxLen = $dataCollectionRules.Count.ToString().Length

            # Display the resource groups with their index
            for ($i=0; $i -lt $dataCollectionRules.Count; $i++) {

                # Write-Host "$i  $($resourceGroups[$i])"
                $indexFormattedDCRs = "{0,$idxLen} -> {1}" -f $i, $dataCollectionRules[$i].Name
                Write-Host $indexFormattedDCRs
            }

            # Prompt the user to enter an index
            $index = Read-Host -Prompt 'Enter the index of the Data Collection Rule (DCR) you want to select'
            $index = [int]$index.Trim()
            # Check if the entered index is valid
            if ($index -ge 0 -and $index -lt $dataCollectionRules.Count) {
                $dataCollectionRule = $dataCollectionRules[$index]
            }

        }else{
            Write-Host "DCR Action: $DCR_Action" -ForegroundColor Yellow
            Write-Host "Resource Group : $resourceGroup" -ForegroundColor Green
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

        $DCRId = $dataCollectionRule.Id
        $DCRName = $dataCollectionRule.Name
        
        # Split the string into parts
        $parts = $DCRId -split '/'

        # Select the resource group part
        $resourceGroup = $parts[4]

        # Output the resource group
        if ($resourceGroup) {
            Write-Host "Resource Group : $resourceGroup" -ForegroundColor Green
        }

        if ($dataCollectionRule) {
            Write-Host "Data Collection Rule : $DCRName" -ForegroundColor Green
        }

        # Construct the URL for the REST API call
        $url_DCRRule = "$resourceUrl/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.Insights/dataCollectionRules/$($DCRName)"
        
        if ($DCR_Action.ToLower() -eq 'get') {

            $confirm = Read-Host "Do you want to make a REST API call to GET `'$DCRName`'? (Y/N)"

            if ($confirm -eq 'Y' -or $confirm -eq 'y') {
                $GOT_DCRContent = Invoke-RestMethod ($url_DCRRule+"?api-version=2021-09-01-preview") -Method GET -Headers $headers
                
                if ($GOT_DCRContent) {
                    ConvertTo-JSON -Depth 64 -InputObject $GOT_DCRContent | Out-File "$DCRName.json"
                }

                Write-Host "Your DCR `'$DCRName`' is now ready to be modified -> $DCRName.json" -ForegroundColor Magenta
                Write-Host "Upon completion, you can run the CmdLet Invoke-DCRModify with the `"-DCR_Action Set`" option." -ForegroundColor Yellow

            }
            else {
                Write-Host "API call cancelled by user."
            }
        }

        if ($DCR_Action.ToLower() -eq 'set') {
            $DCRJsonFiles = (Get-ChildItem -Path .\ -Filter *.json).Name

            $idxLen = $DCRJsonFiles.Count.ToString().Length
            # List JSON Files and prompt user to select one
            for ($i=0; $i -lt $DCRJsonFiles.Count; $i++) {

                # Write-Host "$i  $($resourceGroups[$i])"
                $indexFormattedDCRJsonFiles = "{0,$idxLen} -> {1}" -f $i, $DCRJsonFiles[$i]
                Write-Host $indexFormattedDCRJsonFiles
            }

            # Prompt the user to enter an index
            $index = Read-Host -Prompt 'Enter the index of the modified Data Collection Rule (DCR) you want to PUT via REST API.'
            $index = [int]$index.Trim()

            # Check if the entered index is valid
            if ($index -ge 0 -and $index -lt $DCRJsonFiles.Count) {
                $DCRJsonFile = $DCRJsonFiles[$index]
            }
            
            # Copy the deserialized JSON DCR to a variable
            $GOT_DCRContent = Get-Content ./"$DCRJsonFile" -Raw
            
            $confirm = Read-Host "Do you want to make the REST API call (PUT)? (Y/N)"

            if ($confirm -eq 'Y' -or $confirm -eq 'y') {
                $result = Invoke-AzRestMethod ($url_DCRRule+"?api-version=2021-09-01-preview") -Method PUT -Payload $DCRJsonFile
                Write-Host "PUT / REST API call for $DCRJsonFile completed successfully! $result" -ForegroundColor Green
            
                Write-Host "Your modified DCR: $DCRName.json, is now ready to be sent via Azure REST API!" -ForegroundColor Yellow
                Write-Host "You can now go to Azure Monitor and validate the modification of: $DCRName." -ForegroundColor Yellow
            } else {
                Write-Host "API call cancelled by user."
            }
        }
        
    }

    End {
        
        if ($DCR_Action.ToLower() -eq 'get') {
            Write-Host "Action Selected: $DCR_Action" -ForegroundColor Red
            
        }else{
            Write-Host "Action Selected: `"$DCR_Action`"" -ForegroundColor Red
            
        }
    }
}
