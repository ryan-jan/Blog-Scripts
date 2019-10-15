<#
    .SYNOPSIS
    Retrieve CDP information for one or mort hosts from vCenter.

    .DESCRIPTION
    This function will query each host object from vCenter for available Cisco Discovery Protocol (CDP)
    information. Physcial NICs which do not have CDP information available will be excluded from the results.

    .PARAMETER Cluster
    Specify the name of one or more clusters from which to retrieve host CDP information.

    .PARAMETER VMHost
    Specify one or more hosts to retrieve CDP information.

    .PARAMETER Vmnic
    Specify one or more vmnic devices to filter the output by.

    .EXAMPLE
    Connect-VIServer vcenter.example.com
    Get-VMHostCDPInfo.ps1 -Cluster 'Cluster01'

    .EXAMPLE
    Connect-VIServer vcenter.example.com
    Get-VMHostCDPInfo.ps1 -Cluster 'Cluster01' -Vmnic 'vmnic5', 'vmnic7' | Format-Table -GroupBy VMHost

    .EXAMPLE
    Connect-VIServer vcenter.example.com
    Get-VMHostCDPInfo.ps1 -Cluster Cluster01 -Vmnic 'vmnic1', 'vmnic2', 'vmnic4'

    .EXAMPLE
    Connect-VIServer vcenter.example.com
    Get-VMHostCDPInfo.ps1 -VMHost 'esxi01.example.com', 'esxi02.example.com'
#>

param (
    [Parameter(
        Mandatory = $true,
        Position = 0,
        ParameterSetName = "Cluster"
    )]
    [String[]] $Cluster,

    [Parameter(
        Mandatory = $true,
        Position = 0,
        ParameterSetName = "VMHost"
    )]
    [String[]] $VMHost,

    [Parameter(
        Mandatory = $false,
        Position = 1,
        ParameterSetName = "Cluster"
    )]
    [Parameter(
        Mandatory = $false,
        Position = 0,
        ParameterSetName = "VMHost"
    )]
    [String[]] $Vmnic 
)

if ($VMHost) {
    $VHosts = foreach ($HostName in $VMHost) {
        Get-VMHost -Name $HostName
    }
}

if ($Cluster) {
    $VHosts = foreach ($Clu in $Cluster) {
        Get-Cluster -Name $Clu | Get-VMHost
    }
}

foreach ($VHost in $VHosts) {
    $NetSystem = Get-View $VHost.ExtensionData.ConfigManager.NetworkSystem
    if ($Vmnic) {
        foreach ($Pnic in $VHost.ExtensionData.Config.Network.Pnic) {
            if ($Vmnic.Contains($Pnic.Device)) {
                $PnicInfo = $NetSystem.QueryNetworkHint($Pnic.Device)
                if ($PnicInfo.ConnectedSwitchPort) {
                    $SwitchPort = $PnicInfo.ConnectedSwitchPort
                    [PSCustomObject] @{
                        'VMHost' = $VHost.Name
                        'Pnic' = $Pnic.Device
                        'CdpVersion' = $SwitchPort.CdpVersion
                        'Timeout' = $SwitchPort.Timeout
                        'Ttl' = $SwitchPort.Ttl
                        'Samples' = $SwitchPort.Samples
                        'DevId' = $SwitchPort.DevId
                        'Address' = $SwitchPort.Address
                        'PortId' = $SwitchPort.PortId
                        'DeviceCapability' = $SwitchPort.DeviceCapability
                        'SoftwareVersion' = $SwitchPort.SoftwareVersion
                        'HardwarePlatform' = $SwitchPort.HardwarePlatform
                        'IpPrefix' = $SwitchPort.IpPrefix
                        'IpPrefixLen' = $SwitchPort.IpPrefixLen
                        'Vlan' = $SwitchPort.Vlan
                        'FullDuplex' = $SwitchPort.FullDuplex
                        'Mtu' = $SwitchPort.Mtu
                        'SystemName' = $SwitchPort.SystemName
                        'SystemOID' = $SwitchPort.SystemOID
                        'MgmtAddr' = $SwitchPort.MgmtAddr
                        'Location' = $SwitchPort.Location
                    }
                }
            }
        }
    } else {
        foreach ($Pnic in $VHost.ExtensionData.Config.Network.Pnic) {
            $PnicInfo = $NetSystem.QueryNetworkHint($Pnic.Device)
            if ($PnicInfo.ConnectedSwitchPort) {
                $SwitchPort = $PnicInfo.ConnectedSwitchPort
                [PSCustomObject] @{
                    'VMHost' = $VHost.Name
                    'Pnic' = $Pnic.Device
                    'CdpVersion' = $SwitchPort.CdpVersion
                    'Timeout' = $SwitchPort.Timeout
                    'Ttl' = $SwitchPort.Ttl
                    'Samples' = $SwitchPort.Samples
                    'DevId' = $SwitchPort.DevId
                    'Address' = $SwitchPort.Address
                    'PortId' = $SwitchPort.PortId
                    'DeviceCapability' = $SwitchPort.DeviceCapability
                    'SoftwareVersion' = $SwitchPort.SoftwareVersion
                    'HardwarePlatform' = $SwitchPort.HardwarePlatform
                    'IpPrefix' = $SwitchPort.IpPrefix
                    'IpPrefixLen' = $SwitchPort.IpPrefixLen
                    'Vlan' = $SwitchPort.Vlan
                    'FullDuplex' = $SwitchPort.FullDuplex
                    'Mtu' = $SwitchPort.Mtu
                    'SystemName' = $SwitchPort.SystemName
                    'SystemOID' = $SwitchPort.SystemOID
                    'MgmtAddr' = $SwitchPort.MgmtAddr
                    'Location' = $SwitchPort.Location
                }
            }
        }
    }
}
