<#
.SYNOPSIS
    This script allows for the re-ip or re-creation of DIG | Prisma Cloud DSPM VNets used for data scanning.

.DESCRIPTION
    This script will look for all VNets in a resource group matching: "dig-security-rg-" and then find all VNets matching the tag "dig-security"
    Once identified the script will remove all subnets and CIDR's, replace with specified CIDR.

.PARAMETER Backup
    Switch to backup existing VNet as JSON file.

.PARAMETER Cidr
    Address prefix to use for new VNets: 10.1.0.0/24

.PARAMETER CreateVNet
    Create/re-create new VNets based on defined regions.

.PARAMETER Prompt
    Switch to prompt user for new CIDR.
    
.PARAMETER Force
    If CreateVNet is used, this will overwrite existing VNets instead of prompting to replace.

.PARAMETER Regions
    Comma-separated list of Azure regions used for CreateVNet switch: "westus,eastus,centralus"

.EXAMPLE
    Create VNet's in westus, eastus, and eastus2 regions.

    .\dspm-vnet-change.ps1 -CreateVNet -Regions "westus,eastus, eastus2" -Cidr 10.10.0.0/24

.EXAMPLE
    Re-IP existing VNets with new CIDR.

    .\dspm-vnet-change.ps1 -Cidr 10.10.0.0/24

.EXAMPLE
    Re-IP existing VNets with new CIDR and backup existing VNets.

    .\dspm-vnet-change.ps1 -Cidr 10.10.0.0/24 -Backup

.EXAMPLE
    Re-IP existing VNets with new CIDR and prompt for each region CIDR.

    .\dspm-vnet-change.ps1 -Cidr 10.10.0.0/24 -Prompt

.NOTES
    Author: Erick Moore
    Date: 2024-12-09
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory=$false, HelpMessage="If selected will output raw JSON of VNet's.")]
    [switch]$Backup,
    [Parameter(Mandatory=$false, HelpMessage = "IP CIDR range to use for new VNet: 10.10.0.0/22")]
    [string]$Cidr,
    [Parameter(Mandatory=$false, HelpMessage="Create new VNets based on defined regions.")]
    [switch]$CreateVNet,
    [Parameter(Mandatory = $false, HelpMessage = "Path to CSV file containing regions and CIDRs for updating.")]
    [string]$ImportFile,
    [Parameter(Mandatory=$false, HelpMessage="If CreateVNet is used, this will overwrite existing VNets instead of prompting to replace.")]
    [switch]$Force,
    [Parameter(Mandatory=$false, HelpMessage="Prompt for CIDR on each region.")]
    [switch]$Prompt,    
    [Parameter(Mandatory=$false, HelpMessage="Comma-separated list of Azure regions used for CreateVNet switch (e.g., 'westus,eastus,centralus')")]
    [string]$Regions
)

$tagName        = 'dig-security'
$resourceGroup  = Get-AzResourceGroup | Where-Object { $_.ResourceGroupName -match "dig-security-rg-" }
$allVnets       = Get-AzVirtualNetwork -ResourceGroupName $resourceGroup.ResourceGroupName
$allNatGWs      = Get-AzNatGateway -ResourceGroupName $resourceGroup.ResourceGroupName
$vnetCount      = $allVnets.Count
$newAddress     = $Cidr

if ($Regions) {
    $dspmRegions = $Regions.Split(',').Trim()
    $regionCount = $dspmRegions.Count
}

# ╔══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗
# ║ Test-CIDR Function: RegEx to match format x.x.x.x/xx                                                                                     ║
# ╚══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝
function Test-CIDR {
    param (
        [string]$cidr
    )
    $regex = '^([0-9]{1,3}\.){3}[0-9]{1,3}\/([0-9]|[1-2][0-9]|3[0-2])$'
    return $cidr -match $regex
}

# ╔══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗
# ║ Get-ValidCIDR Function: Prompt for valid CIDR 3 times before failing                                                                     ║
# ╚══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝
function Get-ValidCIDR {
    param (
        [string]$location,
        [int]$maxRetries = 3
    )
    $retryCount = 0
    do {
        $cidr = Read-Host "Enter CIDR for $location"
        if (Test-CIDR -cidr $cidr) {
            return $cidr
        }
        else {
            Write-Host "Invalid CIDR format. Please enter a valid CIDR notation (e.g., 10.1.0.0/24)." -BackgroundColor DarkRed -ForegroundColor White
            $retryCount++
        }
    } while ($retryCount -lt $maxRetries)

    Write-Host "Maximum retries reached. Skipping $location"
    return $null
}

# ╔══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗
# ║ Backup-VNet Function: Export existing VNet as RAW json                                                                                   ║
# ╚══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝
function Backup-VNet {
    param (
        [Parameter(Mandatory = $true)]
        [Microsoft.Azure.Commands.Network.Models.PSVirtualNetwork] $vnet
    )
    $timestamp = Get-Date -Format "yyyyMMddHHmmss"
    $filename = "$($vnet.Name)-raw-$timestamp.json"
    $vnet | ConvertTo-Json -Depth 10 | Out-File -FilePath $filename
}

# ╔══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗
# ║ ImporFile: Modify/Create DIG | DSPM VNet's in all specified regions from imported csv file                                               ║
# ╚══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝
if ($ImportFile) {
    $csvData = Import-Csv -Path $ImportFile
    
    foreach ($item in $csvData) {
        $item.Region = $item.Region.Trim()
        $item.Cidr = $item.Cidr.Trim()
        $validCidr = Test-CIDR -cidr $item.Cidr
        if (-not $validCidr) {
            Write-Error "Invalid CIDR format in CSV file for $($item.Region). Please ensure CIDR is in the format x.x.x.x/xx"
            exit
        }
    }

    $dspmRegions = ($csvData | Select-Object Region).Region
    $regionCount = $dspmRegions.Count
}

# ╔══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗
# ║ New-Vnet: Create DIG | DSPM VNet's in all specified regions                                                                              ║
# ╚══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝
if ($CreateVNet){

    foreach ($region in $dspmRegions) {

        # If ImportFile switch is used, get CIDR from CSV file
        if ($ImportFile) {
            $regionData = $csvData | Where-Object Region -eq $region
            $newAddress = $regionData.Cidr
        }

        if ($Prompt) {
            $newAddress = Get-ValidCIDR -location $region
            if (-not $newAddress) {
                continue
            }
        }

        $counter++
        $percentComplete = ($counter / $regionCount ) * 100
        Write-Progress -Activity "Creating VNet in $region" -Status "$counter of $regionCount" -PercentComplete $percentComplete

        $digName = "$tagName-$region"

        if ($Force) {
            $newVNet = New-AzVirtualNetwork -Name $digName -ResourceGroupName $resourceGroup.ResourceGroupName -Location $region -AddressPrefix $newAddress -Tag @{ $tagName = 'true' } -Force
        }

        if (-not $Force) {
            $newVNet = New-AzVirtualNetwork -Name $digName -ResourceGroupName $resourceGroup.ResourceGroupName -Location $region -AddressPrefix $newAddress -Tag @{ $tagName = 'true' }
        }

        if ($newVNet) {
            Add-AzVirtualNetworkSubnetConfig -Name $digName -VirtualNetwork $newVNet -AddressPrefix $newAddress  > $null
            Set-AzVirtualNetwork -VirtualNetwork $newVNet > $null
        }
    }
    $counter = 0
    exit
}

# ╔══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗
# ║ Main Process: Loop through all discovered VNet's, find matching tag, remove all subnets and CIDR's, replace with specified CIDR.         ║
# ╚══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝
foreach ($vnet in $allVnets) {
    $counter++
    $percentComplete = ($counter / $vnetCount) * 100
    Write-Progress -Activity "Processing VNet $($vnet.Name)" -Status "Processing VNet $counter of $vnetCount" -PercentComplete $percentComplete -Id 1

    # If no tag on VNet skip it and wait 1 second so progress bar is visible
    if (-not $vnet.Tag) { Start-Sleep -Seconds 1; continue }
    
    if ($vnet.Tag.ContainsKey($tagName)) {
        # Set subnet name format (current matches DIG, DSPM subnet name)
        $subnetName = "$($tagName)-$($vnet.Location)"

        # If ImportFile switch is used, get CIDR from CSV file
        if ($ImportFile) {
            $regionData = $csvData | Where-Object Region -eq $vnet.Location
            $newAddress = $regionData.Cidr
        }

        # If Prompt switch is used, prompt user for new CIDR
        if ($Prompt) {
            $newAddress = Get-ValidCIDR -location $vnet.Location
            if (-not $newAddress) {
                continue
            }
        }

        try {
            # Backup VNet as JSON file
            if ($Backup) { Backup-VNet -vnet $vnet }

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

            # Regional NAT GW
            $currentNatGW = $allNatGWs | Where-Object Location -eq $vnet.Location

            # Add new subnet
            Add-AzVirtualNetworkSubnetConfig -Name $subnetName -AddressPrefix $newAddress -VirtualNetwork $vnet -InputObject $currentNatGW > $null

            # Update VNet config
            Set-AzVirtualNetwork -VirtualNetwork $vnet > $null
        }
        catch {
            Write-Error "Failed to modify VNet $($vnet.Name): $_"
        }
        finally {}
    }
}