# Connect to vcenter server with locally stored admin credentials
# to store your login type $cred = Get-Credential at ps prompt
# Get-Module -ListAvailable | Import-Module

Connect-VIServer -Server aspvc1 -Protocol https -Credential $cred

$outfile="C:\mountedisos20151001.txt"

#this writes name to console so operator can see what is going on
Write-Host $VM

#uncomment to remove .iso from CDDrive
# Get-VM | Get-CDDrive | Where {$_.IsoPath} | Set-CDDrive -NoMedia -Confirm:$false

#get names of vm with mounted iso
Get-VM | Get-CDDrive | select @{N="VM";E="Parent"},IsoPath | where {$_.IsoPath -ne $null} | Out-File -Append -FilePath $outfile -Encoding ASCII
