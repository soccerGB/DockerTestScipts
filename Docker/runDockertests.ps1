
#Start-Transcript 
$MINIMUM_PROCESS="vmmem"

class WorkingSet
{
    # Optionally, add attributes to prevent invalid value
    [ValidateNotNullOrEmpty()][int]$Total_Workingset
    [ValidateNotNullOrEmpty()][int]$Private_Workingset
    [ValidateNotNullOrEmpty()][int]$Shared_Workingset
    [ValidateNotNullOrEmpty()][int]$CommitSize
}

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

#
# The memory performance counter mapping between what''s shown in the Task Manager and those Powershell APIs for getting them
# are super confusing. After many tries, I came out with the following mapping that matches with Taskmgr numbers on Windows 10
#
function ProcessWorkingSetInfoById
{
    param
    ([int]$processId)

    $obj = Get-WmiObject -class Win32_PerfFormattedData_PerfProc_Process | where{$_.idprocess -eq $processId} 

    $ws = [WorkingSet]@{
                        Total_Workingset = $obj.workingSet / 1kb
                        Private_Workingset = $obj.workingSetPrivate / 1kb
                        Shared_Workingset = ($obj.workingSet - $obj.workingSetPrivate) / 1kb
                        CommitSize = $obj.PrivateBytes / 1kb }
    return $ws
}

function Execute-ContainerCommand (
    [Parameter(Mandatory=$true)][string]$Command) {

    #Write-Host "Running: $Command ..."

    $stopwatch=[System.Diagnostics.Stopwatch]::startNew()

    $container = Invoke-Expression $Command
    $stopwatch.Stop()
    #Write-Host $container

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

function Runtest 
{
    param
    ([string]$TestImageName)

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

        $OperationTime.PullImageTime =Execute-ContainerCommand ("docker pull $TestImageName")

        #create container
        $OperationTime.CreateContainerTime = Execute-ContainerCommand ("docker create --name $TestContainerName $TestImageName")

        #start
        $OperationTime.StartContainerTime = Execute-ContainerCommand ("docker start $TestContainerName")

        $ignoredResult = docker stop $TestContainerName
        $ignoredResult = docker rm $TestContainerName

        #
        # Collect information for processes/VMs before instantiating a container  
        #
        $VmmemProcsBefore = Get-Process $MINIMUM_PROCESS
        $UVMsBefore = Get-ComputeProcess

        #$runContainerProc=Execute-AsynContainerCommand("run -it --name $TestContainerName $TestImageName  sleep 10s")
        $runContainerProc=Execute-AsynContainerCommand("run -itd --name $TestContainerName $TestImageName  sh")
         Sleep 3

        #
        # Collect information for processes/VMs after instantiating a container  
        #
        $VmmemProcsAfter = Get-Process $MINIMUM_PROCESS
        $UVMsAfter = Get-ComputeProcess

        # find $MINIMUM_PROCESS process after running a container
        $newProcess = Compare-Object -referenceobject $VmmemProcsBefore -differenceobject $VmmemProcsAfter -Property id -PassThru 
        $workinginfo = ProcessWorkingSetInfoById $newProcess.id

        #exec an command inside the container
        $OperationTime.ExecProcessInContainerTime = Execute-ContainerCommand ("docker exec $TestContainerName ls")

        # find UVM delta after running a container
        $UVMsAfter = Get-ComputeProcess
        $newUVM = Compare-Object -referenceobject $UVMsBefore -differenceobject $UVMsAfter -Property id -PassThru 

        # get the OS memory usage from the guest os
        $memoryUsedByUVMOS=hcsdiag exec -uvm $newUVM.id free

        #stop container
        $OperationTime.StopContainerTime = Execute-ContainerCommand ("docker stop $TestContainerName")

        # wait until the running container to exit
        $runContainerProc.WaitForExit()
        Write-Host  ("exitCode is" + $runContainerProc.ExitCode)

        #remove container
        $OperationTime.RemoveContainerTime = Execute-ContainerCommand ("docker rm " + $TestContainerName)

        #a separate run test
        $OperationTime.RunContainerTime = Execute-ContainerCommand ("docker run --rm $TestImageName")

        #remove image
        $OperationTime.RemoveImageTime = Execute-ContainerCommand ("docker rmi -f " + $TestImageName)

        Write-Host "`n------------------------------------------"
        Write-Host " Test result for $TestImageName"
        Write-Host "------------------------------------------"

        $OperationTime | Format-Table
        Write-Host "`tps. time in the units of ms"

        $workinginfo | Format-Table
        Write-Host "`tps. Working set information in KB"

        Write-Host "`nMemory used by the Linux OS running inside the new UVM"
        Write-Output $memoryUsedByUVMOS
        Write-Host "------------------------------------------"
}



# test start here!

cls

# Dump high level docker information
$dockerVersion = docker version
Write-OUtput $dockerVersion


Runtest("busybox")
Runtest("ubuntu")

#Stop-Transcript 