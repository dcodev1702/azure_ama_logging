
$lo = ConvertFrom-JSON -Depth 20 -InputObject $zo

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



