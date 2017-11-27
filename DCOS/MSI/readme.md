
# Experiments on the redirecting Instance Metadata Service requests from Docker containers to a external facing proxy Docker container  

This experiment was to find a way to access the Instance Metadata Service endpoint (http:// 169.254.169.254) from client containers through a dedicated proxy container. My experiment belows show, with appropriate port fordwarding and routing setup,  it's possible to achieve above scenario inside a Azure VM running a WindowsServerCore:1709 (RS3) build. 

![Block diagram for Proxying Instance Metadata Service request](https://github.com/soccerGB/Tools/tree/master/DCOS/MSI/InstanceMetadata.png "Proxying Instance Metadata Service request")

(Note: in this setup, all containers are in the same subset)

## Building test images for running on the WindowsServerCore 1709 image

1. Build a python image on top of for WindowsServerCore 1709

      - cd pythonOn1709

      - docker build -t pythonwindow1709 .

3. Build a proxy container image

            To make Instance Metadat Service acessible from the proxy container, add a new net route for 169.254.169.254 to the active netowrk interface( see setupproxynet.ps1 for details)
      
      - cd proxy

      - docker build -t proxycontainer .
      
2. Build a client container image

            There are a couple things that need to be setup in a client container
            .Added 169.254.169.254 as a net ip address to the current network interface (see net.ps1)
                  New-NetIPAddress -InterfaceIndex $ifIndex -IPAddress 169.254.169.254
            .Added a port forwarding rule: from 169.254.169.254:80 to IMSProxyIpAddress:80 via Netsh tool (see setup.bat)
                  Netsh interface portproxy add v4tov4 listenaddress=169.254.169.254 listenport=80 connectaddress=%IMSProxyIpAddress% connectport=80  protocol=tcp

      - cd client

      - docker build -t clientcontainer .

You should have the following images in the "docker images" output
   
         C:\DCOS\MSI>docker images

               REPOSITORY                    TAG                 IMAGE ID            CREATED             SIZE

               clientcontainer               latest              d97ff4d103d9        9 minutes ago       5.39GB

               proxycontainer                latest              5439c82fa6d2        22 hours ago        5.58GB

               pythonwindow1709              latest              4f24f5144bea        23 hours ago        5.55GB

               microsoft/windowsservercore   1709                fc3e0de7ea04        5 weeks ago         5.39GB

               microsoft/nanoserver          1709                33dcd52c91c3        5 weeks ago         236MB
   
## Launch the proxy container instance
   The proxy cotnainer is expected to get run first before launching any client containers which relies on the proxy for accessign Instance Metadata. A new IP route to the network interface for 169.254.169.254 in setupproxynet.ps1 for making the Instance Metadata Service work from the proxy cotnainer itself. Some debugging messages were added into the same ps1 script for debugging purpose
      
      C:\DCOS\MSI> docker run -it proxycontainer

      C:\app>PowerShell -NoProfile -ExecutionPolicy Bypass -Command "& '.\setupproxynet.ps1'"
      settig up a new route for the Instance Metadata Service

      ifIndex DestinationPrefix                              NextHop                                  RouteMetric ifMetric PolicyStore
      ------- -----------------                              -------                                  ----------- -------- -----------
      23      169.254.169.254/32                             172.24.32.1                                      256 500      ActiveStore
      23      169.254.169.254/32                             172.24.32.1                                      256          Persiste...
      ===========================================================================
      Interface List
       22...........................Software Loopback Interface 2
       23...00 15 5d e0 c4 cd ......Hyper-V Virtual Ethernet Adapter #2
      ===========================================================================

      IPv4 Route Table
      ===========================================================================
      Active Routes:
      Network Destination        Netmask          Gateway       Interface  Metric
                0.0.0.0          0.0.0.0      172.24.32.1     172.24.32.64    756
              127.0.0.0        255.0.0.0         On-link         127.0.0.1    331
              127.0.0.1  255.255.255.255         On-link         127.0.0.1    331
        127.255.255.255  255.255.255.255         On-link         127.0.0.1    331
        169.254.169.254  255.255.255.255      172.24.32.1     172.24.32.64    756
            172.24.32.0    255.255.240.0         On-link      172.24.32.64    756
           172.24.32.64  255.255.255.255         On-link      172.24.32.64    756
          172.24.47.255  255.255.255.255         On-link      172.24.32.64    756
              224.0.0.0        240.0.0.0         On-link         127.0.0.1    331
              224.0.0.0        240.0.0.0         On-link      172.24.32.64    756
        255.255.255.255  255.255.255.255         On-link         127.0.0.1    331
        255.255.255.255  255.255.255.255         On-link      172.24.32.64    756
      ===========================================================================
      Persistent Routes:
        Network Address          Netmask  Gateway Address  Metric
                0.0.0.0          0.0.0.0      172.24.32.1  Default
        169.254.169.254  255.255.255.255      172.24.32.1  Default
      ===========================================================================
      Testing access to the  Instance Metadata Service from the proxy container
      Invoke-WebRequest -Uri http://169.254.169.254/metadata/instance?api-version=2017-04-02 -Method GET  -Headers {Metadata=True} -UseBasicParsing



      C:\app>python .\app.py
       * Running on http://0.0.0.0:80/ (Press CTRL+C to quit)


  *Note*: In above experiment run, the proxy container's ip address is `172.24.32.64`. it will be used by client containers for forwarding instnace metadata to.

## Launch a client container instance

Once the proxy cotnainer is runnning successfully, use a environment vaiable (IMSProxyIpAddress) to pass the IP addess of the proxy container to client containers. 

- C:\DCOS\MSI>set IMSProxyIpAddress=`172.24.32.64`

         do a 'set' to double check the environment was set correctly 
         C:\DCOS\MSI>set
         ....
         IMSProxyIpAddress=172.24.32.64
         ....

- C:\DCOS\MSI>docker run -it -e IMSProxyIpAddress clientcontainer

         ============ inside the container ===============

         C:\app>PowerShell -NoProfile -ExecutionPolicy Bypass -Command "& '.\net.ps1'"
            adding 169.254.169.254 to network interface


            IPAddress         : 169.254.169.254
            InterfaceIndex    : 28
            InterfaceAlias    : vEthernet (Ethernet) 2
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
            InterfaceIndex    : 28
            InterfaceAlias    : vEthernet (Ethernet) 2
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

            wait for the network setting to be ready for use...

            Windows IP Configuration


            Ethernet adapter vEthernet (Ethernet) 2:

               Connection-specific DNS Suffix  . : 3xojbo1mt10efniqkq31gfg3ja.xx.internal.cloudapp.net
               Link-local IPv6 Address . . . . . : fe80::9c33:ef44:de14:62ab%28
               IPv4 Address. . . . . . . . . . . : 172.24.45.178
               Subnet Mask . . . . . . . . . . . : 255.255.240.0
               IPv4 Address. . . . . . . . . . . : 169.254.169.254
               Subnet Mask . . . . . . . . . . . : 255.255.255.255
               Default Gateway . . . . . . . . . : 172.24.32.1



            C:\app>echo 172.24.32.64
            172.24.32.64
            
            C:\app>Netsh interface portproxy add v4tov4 listenaddress=169.254.169.254 listenport=80 connectaddress=172.24.32.64 connectport=80  protocol=tcp

Accessing the Instance Matadata Service from inside a client container 

            C:\app>PowerShell -NoProfile -ExecutionPolicy Bypass -Command "& Invoke-WebRequest -Uri "http://169.254.169.254" -Method GET -UseBasicParsing"


            StatusCode        : 200
            StatusDescription : OK
            Content           : {"compute":{"location":"westus2","name":"26652acs900-vmss_1","offer":"WindowsServerSemiAnnual","osType":"Windows","platformFaultDomain":"1","platformUpdateDomain":"1","publi
                                sher":"MicrosoftWindowsServ...
            RawContent        : HTTP/1.0 200 OK
                                Content-Length: 564
                                Content-Type: text/html; charset=utf-8
                                Date: Mon, 27 Nov 2017 19:04:28 GMT
                                Server: Werkzeug/0.12.2 Python/3.7.0a2

                                {"compute":{"location":"westus2","name":"26...
            Forms             :
            Headers           : {[Content-Length, 564], [Content-Type, text/html; charset=utf-8], [Date, Mon, 27 Nov 2017 19:04:28 GMT], [Server, Werkzeug/0.12.2 Python/3.7.0a2]}
            Images            : {}
            InputFields       : {}
            Links             : {}
            ParsedHtml        :
            RawContentLength  : 564

            C:\app>cmd
            Microsoft Windows [Version 10.0.16299.19]
            (c) 2017 Microsoft Corporation. All rights reserved.

            C:\app>

