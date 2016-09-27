<#
.Synopsis
    A user wants to see a Virtual Machine inventory for a given CenturyLink Cloud parent account alias.
.Description
    Returns the CLC API V1 get all servers for account hierarchy call and filters IPs, OSes and presents it in a .csv format.
.Author
    Matt Schwabenbauer
    Matt.Schwabenbauer@ctl.io
.Example
    getInventory -alias MSCH -email Matt.Schwabenbauer@ctl.io
#>
function getInventory
{
    [CmdletBinding()]
    Param
    (
        # Customer Alias
        [Parameter(Mandatory=$true)]
        $alias,
        [Parameter(Mandatory=$true)]
        $email
    )

    # Create a hashtable for the results
    $result = @{}
    $errorcode = $null
    
    # Use try/catch block            
    try
    {
        #check user input
        if ($alias.length -gt 4 -or $alias.length -lt 2 -or $alias -eq $null)
        {
            # fail the script
            $errorcode = 2
            stop
        }
        if ($email -eq $null)
        {
            # fail the script
            $errorcode = 6
            stop
        }
        $data = @()
        $allServers = @()
        $theseServers = @()
        $export = @()

        # Log in to APIs

        #API V1

        $global:session = loginCLCAPIV1

        #API V2

        $HeaderValue = loginCLCAPIV2

        $AccountAlias = $alias
        $DCURL = "https://api.ctl.io/v2/datacenters/$alias"
        $datacenterList = Invoke-RestMethod -Uri $DCURL -ContentType "Application/JSON" -Headers $HeaderValue -Method Get
        $datacenterList = $datacenterList.id
        $date = Get-Date -Format Y
        $filename = "g:\CustomerServerData\$AccountAlias-AllServers-$date.csv"

        Foreach ($i in $datacenterList)
        {
            $JSON = @{AccountAlias = $AccountAlias; Location = $i} | ConvertTo-Json 
            $data = Invoke-RestMethod -uri "https://api.ctl.io/REST/Server/GetAllServersForAccountHierarchy/" -ContentType "Application/JSON" -Method Post -WebSession $session -Body $JSON -errorAction Stop
            $allServers += $data.AccountServers
        }

        if ($allservers)
        {
            $allAliases = $allServers.AccountAlias
            $allAliases = $allAliases | Select -Unique
        }
        else
        {
            $allAliases = $alias
        }

        Foreach ($i in $allAliases)
        {
            Foreach ($j in $datacenterList)
            {
                $JSON = @{AccountAlias = $i; Location = $j} | ConvertTo-Json 
                $data = Invoke-RestMethod -uri "https://api.ctl.io/REST/Server/GetAllServers" -ContentType "Application/JSON" -Method Post -WebSession $session -Body $JSON -errorAction Stop
                if ($data.Success -eq $true)
                {
                    $theseServers = $data.servers
                    Foreach ($k in $theseServers)
                    {
                        $IPAddresses = $k.IPAddresses
                        $IPCount = $IPAddresses.count
                        $thisname = $k.Name
                        $thisDescript = $k.Description
                        $thisLoc = $k.Location
                        $thisCPU = $k.CPU
                        $thisRAM = $k.MemoryGB
                        $thisDisk = $k.TotalDiskSpaceGB
                        $thisDiskCount = $k.DiskCount
                        $thisOS = $k.OperatingSystem
                        #filter Operating Systems
                        if ($thisOS -eq 1)
                        {
                            $thisOS = "Third Party Virtual Appliance"
                        }
                        if ($thisOS -eq 2)
                        {
                            $thisOS = "Windows 2003 R2 Standard 32-bit"
                        }
                        if ($thisOS -eq 3)
                        {
                            $thisOS = "Windows 2003 R2 Standard 64-bit"
                        }
                        if ($thisOS -eq 4)
                        {
                            $thisOS = "Windows 2008 32-bit"
                        }
                        if ($thisOS -eq 5)
                        {
                            $thisOS = "Windows 2008 R2 Standard 64-bit"
                        }
                        if ($thisOS -eq 6)
                        {
                            $thisOS = "Cent OS - 64 bit"
                        }
                        if ($thisOS -eq 7)
                        {
                            $thisOS = "Cent OS - 64 bit"
                        }
                        if ($thisOS -eq 8)
                        {
                            $thisOS = "Windows XP 32-bit"
                        }
                        if ($thisOS -eq 9)
                        {
                            $thisOS = "Windows Vista 32-bit"
                        }
                        if ($thisOS -eq 10)
                        {
                            $thisOS = "Windows Vista 64-bit"
                        }   
                        if ($thisOS -eq 11)
                        {
                            $thisOS = "Windows 7 32-bit"
                        }   
                        if ($thisOS -eq 12)
                        {
                            $thisOS = "Windows 7 64-bit"
                        }   
                        if ($thisOS -eq 13)
                        {
                            $thisOS = "FreeBSD 32-bit"
                        }   
                        if ($thisOS -eq 14)
                        {
                            $thisOS = "FreeBSD 64-bit"
                        }                                     
                        if ($thisOS -eq 15)
                        {
                            $thisOS = "Windows 2003 R2 Enterprise 32-bit"
                        }
                        if ($thisOS -eq 16)
                        {
                            $thisOS = "Windows 2003 R2 Enterprise 64-bit"
                        }
                        if ($thisOS -eq 17)
                        {
                            $thisOS = "Windows 2008 Enterprise 32-bit"
                        }                
                        if ($thisOS -eq 18)
                        {
                            $thisOS = "Windows 2008 R2 Enterprise 64-bit"
                        }
                        if ($thisOS -eq 19)
                        {
                            $thisOS = "Ubuntu 32-bit"
                        }
                        if ($thisOS -eq 20)
                        {
                            $thisOS = "Ubuntu - 64 bit"
                        }
                        if ($thisOS -eq 21)
                        {
                            $thisOS = " Debian 64-bit"
                        }  
                        if ($thisOS -eq 22)
                        {
                            $thisOS = "RedHat Enterprise Linux 64-bit"
                        }
                        if ($thisOS -eq 23)
                        {
                            $thisOS = "Windows 8 64-bit"
                        }
                        if ($thisOS -eq 24)
                        {
                            $thisOS = "Windows 2012 64-bit"
                        }
                        if ($thisOS -eq 25)
                        {
                            $thisOS = "RedHat Enterprise Linux 5 64-bit"
                        }
                        if ($thisOS -eq 26)
                        {
                            $thisOS = "Windows 2008 R2 Datacenter Edition 64-bit"
                        }
                        if ($thisOS -eq 27)
                        {
                            $thisOS = "Windows 2012 Datacenter Edition 64-bit"
                        }
                        if ($thisOS -eq 28)
                        {
                            $thisOS = "Windows 2012 R2 Datacenter Edition 64-bit"
                        }
                        if ($thisOS -eq 29)
                        {
                            $thisOS = "Ubuntu 10 32-bit"
                        }
                        if ($thisOS -eq 30)
                        {
                            $thisOS = "Ubuntu 10 64-bit"
                        }
                        if ($thisOS -eq 31)
                        {
                            $thisOS = "Ubuntu 12 64-bit"
                        }
                        if ($thisOS -eq 32)
                        {
                            $thisOS = "CentOS 5 32-bit"
                        }
                        if ($thisOS -eq 33)
                        {
                            $thisOS = "CentOS 5 64-bit"
                        }
                        if ($thisOS -eq 34)
                        {
                            $thisOS = "CentOS 6 32-bit"
                        }
                        if ($thisOS -eq 35)
                        {
                            $thisOS = "CentOS 6 64-bit"
                        }
                        if ($thisOS -eq 36)
                        {
                            $thisOS = "Debian 6 64-bit"
                        }
                        if ($thisOS -eq 37)
                        {
                            $thisOS = "Debian 7 64-bit"
                        }
                        if ($thisOS -eq 38)
                        {
                            $thisOS = "RedHat Enterprise Linux 6 64-bit"
                        }
                        if ($thisOS -eq 39)
                        {
                            $thisOS = "CoreOS"
                        }
                        if ($thisOS -eq 40)
                        {
                            $thisOS = "PXE Boot"
                        }
                        if ($thisOS -eq 41)
                        {
                            $thisOS = "Ubuntu 14 64-bit"
                        }
                        if ($thisOS -eq 42)
                        {
                            $thisOS = "RedHat 7 64-Bit"
                        }
                        if ($thisOS -eq 43)
                        {
                            $thisOS = "Windows 2008 R2 Standard 64-Bit"
                        }
                        if ($thisOS -eq 44)
                        {
                            $thisOS = "Windows 2008 R2 Enterprise 64-Bit"
                        }
                        if ($thisOS -eq 45)
                        {
                            $thisOS = "Windows 2008 R2 Datacenter 64-Bit"
                        }
                        if ($thisOS -eq 46)
                        {
                            $thisOS = "Windows 2012 R2 Standard 64-bit"
                        }
                        if ($thisOS -eq 47)
                        {
                            $thisOS = "CentOS 7"
                        }
                        $thisDNS = $k.DnsName
                        $thisStatus = $k.Status
                        $thisPower = $k.PowerState
                        $thisMaint = $k.InMaintenanceMode
                        $thisType = $k.ServerType
                        #filter server type
                        if ($thisType -eq 1)
                        {
                            $thisType = "Standard"
                        }
                        if ($thisType -eq 2)
                        {
                            $thisType = "Enterprise"
                        }
                        $thisLevel = $k.ServiceLevel
                        #filter server type
                        if ($thisLevel -eq 1)
                        {
                            $thisLevel = "Premium"
                        }
                        if ($thisLevel -eq 2)
                        {
                            $thisLevel = "Standard"
                        }
                        $thisHyper = $k.IsHyperscale
                        $thisTemplate = $k.IsTemplate
                        $thisDate = $k.DateModified
                        $thisModified = $k.ModifiedBy
                        $thisIP = $IPAddresses[0].Address
                        $thisIPType = $IPAddresses[0].AddressType
                        #filter IP Address Types
                        if ($thisIPType -eq "MIP")
                        {
                            $thisIPType = "Public IP"
                        }
                        if ($thisIPType -eq "RIP")
                        {
                            $thisIPType = "Internal IP"
                        }
                        if ($thisIPType -eq "VIP")
                        {
                            $thisIPType = "Load Balanced Public IP"
                        }
                        $thisRow = New-Object PSObject -Property @{ "Server Name" = $thisname; "Description" = $thisdescript; "Parent Account Alias" = $i; "Location" = $thisLoc; "CPU" = $thisCPU; "RAM" = $thisRAM; "Total Disk Space GB" = $thisDisk; "Disk Count" = $thisdiskcount; "Operating System" = $thisOS; "DNS" = $thisDNS; "IP Address" = $thisIP; "IP Address Type" = $thisIPType; "Status" = $thisStatus; "Power State" = $thispower; "In Maintenance Mode" = $thisMaint; "Server Type" = $thisType; "Storage/Backup Level" = $thislevel; "Is HyperScale" = $thisHyper; "Is Template" = $thisTemplate; "Modified Date" = $thisDate; "Modified By" = $thisModified} | select "Server Name", "Description", "Parent Account Alias", "Location", "CPU", "RAM", "Total Disk Space GB", "Disk Count", "Operating System", "IP Address", "IP Address Type", "DNS", "Status", "Power State", "In Maintenance Mode", "Server Type", "Storage/Backup Level", "Is Template", "Is Hyperscale", "Modified By", "Modified Date"
                        $export += $thisrow
                        $count = 1
                        if ($IPCount -gt 1)
                        {
                            $thisIP = $IPAddresses[$count].Address
                            $thisIPType = $IPAddresses[$count].AddressType 
                        if ($thisIPType -eq "MIP")
                        {
                            $thisIPType = "Public IP"
                        }
                        if ($thisIPType -eq "RIP")
                        {
                            $thisIPType = "Internal IP"
                        }
                        if ($thisIPType -eq "VIP")
                        {
                            $thisIPType = "Load Balanced Public IP"
                        }                 
                            $thisRow = New-Object PSObject -Property @{ "IP Address" = $thisIP; "IP Address Type" = $thisIPType }
                            $export += $thisrow
                            $count = $count+1
                        }
                    }
                }# end if
            } # end foreach
        } # end for each
        $export | export-csv $filename -NoTypeInformation

        $restreply = Invoke-RestMethod -uri "https://api.ctl.io/REST/Auth/Logout/" -ContentType "Application/JSON" -Method Post -SessionVariable session -errorAction Stop
        $global:session = $session

        #email the spreadsheet
        $User = "MSCH1-relay@t3mx.com"
        $SmtpServer = "relay.t3mx.com"
        $EmailFrom = "CenturyLink Cloud server inventory for $alias <MSCH1-relay@t3mx.com>"
        $EmailTo = "<$email>"
        $PWord = loginCLCSMTP
        $Credential = New-Object –TypeName System.Management.Automation.PSCredential –ArgumentList $User, $PWord

        $EmailBody = "Attached is a CenturyLink Cloud server inventory for $alias."

        Send-MailMessage -To $EmailTo -From $EmailFrom -Subject "CenturyLink Cloud Server Inventory Report for $alias" -Body $EmailBody -SmtpServer $SmtpServer -Port 25 -Credential $Credential -Attachments $filename

        # Create a string for sending back to slack. * and ` are used to make the output look nice in Slack. Details: http://bit.ly/MHSlackFormat
        $result.output = "The server inventory report for *$($alias)* has been emailed to *$($email)*`."
        
        # Set a successful result
        $result.success = $true
    }
    catch
    {
        if ($errorcode -eq 2)
        {
            $result.output = "You entered an account alias that was either too long or too short. How do you even sleep at night?"
        }
        elseif ($errorcode -eq 6)
        {
            $result.output = "Whoops! You didn't enter an e-mail address."
        }
        else
        {
            $result.output = "Failed to return server inventory for $($alias)."
        }
        
        # Set a failed result
        $result.success = $false
    }
    

    dir $filename | Remove-Item -Force
        try
    {
    #increment analytics data
    $thisFunction = "GetInventory"
    $analyticsDir = 'C:\Users\Administrator\Box Sync\Matt\jarvis\analytics\totalCalls.csv'
    $totalCalls = import-csv $analyticsDir
    $increment = $totalCalls | select-object | Where-Object {$_.call -eq $thisFunction}
    $increase = [int]$increment.count + 1
    $thisrow = New-object System.Object
    $thisrow | Add-Member -MemberType NoteProperty -name "count" -value $increase
    $thisrow | Add-Member -MemberType NoteProperty -name "call" -value $thisFunction
    $filter = $totalCalls | select-object | where-object {$_.call -ne $thisFunction}
    $filter += $thisrow
    $filter | export-csv $analyticsDir -NoTypeInformation
    }
    catch
    {
    }
        # Return the result and conver it to json
    return $result | ConvertTo-Json
}