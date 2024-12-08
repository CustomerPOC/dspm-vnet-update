$digTagName              = 'dig-security'
$defaultDigAddressPrefix = '10.0.0.0/16'
$newDigSubnetPrefix      = '10.61.8.0/24'

$allVnets = Get-AzVirtualNetwork
foreach ($vnet in $allVnets) {
    if (-not $vnet.Tag) { continue }
    if ($vnet.Tag.ContainsKey($digTagName)) {

        $digSubnetName = "$($digTagName)-$($vnet.Location)"

        $vnet.AddressSpace.AddressPrefixes.Add($newDigSubnetPrefix)
        Set-AzVirtualNetwork -VirtualNetwork $vnet

        Remove-AzVirtualNetworkSubnetConfig -Name $digSubnetName -VirtualNetwork $vnet
        Add-AzVirtualNetworkSubnetConfig -Name $digSubnetName -AddressPrefix $newDigSubnetPrefix -VirtualNetwork $vnet

        $vnet.AddressSpace.AddressPrefixes.Remove($defaultDigAddressPrefix)
        Set-AzVirtualNetwork -VirtualNetwork $vnet
    }
}