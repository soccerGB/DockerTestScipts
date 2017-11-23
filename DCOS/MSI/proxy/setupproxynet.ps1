Write-Host "settig up a new route for the Instance Metadata Service"
#route add 169.254.169.254 MASK 255.255.255.255 172.24.32.1

$ifIndex = get-netadapter | select -expand ifIndex
$gatewayIP = get-netroute -DestinationPrefix '0.0.0.0/0' | select -ExpandProperty NextHop
New-NetRoute –DestinationPrefix "169.254.169.254/32" –InterfaceIndex $ifIndex –NextHop $gatewayIP

route print -4

Write-Host "Testing access to the  Instance Metadata Service" from the proxy container"
Invoke-WebRequest -Uri "http://169.254.169.254/metadata/instance?api-version=2017-04-02" -Method GET  -Headers {"Metadata"="True"} -UseBasicParsing"
