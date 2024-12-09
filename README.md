# DIG | Prisma Cloud DSPM VNet Update

This repo contains an Azure Powershell script that can be used to re-ip DIG | DSPM VNets that are used for data scanning. Once executed the script will prompt for new VNet address space. The default value for the DIG | DSPM VNet is 10.0.0.0/16, and the default new value in the script is 10.61.8.0/24.


> [!WARNING]
> Running this script will remove all existing VNet address space and subnets for all VNets tagged with 'dig-security'
> The address space provided will be replace VNet address space and a single subnet using the full address space.

Open Azure Cloud Shell and clone this repo.

```shell
git clone https://github.com/CustomerPOC/dspm-vnet-update
```

Set your subscription id to target the DIG hub account subscription.

```shell
Set-AzContext -Subscription 00000000-0000-0000-0000-000000000000
```

Run the script to update all your VNets.

```shell
./dspm-vnet-update/dspm-vnet-change.ps1
```

## Optional Create VNet

Run the script to create VNets in specified regions.

```shell
./dspm-vnet-update/dspm-vnet-change.ps1 -CreateVNet
```
