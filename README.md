# sysadminscripts
Scripts for system administration of vmware and microsoft infrastructure

deployvm.ps1 will deploy a new vm using settings provided in a .csv file. Uses a template, OS specification, configures NIC, joins vm to domain, sets time sync as required, adds drives as required. Queiries Storage for datastore with most available storage

get2012guests.ps1 will retirived the name of all vm's with guests running Server2012 (or other speficied OS)  and create a .csv  of those vm's that can be used as input to other scripts.

checkforkb.ps1 will check the guest OS of vms input from a .csv for the presence of an installed Microsoft update (KB)

auservicestatus.ps1 will check the guest OS of vms input from a .csv for their Automatic Update Service Status
