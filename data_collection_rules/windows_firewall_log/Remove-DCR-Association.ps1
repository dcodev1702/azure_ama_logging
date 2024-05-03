$RGroupName = 'sec_telem_law_1'
$DCRName = 'WindowsFWLog-DCR'

# Get data collection rule associations
$VMResources = Get-AzDataCollectionRuleAssociation -DataCollectionRuleName $DCRName -ResourceGroupName $RGroupName 

foreach ($VMResource in $VMResources) {  
    $parts = $VMResource.Id -split '/'
    $RType = "$($parts[6])/$($parts[7])"    
    $vmName = $parts[8]

    # Get the VM resource
    $VM = Get-AzResource -ResourceGroupName $RGroupName -Name $vmName -ResourceType $RType

    if ($vmResource) {
        # Output the resource id
        Remove-AzDataCollectionRuleAssociation -AssociationName $VMResource.Name -ResourceUri $VM.Id
    } else {
        Write-Warning "VM resource '$vmName' with resource type '$RType' not found in resource group '$RGroupName'."
    }
}
