
# Get-Module -ListAvailable | Import-Module

# Get the .csv with the settings
$vmlist=Import-CSV C:\2012vm.csv

$outfile="C:\AUservicestatus20150730.txt"

# Connect to vcenter server with locally stored admin credentials 
# to store your login type $cred = Get-Credential at ps prompt

Connect-VIServer -Server vc1 -Protocol https -Credential $cred 

#service to check status of
$service = "wuauserv"

# assign the settings from the .csv to variables loop through all of the rows in the file
 
foreach ($item in $vmlist) 
{
$VM = $item.VM

$domain = $item.domain

#$ScriptText = "Set-Service -Name wuauserv -StartupType Automatic -Status Running ; Get-Service -Name wuauserv"

$ScriptText = "Get-Service -Name $service"

#this writes name to console so operator can see what is going on
Write-Host $VM

#this adds the vm name above the script output
Write-Output $VM | Out-File -Append -FilePath $outfile -Encoding ASCII

Invoke-VMScript -VM $VM -ScriptText $ScriptText -GuestUser administrator@$domain -GuestPassword xxxxxxxxxx | Out-File -Append -FilePath $outfile -Encoding ASCII
}

