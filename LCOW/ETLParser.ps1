    $Durations = "UtilityVMConfigPrepTime", "UtilityVMStartDuration", "ConnectToGCSDuration", "UEFIOverheadTime",
                     "HcsStartSystemDuration",  "HcsCreateProcessDuration", "HcsCreateSytemDuration", "TotalHCSTime"


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
                   $Durations[7]=0
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


$DurationTable = ParseHCSTrace -HCSLogFile "HcsTrace0.etl"
        foreach ($item in $table.Keys.GetEnumerator())
        {
            Echo $item
        }

    foreach ($duration in $Durations)
    {
        write-host "$duration = $([int]$DurationTable[$duration])"
    }