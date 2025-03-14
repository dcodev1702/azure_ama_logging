# Assumptions:
1. You have access to an Azure Subscription.
2. You are using PowerShell 7.X or Azure Cloud Shell.
3. Your identity has sufficient priviledges to perform data collection rule modifications.
4. You can navigate PowerShell and understand basic coding concepts.

# Instructions: From the Azure Cloud Shell
The PowerShell code below is used to pull down an existing Data Collection Rule (DCR) so that it can be modified and published via requisite API calls.
All of this can be accomplished through the Azure Cloud Shell using PowerShell.


![Azure_CloudShell](https://user-images.githubusercontent.com/32214072/231885364-9a989838-9ec7-4df3-8cdf-66dd059586f0.png)


## Setup the REST API to GET and PUT Data Collection Rules <br />
```PowerShell
$resourceUrl    = (Get-AzContext).Environment.ResourceManagerUrl
$subscriptionId = (Get-AzContext).Subscription.Id
```

```PowerShell
$resourceGroup  = 'CHANGE-TO-YOUR-RG'   # (Get-AzResourceGroup).ResourceGroupName
```

```PowerShell
$DCR_RuleName = 'CHANGE-TO-YOUR-EXISTING-DCR'  # (Get-AzDataCollectionRule).Name
```

## Setup Authorization for REST API
```PowerShell
$token = (Get-AzAccessToken -AsSecureString -ResourceUrl $resourceUrl).Token
$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("Authorization","Bearer $token")
```

## GET the existing DCR using the REST API
```PowerShell
$url_DCRRule = "$resourceUrl/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.Insights/dataCollectionRules/$($DCR_RuleName)"
$GOT_DCRContent = Invoke-RestMethod ($url_DCRRule+"?api-version=2022-06-01") -Method GET -Headers $headers
```

## Convert serialized JSON & send to a file
```PowerShell
ConvertTo-JSON -Depth 64 -InputObject $GOT_DCRContent | Out-File "$DCR_RuleName.json"
```

## Modify the DCR as required
Use your editor of choice and save your work <br/>
If you're using the Azure Cloud Shell, you can use the upload/download feature to assist in editing the DCR
 
## Copy the modified DCR into a variable (for ease of use)
```PowerShell
$GOT_DCRContent = Get-Content ./"$DCR_RuleName.json" -Raw
```

## Send the modified DCR to Azure via REST API  
```PowerShell
Invoke-AzRestMethod ($url_DCRRule+"?api-version=2022-06-01") -Method PUT -Payload $GOT_DCRContent
```
