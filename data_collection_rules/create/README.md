### Create a Data Collection Rule: [Here!](https://learn.microsoft.com/en-us/rest/api/monitor/data-collection-rules/create?view=rest-monitor-2022-06-01&tabs=HTTP)
### Filename: bt-demo-03232024.json
![image](https://github.com/dcodev1702/azure_ama_logging/assets/32214072/6502200a-f09f-494a-820d-9be6bb890db8)

### Steps to create a Data Collection Rule
1. Define the rule, what you want to collection and the destination where the logs will reside (Log Analytics Workspace)
   * Get the Resource Id of your Log Analytics Workspace
   * Copy that Resource Id to your Data Collection Rule (DCR) -> logAnalytics -> workspaceResourceId: "COPY RESOURCE ID HERE"
   * Go to Azure -> Log Analytics Workspace (LAW) -> Select the LAW -> Select "JSON View" on the far right
   * Save the Data Collection Rule as JSON (bt-demo-03232024.json)
![image](https://github.com/dcodev1702/azure_ama_logging/assets/32214072/bf041a64-b087-4551-972a-746e52db5136)

2. Fill out the Resource ID for the Data Collection Rule (DCR)
```console
$RescourceId = "/subscriptions/<SUBSCRIPTION_ID>/resourceGroups/<RESOURCE_GROUP>/providers/Microsoft.Insights/dataCollectionRules/bt-demo-03232024-dcr"
```
3. Assign contents of your DCR to a variable $DCRContent that will be used by the PowerShell CmdLet: Invoke-AzRestMethod
```console
$File = ".\bt-demo-03232024.json"
$DCRContent = Get-Content $File -Raw
```
4. Upload the DCR content via PowerShell Az Rest Method CmdLet (Invoke-AzRestMethod)
   * Az Module is required to be installed.
   * If your environment doesn't support using PowerShell, you can use the Azure Cloud Shell.
   * Upon successful upload, you will see a STATUS of 200 / 201
```console
Invoke-AzRestMethod -Path("$RescourceId"+"?api-version=2022-06-01") -Method PUT -Payload $DCRContent
```
### Upload via HTTP REST API
![image](https://github.com/dcodev1702/azure_ama_logging/assets/32214072/ff1f01ea-5654-4267-bac2-58977729f1c5)

