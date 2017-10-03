
#stop running whenever any error was encounterd
$ErrorActionPreference='Stop'

#Start-Transcript 
$MINIMUM_PROCESS="vmmem"

$Durations = "TotalHCSTime",
             "HcsCreateSytemDuration",  
             "UtilityVMConfigPrepTime", "UtilityVMStartDuration", "ConnectToGCSDuration", 
             "UEFIOverheadTime", "LinuxKernelDecompressingTime", "KernelModeBootDuration", "UserModeBootTime",
             "HcsStartSystemDuration",  "HcsCreateProcessDuration"
             

class DockerOperationTime
{
    # Optionally, add attributes to prevent invalid values
    [ValidateNotNullOrEmpty()][int]$PullImageTime
    [ValidateNotNullOrEmpty()][int]$CreateContainerTime
    [ValidateNotNullOrEmpty()][int]$StartContainerTime
    [ValidateNotNullOrEmpty()][int]$ExecProcessInContainerTime
    [ValidateNotNullOrEmpty()][int]$StopContainerTime
    [ValidateNotNullOrEmpty()][int]$RunContainerTime
    [ValidateNotNullOrEmpty()][int]$RemoveContainerTime
    [ValidateNotNullOrEmpty()][int]$RemoveImageTime
}

function Execute-ContainerCommand (
    [Parameter(Mandatory=$true)][string]$Command
    ) {



    #Write-Host "Running: $Command ..."

    $stopwatch=[System.Diagnostics.Stopwatch]::startNew()

    $container = Invoke-Expression $Command
    $stopwatch.Stop()
    Write-Host $container

    $exectime = $stopwatch.ElapsedMilliseconds
    Write-Host "Executing: `"$Command`" elpased time:`t$exectime ms"
    return [int]$exectime
}

function Execute-SyncCommand (
    [Parameter(Mandatory=$true)][string]$Command) {

    #Write-Host "Running: $Command ..."

    $stopwatch=[System.Diagnostics.Stopwatch]::startNew()

    $container = Invoke-Expression $Command
    $stopwatch.Stop()
    Write-Host $container

    $exectime = $stopwatch.ElapsedMilliseconds
    Write-Host "Executing: `"$Command`" elpased time:`t$exectime ms"
    return [int]$exectime
}

function Execute-AsynContainerCommand (
    [Parameter(Mandatory=$true)][string]$Command) {

    $ErrOutFilePath = New-TemporaryFile
    $StdOutFilePath = New-TemporaryFile

    $stopwatch=[System.Diagnostics.Stopwatch]::startNew()
    $proc=Start-Process -FilePath "docker" -ArgumentList $Command -RedirectStandardError $ErrOutFilePath.FullName -RedirectStandardOutput $StdOutFilePath.FullName -NoNewWindow -PassThru
    $stopwatch.Stop()

    $exectime = $stopwatch.ElapsedMilliseconds
    Write-Host "Executing: `"$Command`" elpased time:`t$exectime ms"

    Get-Content $ErrOutFilePath.FullName | Write-Host
    Get-Content $StdOutFilePath.FullName | Write-Host

    #Remove-Item $ErrOutFilePath.FullName -Force
    #Remove-Item $StdOutFilePath.FullName -Force

    return $proc
}

function SearchTimeStampByMarker (
    [Parameter(Mandatory=$true)][Object[]]$Contents,
    [Parameter(Mandatory=$true)][string]$Marker
     ) {

        # Write-Host $Contents
        # Parse DMESG output to get the kernel boot time
        # Find the line with 
        # [   0.829038] tmpfs: No value for mount option 'user-init-started'

        $TimeStampString = ""
        foreach ( $line in $Contents ) {
             #Write-Host "$line"
             if ($line -match $Marker)
             {
               $TimeStampString = $line
             }
        }
        $TimeStampString = $TimeStampString -replace " ", ""
        Write-Host "Marker:<$TimeStampString> "

        $delim = "[","]"
        $resultArray = $TimeStampString -Split {$delim -contains $_}
        #foreach ($s in $resultArray) {
        #    Write-Host $s
        #}

        [int]$timeStamp = 0
        if ($resultArray.count -gt 0) {
            $timeStamp = [int](([single]$resultArray[1]) * 1000)
        }
        else {
            Write-Host "error out here : no kernel boot time marker found"
            exit 1 
        }

        Write-Host "$Marker was found at $timeStamp" 
        return $timeStamp
}

function ParseHCSTrace (
    [Parameter(Mandatory=$true)][string]$HCSLogFile
     )
{
    Write-Host "ETL filename = $HCSLogFile"
    $Command = "./ETWParser.exe $HCSLogFile"
    $result = Invoke-Expression $Command

    $hashtable = @{$Durations[0]=0;
                   $Durations[1]=0;
                   $Durations[2]=0;
                   $Durations[3]=0;
                   $Durations[4]=0;
                   $Durations[5]=0;
                   $Durations[6]=0;
                   $Durations[7]=0;
                   $Durations[8]=0;
                   $Durations[9]=0
                     } 

    foreach ( $line in $result ) {
        foreach ($duration in $Durations)
        {
            if ($line.contains($duration))
            {
                $hashtable[$duration] = [int] $line.TrimStart($duration + ":")
                break;
            }
        }
    }
    return $hashtable
}

function Runtest 
{
    param
    ([string]$TestImageName,
     [string]$ETLLogFilename
    )

        Write-Host "Testing $TestImageName image"
        $OperationTime = [DockerOperationTime]@{
                        PullImageTime = 0
                        CreateContainerTime = 0
                        StartContainerTime = 0
                        ExecProcessInContainerTime = 0
                        StopContainerTime = 0
                        RunContainerTime = 0
                        RemoveContainerTime = 0
                        RemoveImageTime = 0
                        }

        #
        # Get container image name and version
        #
        $TestContainerName="testcontainer"

        Write-Host "pulling $TestImageName image"

        #Execute-ContainerCommand ("docker rm -f $TestImageName") -AdditionalParams "-ErrorAction SilentlyContinue"

        $OperationTime.PullImageTime =Execute-ContainerCommand ("docker pull $TestImageName")

        #
        # Start ETL logging 
        #
        Write-Host "Start ETL logging"
        Wpr.exe -start HcsTraceProfile.wprp!Hcs -filemode

        #
        # Collect information for processes/VMs before instantiating a container  
        #

        $UVMsBefore = Get-ComputeProcess

        $runContainerProc=Execute-AsynContainerCommand("run -itd --name $TestContainerName $TestImageName  sh")
        Sleep 5 # make sure the container is running


        #
        # Collect information for processes/VMs after instantiating a container  
        #
        #$VmmemProcsAfter = Get-Process $MINIMUM_PROCESS
        $UVMsAfter = Get-ComputeProcess

        # find UVM delta after running a container
        $UVMsAfter = Get-ComputeProcess

        if ($UVMsBefore-eq $null)
        {
            $newUVM = $UVMsAfter
        }
        else
        {
            $newUVM = Compare-Object -referenceobject $UVMsBefore -differenceobject $UVMsAfter -Property id -PassThru
        } 

        # get the DMESG from the Utility VM
        Write-Host $newUVM.id
        $DMESG_CONTENTS=hcsdiag exec -uvm $newUVM.Id dmesg

        $kernelModeBootEndTime = SearchTimeStampByMarker -Contents $DMESG_CONTENTS -Marker "user-init-started"
        Write-Host "kernelModeBootEndTime = $kernelModeBootEndTime ms"

        $userModeBootEndTime = SearchTimeStampByMarker -Contents $DMESG_CONTENTS  -Marker "user-init-ended"
        Write-Host "userModeBootTime = $($userModeBootEndTime - $kernelModeBootEndTime) ms"

        #stop container
        $OperationTime.StopContainerTime = Execute-ContainerCommand ("docker stop $TestContainerName")

        # wait until the running container to exit
        $runContainerProc.WaitForExit()

 
        Wpr.exe -stop $ETLLogFilename " Logfile for $TestImageName test run"
        Write-Host "ETL logging ended"

        #remove container
        $OperationTime.RemoveContainerTime = Execute-ContainerCommand ("docker rm " + $TestContainerName)

        #a separate run test
        #$OperationTime.RunContainerTime = Execute-ContainerCommand ("docker run --rm $TestImageName")

        #remove image
        Sleep 5
        $OperationTime.RemoveImageTime = Execute-ContainerCommand ("docker rmi -f " + $TestImageName)

        #analyze HCS ETL file for duration breakdown
        $Durationtable = ParseHCSTrace -HCSLogFile $ETLLogFilename
        Remove-Item $ETLLogFilename

        $Durationtable["KernelModeBootDuration"] = $kernelModeBootEndTime
        $Durationtable["UserModeBootTime"] = $userModeBootEndTime - $kernelModeBootEndTime
        $Durationtable["LinuxKernelDecompressingTime"] = [int]$Durationtable["ConnectToGCSDuration"] - [int]$Durationtable["UEFIOverheadTime"] - [int]$Durationtable["KernelModeBootDuration"]  - [int]$Durationtable["UserModeBootTime"]

        
        Write-Host "`n------------------------------------------"
        Write-Host " Test result for $TestImageName"
        Write-Host "------------------------------------------"

        Write-Host "kernelModeBootTime = $kernelModeBootEndTime ms"
        Write-Host "userModeBootTime = $($userModeBootEndTime - $kernelModeBootEndTime) ms"

        Write-Host "------------------------------------------"

        return $Durationtable
}

# test start here!

cls
Write-Output ("=== Get performance numbers ===")
# Dump high level docker information
$dockerVersion = docker version
Write-OUtput $dockerVersion


    $testCount=5
    $totalTimeK=0
    $totalTimeU=0

    $DurationSumTable = @{}
    foreach ($duration in $DurationSumTable)
    {
        $DurationSumTable.Add($duration, 0)
    }

    for ($i=0; $i -lt $testCount; $i++)
    {
        Write-Host "Run iteration= $i"
        $table = Runtest -TestImageName "ubuntu" -ETLLogFilename "HcsTrace$i.etl"
        foreach ($item in $table.Keys.GetEnumerator())
        {
            write-host "* $item = $([int]$table[$item])"
            [int]$DurationSumTable[$item] += [int]$table[$item]
            write-host "- $item = $([int]$DurationSumTable[$item])"
        }
    }
    Write-Host "==========================================="
    foreach ($item in $Durations)
    {
        write-host "Avg: $item = $([int]$DurationSumTable[$item] / $testCount) ms"
    }



#busybox 
#kernelBootTime = 839.58 ms
#usermodeBootTime = 17.54 ms 

#ubuntu
#kernelBootTime = 848 ms
#usermodeBootTime = 21.7 ms 