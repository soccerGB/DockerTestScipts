$env:KUBE_NETWORK = "l2bridge"
$global:NetworkMode = "L2Bridge"
$hnsNetwork = Get-HnsNetwork | ? Name -EQ $global:NetworkMode.ToLower()
while (!$hnsNetwork)
{
    Start-Sleep 10
    $hnsNetwork = Get-HnsNetwork | ? Name -EQ $global:NetworkMode.ToLower()
}

c:\k\kube-proxy.exe --v=3 --proxy-mode=kernelspace --hostname-override=24065k8s9003 --kubeconfig=c:\k\config
