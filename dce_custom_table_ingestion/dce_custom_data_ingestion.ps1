<#
DESCRIPTION:
------------
https://learn.microsoft.com/en-us/azure/azure-monitor/logs/tutorial-logs-ingestion-code?tabs=powershell
This script sends data to a custom table (ACEHW_CL) within Log Analytics using the Data Collection Endpoint (DCE) API
The DCE API is used to send data to Log Analytics without the need for the Azure Monitor Agent (AMA) or any other data shipper (e.g. Logstash/Fluent-Bit)
The script uses the client credentials flow to authenticate against the DCE API
The script sends a JSON payload to the custom table (ACEHW_CL) within Log Analytics

PRE-CONDITIONS:
---------------
1. Data Collection Endpoint Created
2. Goto Log Analytics -> Create Custom Table (DCR)
   -- Create new DCR and assign DCE
   -- Name Custom Table
   -- Provide sample JSON to create custom table columns
      + TimeGenerated (datetime)
      + RawData (dynamic)
   -- Record DCR Immutable ID:
   -- Record DCR Stream Name:
3. Create App Registration, Secret, and record the information
   -- Tenant ID:
   -- Client ID:
   -- Client Secret:
4. DCR IAM - Assign Monitor Metrics Publisher role to the App Registration

USAGE:
------
./dce_custom_data_ingestion.ps1

POST CONDITION:
---------------
JSON payload shows up in Log Analytics Custom Table: ACEHW_CL
#>

$tenantId     = ""; # Tenant ID in which the Data Collection Endpoint resides
$appId        = ""; # Client ID created and granted permissions
$appSecret    = ""; # Client Secret created for the above app - never store your secrets in the source code
$DceURI       = ""; # DCE ingestion url

$DcrImmutableId = ""
$StreamName = ""

# JSON payload to be sent to the custom table (ACEHW_CL) within Log Analytics
$json_data = @"
[
    { 
        "RawData" : {
            "Name" : "DCODEV - Cloud Hunter", 
            "Age" : 47, 
            "State": "VA", 
            "City" : "Reston", 
            "Zip" : 90210, 
            "Address" : "7601 Woodgrove Cr."
        }
    }
]
"@;


Write-Output "Sending data to Log Analytics via the Data Collection Endpoint!"
Write-Output $json_data

## Obtain a bearer token used to authenticate against the data collection endpoint
$scope = [System.Web.HttpUtility]::UrlEncode("https://monitor.azure.com/.default")   
$body = "client_id=$appId&scope=$scope&client_secret=$appSecret&grant_type=client_credentials";
$headers = @{"Content-Type" = "application/x-www-form-urlencoded"};

$uri = "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token"
$bearerToken = (Invoke-RestMethod -Uri $uri -Method POST -Body $body -Headers $headers).access_token

# Prepare the headers and construct the URI for data upload via the DCE
$headers = @{"Authorization" = "Bearer $bearerToken"; "Content-Type" = "application/json"};
$uri = "$DceURI/dataCollectionRules/$DcrImmutableId/streams/$($StreamName)?api-version=2023-01-01"

# Sending the auth and data to Log Analytics Custom Table via the DCE!
$uploadResponse = Invoke-WebRequest -Uri $uri -Method POST -Body $json_data -Headers $headers
$uploadResponse | ConvertTo-Json
