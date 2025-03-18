### Step 0: Set variables required for the rest of the script.
# Create an application registration and give it the Metrics Publishing RBAC role to the DCR!

# Add-Type -AssemblyName System.Web

# information needed to authenticate to Entra ID and obtain a bearer token
$tenantId  = "$((Get-AzContext).Tenant.Id)"
$appId     = "INSERT_YOUR_APP_ID_HERE"
$appSecret = "INSERT_YOUR_APP_SECRET_HERE"

# information needed to send data to the DCR endpoint
$dceEndpoint    = "INSERT_YOUR_INGESTION_API_ENDPOINT_URL_HERE"
$dcrImmutableId = "INSERT_YOUR_DCR_IMMUTABLE_ID_HERE"
$streamName     = "Custom-PSDataIngest_CL" # name of the stream in the DCR that represents the destination table

### Step 1: Obtain a bearer token used later to authenticate against the DCE.
$scope = [System.Web.HttpUtility]::UrlEncode("https://monitor.azure.com//.default")   
$body  = "client_id=$appId&scope=$scope&client_secret=$appSecret&grant_type=client_credentials"

$headers = @{"Content-Type"="application/x-www-form-urlencoded"}
$uri = "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token"

$bearerToken = (Invoke-RestMethod -Uri $uri -Method POST -Body $body -Headers $headers).access_token

### Step 2: Import JSON data from file into the $staticData variable.
$staticData = Get-Content -Path "mde_log_01.json" -Raw

### Step 3: Send the data to the Log Analytics workspace via the DCE.
$body    = $staticData
$headers = @{"Authorization"="Bearer $bearerToken";"Content-Type"="application/json"}
$uri     = "$dceEndpoint/dataCollectionRules/$dcrImmutableId/streams/$($streamName)?api-version=2023-01-01"

Invoke-RestMethod -Uri $uri -Method POST -Body $body -Headers $headers -ErrorVariable RestError

if ($RestError) {
    Write-Host "Error uploading data to the Log Analytics Custom Table `"$streamName`". Error: $RestError" -ForegroundColor Red
    exit 1
} else {
    Write-Host "Data uploaded successfully to the Log Analytics Custom Table: `"$streamName`"." -ForegroundColor Green
}
