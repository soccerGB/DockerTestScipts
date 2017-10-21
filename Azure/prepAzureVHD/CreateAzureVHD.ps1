
#Function to get mounted VHD drive letters. Thanks internet for the example.
function get-mountedvhdDrive {
    $disks = Get-CimInstance -ClassName Win32_DiskDrive | where Caption -eq "Microsoft Virtual Disk"            
    foreach ($disk in $disks){
        $vols = Get-CimAssociatedInstance -CimInstance $disk -ResultClassName Win32_DiskPartition             
        foreach ($vol in $vols){       
            Get-CimAssociatedInstance -CimInstance $vol -ResultClassName Win32_LogicalDisk |            
            where VolumeName -ne 'System Reserved'            
        }            
    }
}

#Get just the drive letters (Used to ensure only one device)
#$vhdletter = (get-mountedvhdDrive | select DeviceID )
#Write-Host $vhdletter

$sourceDir="\\winbuilds\release\RS3_RELEASE_BASE\16279.1001.170827-1700"
$AzureImageVersion=3   #0 to not do the azure thing
$debugPort=50010
$AzureVMSize="Standard_D2_v3_Promo"  # D3 for production, D2 for test
$AzurePassword="12345678"
$AzureStorageAccount="winrs1"
$configSet="rs"
$redstoneRelease=3
$vmBasePath="c:\temp"
$localPassword="p@ssw0rd"
$vmSwitch="Wired"
$IgnoreMissingImages="No"
$SkipBaseImages=$true

$WORK_PATH = Split-Path -parent $MyInvocation.MyCommand.Definition

Write-Host $WORK_PATH

$ModuleName = "$WORK_PATH\PrepVHD"

if (Get-Module -Name $ModuleName)  
{ 
    Remove-Module -Name $ModuleName 
} 
Import-Module $ModuleName


PrepVHDWorker -Target $vmBasePath -Password $localPassword -CreateVM -Switch $vmSwitch -DebugPort $debugPort -Path $sourceDir -ConfigSet $configSet -AzureImageVersion $AzureImageVersion -AzurePassword  $AzurePassword -IgnoreMissingImages $IgnoreMissingImages -RedstoneRelease $redstoneRelease