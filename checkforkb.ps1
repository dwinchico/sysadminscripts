# Get-Module -ListAvailable | Import-Module
# vcenter login creds stored in $cred session variable
# to store your login type $cred = Get-Credential at ps prompt
# replace $pass in Invoke Script with the admin password for all domains
# cred only stored during session, closing powershell removes it
# Get the .csv with the settings
$vmlist=Import-CSV C:\Windows2008VM20170515.csv

# Connect to vcenter server with locally stored admin credentials
Connect-VIServer -Server virtualcenter1 -Protocol https -Credential $cred 

# assign the settings from the .csv to variables loop through all of the rows in the file)
foreach ($item in $vmlist) 

{
$VM = $item.Name
$domain = $item.Domain

$ScriptText = "get-hotfix | out-string -stream | select-string  ""KB4012598"""

Invoke-VMScript -VM $VM -ScriptText $ScriptText -GuestUser administrator@$domain -GuestPassword $pass

}
