# DIG | Prisma Cloud DSPM VNet Update

This repo contains an Azure Powershell script that can be used to re-ip DIG | DSPM VNets that are used for data scanning.  This script will look for all VNets in a resource group matching: "dig-security-rg-" and then find all VNets that also have the tag 'dig-security'. Once identified, the script will remove all existing VNet address space and subnets and replace with the address space provided.


> :warning:
>
> Running this script will remove all existing VNet address space and subnets for all VNets in the dig-security-rg-* Resource Group that also have VNets tagged with 'dig-security'
> The address space provided will be replace VNet address space and a single subnet using the full address space.

Open Azure Cloud Shell and clone this repo.

```shell
git clone https://github.com/CustomerPOC/dspm-vnet-update
```

Set your subscription id to target the DIG hub account subscription.

```shell
Set-AzContext -Subscription 00000000-0000-0000-0000-000000000000
```

Run the script to update all your VNets. This example re-ip's all the DSPM VNets to 10.61.8.0/22

```shell
./dspm-vnet-update/dspm-vnet-change.ps1 -Cidr 10.61.8.0/22
```

## Optional Create VNet

Run the script to create VNets in specified regions.

```shell
./dspm-vnet-update/dspm-vnet-change.ps1 -Cidr 10.61.8.0/22 -CreateVNet -Regions "canadaeast, centralus, eastus, eastus2, northcentralus, southcentralus, westcentralus, westus, westus2, westus3"
```
