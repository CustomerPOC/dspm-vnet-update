$tagName      = 'dig-security'
$currentCIDR  = '10.0.0.0/24'
$newCIDR      = '10.50.0.0/24'

$allVnets = Get-AzVirtualNetwork
foreach ($vnet in $allVnets) {
    $counter++
    $percentComplete = ($counter / $totalVnets) * 100
    Write-Progress -Activity "Processing VNets" -Status "Processing VNet $counter of $totalVnets" -PercentComplete $percentComplete
    
    if (-not $vnet.Tag) { continue }
    if ($vnet.Tag.ContainsKey($tagName)) {
        $subnetName = "$($tagName)-$($vnet.Location)"

        try {
            # Backup VNet as JSON file
            backup-vnet -vnet $vnet

            # Remove existing subnet
            Remove-AzVirtualNetworkSubnetConfig -Name $subnetName -VirtualNetwork $vnet

            # Add new CIDR and remove old CIDR
            $vnet.AddressSpace.AddressPrefixes.Add($newCIDR)
            $vnet.AddressSpace.AddressPrefixes.Remove($currentCIDR)

            # Update VNet with new values
            Add-AzVirtualNetworkSubnetConfig -Name $subnetName -AddressPrefix $newCIDR -VirtualNetwork $vnet
            Set-AzVirtualNetwork -VirtualNetwork $vnet
        }
        catch {
            Write-Error "Failed to modify VNet $($vnet.Name): $_"
        }
        finally {}


    }
}

function backup-vnet {
    param (
        [Parameter(Mandatory = $true)]
        [Microsoft.Azure.Commands.Network.Models.PSVirtualNetwork] $vnet
    )
    $timestamp = Get-Date -Format "yyyyMMddHHmmss"
    $filename = "vnet-modification-before-$timestamp.json"
    $vnet | ConvertTo-Json -Depth 10 | Out-File -FilePath $filename
}