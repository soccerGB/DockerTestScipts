
Write-Host "adding 169.254.169.254 to network interface"

$ifIndex = get-netadapter | select -expand ifIndex
New-NetIPAddress -InterfaceIndex $ifIndex -IPAddress 169.254.169.254

Write-host "wait for the network setting to be ready for use..."
Start-Sleep -s 4
ipconfig