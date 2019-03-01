# Get the .csv with the settings
$vmlist=Import-CSV C:\reboot.csv

# Connect to vcenter server with locally stored admin credentials
Connect-VIServer -Server aspvc1 -Protocol https -Credential $cred 

# assign the settings from the .csv to variables loop through all of the rows in the file
foreach ($item in $vmlist) 

{
$VM = $item.VM
$domain = $item.domain

$ScriptText = "restart-computer -Force"

Invoke-VMScript -VM $VM -ScriptText $ScriptText -GuestUser administrator@$domain -GuestPassword xxxxxxxxxx
}
