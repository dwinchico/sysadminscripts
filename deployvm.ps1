##############################################################
# DeployVM.ps1  
# Version: 20150626.1
# Author: Dewayne Doud
# Script to deploy VM(s) from Template(s) using a temporary OS
# customization spec created from settings in a .csv file
# Select datastore with most freespace for new vm
# Move deployed VM into client's folder/subfolder
# Start vm 
# disable time sync to host in vmtools unless a dc
# If a sql server, add four hard drives
# If a job server, add one 10 GB hard drive 
# If a dc add, one 4 GB hard drive
# Mount appropriate install media in CD Drive
#
# Creds:
# vcenter login creds stored in $cred session variable
# to store your login type $cred = Get-Credential 
# cred only stored during session, closing powershell removes it
#
# Assumptions:
# folder exsists in vcenter
# 2012R2, 2008R2, citrix install media paths are correct
# .csv file called DeployVMServers.csv located in C:\
# check .csv in notepad before running - excel adds extra ,,,,,
# vms are named following naming convention in .csv
# Templates in place and tested
#
# to add:
# check for template 
# create folder in vcenter if it does not exsist already
# error handling
# Get-Module -ListAvailable | Import-Module
##############################################################

# CSV File Syntax and sample - first row needs to be header, all rows after are particular to each vm(s) being created, dbsize in GB and only needed for sql server vms

# template,folder,vmname,adminpassword,productkey,computername,domain,domainusername,domainpassword,timezone,ipaddress,subnet,gateway,dns,portgroup,memsize,cpucount,dbsize
# base_OS_2012_R2,datacenterChico/blerg/Test,blerg_tctx2,xxxxxxxxx,xxxx-xxxx-xxxx-xxxx,blergtctx2,blerg.nada.com,administrator@FQDN,xxxxxxxxx,004,172.16.xx.xx,255.255.255.0,172.16.xx.xx,172.xx.xx.xx,blerg,16,4
# base_OS_2012_R2,datacenterChico/blerg/Test,blerg_tsql1,xxxxxxxxx,xxxx-xxxx-xxxx-xxxx,blergtctx3,blerg.nada.com,administrator@FQDN,xxxxxxxxx,004,172.16.xx.xx,255.255.255.0,172.16.xx.xx,172.xx.xx.xx,blerg,16,4,120

#############################################################

# Load PowerCLI Core snapin  
#$psSnapInName = “VMware.VimAutomation.Core”
#if (-not (Get-PSSnapin -Name $psSnapInName -ErrorAction SilentlyContinue))
#{
## Exit if the PowerCLI snapin can’t be loaded
#Add-PSSnapin -Name $psSnapInName -ErrorAction Stop
#}


function Get-FolderByPath{
  #Retrieve folders by giving a path 

  param(
  [CmdletBinding()]
  [parameter(Mandatory = $true)]
  [System.String[]]${Path},
  [char]${Separator} = '/'
  )

  process{
    if((Get-PowerCLIConfiguration).DefaultVIServerMode -eq "Multiple"){
      $vcs = $defaultVIServers
    }
    else{
      $vcs = $defaultVIServers[0]
    }

    foreach($vc in $vcs){
      foreach($strPath in $Path){
        $root = Get-Folder -Name Datacenters -Server $vc
        $strPath.Split($Separator) | %{
          $root = Get-Inventory -Name $_ -Location $root -Server $vc -NoRecursion
          if((Get-Inventory -Location $root -NoRecursion | Select -ExpandProperty Name) -contains "vm"){
            $root = Get-Inventory -Name "vm" -Location $root -Server $vc -NoRecursion
          }
        }
        $root | where {$_ -is
[VMware.VimAutomation.ViCore.Impl.V1.Inventory.FolderImpl]}|%{
          Get-Folder -Name $_.Name -Location $root.Parent -Server $vc
        }
      }
    }
  }
}
 
 


$vmlist=Import-CSV C:\DeployVms\DeployVMServers.csv


#Path to citrix install .iso
$ctxiso="[san0_workspace] XenApp_and_XenDesktop7_6.iso"

#Path to Server 2012R2 install .iso
$2012R2iso="[san0_workspace] SPLA_SW\SW_DVD9_Windows_Svr_Std_and_DataCtr_2012_R2_64Bit_English_-2_Core_MLF_X19-31419.ISO"

#Path to Server 2008R2 install .iso
$2008R2iso="[san0_workspace] SPLA_SW\SW_DVD5_Windows_Svr_DC_EE_SE_Web_2008R2_64-bit_English_X15-59754.ISO"

# Connect to vcenter server with locally stored admin credentials
Connect-VIServer -Server virtalcenter1 -Protocol https -Credential $cred 

# assign the settings from the .csv to variables loop through all of the rows in the file)
foreach ($item in $vmlist) 

{
$template = $item.template
$custspec = $item.custspec
$folder = $item.folder
$vmname = $item.vmname
$adminpassword = $item.adminpassword
$productkey = $item.productkey
$computername = $item.computername
$domain = $item.domain
$domainusername = $item.domainusername
$domainpassword = $item.domainpassword
$timezone = $item.timezone
$ipaddr = $item.ipaddress
$subnet = $item.subnet
$gateway = $item.gateway
$dns = $item.dns
$portgroup = $item.portgroup
$memsize = $item.memsize
$cpucount = $item.cpucount
$dbsize = $item.dbsize

# select the datastore with the most freespace
$datastore = Get-Datastore | sort -Descending FreeSpaceMB

$datastore = $datastore[0].name 


# Create a temp OSCustomization Spec to specify compute name, domain, username/password to join domain, timezone , etc..
New-OSCustomizationSpec -Name tempOSspec -OSType Windows -Type NonPersistent -NamingScheme fixed -NamingPrefix $computername -FullName Administrator -OrgName "SunGard Public Sector" -AdminPassword $adminpassword -AutoLogonCount 2 -LicenseMode PerSeat -ProductKey $productkey -Domain $domain -DomainUsername $domainusername -DomainPassword $domainpassword -TimeZone $timezone -ChangeSid -GuiRunOnce "powershell -file c:\postconfig.ps1" 

# modify the Customization Spec to add Network settings
Get-OSCustomizationSpec -Name tempOSspec | Get-OSCustomizationNicMapping | Set-OSCustomizationNicMapping -IpMode UseStaticIp -IpAddress $ipaddr -SubnetMask $subnet -DefaultGateway $gateway -Dns $dns

#Deploy the VM based on the template with the temp OSCustomization Specification
New-VM -Name $vmname -Template $template -ResourcePool Resources -Datastore $datastore -DiskStorageFormat EagerZeroedThick -OSCustomizationSpec tempOSspec -Confirm:$false

#Set the number of CPUs and MB of RAM
Get-VM -Name $vmname | Set-VM -MemoryGB $memsize -NumCpu $cpucount -Confirm:$false

#Move VM to client's folder - need the function to move into subfolders
Get-vm -Name $vmname | move-vm -Destination $(Get-FolderByPath -Path $folder) 

#Set the Port Group Network Name 
Get-NetworkAdapter $vmname | Set-NetworkAdapter -Portgroup $portgroup -Confirm:$false

#Set the Network to Start Connected (would not work on same line above - go figure)  
Get-NetworkAdapter $vmname | Set-NetworkAdapter -StartConnected:$true -Confirm:$false

#Set the CDDrive to Start Connected
Get-VM -Name $vmname | Get-CDDrive | Set-CDDrive -StartConnected:$true -Confirm:$false

#Remove the temp OS Customization Spec to keep things tidy on Vcenter server
Remove-OSCustomizationSpec tempOSspec -Confirm:$false

#Start up new VM
Start-VM $vmname -Confirm:$false

#Set the Network Adpater to be connected (vm must be started first) 
Get-VM -Name $vmname | Get-NetworkAdapter | Set-NetworkAdapter -Connected:$true -Confirm:$false

#Set the CDDrive to be connected
Get-VM -Name $vmname | Get-CDDrive | Set-CDDrive -Connected:$true -Confirm:$false

#Set vmtools to not sync with host (unless vm is a dc)

    if ($vmname -notlike "*dc*") {
      
    # create the object that encapsulates the settings for reconfiguring the VM 
    $vmConfigSpec = New-Object VMware.Vim.VirtualMachineConfigSpec

    # create the object we will be modifying 
    $vmConfigSpec.Tools = New-Object VMware.Vim.ToolsConfigInfo
     
    # clears the Tools Sync Time With Host checkbox 
    $vmConfigSpec.Tools.syncTimeWithHost = $false 

    # Set to Run Upgrade at next Power Cycle
    # $vmConfigSpec.Tools.ToolsUpgradePolicy = "UpgradeAtPowerCycle"

    # This line commits the change to the virtual machine 
    Get-VM -Name $vmname | Get-View | %{ $_.ReconfigVM($vmConfigSpec)}

    Write-Host $vmname "is not a dc - sync time with host in vmtools is disabled"
    
    }
    else {
    Write-Host $vmname "is a dc - sync time with host in vmtools is enabled"
    }

#sql servers only - create four additional drives for sql install, db, logs, tempdb (order created is important)

    if ($vmname -like "*sql*") {

    New-HardDisk -VM $vmname -CapacityGB 5 -StorageFormat EagerZeroedThick  

    New-HardDisk -VM $vmname -CapacityGB 20 -StorageFormat EagerZeroedThick 

    New-HardDisk -VM $vmname -CapacityGB 20 -StorageFormat EagerZeroedThick
    
    New-HardDisk -VM $vmname -CapacityGB $dbsize -StorageFormat EagerZeroedThick 
    
    Write-Host $vmname "is a sql server - four additional hard drives have been added"
    }

    else {
    }

#If it is a job server - create an additonal 10 GB drive

    if ($vmname -like "*job*") {
    New-HardDisk -VM $vmname -CapacityGB 10 -StorageFormat EagerZeroedThick 
 
    Write-Host $vmname "is a job server - one additional 10 GB hard drive has been added"
    }
    else {
    }

#If it is a DC - create an additonal 4 GB drive

    if ($vmname -like "*dc*") {
    New-HardDisk -VM $vmname -CapacityGB 4 -StorageFormat EagerZeroedThick 
 
    Write-Host $vmname "is a dc - one additional 4 GB hard drive has been added"
    }
    else {
    }


# mount 2012R2 Server install media into CDROM drive unless ctx server then mount Citrix install media if template is not 2012 then mount 2008 iso
  if ($template -like "*2012*"){

    if ($vmname -like "*ctx*") {
    Get-VM -Name $vmname | Get-CDDrive | Set-CDDrive -IsoPath $ctxiso -Connected:$true -Confirm:$false 
    }
    else {
    Get-VM -Name $vmname | Get-CDDrive | Set-CDDrive -IsoPath $2012R2iso -Connected:$true -Confirm:$false 
    }

  }
  else {
  Get-VM -Name $vmname | Get-CDDrive | Set-CDDrive -IsoPath $2008R2iso -Connected:$true -Confirm:$false 
  }


}


Disconnect-VIServer -Server virtualcenter1 -Confirm:$false

