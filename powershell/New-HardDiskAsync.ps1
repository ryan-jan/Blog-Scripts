<#
    .SYNOPSIS
    Create a hard disk for a virtual machine asynchronously.

    .DESCRIPTION
    As at VMware.VimAutomation.Core version 11.3.0.13964826, the New-HardDisk CmdLet does not include the
    -RunAsync parameter that so many other PowerCLI CmdLets do. This function uses the ReconfigVM_Task method
    to implement an asynchronus way to create new hard disks for VMs. This is especially useful when creating
    large hard disks which are thick provisioned with eager zeroing.

    .PARAMETER Name
    Specify a VM by name.

    .PARAMETER CapacityGB
    Specify the capacity of the new hard disk in GB.

    .PARAMETER Controller
    Specify the Id of the target controller.

    .PARAMETER StorageFormat
    Specify a storage format.

    .PARAMETER ThinProvisioned
    Specify if the new disk should be thin provisioned.

    .EXAMPLE
    .\New-HardDiskAsync.ps1 -Name "vm0123" -CapacityGB 20

    This will create a 20 GB thin provisioned disk using the first available SCSI controller.

    .EXAMPLE
    .\New-HardDiskAsync.ps1 -Name "vm0123" -CapacityGB 20 -StorageFormat "EagerZeroedThick"

    This will create a 20 GB eagerly zeroed disk using the first available SCSI controller.

    .EXAMPLE
    $VM = Get-VM -Name "vm0123"
    $ScsiController = $VM | Get-ScsiController
    $VM | .\New-HardDiskAsync.ps1 -CapacityGB 20 -Controller $ScsiController[1]

    This will create a 20 GB thin provisioned disk using the second SCSI controller attched to
    the VM (second controller specified by its index in the $ScsiController variable).
#>

param (
    [Parameter(
        Mandatory = $true,
        ValueFromPipelineByPropertyName = $true
    )]
    [string] $Name,

    [Parameter(
        Mandatory = $true
    )]
    [Decimal] $CapacityGB,

    [Parameter(
        Mandatory = $false
    )]
    $Controller,

    [Parameter(
        Mandatory = $false
    )]
    [ValidateSet("Thin", "Thick", "EagerZeroedThick")]
    $StorageFormat = "Thin",

    [Parameter(
        Mandatory = $false
    )]
    [Switch] $ThinProvisioned
)


try {
    $VM = Get-VM -Name $Name
    $VMDevice = $VM.ExtensionData.Config.Hardware.Device
    if (-not $Controller) {
        $Controller = $VMDevice.Where({
            ($_.GetType().BaseType.Name -eq "VirtualSCSIController") -and
            ($_.Device.Count -lt 16)
        })[0]
        $Controller = Get-ScsiController -VM $VM.Name -Name $Controller.DeviceInfo.Label
    } else {
        $Controller = Get-ScsiController -Id $Controller.Id
    }

    $UnitNumber = 0
    $UnitNumbers = $VMDevice.Where({$_.Key -in $Controller.ExtensionData.Device}).UnitNumber
    while (($UnitNumber -in $UnitNumbers) -and -not ($i -ge 16)) {$UnitNumber++}

    $Spec = New-Object VMware.Vim.VirtualMachineConfigSpec
    $Spec.DeviceChange = New-Object VMware.Vim.VirtualDeviceConfigSpec[] (1)
    $Spec.DeviceChange[0] = New-Object VMware.Vim.VirtualDeviceConfigSpec
    $Spec.DeviceChange[0].FileOperation = "create"
    $Spec.DeviceChange[0].Device = New-Object VMware.Vim.VirtualDisk
    $Spec.DeviceChange[0].Device.CapacityInBytes = ($CapacityGB * 1024 * 1024 * 1024)
    $Spec.DeviceChange[0].Device.CapacityInKB = ($CapacityGB * 1024 * 1024)
    $Spec.DeviceChange[0].Device.Backing = New-Object VMware.Vim.VirtualDiskFlatVer2BackingInfo
    $Spec.DeviceChange[0].Device.Backing.FileName = ''
    if ($StorageFormat -eq "EagerZeroedThick") {
        $Spec.DeviceChange[0].Device.Backing.EagerlyScrub = $true
    } else {
        $Spec.DeviceChange[0].Device.Backing.EagerlyScrub = $false
    }
    if ($ThinProvisioned -or ($StorageFormat -eq "Thin")) {
        $Spec.DeviceChange[0].Device.Backing.ThinProvisioned = $true
    } else {
        $Spec.DeviceChange[0].Device.Backing.ThinProvisioned = $false
    }
    $Spec.DeviceChange[0].Device.Backing.DiskMode = "persistent"
    $Spec.DeviceChange[0].Device.ControllerKey = $Controller.Key
    $Spec.DeviceChange[0].Device.UnitNumber = $UnitNumber
    $Spec.DeviceChange[0].Device.Key = (-101 - $VMDevice.Where({$_.ControllerKey -eq $Controller.Key}).Count)
    $Spec.DeviceChange[0].Device.DeviceInfo = New-Object VMware.Vim.Description
    $Spec.DeviceChange[0].Device.DeviceInfo.Summary = "New Hard disk"
    $Spec.DeviceChange[0].Device.DeviceInfo.Label = "New Hard disk"
    $Spec.DeviceChange[0].Operation = "add"
    $TaskId = $VM.ExtensionData.ReconfigVM_Task($Spec)
    Get-Task -Id $TaskId.ToString()
} catch {
    $Err = $_
    throw $Err
}
