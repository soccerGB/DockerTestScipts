

$interfaceName = get-netadapter | select -expand Name
$gatewayIP = get-netroute -DestinationPrefix '0.0.0.0/0' | select -ExpandProperty NextHop
netsh interface ipv4 add address "$interfaceName" 169.254.169.254 255.255.255.255 $gatewayIP
#Netsh interface portproxy add v4tov4 listenaddress=169.25.169.254 listenport=80 connectaddress=172.24.38.149 connectport=80  protocol=tcp
powershell

