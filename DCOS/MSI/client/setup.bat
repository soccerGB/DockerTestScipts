PowerShell -NoProfile -ExecutionPolicy Bypass -Command "& '.\net.ps1'"
Netsh interface portproxy add v4tov4 listenaddress=169.254.169.254 listenport=80 connectaddress=172.24.38.149 connectport=80  protocol=tcp
PowerShell -NoProfile -ExecutionPolicy Bypass -Command "& Invoke-WebRequest -Uri "http://169.254.169.254" -Method GET -UseBasicParsing"
cmd