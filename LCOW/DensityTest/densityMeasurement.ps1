
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
    [ValidateNotNullOrEmpty()][int]$LoopCount
    [ValidateNotNullOrEmpty()][int]$AvailMemInMB
    [ValidateNotNullOrEmpty()][int]$CreateTime
    [ValidateNotNullOrEmpty()][int]$StartTime
    [ValidateNotNullOrEmpty()][int]$ExecProcessTime
    [ValidateNotNullOrEmpty()][int]$StopContainerTime
    [ValidateNotNullOrEmpty()][int]$RemoveTime
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

    Write-Host "Running: $Command ..."

    $stopwatch=[System.Diagnostics.Stopwatch]::startNew()

    $message = Invoke-Expression $Command
    $stopwatch.Stop()
    #Write-Host $message

    $exectime = $stopwatch.ElapsedMilliseconds
    Write-Host "Executing: `"$Command`" elpased time:`t$exectime ms"
    return [int]$exectime, $message
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
    ([int]$TestRunIndex,
     [string]$TestImageName)

        Write-Host "Testing $TestImageName image"
        $OperationTime = [DockerOperationTime]@{
                        LoopCount = 0
                        AvailMemInMB = 0
                        CreateTime = 0
                        StartTime = 0
                        ExecProcessTime = 0
                        StopContainerTime = 0
                        RemoveTime = 0
                        }

        $OperationTime.AvailMemInMB = [int] ((get-counter -counter "\Memory\Available Bytes").CounterSamples[0].CookedValue /1024 /1024)

        #create container
        $OperationTime.CreateTime, $testContainerName = Execute-ContainerCommand ("docker create $TestImageName")
        write-host $testContainerName


        #start
        $OperationTime.StartTime, $returnedMessage = Execute-ContainerCommand ("docker start $testContainerName")
        write-host $returnedMessage

        #
        # Collect information for processes/VMs after instantiating a container  
        #
        #exec an command inside the container
        #write-host "docker exec $testContainerName ls"
        $OperationTime.ExecProcessTime, $returnedMessage = Execute-ContainerCommand ("docker exec $testContainerName ls")
        write-host $returnedMessage

        #stop container
        $OperationTime.StopContainerTime, $returnedMessage = Execute-ContainerCommand ("docker stop $testContainerName")
        write-host $returnedMessage

        #remove container
        sleep(3)
        $OperationTime.RemoveTime, $returnedMessage = Execute-ContainerCommand ("docker rm " + $testContainerName)
        write-host $returnedMessage

        $OperationTime.LoopCount = $TestRunIndex

        return $OperationTime
}

function AddOneContainerInstance
{
    param
    ([string]$TestImageName)

        Write-Host "Add a new $TestImageName container"
        $runContainerProc=Execute-AsynContainerCommand("run -d $TestImageName")
}


function CleanupAllContainerInstances
{
    param ([string]$TestImageName)

    Write-Host " Cleaning up ...."

    $containerInstances = $(docker ps -a -q)
    if ($containerInstances -ne $null)
    {
        docker stop $containerInstances
        docker rm   $containerInstances
    }

    #Remove image
    Execute-ContainerCommand ("docker rmi -f " + $TestImageName)
}

# test start here!

cls

Write-OUtput "LCOW container density measurement"

# Dump high level docker information
$dockerVersion = docker version
Write-OUtput $dockerVersion

$TestImageName = "redis"
Execute-ContainerCommand ("docker pull $TestImageName")

$LoopCount = 500

Write-OUtput "Start test runs"

$resultArray = @()

Try
{
    for ($i=0; $i -lt $LoopCount; $i++)
    {
        write-host "loop = $i"
        $operationTime = Runtest -TestRunIndex $i -TestImageName $TestImageName
        $resultArray += $operationTime
        AddOneContainerInstance($TestImageName)
    }
}
Catch 
{
    write-host $_.Exception.Message
}

Finally 
{
    #cleanup
    #CleanupAllContainerInstances -TestImageName $TestImageName

    foreach ($result in $resultArray)
    {
        $result | Format-Table
    }
    $resultArray  | ConvertTo-HTML | Out-File "$((Get-Item -Path ".\" -Verbose).FullName)\Test.htm"
    Invoke-Expression  "$((Get-Item -Path ".\" -Verbose).FullName)\Test.htm"
}


#Stop-Transcript 