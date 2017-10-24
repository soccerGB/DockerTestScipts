# How to prepare and upload a Windows VHD file for use in an Azure VM 

1. Get a windows image in VHD format

      eg. \\winbuilds\release\RS3_RELEASE\16299.15.170928-1534\amd64fre\vhd\vhd_server_serverdatacenter_en-us_vl

2. Resize VHD and make it bootable 
   
   - copy unattended.xml and MakeWindowsVHDBootable.ps1 from https://github.com/soccerGB/Tools/tree/master/Azure/prepAzureVHD repro to your local directory
    (eg D:\github\Tools\Azure\prepAzureVHD)

   - In an elevated powershell windows, run the following script to generate a bootable VHD:
     PS D:\github\Tools\Azure\prepAzureVHD> ./MakeWindowsVHDBootable.ps1 WindowsRS3.vhd

     This script expands the dynamic VHD to 24 GB size and converts it to fixed VHD format before creating a VM ("vmname") and boot into Windows unattendedly
     It also creates an administrator account with the following credential:
     
     - Username: administrator
     - Password: replacepassword1234$
  
3. Prep Windows VHD image for Azure
  
   - Connect to the "vmname" VM from the Hyper-V Manager
   - Enable remote desktop connection for the machine
   - Generalize the image using sysprep tool
      Run "c:\windows\system32\sysprep\sysprep.exe /generalize /oobe /shutdown" to [sysprep] (https://docs.microsoft.com/en-us/azure/virtual-machines/windows/classic/createupload-vhd) a VHD  
      
   - You can delete the VM("vmname") from the Hyper-V Manager 

      The output image will be named Azure+"WindowsRS3.vhd" in the current directory
   
      If you decide to skip the image generating process from step 1-3, you can get a copy of what I used in  https://soccerlstorage.blob.core.windows.net/rs3container/WindowsServer2016Insider.vhd
   
4. Upload to the Azure

   Install [Azure CLI2.0] (https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest)
   
   Assuming you have an existing Azure subscription, the following information is what I used in my example on Azure CLI 2.0
   - resource group name: soccerl-rs3 
   - storage account name:soccerlstorage
   - storage container name:rs3container 
   - blob name:AzureWindowsRS3.vhd
   - disk name:rs3disk

      - az login
      - az group create --name soccerl-rs3 --location westus2
      - az storage account create --resource-group soccerl-rs3 --location westus2 --name soccerlstorage --kind Storage --sku Standard_LRS
          Get the value of the account-key (key1) from the following for use in the later commands        
      az storage account keys list --resource-group soccerl-rs3 --account-name soccerlstorage
            [{
                "keyName": "key1",
                "permissions": "Full",
                "value": "I/lwrXa582/7ffAJ1XX5noaNDw23Uh3YmXfnI1JR0ivcfHd9pXZ2ktktaq0nAlP8DHy6xdM7vod7gHBOPr9ymw=="
              },
              {
                "keyName": "key2",
                "permissions": "Full",
                "value": "TtupCz96vmfi42a6iTbEl8nwsN3o8thS3aBnSgCBkYNchJ+OFrHsTsVE1loeCggcSdRhPdEBMh1bAU+5GXOtHw=="
              }
            ]
      
      - az storage container create -n rs3container --account-name soccerlstorage --account-key "I/lwrXa582/7ffAJ1XX5noaNDw23Uh3YmXfnI1JR0ivcfHd9pXZ2ktktaq0nAlP8DHy6xdM7vod7gHBOPr9ymw=="

      - az storage blob upload --account-name soccerlstorage --account-key "I/lwrXa582/7ffAJ1XX5noaNDw23Uh3YmXfnI1JR0ivcfHd9pXZ2ktktaq0nAlP8DHy6xdM7vod7gHBOPr9ymw==" --container-name rs3container --type page --file ./AzureWindowsRS3.vhd --name AzureWindowsRS3.vhd

      - az storage blob url    --account-name soccerlstorage --account-key "I/lwrXa582/7ffAJ1XX5noaNDw23Uh3YmXfnI1JR0ivcfHd9pXZ2ktktaq0nAlP8DHy6xdM7vod7gHBOPr9ymw==" --container-name rs3container --name AzureWindowsRS3.vhd

      - az disk create --resource-group soccerl-rs3 --name rs3disk --source "https://soccerlstorage.blob.core.windows.net/rs3container/AzureWindowsRS3.vhd"

      - az vm create --resource-group soccerl-rs3  --location westus2 --name wrs3vm --os-type windows --attach-os-disk rs3disk

After the the VM is successfully created, you would need to wait a few minutes for the Windows to fully boot before you could 
successfully remote-desktop to it (eg  mstsc.exe /v:52.219.2.2 )
