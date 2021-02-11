<#
.Synopsis
    Returns a legacy CLC Consumption Report for a given account alias start date, end date, and reseller toggle. It then emails the report to a given e-mail address.
.DESCRIPTION
    Returns a legacy CLC Consumption Report for a given account alias start date, end date, and reseller toggle. It then emails the report to a given e-mail address.
.EXAMPLE
    consumption report <alias> <start date (ex. 2016-10-01)> <end date (ex. 2016-11-01)> <e-mail (ex. Matt.Schwabenbauer@ctl.io)> <reseller toggle (y/n)> <email>
    getConsumptionReport -alias msch -start 2016-10-01 -end 2016-11-01 -reseller y -email Matt.Schwabenbauer@ctl.io
#>
function getConsumptionReport
{
    [CmdletBinding()]
    Param
    (
        # Customer Alias
        [Parameter(Mandatory=$true)]
        $alias,
        [Parameter(Mandatory=$true)]
        $start,
        [Parameter(Mandatory=$true)]
        $end,
        [Parameter(Mandatory=$true)]
        $reseller,
        [Parameter(Mandatory=$true)]
        $email
        
    )

    # set account alias variable to the input
    $AccountAlias = $alias

    # Create a hashtable for the results
    $result = @{}
    $errorcode = $null

    # Use try/catch block            
    try
    {
        #check formatting of input
        $dateCheck = NEW-TIMESPAN -start $start -end $end
        if ($dateCheck.days -gt 3650)
        {
            # fail the script
            $errorcode = 1
            stop
        }

        if ($alias.length -gt 4 -or $alias.length -lt 2 -or $alias -eq $null)
        {
            # fail the script
            $errorcode = 2
            stop
        }

        if ($start.length -gt 10 -or $start.length -lt 10)
        {
            $errorcode = 3
            stop
        }

        if ($end.length -gt 10 -or $end.length -lt 10)
        {
            $errorcode = 4
            stop
        }
        $username = $null

        if ($reseller -eq "y")
        {
            $username = "jarvis.ctlz"
        }
        elseif ($reseller -eq "n")
        {
            $username = "jarvis.ctlx"
        }
        else
        {
            $errorcode = 5
            stop
        }
        if ($email -eq $null)
        {
            # fail the script
            $errorcode = 6
            stop
        }

        #Get password
        $import = "C:\users\administrator\JK\config.json"

        $config = get-content $import -Raw | convertfrom-json

        $JK6 = $config.jk6
        $JK4 = $config.jk4 | ConvertTo-SecureString
        $V2Credential = New-Object –TypeName System.Management.Automation.PSCredential –ArgumentList $JK6, $JK4
        $DecodePassword2 = $V2Credential.GetNetworkCredential().Password


        #login to consumption API
        $body = @{username = $username; password = $DecodePassword2} | ConvertTo-Json 
        $global:resttoken = Invoke-RestMethod -uri "https://api.ctl.io/v2/authentication/login" -ContentType "Application/JSON" -Body $body -Method Post 
        $HeaderValue = @{Authorization = "Bearer " + $resttoken.bearerToken} 

        $genday = Get-Date -Uformat %d
        $genmonth = Get-Date -Uformat %b
        $genyear = Get-Date -Uformat %Y
        $genhour = Get-Date -UFormat %H
        $genmins = Get-Date -Uformat %M
        $gensecs = Get-Date -Uformat %S

        $gendate = "Generated-$genday-$genmonth-$genyear-$genhour-$genmins-$gensecs"

        $filename = "C:\users\Public\CLC\$accountAlias-ConsumptionAPI-$start-to-$end-Generated-$gendate.csv"

        #Have the operation pause for 30 seconds to reduce load on the Consumption API
        Start-Sleep -s 30
        
        <# Get the consumption data #>
        $url = "https://api.ctl.io/v2/accounts/$accountAlias/usage?startDate=$start&endDate=$end"
        $response = Invoke-RestMethod -Uri $url -ContentType "Application/JSON" -Headers $HeaderValue -Method Get

        $thisName = $null
        $thisStorageType = $null
        $thisStorage = $null
        $thisCPU = $null
        $thisRAM = $null
        $thisOS = $null
        $thisOSType = $null
        $server = $null

        $serverList = $response.serverGroups.serverlist

    <# parse the consumption data and export to csv #>
    foreach ($server in $serverList)
    {
        $thisName = $server.name
        $thisStorage = $server.storage.quantity
        $thisStorageType = $server.storage.productcode
        $thisCPU = $server.cpu.quantity
        $thisRAM = $server.memory.quantity
        $thisOS = $server.OS.quantity
        $thisOSType = $server.os.ProductCode
        $thisRow = New-Object PSObject -Property @{ "Server Name" = $thisName; "Storage Hours" = $thisStorage; "Storage Type" = $thisStorageType; "CPU Hours" = $thisCPU; "RAM Hours" = $thisRAM; "OS Hours" = $thisOS; "OS Type" = $thisOSType; "Software Product Code" = $null; "Software Hours" = $null} | Select "Server Name", "Storage Hours", "Storage Type", "CPU Hours", "RAM Hours", "OS Hours", "OS Type", "Software Product Code", "Software Hours"
        $thisRow | export-csv $filename -append -notypeinformation -force -ErrorAction SilentlyContinue
    }

    $breakrow = New-Object PSObject -Property @{ "Server Name" = "Software licensing Costs"; "Software Product Code" = "Software Product Code"; "Software Hours" = "Software Hours"}
    $breakRow | export-csv $filename -append -notypeinformation -force -ErrorAction SilentlyContinue

    $thisName = $null
    $thisCode = $null
    $thisQuantity = $null
    $server = $null

    $software = $response.software
    foreach ($server in $software)
    {
        $thisName = $server.name
        $thisCode = $server.productcode
        $thisQuantity = $server.quantity
        $thisRow = New-Object PSObject -Property @{ "Server Name" = $thisName; "Software Product Code" = $thisCode; "Software Hours" = $thisQuantity} | Select "Server Name", "Software Product Code", "Software Hours"
        $thisRow | export-csv $filename -append -notypeinformation -force -ErrorAction SilentlyContinue
    }


  try
        {
           #email the spreadsheet
            #$User = "a175c1c3db8f444804331808510f6456"
            #$SmtpServer = "in-v3.mailjet.com"
            $User = 'platform-team@ctl.io'
            $SmtpServer = "smtp.dynect.net"
            $PWord = loginCLCSMTP

            $EmailFrom = "CenturyLink Cloud revenue details for $alias <jarvis@ctl.io>"
            $EmailTo = "<$email>"
            
            $Credential = New-Object –TypeName System.Management.Automation.PSCredential –ArgumentList $User, $PWord

            $EmailBody = "Attached is a CenturyLink Cloud revenue report for $alias."

            Send-MailMessage -To $EmailTo -From $EmailFrom -Subject "CenturyLink Cloud Revenue Report for the sub account $alias" -Body $EmailBody -SmtpServer $SmtpServer -Port 25 -Credential $Credential -Attachments $filename
        }
        catch
        {
            $errorcode = 7
            $errorReason = $_
            stop
        }
            
            # Create a string for sending back to slack. * and ` are used to make the output look nice in Slack. Details: http://bit.ly/MHSlackFormat
            $result.output = "Consumption API Report for *$($AccountAlias)* between *$($start)* and *$($end)* has been emailed to *$($email)*`. (Reseller: *$($reseller)*)."
        
            # Set a successful result
            $result.success = $true
    } #end try
    catch
    {
        if ($errorcode -eq 1)
        {
            $result.output = "The dates you specified are greater than 10 years."
        }
        elseif ($errorcode -eq 2)
        {
            $result.output = "You entered an account alias that was either too long or too short."
        }
        elseif ($errorcode -eq 3)
        {
            $result.output = "Incorrect start date."
        }
        elseif ($errorcode -eq 4)
        {
            $result.output = "Incorrect end date."
        }
        elseif ($errorcode -eq 5)
        {
        $result.output = "You did not specify Y or N for the reseller input."
        }
        elseif ($errorcode -eq 6)
        {
            $result.output = "You didn't enter an e-mail address."
        }
        elseif ($errorcode -eq 7)
        {
            $result.output = "Failed to email the report: $errorReason"
        }
        else
        {
            $result.output = "Failed to generate a consumption report for $($AccountAlias): $_"
        }
        
        # Set a failed result
        $result.success = $false
    }
    
    # Return the result and conver it to json
    return $result | ConvertTo-Json
}