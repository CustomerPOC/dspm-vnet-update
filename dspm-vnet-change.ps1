$tagName      = 'dig-security'
$newCIDR      = '10.61.8.0/24'
$allVnets     = Get-AzVirtualNetwork
$vnetCount    = $allVnets.Count

function Test-CIDR {
    param (
        [string]$cidr
    )
    $regex = '^([0-9]{1,3}\.){3}[0-9]{1,3}\/([0-9]|[1-2][0-9]|3[0-2])$'
    return $cidr -match $regex
}
function Backup-VNet {
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

do {
    $newAddress = Read-Host -Prompt "Enter the new CIDR for the VNet (default: $newCIDR)"

    # Use default value if none provided
    if (-not $newAddress) { $newAddress = $newCIDR }

    # Validate provided CIDR is in valid format
    $isValid = Test-CIDR -cidr $newAddress

    if (-not $isValid) {
        Write-Host ""
        Write-Host "Invalid CIDR format. Please enter a valid CIDR notation (e.g., 10.1.0.0/24)." -BackgroundColor DarkRed -ForegroundColor White
    }
}
until ($isValid)

foreach ($vnet in $allVnets) {
    $counter++
    $percentComplete = ($counter / $vnetCount) * 100
    Write-Progress -Activity "Processing VNets" -Status "Processing VNet $counter of $vnetCount" -PercentComplete $percentComplete

    # If no tag on VNet skip it and wait 1 second so progress bar is visible
    if (-not $vnet.Tag) { Start-Sleep -Seconds 1; continue }
    
    if ($vnet.Tag.ContainsKey($tagName)) {
        $subnetName = "$($tagName)-$($vnet.Location)"

        try {
            # Backup VNet as JSON file
            Backup-VNet -vnet $vnet

            # Remove all existing address space
            foreach ($address in $($vnet.AddressSpace.AddressPrefixes)) {
                $vnet.AddressSpace.AddressPrefixes.Remove($address) > $null
            }
            
            # Add new address space
            $vnet.AddressSpace.AddressPrefixes.Add($newAddress)

            # Remove all subnets
            foreach ($subnet in $($vnet.Subnets)) {
                $vnet.Subnets.Remove($subnet) > $null
            }

            # Add new subnet
            Add-AzVirtualNetworkSubnetConfig -Name $subnetName -AddressPrefix $newAddress -VirtualNetwork $vnet > $null

            # Update VNet config
            Set-AzVirtualNetwork -VirtualNetwork $vnet > $null
        }
        catch {
            Write-Error "Failed to modify VNet $($vnet.Name): $_"
        }
        finally {}


    }
}

