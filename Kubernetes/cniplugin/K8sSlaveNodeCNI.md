    
    # The K8 Slave Node setup
    
    c:\k\kubelet.exe 
	
	
	--hostname-override=$global:AzureHostname 
	--pod-infra-container-image=kubletwin/pause 
	--resolv-conf="" 
	--allow-privileged=true 
	--enable-debugging-handlers 

	--cluster-dns=$global:KubeDnsServiceIp 
	--cluster-domain=cluster.local  
	--kubeconfig=c:\k\config 
	--hairpin-mode=promiscuous-bridge --v=2 
	--azure-container-registry-config=c:\k\azure.json 
	
	--runtime-request-timeout=10m  
	--cloud-provider=azure 
	--cloud-config=c:\k\azure.json 
	--api-servers=https://${global:MasterIP}:443 
	
	--network-plugin=cni 
	--cni-bin-dir=$global:CNIPath 
	--cni-conf-dir $global:CNIPath\config 
	
	--image-pull-progress-deadline=20m 
	--cgroups-per-qos=false 
	--enforce-node-allocatable=""

	$env:CONTAINER_NETWORK="l2bridge" 
$global:AzureHostname = "24065k8s9003"
$global:MasterIP = "10.240.255.5"
$global:KubeDnsServiceIp = "10.0.0.10"
$global:MasterSubnet = "10.240.0.0/16"
$global:KubeClusterCIDR = "10.244.0.0/16"
$global:KubeServiceCIDR = "10.0.0.0/16"
$global:KubeBinariesVersion = "1.7.9"
$global:CNIPath = "c:\k\cni"
$global:NetworkMode = "L2Bridge"
$global:CNIConfig = "c:\k\cni\config\$global:NetworkMode.conf"
$global:HNSModule = "c:\k\hns.psm1"

