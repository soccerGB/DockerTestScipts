PowerShell -NoProfile -ExecutionPolicy Bypass -Command "& '.\net.ps1'"
PowerShell -NoProfile -ExecutionPolicy Bypass -Command "& Invoke-WebRequest -Uri "http://169.254.169.254" -Method GET -UseBasicParsing"
cmd