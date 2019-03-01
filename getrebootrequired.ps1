
# Connect to vcenter server with locally stored admin credentials
Connect-VIServer -Server aspvc1 -Protocol https -Credential $cred 

# assign the settings from the .csv to variables loop through all of the rows in the file)
foreach ($item in $vmlist) 

{
$VM = $item.VM

$domain = $item.domain

$ScriptText = "Get-ItemProperty -Path ""Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired"""

Write-Host $VM

Write-Output $VM | Out-File -Append -FilePath $outfile -Encoding ASCII

Invoke-VMScript -VM $VM -ScriptText $ScriptText -GuestUser Administrator -GuestPassword xxxxxxxxxx | Out-File -Append -FilePath $outfile -Encoding ASCII

}
