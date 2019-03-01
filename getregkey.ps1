
# Connect to vcenter server with locally stored admin credentials
Connect-VIServer -Server aspvc1 -Protocol https -Credential $cred 

# assign the settings from the .csv to variables loop through all of the rows in the file)
foreach ($item in $vmlist) 

{
$VM = $item.Name
$domain = $item.Domain



$ScriptText = "Get-ItemProperty -Path ""Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU\"""

Invoke-VMScript -VM $VM -ScriptText $ScriptText -GuestUser administrator@$domain -GuestPassword xxxxxxxxxxx

}
