$IPAddress = "127.0.0.1"
$Port = "80"
$OUPath = "OU=Test,DC=Lab,DC=Local"
$DomainName = "IKTLekestua.no"
$Website = ($DomainName + "/")
$HomeDrive = "C:\Shares\test$"
$Domain = "Test.local"
$appPoolName = "Elever" 

Import-Module WebAdministration, ActiveDirectory, DnsServer

Set-Location IIS:\

    if(!(test-path IIS:\AppPools\$appPoolName)){
        Write-Host "...Creating AppPool: $appPoolName" # Skriver hvilken AppPool som blir laget
        New-Item IIS:\AppPools\$appPoolName -Verbose:$false -ErrorAction SilentlyContinue| Out-Null # Lager App pool hvis den ikke eksisterer
}


$TestSite = get-website -Name $DomainName

    if($TestSite -eq $null){
      New-Item iis:\Sites\$Website -bindings @{protocol="http";bindingInformation="*:80:$Website"} -physicalPath $HomeDrive
      New-WebBinding -Name $Website -IPAddress $IPAddress
      Remove-WebBinding -Name $Website -HostHeader $Website
}


$Users = Get-ADUser -SearchBase $OUPath -Filter * -Property DisplayName,DistinguishedName

ForEach ($User in $Users) {
    $WebsiteName = ( $Website + $User.DisplayName)
    $FolderName = $User.DisplayName
    $homeDir = $User.SamAccountName
    $NewFolderPath = ($HomeDrive + "\" + $FolderName)

# Folder creation
    if(!(Test-Path $NewFolderPath)){ 
        $Newfolder = New-Item -Path $NewFolderPath -ItemType Directory -ErrorAction Stop

        $Rights = [System.Security.AccessControl.FileSystemRights]"FullControl,Modify,ReadAndExecute,ListDirectory,Read,Write"
        $InheritanceFlag = @([System.Security.AccessControl.InheritanceFlags]::ContainerInherit,[System.Security.AccessControl.InheritanceFlags]::ObjectInherit)
        $PropagationFlag = [System.Security.AccessControl.PropagationFlags]::None
        $objType =[System.Security.AccessControl.AccessControlType]::Allow

        $objUser = New-Object System.Security.Principal.NTAccount "$Domain\$homeDir"
        $objACE = New-Object System.Security.AccessControl.FileSystemAccessRule `
                ($objUser, $Rights, $InheritanceFlag, $PropagationFlag, $objType)
        $ACL = Get-Acl -Path $NewFolder
        $ACL.AddAccessRule($objACE)
        
        Set-ADuser -Identity $homeDir -HomeDrive "$HomeDrive" -HomeDirectory "\\server\share\$homeDir"
    }

}

Get-Website $Website | Start-Website
Clear-DnsClientCache
