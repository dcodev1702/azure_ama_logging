<#

W3CIISLog DCR Setup:
--------------------
# WRITE THIS FROM THE PERSPECTIVE OF USING CLOUD SHELL

1. Create a new DCE
    New-AzDCE -Environment 'AzureUSGovernment' -ResourceGroup 'CEF' `
    -Location 'usgovvirginia' -EndpointName 'CLI-W3CIISLogs-ZO-DCE' `
    -OperatingSystem 'Windows' -NetworkIsPublic $true

2. We will be using the existing table (No need to create a new table):
    [W3CIISLog] = Verify the table exists in your Log Analytics Workspace

3. Create a new DCR rule via REST API.
    Currently doing something wrong in MAG and unable to create a new DCR rule via the CLI.
    TEMPORARY WORK-AROUND: Create a new DCR rule via the Azure Portal.
    MOST IMPORTANT PARTS TO MODIFY:
        - kind = Windows
        - dataCollectionEndpointId = /subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/CEF/providers/Microsoft.Insights/dataCollectionEndpoints/CLI-W3CIISLogs-ZO-DCE
        "streamDeclarations": {
            "Custom-MyTable_CL": {
                "columns": [
                    {
                        "name": "TimeGenerated",
                        "type": "datetime"
                    },
                    {
                        "name": "RawData",
                        "type": "string"
                    }
                ]
            }
        },
        - dataSources:
            - iisLogs
            - "logDirectories": [ "D:\\IIS_LOGS\\LogFiles\\W3SVC1" ]
        - dataFlows:
            - transformKql, outputStream
        - streamDeclarations = W3CIISLog

4. Modify the DCR rule by hand (VSCode) to add the DCE, dataSources, dataFlows, and transformKql/outputStream fields.

5. Upload the DCR to Azure Monitor using [upload_dcr.ps1] via the REST API.
    Upload-AzDataCollectionRule -Environment 'AzureUSGovernment' -ResourceGroup 'CEF' `
    -DCRRuleName 'CLI-W3CIISLogs-ZO-DCR' -DCRJSONFile ./CLI-W3CIISLogs-ZO-DCR-Rule.json

6. Assign VM in the Resource Group to the DCE

7. Assign VM in the Resource Group to the DCR

#>


$exp = ConvertFrom-JSON -Depth 20 -InputObject $zo

# Add properties to a JSON Obj
# zo.json represents a new DCR rule with no dataSources, DCE, Table, etc
# CLI-WHYTHO-DCR-Rule.json is a fully configured DCR with 
$s = Get-Content -Path ./zo.json | ConvertFrom-Json -Depth 32
$JSONObj = Get-Content -Path ./CLI-WHYTHO-DCR-Rule.json | ConvertFrom-Json -Depth 32

# Build out the $s JSON object using $JSONObj
# I'm using another JSON object to make life easier but you can create JSON 
# with the values you want, convert the json file to an JSON Objeect and 
# assign those values as an object via Add-Member
$s | Add-Member -MemberType NoteProperty -Name 'kind' -Value 'Linux'

$s.properties | Add-Member -MemberType NoteProperty -Name 'dataCollectionEndpointId' -Value $JSONObj.properties.dataCollectionEndpointId
$s.properties | Add-Member -MemberType NoteProperty -Name 'streamDeclarations' -Value $JSONObj.properties.streamDeclarations

$s.properties.dataSources | Add-Member -MemberType NoteProperty -Name 'logFiles' -Value $JSONObj.properties.dataSources.logFiles

$s.properties.dataFlows | Add-Member -MemberType NoteProperty -Name 'transformKql' -Value $JSONObj.properties.dataFlows.transformKql
$s.properties.dataFlows | Add-Member -MemberType NoteProperty -Name 'outputStream' -Value $JSONObj.properties.dataFlows.outputStream



