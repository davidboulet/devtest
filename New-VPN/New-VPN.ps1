function New-VPN {

    param (
         # Name of the Automation Credential for the Tenant
         [parameter(Mandatory=$true)] 
         [SecureString] $automationcredentialName,
 
         # Name of the target Resource Group
         [parameter(Mandatory=$true)] 
         [string] $resourceGroup,
 
         # Name of region ex: East US
         [parameter(Mandatory=$true)] 
         [string] $location,
 
         # Network range for Gateway Subnet in CIDR Notation ex: 10.0.255.0/28
         [parameter(Mandatory=$true)] 
         [string] $gatewaysubnetNetwork,
 
         # Name of Main Subnet to deploy resources
         [parameter(Mandatory=$true)] 
         [string] $subnetName,
 
         # Network range for Main Subnet in CIDR Notation ex: 10.0.0.0/24
         [parameter(Mandatory=$true)] 
         [string] $subnetNetwork,
 
         # Name of Virtual Network ex: SFT-Cloud
         [parameter(Mandatory=$true)] 
         [string] $vnetName,
 
         # Address space for Virtual Network in CIDR Notation ex: 10.0.0.0/16
         [parameter(Mandatory=$true)] 
         [string] $vnetNetwork,
 
         # Name of Local Network Gateway ex: SFT-LAN-Gateway
         [parameter(Mandatory=$true)] 
         [string] $localgatewayName,
 
         # WAN IP of on-premises VPN appliance
         [parameter(Mandatory=$true)] 
         [string] $localWANIP,
 
         # Network range for LAN in CIDR Notation ex: 192.168.1.0/24
         [parameter(Mandatory=$true)] 
         [string] $lanNetwork,
 
         # Name of Azure Network Gateway ex: SFT-Cloud-Gateway
         [parameter(Mandatory=$true)] 
         [string] $gatewayName,
 
         # Name of VPN Connection ex: SFT-Cloud
         [parameter(Mandatory=$true)] 
         [string] $connectionName,
 
         # Preshared Key for IPSec Tunnel
         [parameter(Mandatory=$true)] 
         [string] $sharedKey
    )
    
    #Connect to Azure Tenant

    Write-Output "Logging into Azure tenant..."

        Login-AzureRmAccount

    Write-Output "Done."

    #Create new resource group

    Write-Output "Creating resource group..."

        New-AzureRmResourceGroup `
            -Name $resourceGroup `
            -Location $location

    Write-Output "Done."

    #Create a virtual network and a gateway subnet

    Write-Output "Creating vnet and gateway subnet..."

        $gatewaySubnet = New-AzureRmVirtualNetworkSubnetConfig `
            -Name 'GatewaySubnet' `
            -AddressPrefix $gatewaysubnetNetwork

        $mainSubnet = New-AzureRmVirtualNetworkSubnetConfig `
            -Name $subnetName `
            -AddressPrefix $subnetNetwork

        New-AzureRMVirtualNetwork `
            -Name $vnetName `
            -ResourceGroupName $resourceGroup `
            -Location $location `
            -AddressPrefix $vnetNetwork `
            -Subnet $gatewaySubnet, $mainSubnet

    Write-Output "Done."

    #Create a local network gateway

    Write-Output "Creating local network gateway..."

        New-AzureRmLocalNetworkGateway `
            -Name $localgatewayName `
            -ResourceGroupName $resourceGroup `
            -Location $location `
            -GatewayIpAddress $localWANIP `
            -AddressPrefix $lanNetwork

    Write-Output "Done."

    #Request a public IP address

    Write-Output "Requesting public IP address..."

        $gatewayPIP = New-AzureRmPublicIpAddress `
            -Name $gatewayName `
            -ResourceGroupName $resourceGroup `
            -Location $location `
            -AllocationMethod Dynamic

    Write-Output "Done."

    #Create the gateway IP addressing configuration

    Write-Output "Creating gateway IP config..."

        $vnet = Get-AzureRmVirtualNetwork `
            -Name $vnetName `
            -ResourceGroupName $resourceGroup

        $subnet = Get-AzureRmVirtualNetworkSubnetConfig `
            -Name 'GatewaySubnet' `
            -VirtualNetwork $vnet

        $gatewayIPConfig = New-AzureRmVirtualNetworkGatewayIpConfig `
            -Name 'GatewayIPConfig' `
            -SubnetId $subnet.Id `
            -PublicIpAddressId $gatewayPIP.Id

    Write-Output "Done."

    #Create the VPN gateway

    Write-Output "Creating vnet gateway... May take some time... Please standby..."

        New-AzureRmVirtualNetworkGateway `
            -Name $gatewayName `
            -ResourceGroupName $resourceGroup `
            -Location $location `
            -IpConfigurations $gatewayIPConfig `
            -GatewayType Vpn `
            -VpnType PolicyBased `
            -GatewaySku Basic

    #Create the VPN connection

            DO{
        
                Write-Output "Checking for created vnet gateway..."    

                $gateway = Get-AzureRmVirtualNetworkGateway `
                    -Name $gatewayName `
                    -ResourceGroupName $resourceGroup

            }While($null -eq $gateway)

    Write-Output "Received created gateway - $($gateway.Name) - from resource group - $($gateway.ResourceGroupName) -"

    Write-Output "Getting local network gateway..."

        $localGateway = Get-AzureRmLocalNetworkGateway `
            -Name $localgatewayName `
            -ResourceGroupName $resourceGroup
    
    Write-Output "Done."

    Write-Output "Creating vnet gateway connection..."

        New-AzureRmVirtualNetworkGatewayConnection `
            -Name $connectionName `
            -ResourceGroupName $resourceGroup `
            -Location $location `
            -VirtualNetworkGateway1 $gateway `
            -LocalNetworkGateway2 $localGateway `
            -ConnectionType IPsec `
            -RoutingWeight 10 `
            -SharedKey $sharedKey

    #Collecting information

        $pip = Get-AzureRMPublicIpAddress `
            -Name $gatewayName `
            -ResourceGroupName $resourceGroup

        $vnetGateway = Get-AzureRMVirtualNetworkGatewayConnection `
            -Name $connectionName `
            -ResourceGroupName $resourceGroup


    Write-Output "Connection Information:

IPsec Primary Gateway Address: $($pip.IpAddress)
Shared Secret: $($vnetGateway.SharedKey)
Destination Network: $($vnet.AddressSpace.AddressPrefixes)"

    Write-Output "Done. Please configure onsite VPN appliance. If already configured, monitor tunnel status."

}