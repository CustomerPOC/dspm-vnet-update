# DIG | Prisma Cloud DSPM VNet Update

This repo contains an Azure Powershell script that can be used to re-ip DIG | DSPM VNets that are used for data scanning.  This script will look for all VNets in a resource group matching: "dig-security-rg-" and then find all VNets that also have the tag 'dig-security'. Once identified, the script will remove all existing VNet address space and subnets and replace with the address space provided.

---

> :warning: **WARNING**
>  Running this script will remove all existing VNet address space and subnets for all VNets in the dig-security-rg-* Resource Group that also have VNets tagged with 'dig-security'
>  The address space provided will replace the existing VNet address space and a single subnet using the full address space will be created.

---

Help can be acccessed by running the script with the -Help parameter.

```shell
help ./dspm-vnet-change.ps1 
```

Examples are also available using the help -Examples switch.

```shell
help ./dspm-vnet-change.ps1 -Examples
```

## Installation

Open Azure Cloud Shell and clone this repo.

```shell
git clone https://github.com/CustomerPOC/dspm-vnet-update
```

Set your subscription id to target the DIG hub account subscription.

```shell
Set-AzContext -Subscription 00000000-0000-0000-0000-000000000000
```

Chnage the directory to the cloned repo.

```shell
cd dspm-vnet-update
```

## Example Usage

Re-IP all DSPM VNets to 10.20.0.0/24

```shell
./dspm-vnet-change.ps1 -Cidr 10.20.0.0/24
```

Import a CSV and update DIG | DSPM VNets defined in the CSV.

```shell
./dspm-vnet-change.ps1 -ImportFile ./example.csv
```

Import a CSV and update DIG | DSPM VNets defined in the CSV only when they match the specified regions.

```shell
./dspm-vnet-change.ps1 -ImportFile ./example.csv -Regions "eastus, eastus2"
```

Update all DIG | DSPM VNets prompting for the CIDR in each region.

```shell
./dspm-vnet-change.ps1 -Prompt
```

Create VNets in specified regions.

```shell
./dspm-vnet-change.ps1 -Cidr 10.20.0.0/24 -CreateVNet -Regions "canadaeast, centralus, eastus, eastus2"
```
