param([string]$inputVHDFileName)

Function Test-IsAdmin () {
    [Security.Principal.WindowsPrincipal] $Identity = [Security.Principal.WindowsIdentity]::GetCurrent()            
    $Identity.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)  
}

# Start of the main script. In a try block to catch any exception
Try {
    Write-Host -ForegroundColor Cyan "INFO: Starting at $(date)`n"
    set-PSDebug -Trace 0  # 1 to turn on

    if (-not (Test-IsAdmin)) {
        Throw("This must be run elevated")
    }

    #$inputVHDFileName = "WindowsRS3.vhd"
    $vhdFilename = "TempAzure$inputVHDFileName"
    $azureVhdFilename = "Azure$inputVHDFileName"

    Write-host "Input file:$vhdFilename, outputfile:$azureVhdFilename"
 
    $workingDir = (Resolve-Path .\).Path
    $vhdFullFilename = (Join-Path $workingDir -ChildPath $vhdFilename)
    $Password = "replacepassword1234$"
    $vmName = "vmname"

    Write-Host "Clean up previously VM instance for the prep work if there is any"
    $vm = Get-VM $vmName -ErrorAction SilentlyContinue
    if ($vm -ne $null) {
        Write-Host "WARN: VM already exists - deleting"
        Stop-VM $vm -TurnOff
        Remove-VM $vm -Force
    }
    Write-host "Expanding VHD size to 24 GB..."
    Copy-Item $inputVHDFileName $vhdFilename -Force

    Write-host "Copy file input vhd to a temp vhd... it will take a while..."
    # desired max VHD size : 128 GB"
    $targetSize = 24*1024*1024*1024
    Write-host "VHD file nanme is $vhdFilename , vhdFullFilename = $vhdFullFilename"
  
    # Get the VHD size in GB, and resize to the target if not already
    Write-Host "INFO: Examining the original VHD"
    $disk=Get-VHD $vhdFullFilename
    $size=($disk.size)
    Write-Host "INFO: Original VHD disk size is $($size/1024/1024/1024) GB"
    if ($size -lt $targetSize) {
        Write-Host "INFO: Resizing to $($targetSize/1024/1024/1024) GB"
        Resize-VHD $vhdFullFilename -SizeBytes $targetSize

        $disk=Get-VHD $vhdFullFilename
        $size=($disk.size)
        Write-Host "INFO: New VHD disk size is $($size/1024/1024/1024) GB"
    }

    Write-Host "Coverting a dynamic VHD to fixed format"
    Convert-VHD -Path $vhdFilename -DestinationPath $azureVhdFilename -VHDType Fixed -DeleteSource

    Write-Host "INFO: Mounting the VHD"
    $vhdFullFilename = (Join-Path $workingDir -ChildPath $azureVhdFilename)
    Mount-DiskImage $vhdFullFilename

    $mounted = $true

    # Get the drive letter
    $driveLetter = (Get-DiskImage $vhdFullFilename | Get-Disk | Get-Partition | Get-Volume).DriveLetter
    Write-Host "INFO: Drive letter is $driveLetter"

    # To work around a bug when a drive is mounted from a function inside a moduel the drive is not avalible to the module. 
    # use New-PSDrive so other cmdlets in this session can see the new drive
    # New-PSDrive -Name $driveLetter -PSProvider FileSystem -Root "$($driveLetter):\"

    # Get the partition
    $partition = Get-DiskImage $vhdFullFilename | Get-Disk | Get-Partition

    # Resize the partition to its maximum size
    $maxSize = (Get-PartitionSupportedSize -DriveLetter $driveLetter).sizeMax
    if ($partition.size -lt $maxSize) {
        Write-Host "INFO: Resizing partition to maximum : $driveLetter $maxSize"
        Resize-Partition -DriveLetter $driveLetter -Size $maxSize
    }

    # The entire repo of w2w (we need this for a dev-vm scenario - bootstrap.ps1 makes that decision
    #Copy-Item ..\* "$driveletter`:\w2w" -Recurse -Force

    # Put the bootstrap file additionally in \packer
    #Copy-Item ..\common\Bootstrap.ps1 "$driveletter`:\packer\"

    # Files for test-signing and copying privates
    #Copy-Item "\\sesdfs\1windows\TestContent\CORE\Base\HYP\HAT\setup\testroot-sha2.cer" "$driveLetter`:\privates\"
    #Copy-Item ("\\winbuilds\release\$branch\$build"+".$timestamp\amd64fre\test_automation_bins\idw\sfpcopy.exe") "$driveLetter`:\privates\"

    # We need NuGet
    #Write-Host "INFO: Installing NuGet package provider..."
    #Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force | Out-Null


    Write-Host "Preparing VHD for unattended booting" 
    Write-Host "INFO: Creating unattend.xml"
    $unattend = Get-Content ".\unattend.xml"
    $unattend = $unattend.Replace("!!REPLACEME!!", $Password)

    [System.IO.File]::WriteAllText("$driveLetter`:\unattend.xml", $unattend, (New-Object System.Text.UTF8Encoding($False)))

    # Create the password file
    [System.IO.File]::WriteAllText("$driveLetter`:\password.txt", $Password, (New-Object System.Text.UTF8Encoding($False)))


    # Flush the disk
    Write-Host "INFO: Flushing drive $driveLetter"
    Write-VolumeCache -DriveLetter $driveLetter

    # Dismount - we're done preparing it.
    Write-Host "INFO: Dismounting VHD"
    Dismount-DiskImage $vhdFullFilename
    $mounted = $false
    
    # Create a VM from that VHD

    Write-Host "INFO: Creating a VM"
    $vm = New-VM -generation 1 -Path $workingDir -Name $vmName -NoVHD
    Set-VMProcessor $vm -ExposeVirtualizationExtensions $true -Count 2
	Set-VM $vm -MemoryStartupBytes 4GB
	Set-VM $vm -CheckpointType Standard

	#Set-VM $vm -AutomaticCheckpointsEnabled $False
    Add-VMHardDiskDrive $vm -ControllerNumber 0 -ControllerLocation 0 -Path $vhdFullFilename

    Start-VM $vm
    Write-Host -NoNewline "INFO: Waiting for VM to complete booting and re-sysprep: "
    while ($vm.State -ne "Running") {
        Write-host -NoNewline "."
        Start-Sleep -seconds 6
    }

    #if ($vm -ne $null) {
    #    Write-Host "INFO: Starting the development VM. It will ask for creds in a few minutes..."
    #    Stop-VM $vm
    #    Remove-VM $vm -Force
    #}
}
Catch [Exception] {

    $ErrorMessage = $_.Exception.Message
    $FailedItem = $_.Exception.ItemName
    Write-Host $ErrorMessage
    Write-Host $FailedItem

    Throw $_
}
Finally {
    if ($mounted) { 
        Write-Host "INFO: Dismounting VHD"
        Dismount-DiskImage $vhdFullFilename
    }

    Write-Host "INFO: Exiting at $(date)"
}