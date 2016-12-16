<#
.Synopsis
    A user wants to see a two week view of the compute usage, storage usage, number of VMs, and bandwidth for a given account alias.
.Description
    Rolls up the group monitoring statistics API V2 call to a parent account alias and presents it across multiple CSV files.
.Author
    Matt Schwabenbauer
    Matt.Schwabenbauer@ctl.io
.Example
    getTwoWeekReport -alias MSCH -email Matt.Schwabenbauer@ctl.io
#>
function getTwoWeekReport
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


        # Log in to APIs

        #API V1

        $global:session = loginCLCAPIV1

        #API V2

        $HeaderValue = loginCLCAPIV2
        
        #session variables

        $AccountAlias = $alias

        # Generate a very specific date and time for final exported file's filename

        $genday = Get-Date -Uformat %d
        $genmonth = Get-Date -Uformat %b
        $genyear = Get-Date -Uformat %Y
        $genhour = Get-Date -UFormat %H
        $genmins = Get-Date -Uformat %M
        $gensecs = Get-Date -Uformat %S
        $gendate = "Generated-$genday-$genmonth-$genyear-$genhour-$genmins-$gensecs"

        
        # Create directory for temp file
        New-Item -ItemType Directory -Force -Path c:\Users\Public\Jarvis\Temp | Out-Null

        # Create Directory variable

        $dir = "c:\users\Public\Jarvis\"

        $filename = "$dir\$accountAlias-TwoWeek-ServerMetrics-generated-$gendate.csv"

        #Create a file name for the temp file that will hold the group names

        $groupfilename = "$dir\$AccountAlias-AllGroups-$gendate.csv"
        $aliasfilename = "$dir\$AccountAlias-AllAliases-$gendate.csv"
        $temp1 = "$dir\$accountalias-temp1-$gendate.csv"
        $temp2 = "$dir\$accountalias-temp2-$gendate.csv"

        # Create variable for data centers

        $DCURL = "https://api.ctl.io/v2/datacenters/$alias"
        $datacenterList = Invoke-RestMethod -Uri $DCURL -ContentType "Application/JSON" -Headers $HeaderValue -Method Get
        $datacenterList = $datacenterList.id

        # Create a bunch of variables to be used in the functions. Null them out in case this script is run twice in a row.

        $val=$null
        $response = $null
        $groups = $null
        $serverNames = $null
        $allrows = @()
        $allmetrics = @()
        $aliases = $null

        #Function to return a list of hardware groups

        function getServers
        {
            $Location = $args[0]
            $JSON = @{AccountAlias = $AccountAlias; Location = $Location} | ConvertTo-Json 
            $response = Invoke-RestMethod -uri "https://api.ctl.io/REST/Server/GetAllServersForAccountHierarchy/" -ContentType "Application/JSON" -Method Post -WebSession $session -Body $JSON 
            $response.AccountServers | Export-Csv $temp2 -Append -ErrorAction SilentlyContinue -NoTypeInformation
        }

        # Run getServers for each data center

        Foreach ($i in $datacenterList)
        {
            getServers($i)
        }

        # Import the temp file with the group names, filter it for just the hardware groups, then export it with a nice, readable and unique file name

        Import-Csv $temp2 | Select AccountAlias -Unique  | Export-Csv $aliasfilename  -NoTypeInformation

        # Import the parsed list of groups to a variable

        $aliases = Import-csv $aliasfilename

        <# Begin main script #>

        <# Get server metrics for past 13 days #>

        $day = 0

        while ($day -gt -13)
        {
        $day--

        # declare date for storing this day's data
        $countDate = ((Get-Date).addDays($day).toUniversalTime()).ToString("yyyy-MM-dd")

        # Declare start and end date for the function that will return the server metrics from the API
        $start = ((get-date).addDays($day).ToUniversalTime()).ToString("yyyy-MM-dd")+"T00:00:01.000z"
        $end = ((get-date).addDays($day).ToUniversalTime()).ToString("yyyy-MM-dd")+"T23:59:59.000Z"

        # Create a variable outside the loop for the day of data you are pulling

        $theserows = @()

        # Foreach loop to get the server metrics data from the API

        Foreach ($alias in $aliases)
        {
            $response = $null
            $thisalias = $alias.AccountAlias
            $temp1 = "$dir\$thisalias-temp1-$gendate-$day.csv"
             Foreach ($i in $datacenterList)
            {
                $JSON = @{AccountAlias = $thisalias; Location = $i} | ConvertTo-Json 
                $response = Invoke-RestMethod -uri "https://api.ctl.io/REST/Server/GetAllServersForAccountHierarchy/" -ContentType "Application/JSON" -Method Post -WebSession $session -Body $JSON 
                $response.AccountServers.Servers | Export-Csv $temp1 -Append -ErrorAction SilentlyContinue -NoTypeInformation
            }
            Import-Csv $temp1 | Select HardwareGroupUUID -Unique  | Export-Csv $groupfilename  -NoTypeInformation
            $groups = Import-csv $groupfilename
        Foreach ($group in $groups)
        {
            $response = $null
            $thisgroup = $group.HardwareGroupUUID

            $url = "https://api.ctl.io/v2/groups/$thisalias/$thisgroup/statistics?type=hourly&start=$start&end=$end&sampleInterval=23:59:58"
            try
            {
                $response = Invoke-RestMethod -Uri $url -ContentType "Application/JSON" -Headers $HeaderValue -Method Get
            }
            catch
            {
            }
            if ($response)
            {

            Foreach ($i in $response)
            {
                $totalstorageusage = $null
                $totalstoragecapacity = $null
                Foreach ($j in $i.stats.guestDiskUsage)
                {
                    $storageCapacity = $j.capacityMB
                    $StorageUsage = $j.consumedMB
                    $totalstorageusage += $storageusage
                    $totalstorageCapacity += $storageCapacity 
                }
   
                $thisrow = New-object system.object
                $thisrow | Add-Member -MemberType NoteProperty -Name "Server Name" -Value $i.name 
                $thisrow | Add-Member -MemberType NoteProperty -Name "Date & Time" -Value $i.stats.timestamp[0]
                $thisrow | Add-Member -MemberType NoteProperty -Name "CPUAmount" -Value $i.stats.cpu[0]
                $thisrow | Add-Member -MemberType NoteProperty -Name "CPUUtil" -Value $i.stats.cpuPercent[0]
                $thisrow | Add-Member -MemberType NoteProperty -Name "MemoryMB" -Value $i.stats.memoryMB[0]
                $thisrow | Add-Member -MemberType NoteProperty -Name "MemoryUtil" -Value $i.stats.memoryPercent[0]
                $thisrow | Add-Member -MemberType NoteProperty -Name "Storage" -Value $totalstorageCapacity
                $thisrow | Add-Member -MemberType NoteProperty -Name "networkReceivedKbps" -Value $i.stats.networkReceivedKbps[0]
                $thisrow | Add-Member -MemberType NoteProperty -Name "networkTransmittedKbps" -Value $i.stats.networkTransmittedKbps[0]
                $thisrow | Add-Member -MemberType NoteProperty -Name "predictedTransmittedMB" -Value (($i.stats.networkTransmittedKbps[0] * 0.0001220703125) * 86400)
                $thisrow | Add-Member -MemberType NoteProperty -Name "predictedReceivedMB" -Value (($i.stats.networkReceivedKbps[0] * 0.0001220703125) * 86400)

          if ($totalstorageusage -eq $null)
          {
              $thisrow | Add-Member -MemberType NoteProperty -Name "StorageUsage" -Value "0"
          }
          else
          {
              $thisrow | Add-Member -MemberType NoteProperty -Name "StorageUsage" -Value $totalstorageusage
          }
              try
              {
                  $storageutilization = (([int]$totalstorageUsage)/($totalStorageCapacity))*100
                  $storageutilization = "{0:N0}" -f $storageutilization
              }
              catch
              {
                $storageUtilization = 0
              }
              $thisrow | Add-Member -MemberType NoteProperty -Name "StorageUtil" -Value $storageutilization
              $allrows += $thisrow
              $theserows += $thisrow
          } # end foreach result
            } # end if result
            else
            { 
            }
        } # end foreach group
        } # end foreach alias

                #Calculate metrics
  
                $allServers = $theserows.Count
                $allCPU = $theserows.CPUAmount | Measure-Object -Sum
                $allCPU = $allCPU.sum
                $allRAM = $theserows.MemoryMB | Measure-Object -Sum
                $allRAM = ($allRAM.sum)/1000
                $allRAM = "{0:N0}" -f $allRAM
                $allStorage = $theserows.Storage | Measure-Object -Sum
                $allStorage = ($allStorage.sum)/1000
                $allRAM = "{0:N0}" -f $allRAM
                $averageCPU = $theserows.CPUutil | Measure-Object -Average
                $averageCPU = $averageCPU.Average
                $averageCPU = "{0:N1}" -f $averageCPU
                $averageRAM = $theserows.MemoryUtil | Measure-Object -Average
                $averageRAM = $averageRAM.Average
                $averageRAM = "{0:N1}" -f $averageRAM
                $averageStorage = $theserows.StorageUtil | Measure-Object -Average
                $averageStorage = $averageStorage.Average
                $averageStorage = "{0:N1}" -f $averageStorage
                $averagenetworkReceivedKbps = $theserows.networkReceivedKbps | Measure-Object -Average
                $averagenetworkReceivedKbps = $averagenetworkReceivedKbps.Average
                $averagenetworkReceivedKbps = "{0:N1}" -f $averagenetworkReceivedKbps
                $averagenetworkTransmittedKbps = $theserows.networkTransmittedKbps | Measure-Object -Average
                $averagenetworkTransmittedKbps = $averagenetworkTransmittedKbps.Average
                $averagenetworkTransmittedKbps = "{0:N1}" -f $averagenetworkTransmittedKbps
                $sumNetworkReceivedKbps = $theserows.networkReceivedKbps | Measure-Object -Sum
                $sumNetworkReceivedKbps = $sumNetworkReceivedKbps.Sum
                $predictedNetworkTransmittedMB = $theserows.predictedTransmittedMB | Measure-Object -Sum
                $predictedNetworkTransmittedMB = $predictedNetworkTransmittedMB.Sum
                $predictedNetworkTransmittedMB = "{0:N1}" -f $predictedNetworkTransmittedMB
                $predictedNetworkReceivedMB = $theserows.predictedReceivedMB | Measure-Object -Sum
                $predictedNetworkReceivedMB = $predictedNetworkReceivedMB.Sum
                $predictedNetworkReceivedMB = "{0:N1}" -f $predictedNetworkReceivedMB

                $thisrow = New-object system.object
                $thisrow | Add-Member -MemberType NoteProperty -Name "Date" -value $countDate
                $thisrow | Add-Member -MemberType NoteProperty -Name "Server Count" -value $allServers
                $thisrow | Add-Member -MemberType NoteProperty -Name "Allocated CPUs" -value $allCPU
                $thisrow | Add-Member -MemberType NoteProperty -Name "CPU Utilization %" -value $averageCPU
                $thisrow | Add-Member -MemberType NoteProperty -Name "Allocated RAM in GB" -value $allRAM
                $thisrow | Add-Member -MemberType NoteProperty -Name "RAM Utilization %" -value $averageRAM
                $thisrow | Add-Member -MemberType NoteProperty -Name "Allocated HD in GB" -value $allStorage
                $thisrow | Add-Member -MemberType NoteProperty -Name "HD Utilization %" -value $averageStorage
                $thisrow | Add-Member -MemberType NoteProperty -Name "Average Bandwidth Received in Kbps" -value $averagenetworkReceivedKbps
                $thisrow | Add-Member -MemberType NoteProperty -Name "Average Bandwidth Transmitted in Kbps" -value $averagenetworkTransmittedKbps
                $thisrow | Add-Member -MemberType NoteProperty -Name "Bandwidth Received in MB" -value $predictedNetworkReceivedMB
                $thisrow | Add-Member -MemberType NoteProperty -Name "Bandwidth Transmitted in MB" -value $predictedNetworkTransmittedMB

                $allMetrics += $thisrow
            } #end 13 day do while

            # Filter high/low utilization servers

            $highCPUUtil = @()
            $highRAMUtil = @()
            $highHDUtil = @()
            $lowCPUUtil = @()
            $lowRAMUtil = @()
            $lowHDUtil = @()

            try
            {
                $highCPUUtil += $allrows | Select-Object | Where-Object {[int]$_.CPUUtil -gt 70}
            }
            catch
            {}
            try
            {
                $highRAMUtil += $allrows | Select-Object | Where-Object {[int]$_.MemoryUtil -gt 70}
            }
            catch
            {}
            try
            {
                $highHDUtil += $allrows | Select-Object | Where-Object {[int]$_.StorageUtil -gt 70}
            }
            catch
            {}

            try
            {
                $lowCPUUtil += $allrows | Select-Object | Where-Object {[int]$_.CPUUtil -lt 25}
            }
            catch
            {}
            try
            {
                $lowRAMUtil += $allrows | Select-Object | Where-Object {[int]$_.MemoryUtil -lt 25}
            }
            catch
            {}
            try
            {
                $lowHDUtil += $allrows | Select-Object | Where-Object {[int]$_.StorageUtil -lt 25}
            }
            catch
            {}

            # Check to see if there aren't any servers with high/ow utilization, and give the user some direction if so

            if (!$highCPUUtil)
            {
                $thisrow = New-object system.object
                $thisrow | Add-Member -MemberType NoteProperty -Name "Server Name" -Value "No servers were identified with CPU utilization over 70%"
                $highCPUUtil = $thisrow
            }

            if (!$highRAMUtil)
            {
                $thisrow = New-object system.object
                $thisrow | Add-Member -MemberType NoteProperty -Name "Server Name" -Value "No servers were identified with RAM utilization over 70%"
                $highRAMUtil = $thisrow
            }

            if (!$highHDUtil)
            {
                $thisrow = New-object system.object
                $thisrow | Add-Member -MemberType NoteProperty -Name "Server Name" -Value "No servers were identified with storage utilization over 70%"
                $highHDUtil = $thisrow
            }

            if (!$lowCPUUtil)
            {
                $thisrow = New-object system.object
                $thisrow | Add-Member -MemberType NoteProperty -Name "Server Name" -Value "No servers were identified with CPU utilization under 25%"
                $highCPUUtil = $thisrow
            }

            if (!$lowRAMUtil)
            {
                $thisrow = New-object system.object
                $thisrow | Add-Member -MemberType NoteProperty -Name "Server Name" -Value "No servers were identified with RAM utilization under 25%"
                $highRAMUtil = $thisrow
            }

            if (!$lowHDUtil)
            {
                $thisrow = New-object system.object
                $thisrow | Add-Member -MemberType NoteProperty -Name "Server Name" -Value "No servers were identified with storage utilization under 25%"
                $highHDUtil = $thisrow
            }

            # export everything to a few CSVs

            $allrows | Select-Object @{Name="Server Name";Expression={$_."Server Name"}}, @{Name="Date & Time";Expression={$_."Date & Time"}}, @{Name="Total CPUs";Expression={$_."CPUAmount"}}, @{Name="CPU Utilization %";Expression={$_."CPUUtil"}}, @{Name="Total Memory in MB";Expression={$_."MemoryMB"}}, @{Name="Memory Utilization %";Expression={$_."MemoryUtil"}}, @{Name="Total Storage in MB";Expression={$_."Storage"}}, @{Name="Total Storage Usage in MB";Expression={$_."StorageUsage"}}, @{Name="Storage Utilization %";Expression={$_."StorageUtil"}}, @{Name="Network Received Kbps";Expression={$_."networkReceivedKBps"}}, @{Name="Network Transmitted Kbps";Expression={$_."networkTransmittedKBps"}}, @{Name="Predicted Bandwidth Received MB";Expression={$_."predictedReceivedMB"}},@{Name="Predicted Bandwidth Transmitted MB";Expression={$_."predictedTransmittedMB"}} | export-csv $filename -NoTypeInformation

            $filename2 = "$dir\$AccountAlias-TwoWeekUtilizationMetrics-$gendate.csv"

            $allMetrics | export-csv $filename2 -NoTypeInformation

            $filename3 = "$dir\$AccountAlias-HighCPU-$gendate.csv"

            $highCPUUtil | Select-Object @{Name="Server Name";Expression={$_."Server Name"}}, @{Name="Date & Time";Expression={$_."Date & Time"}}, @{Name="Total CPUs";Expression={$_."CPUAmount"}}, @{Name="CPU Utilization %";Expression={$_."CPUUtil"}}, @{Name="Total Memory in MB";Expression={$_."MemoryMB"}}, @{Name="Memory Utilization %";Expression={$_."MemoryUtil"}}, @{Name="Total Storage in MB";Expression={$_."Storage"}}, @{Name="Total Storage Usage in MB";Expression={$_."StorageUsage"}}, @{Name="Storage Utilization %";Expression={$_."StorageUtil"}} | export-csv $filename3 -NoTypeInformation

            $filename4 = "$dir\$AccountAlias-HighRAM-$gendate.csv"

            $highRAMUtil | Select-Object @{Name="Server Name";Expression={$_."Server Name"}}, @{Name="Date & Time";Expression={$_."Date & Time"}}, @{Name="Total CPUs";Expression={$_."CPUAmount"}}, @{Name="CPU Utilization %";Expression={$_."CPUUtil"}}, @{Name="Total Memory in MB";Expression={$_."MemoryMB"}}, @{Name="Memory Utilization %";Expression={$_."MemoryUtil"}}, @{Name="Total Storage in MB";Expression={$_."Storage"}}, @{Name="Total Storage Usage in MB";Expression={$_."StorageUsage"}}, @{Name="Storage Utilization %";Expression={$_."StorageUtil"}} | export-csv $filename4 -NoTypeInformation

            $filename5 = "$dir\$AccountAlias-HighHD-$gendate.csv"

            $highHDUtil | Select-Object @{Name="Server Name";Expression={$_."Server Name"}}, @{Name="Date & Time";Expression={$_."Date & Time"}}, @{Name="Total CPUs";Expression={$_."CPUAmount"}}, @{Name="CPU Utilization %";Expression={$_."CPUUtil"}}, @{Name="Total Memory in MB";Expression={$_."MemoryMB"}}, @{Name="Memory Utilization %";Expression={$_."MemoryUtil"}}, @{Name="Total Storage in MB";Expression={$_."Storage"}}, @{Name="Total Storage Usage in MB";Expression={$_."StorageUsage"}}, @{Name="Storage Utilization %";Expression={$_."StorageUtil"}} | export-csv $filename5  -NoTypeInformation

            $filename6 = "$dir\$AccountAlias-LowCPU-$gendate.csv"

            $lowCPUUtil | Select-Object @{Name="Server Name";Expression={$_."Server Name"}}, @{Name="Date & Time";Expression={$_."Date & Time"}}, @{Name="Total CPUs";Expression={$_."CPUAmount"}}, @{Name="CPU Utilization %";Expression={$_."CPUUtil"}}, @{Name="Total Memory in MB";Expression={$_."MemoryMB"}}, @{Name="Memory Utilization %";Expression={$_."MemoryUtil"}}, @{Name="Total Storage in MB";Expression={$_."Storage"}}, @{Name="Total Storage Usage in MB";Expression={$_."StorageUsage"}}, @{Name="Storage Utilization %";Expression={$_."StorageUtil"}} | export-csv $filename6 -NoTypeInformation

            $filename7 = "$dir\$AccountAlias-LowRAM-$gendate.csv"

            $lowRAMUtil | Select-Object @{Name="Server Name";Expression={$_."Server Name"}}, @{Name="Date & Time";Expression={$_."Date & Time"}}, @{Name="Total CPUs";Expression={$_."CPUAmount"}}, @{Name="CPU Utilization %";Expression={$_."CPUUtil"}}, @{Name="Total Memory in MB";Expression={$_."MemoryMB"}}, @{Name="Memory Utilization %";Expression={$_."MemoryUtil"}}, @{Name="Total Storage in MB";Expression={$_."Storage"}}, @{Name="Total Storage Usage in MB";Expression={$_."StorageUsage"}}, @{Name="Storage Utilization %";Expression={$_."StorageUtil"}} | export-csv $filename7 -NoTypeInformation

            $filename8 = "$dir\$AccountAlias-LowHD-$gendate.csv"

            $lowHDUtil | Select-Object @{Name="Server Name";Expression={$_."Server Name"}}, @{Name="Date & Time";Expression={$_."Date & Time"}}, @{Name="Total CPUs";Expression={$_."CPUAmount"}}, @{Name="CPU Utilization %";Expression={$_."CPUUtil"}}, @{Name="Total Memory in MB";Expression={$_."MemoryMB"}}, @{Name="Memory Utilization %";Expression={$_."MemoryUtil"}}, @{Name="Total Storage in MB";Expression={$_."Storage"}}, @{Name="Total Storage Usage in MB";Expression={$_."StorageUsage"}}, @{Name="Storage Utilization %";Expression={$_."StorageUtil"}} | export-csv $filename8 -NoTypeInformation
 
            # log out of v1 API

            $restreply = Invoke-RestMethod -uri "https://api.ctl.io/REST/Auth/Logout/" -ContentType "Application/JSON" -Method Post -SessionVariable session 
            $global:session = $session

            #email the spreadsheet
            $User = 'a175c1c3db8f444804331808510f6456'
            $SmtpServer = "in-v3.mailjet.com"
            $EmailFrom = "Jarvis SMTP Relay - PLEASE DO NOT REPLY <matt.schwabenbauer@ctl.io>"
            $EmailTo = "<$email>"
            $PWord = loginCLCSMTP
            $Credential = New-Object –TypeName System.Management.Automation.PSCredential –ArgumentList $User, $PWord
            
            $attachments =@()

            $attachments += $filename2
            $attachments += $filename3
            $attachments += $filename4
            $attachments += $filename5
            $attachments += $filename6
            $attachments += $filename7
            $attachments += $filename8
            $attachments += $filename

            $EmailBody = "Attached is a CenturyLink Cloud Two Week Utilization Report for $AccountAlias Generated on $genmonth $genday, $genyear.

Summary:
    
    Servers: $($allServers) | CPUs: $($allCPU) Utilization: $($averageCPU)% | RAM: $($allRAM) GB Utilization: $($averageRAM)% | Storage: $($allStorage) GB Utilization: $($averageStorage)%.

        Spreadsheets are as follows:
            - Two Week Utilization Metrics: A 13 day view rolling up each of these metrics for the entire $accountalias account.
            - High CPU: Virtual Machines with average CPU utilization over 70%.
            - Low CPU: Virtual Machines with average CPU utilization under 25%.
            - High RAM: Virtual Machines with average RAM utilization over 70%.
            - Low RAM: Virtual Machines with average RAM utilization under 25%.
            - High HD: Virtual Machines with average storage utilization over 70%.
            - Low HD: Virtual Machines with average storage utilization under 25%.
            - Two Week Server Metrics: A dump of all of the metrics for each of the Virtual Machines in the $accountalias account.

    "

            Send-MailMessage -To $EmailTo -From $EmailFrom -Subject "CenturyLink Cloud Two Week Utilization Report for $AccountAlias" -Body $EmailBody -SmtpServer $SmtpServer -Port 25 -Credential $Credential -Attachments $attachments
            
            $result.output = "Two week server utilization report for *$($AccountAlias)* has been emailed to *$($email)*`. Servers: *$($allServers)* | CPUs: *$($allCPU)* Utilization: *$($averageCPU)%* | RAM: *$($allRAM)* GB Utilization: *$($averageRAM)%* | Storage: *$($allStorage)* GB Utilization: *$($averageStorage)%*."
        
            $result.success = $true
    } #end try
    catch
    {
        if ($errorcode -eq 2)
        {
            $result.output = "You entered an account alias that was either too long or too short. How embarassing."
        }
        else
        {
        $result.output = "Failed to return a utilization report for $($AccountAlias)."
        }
        
        $result.success = $false
    }

    dir $filename | Remove-Item -force
    dir $groupfilename | Remove-Item -force
    dir $aliasfilename | Remove-Item -force
    dir $temp1 | Remove-Item -force
    dir $temp2 | Remove-Item -force
    
    return $result | ConvertTo-Json
}