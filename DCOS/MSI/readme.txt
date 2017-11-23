1. Build a python image on top of for WindowsServerCore 1709

cd pythonOn1709
docker build -t pythonwindow1709 .


2. Build a client container

cd client
docker build -t clientcontainer .

3. Build a proxy container

cd client
docker build -t proxycontainer .

======================= note ===================




C:\app>PowerShell -NoProfile -ExecutionPolicy Bypass -Command "& '.\net.ps1'"
adding 169.254.169.254 to network interface


IPAddress         : 169.254.169.254
InterfaceIndex    : 23
InterfaceAlias    : vEthernet (Ethernet)
AddressFamily     : IPv4
Type              : Unicast
PrefixLength      : 32
PrefixOrigin      : Manual
SuffixOrigin      : Manual
AddressState      : Tentative
ValidLifetime     : Infinite ([TimeSpan]::MaxValue)
PreferredLifetime : Infinite ([TimeSpan]::MaxValue)
SkipAsSource      : False
PolicyStore       : ActiveStore

IPAddress         : 169.254.169.254
InterfaceIndex    : 23
InterfaceAlias    : vEthernet (Ethernet)
AddressFamily     : IPv4
Type              : Unicast
PrefixLength      : 32
PrefixOrigin      : Manual
SuffixOrigin      : Manual
AddressState      : Invalid
ValidLifetime     : Infinite ([TimeSpan]::MaxValue)
PreferredLifetime : Infinite ([TimeSpan]::MaxValue)
SkipAsSource      : False
PolicyStore       : PersistentStore


Windows IP Configuration


Ethernet adapter vEthernet (Ethernet):

   Connection-specific DNS Suffix  . : 3xojbo1mt10efniqkq31gfg3ja.xx.internal.cloudapp.net
   Link-local IPv6 Address . . . . . : fe80::a13e:82dc:c562:5edf%23
   IPv4 Address. . . . . . . . . . . : 172.24.36.99
   Subnet Mask . . . . . . . . . . . : 255.255.240.0
   IPv4 Address. . . . . . . . . . . : 169.254.169.254
   Subnet Mask . . . . . . . . . . . : 255.255.255.255
   Default Gateway . . . . . . . . . : 172.24.32.1



C:\app>Netsh interface portproxy add v4tov4 listenaddress=169.254.169.254 listenport=80 connectaddress=172.24.38.149 connectport=80  protocol=tcp


C:\app>PowerShell -NoProfile -ExecutionPolicy Bypass -Command "& Invoke-WebRequest -Uri "http://169.254.169.254" -Method GET -UseBasicParsing"


StatusCode        : 200
StatusDescription : OK
Content           : {"compute":{"location":"westus2","name":"26652acs900-vmss_1","offer":"WindowsServerSemiAnnual","osType":"Windows","platformFaultDom
                    ain":"1","platformUpdateDomain":"1","publisher":"MicrosoftWindowsServ...
RawContent        : HTTP/1.0 200 OK
                    Content-Length: 564
                    Content-Type: text/html; charset=utf-8
                    Date: Thu, 23 Nov 2017 07:54:55 GMT
                    Server: Werkzeug/0.12.2 Python/3.7.0a2

                    {"compute":{"location":"westus2","name":"26...
Forms             :
Headers           : {[Content-Length, 564], [Content-Type, text/html; charset=utf-8], [Date, Thu, 23 Nov 2017 07:54:55 GMT], [Server, Werkzeug/0.12.2
                    Python/3.7.0a2]}
Images            : {}
InputFields       : {}
Links             : {}
ParsedHtml        :
RawContentLength  : 564




C:\app>cmd
Microsoft Windows [Version 10.0.16299.19]
(c) 2017 Microsoft Corporation. All rights reserved.

C:\app>










===================================================================
# proxy container
===================================================================

C:\app>
C:\app>route add 169.254.169.254 MASK 255.255.255.255 172.24.32.1

PS C:\app> ipconfig

Windows IP Configuration


Ethernet adapter vEthernet (Ethernet) 2:

   Connection-specific DNS Suffix  . : 3xojbo1mt10efniqkq31gfg3ja.xx.internal.cloudapp.net
   Link-local IPv6 Address . . . . . : fe80::d9eb:871d:bf94:8d33%28
   IPv4 Address. . . . . . . . . . . : 172.24.38.149
   Subnet Mask . . . . . . . . . . . : 255.255.240.0
   Default Gateway . . . . . . . . . : 172.24.32.1
PS C:\app> python .\app.py
 * Running on http://0.0.0.0:80/ (Press CTRL+C to quit)
client request connecting...
retrun from 169.254.169.254 endpoint ...
172.24.33.167 - - [22/Nov/2017 10:11:21] "GET / HTTP/1.1" 200 -
client request connecting...

======================================================
# client container
======================================================

C:\Users\azureuser>docker images
REPOSITORY                    TAG                 IMAGE ID            CREATED             SIZE
clientcontainer               latest              d97ff4d103d9        9 minutes ago       5.39GB
<none>                        <none>              0ff34842e4c1        35 minutes ago      5.39GB
proxycontainer                latest              5439c82fa6d2        22 hours ago        5.58GB
pythonwindow1709              latest              4f24f5144bea        23 hours ago        5.55GB
microsoft/windowsservercore   1709                fc3e0de7ea04        5 weeks ago         5.39GB
microsoft/nanoserver          1709                33dcd52c91c3        5 weeks ago         236MB

C:\Users\azureuser>docker run -it clientcontainer



Microsoft Windows [Version 10.0.16299.19]
(c) 2017 Microsoft Corporation. All rights reserved.

C:\app>

C:\msi\adobe>docker run -it clientcontainer
Microsoft Windows [Version 10.0.16299.19]


C:\app>PowerShell -NoProfile -ExecutionPolicy Bypass -Command "& '.\net.ps1'"
adding 169.254.169.254 to network interface


IPAddress         : 169.254.169.254
InterfaceIndex    : 23
InterfaceAlias    : vEthernet (Ethernet)
AddressFamily     : IPv4
Type              : Unicast
PrefixLength      : 32
PrefixOrigin      : Manual
SuffixOrigin      : Manual
AddressState      : Tentative
ValidLifetime     : Infinite ([TimeSpan]::MaxValue)
PreferredLifetime : Infinite ([TimeSpan]::MaxValue)
SkipAsSource      : False
PolicyStore       : ActiveStore

IPAddress         : 169.254.169.254
InterfaceIndex    : 23
InterfaceAlias    : vEthernet (Ethernet)
AddressFamily     : IPv4
Type              : Unicast
PrefixLength      : 32
PrefixOrigin      : Manual
SuffixOrigin      : Manual
AddressState      : Invalid
ValidLifetime     : Infinite ([TimeSpan]::MaxValue)
PreferredLifetime : Infinite ([TimeSpan]::MaxValue)
SkipAsSource      : False
PolicyStore       : PersistentStore


Windows IP Configuration


Ethernet adapter vEthernet (Ethernet):

   Connection-specific DNS Suffix  . : 3xojbo1mt10efniqkq31gfg3ja.xx.internal.cloudapp.net
   Link-local IPv6 Address . . . . . : fe80::a13e:82dc:c562:5edf%23
   IPv4 Address. . . . . . . . . . . : 172.24.36.99
   Subnet Mask . . . . . . . . . . . : 255.255.240.0
   IPv4 Address. . . . . . . . . . . : 169.254.169.254
   Subnet Mask . . . . . . . . . . . : 255.255.255.255
   Default Gateway . . . . . . . . . : 172.24.32.1



C:\app>Netsh interface portproxy add v4tov4 listenaddress=169.254.169.254 listenport=80 connectaddress=172.24.38.149 connectport=80  protocol=tcp


C:\app>PowerShell -NoProfile -ExecutionPolicy Bypass -Command "& Invoke-WebRequest -Uri "http://169.254.169.254" -Method GET -UseBasicParsing"


StatusCode        : 200
StatusDescription : OK
Content           : {"compute":{"location":"westus2","name":"26652acs900-vmss_1","offer":"WindowsServerSemiAnnual","osType":"Windows","platformFaultDom
                    ain":"1","platformUpdateDomain":"1","publisher":"MicrosoftWindowsServ...
RawContent        : HTTP/1.0 200 OK
                    Content-Length: 564
                    Content-Type: text/html; charset=utf-8
                    Date: Thu, 23 Nov 2017 07:54:55 GMT
                    Server: Werkzeug/0.12.2 Python/3.7.0a2

                    {"compute":{"location":"westus2","name":"26...
Forms             :
Headers           : {[Content-Length, 564], [Content-Type, text/html; charset=utf-8], [Date, Thu, 23 Nov 2017 07:54:55 GMT], [Server, Werkzeug/0.12.2
                    Python/3.7.0a2]}
Images            : {}
InputFields       : {}
Links             : {}
ParsedHtml        :
RawContentLength  : 564




C:\app>cmd
