
# From the Azure Cloud Shell within the Azure Portal
$resourceUrl = (Get-AzContext).Environment.ResourceManagerUrl
$subscriptionId = (Get-AzContext).Subscription.Id
$resourceGroup = 'CEF'                 # (Get-AzResourceGroup).ResourceGroupName
$DCRRuleName = 'Linux-SecureLogs-DCR'  # Azure Monitor -> Data Collection Rules -> DCR Name

# Setup Authorization for REST API (Invoke-RestMethod|Invoke-AzRestMethod)
$token = (Get-AzAccessToken -ResourceUrl $resourceUrl).Token
$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("Authorization","Bearer $token")
    
# GET DCR using the REST API for DCR
$url_DCRRule = "$resourceUrl/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.Insights/dataCollectionRules/$($DCRRuleName)"
$GOT_DCRContent = Invoke-RestMethod ($url_DCRRule+"?api-version=2021-09-01-preview") -Method GET -Headers $headers

# Convert serialized JSON ($GOT_DCRContent) to editable JSON and send to a file named $DCRRuleName.json
$DCRContentJSON = ConvertTo-JSON -Depth 64 -InputObject $GOT_DCRContent | Out-File "$DCRRuleName.json"

#$DCRContentJSON | Out-File "$DCRRuleName.json"

# Modify the DCR as required using your editor of choice and save your work 
# Once that is complete, uncomment the line below in order to copy the modified DCR into a variable for ease of use. 
# $GOT_DCRContent = Get-Content ./$DCRRuleName.json -Raw

# Uncomment the last line when you're ready to send this modified DCR to Azure 
# Invoke-AzRestMethod ($url_Get_DCRRule+"?api-version=2021-09-01-preview") -Method PUT -Payload $GOT_DCRContent
