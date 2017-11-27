PowerShell -NoProfile -ExecutionPolicy Bypass -Command "& '.\net.ps1'"
echo %IMSProxyIpAddress%
Netsh interface portproxy add v4tov4 listenaddress=169.254.169.254 listenport=80 connectaddress=%IMSProxyIpAddress% connectport=80  protocol=tcp
PowerShell -NoProfile -ExecutionPolicy Bypass -Command "& Invoke-WebRequest -Uri "http://169.254.169.254" -Method GET -UseBasicParsing"
cmd