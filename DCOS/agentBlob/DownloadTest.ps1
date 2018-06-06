$BootstrapUrl = "http://52.151.39.54/performance"
$AGENT_BLOB_DEST_DIR = Join-Path "c:\" "blob"

function Download-Blob {
    $BINARIES_URL = "$BootstrapUrl/agentblob.zip"
    $blobPath = Join-Path $AGENT_BLOB_DEST_DIR "agentblob.zip"
    Remove-item $blobPath -ErrorAction SilentlyContinue
    New-item $AGENT_BLOB_DEST_DIR -itemtype directory -ErrorAction SilentlyContinue
    Write-Output "Downloading $BINARIES_URL to $blobPath"
    #Measure-Command { Invoke-WebRequest -UseBasicParsing -Uri $BINARIES_URL -OutFile $blobPath }
    Measure-Command { curl.exe --keepalive-time 2 -fLsS --retry 20 -Y 100000 -y 60 -o $blobPath $BINARIES_URL }
    #curl.exe --keepalive-time 2 -fLsS --retry 20 -Y 100000 -y 60 -o $blobPath $BINARIES_URL

    Write-Output "Extracting the agent blob @ $blobPath to $AGENT_BLOB_DEST_DIR"
    Measure-Command { Expand-Archive -LiteralPath $blobPath -DestinationPath $AGENT_BLOB_DEST_DIR -Force }
    Remove-item $blobPath #-ErrorAction SilentlyContinue
}



Download-Blob



