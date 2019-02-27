##############################################################
# DeployASAV.ps1  
# Version: 20150626.1
# Author: Dewayne Doud
# Script to deploy ASAv from Template(s) using a temporary OS
# customization spec created from settings in a .csv file
# Select datastore with most freespace for new vm
# Move deployed VM into client's folder/subfolder
# Start vm 
# 
#
# Creds:
# vcenter login creds stored in $cred session variable
# to store your login type $cred = Get-Credential 
# cred only stored during session, closing powershell removes it
#
# Assumptions:
# folder exsists in vcenter
#
# .csv file called DeployVMServers.csv located in C:\
# check .csv in notepad before running - excel adds extra ,,,,,
# vms are named following naming convention in .csv
# Templates in place and tested
#
# To add:
# check for template 
# create folder in vcenter if it does not exist already
# error handling (always on todo list)
# Get-Module -ListAvailable | Import-Module
##############################################################

# CSV File Syntax and sample - first row needs to be header, all rows after are particular to each vm(s) being created, dbsize in GB and only needed for sql server vms

# template,folder,vmname,adminpassword,productkey,computername,domain,domainusername,domainpassword,timezone,ipaddress,subnet,gateway,dns,portgroup,memsize,cpucount,dbsize
# base_OS_2012_R2,Chico/blerg/Test,blerg_tctx2,xxxxxxxxx,xxxx-xxxx-xxxx-xxxx,blergtctx2,blerg.sungardps.com,administrator@FQDN,xxxxxxxxx,004,172.16.xx.xx,255.255.255.0,172.16.xx.1,172.16.xx.xx,blerg,16,4
# base_OS_2012_R2,Chico/blerg/Test,blerg_tsql1,xxxxxxxxx,xxxx-xxxx-xxxx-xxxx,blergtctx3,blerg.sungardps.com,administrator@FQDN,xxxxxxxxx,004,172.16.xx.xxx,255.255.255.0,172.16.xx.1,172.16.xx.xx,blerg,16,4,120

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

$vmlist=Import-CSV C:\DeployVms\DeployASAv.csv

# Connect to vcenter server with locally stored admin credentials
Connect-VIServer -Server vc1 -Protocol https -Credential $cred 

# assign the settings from the .csv to variables loop through all of the rows in the file)
foreach ($item in $vmlist) 

{

$folder = $item.folder
$vmname = $item.vmname
$portgroup = $item.portgroup

$datastore = Get-Datastore -Name sanxx-xxx-01

# select the datastore with the most freespace
# $datastore = Get-Datastore | sort -Descending FreeSpaceMB

# $datastore = $datastore[0].name 

# $template = Get-Template -Name tpl-ASAv971

#Deploy the VM based on the template
New-VM -Name $vmname -Template $template -ResourcePool Resources -Datastore $datastore -DiskStorageFormat EagerZeroedThick -Confirm:$false

#Move VM to client's folder - need the function to move into subfolders
Get-VM -Name $vmname | move-vm -Destination $(Get-FolderByPath -Path $folder) 

Set-Annotation -Entity $vmname -CustomAttribute "NBUPolicies" -Value vmware-prod-default-daily

#Set the Port Group Network Name 
Get-VM $vmname | Get-NetworkAdapter -Name "Network adapter 3" | Set-NetworkAdapter -Portgroup $portgroup -Confirm:$false

#Remove unused Network Adapters 
Get-VM $vmname | Get-NetworkAdapter -Name "Network adapter 5" | Remove-NetworkAdapter -Confirm:$false

#Remove unused Network Adapters 
Get-VM $vmname | Get-NetworkAdapter -Name "Network adapter 6"  | Remove-NetworkAdapter -Confirm:$false

#Remove unused Network Adapters 
Get-VM $vmname | Get-NetworkAdapter -Name "Network adapter 7" | Remove-NetworkAdapter -Confirm:$false

#Remove unused Network Adapters 
Get-VM $vmname | Get-NetworkAdapter -Name "Network adapter 8" | Remove-NetworkAdapter -Confirm:$false

#Remove unused Network Adapters 
Get-VM $vmname | Get-NetworkAdapter -Name "Network adapter 9" | Remove-NetworkAdapter -Confirm:$false

#Remove unused Network Adapters 
Get-VM $vmname | Get-NetworkAdapter -Name "Network adapter 10" | Remove-NetworkAdapter -Confirm:$false

#Set the Network to Start Connected (would not work on same line above - go figure)  
Get-NetworkAdapter -VM $vmname | Set-NetworkAdapter -StartConnected:$true -Confirm:$false

#Start up new VM
#Start-VM $vmname -Confirm:$false

#Set the Network Adpater to be connected (vm must be started first) 
#Get-VM -Name $vmname | Get-NetworkAdapter | Set-NetworkAdapter -Connected:$true -Confirm:$false

}
Disconnect-VIServer -Server vc1 -Confirm:$false

