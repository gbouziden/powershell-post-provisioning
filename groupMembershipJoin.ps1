# This uses a default gateway to apply group membership to teams
# Switch's can be added to expand to more teams and cases can be
# added to run more provisioning steps

# Use a password manager API call here instead. You shouldn't store passwords in scripts
$username = "username"
$password = "password"
$securePassword = ConvertTo-SecureString $password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential ($username, $securePassword)
$computerName = $env:COMPUTERNAME
get-windowsfeature | where name -like RSAT-AD-PowerShell | Install-WindowsFeature

# Function to handle common tasks
function Handle-Computer {
    param (
        [string]$computerName,
        [pscredential]$credential
    )

    # Check if the computer object exists in AD
    $adComputer = New-PSSession -ComputerName $computerName -Credential $credential; Get-ADComputer -Identity $computerName -ErrorAction SilentlyContinue; Remove-PSSession -Session $session

    if ($adComputer) {
        write-host("Computer object exists in AD. Removing it.")
        
        # Enter a remote PowerShell session
        $session = New-PSSession -ComputerName $computerName -Credential $credential
        
        Invoke-Command -Session $session -ScriptBlock {
            param ($credential)
            
            # Remove the computer object from AD
            Remove-ADComputer -Identity $computerName -Credential $credential -Confirm:$false -Force
            
            # Leave the domain
            Remove-Computer -UnjoinDomainCredential $credential -PassThru -Verbose -Force #-Restart
        } -ArgumentList $credential
        
        # Close the remote session
        Remove-PSSession -Session $session
    }
    
    # Add the computer to the domain
    Add-Computer -DomainName domain.youplace.com -OUPath "OU=Path,dc=domain,dc=yourplace,dc=com" -ErrorAction stop -Credential $credential -Force
    Add-LocalGroupMember -Group "Administrators" -Member "DOMAIN\group_name"
    Restart-Computer -Force
}

$defaultGateways = Get-NetRoute |
    where {$_.DestinationPrefix -eq '0.0.0.0/0'} |
    Select-Object -ExpandProperty NextHop

foreach ($defaultGateway in $defaultGateways) {
    switch ($defaultGateway) {
        "10.1.100.1" {
            write-host("The Gateway is 10.1.100.1")
            # Run join command for this tenant
            Handle-Computer -computerName $computerName -credential $credential
        }
        "10.1.101.1" {
            write-host("The Gateway is 10.1.101.1")
            Handle-Computer -computerName $computerName -credential $credential
        }
        default {
            write-host("No gateway matched")
        }
    }
}
