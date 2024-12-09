$tagName      = 'dig-security'
$currentCIDR  = '10.0.0.0/16'
$newCIDR      = '10.68.10.0/24'
$allVnets     = Get-AzVirtualNetwork
$vnetCount    = $allVnets.Count

$currentAddress = Read-Host -Prompt "Enter the current CIDR for the VNet" -Default $currentCIDR
$newAddress     = Read-Host -Prompt "Enter the new CIDR for the VNet" -Default $newCIDR

function backup-vnet {
    param (
        [Parameter(Mandatory = $true)]
        [Microsoft.Azure.Commands.Network.Models.PSVirtualNetwork] $vnet
    )
    $timestamp = Get-Date -Format "yyyyMMddHHmmss"
    $filename = "$($vnet.Name)-raw-$timestamp.json"
    $vnet | ConvertTo-Json -Depth 10 | Out-File -FilePath $filename

    # Export-AzResourceGroup `
    #     -ResourceGroupName $vnet.ResourceGroupName `
    #     -Resource $vnet.Id `
    #     -SkipAllParameterization `
    #     -Force 
}

foreach ($vnet in $allVnets) {
    $counter++
    $percentComplete = ($counter / $vnetCount) * 100
    Write-Progress -Activity "Processing VNets" -Status "Processing VNet $counter of $vnetCount" -PercentComplete $percentComplete

    if (-not $vnet.Tag) { Start-Sleep -Seconds 1; continue }
    
    if ($vnet.Tag.ContainsKey($tagName)) {
        $subnetName = "$($tagName)-$($vnet.Location)"

        try {
            # Backup VNet as JSON file
            backup-vnet -vnet $vnet

            # Remove existing subnet
            Remove-AzVirtualNetworkSubnetConfig -Name $subnetName -VirtualNetwork $vnet > $null

            # Add new CIDR and remove old CIDR
            $vnet.AddressSpace.AddressPrefixes.Add($newAddress)
            $vnet.AddressSpace.AddressPrefixes.Remove($currentAddress)

            # Update VNet with new values
            Add-AzVirtualNetworkSubnetConfig -Name $subnetName -AddressPrefix $newAddress -VirtualNetwork $vnet > $null
            Set-AzVirtualNetwork -VirtualNetwork $vnet > $null
        }
        catch {
            Write-Error "Failed to modify VNet $($vnet.Name): $_"
        }
        finally {}


    }
}
