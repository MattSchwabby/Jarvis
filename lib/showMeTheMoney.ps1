<#
.Synopsis
    Returns a revenue details for a given account alias, usage month/year and pricing month/year. Has option to roll up subaccounts.
.DESCRIPTION
    Returns a revenue details for a given account alias, usage month/year and pricing month/year. Has option to roll up subaccounts.
.EXAMPLE
    showMeTheMoney -alias MSCH -usageMonth 06 -usageYear 2016 -pricingMonth 07 -pricingYear 2016 -includeSubs y -email matt.schwabenbauer@ctl.io

#>

function showMeTheMoney
{
    [CmdletBinding()]
    Param
    (
        # Name of the Service
        [Parameter(Mandatory=$true)]
        $alias,
        [Parameter(Mandatory=$true)]
        $usageMonth,
        [Parameter(Mandatory=$true)]
        $usageYear,
        [Parameter(Mandatory=$true)]
        $pricingMonth,
        [Parameter(Mandatory=$true)]
        $pricingYear,
        [Parameter(Mandatory=$true)]
        $includeSubs,
        [Parameter(Mandatory=$true)]
        $email
    )

    # Create a hashtable for the results
    $result = @{}
    $errorcode = $null
    
    # Use try/catch block            
    try
    {

        #check input
        if ($alias.length -gt 4 -or $alias.length -lt 2 -or $alias -eq $null)
        {
            # fail the script
            $errorcode = 1
            stop
        }

        if ($email -eq $null)
        {
            $errorcode = 4
            stop
        }

        <#
        OLD CODE TO VALIDATE THAT USER WAS AUTHORIZED. NO LONGER NEEDED AS OF 11/7/2016.

        #validate e-mail address against allowed users
        $authorizedAddresses = Get-Content "C:\users\Administrator\JK\authorizedAddresses.txt"
        $authorized = $false

        Foreach ($i in $authorizedAddresses)
        {
            if ($email -eq $i)
            {
                $authorized = $true
            }
        }

        if (-not $authorized)
        {
            $errorcode = 3
            stop
        }
        #>

        #log in to APIs

        <#
        $JK1 = Get-Content "C:\users\Administrator\JK\JK1.txt"
        $JK2 = Get-Content "C:\users\Administrator\JK\JK2.txt" | ConvertTo-SecureString


        $V1Credential = New-Object –TypeName System.Management.Automation.PSCredential –ArgumentList $JK1, $JK2
        $DecodePassword1 = $V1Credential.GetNetworkCredential().Password

                $json = @"
        { 'APIKey': '$JK1', 'Password': '$DecodePassword1' }
"@

        #Log in to V1 API
        #$body = @{APIKey = $JK1; Password = $DecodePassword1 } | ConvertTo-Json
        $restreply = Invoke-RestMethod -uri "https://api.ctl.io/REST/Auth/Logon/" -ContentType "Application/JSON" -Body $json -Method Post -SessionVariable session -errorAction Stop
        $global:session = $session 
        #>

        
        $import = "C:\users\administrator\JK\config.json"

        $config = get-content $import -Raw | convertfrom-json

        $JK6 = $config.jk6
        $JK7 = $config.jk7 | ConvertTo-SecureString
        $V2Credential = New-Object –TypeName System.Management.Automation.PSCredential –ArgumentList $JK6, $JK7
        $DecodePassword2 = $V2Credential.GetNetworkCredential().Password

                $json = @"
        { 'username':'$JK6', 'password':'$DecodePassword2' } 
"@
        

        #Log in to V2 API
        #$body = @{username = $JK3; password = $DecodePassword2} | ConvertTo-Json 
        $global:resttoken = Invoke-RestMethod -uri "https://api.ctl.io/v2/authentication/login" -ContentType "Application/JSON" -Body $json -Method Post 
        $HeaderValue = @{Authorization = "Bearer " + $resttoken.bearerToken}
        Write-Host $resttoken.bearerToken
        $AccountAlias = $alias

        $day = get-date -Uformat %d
        $month = get-date -Uformat %b
        $year = get-date -Uformat %Y
        $hours = get-date -Uformat %H
        $mins = get-date -Uformat %M
        $secs = get-date -Uformat %S
        $date = "$month-$day-$year"
        $tempDate = "$month-$day-$year-$hours-$mins-$secs"
        $filename = "C:\users\public\CLC\$alias-RevenueDetails-InvoiceDate-$usagemonth-$usageyear-PricingDate-$pricingmonth-$pricingyear-IncludeSubs-$includesubs-Generated-$date.csv"
        $tempFileName = "C:\Users\Public\CLC\$alias-RevenueDetails-temp-generated-$tempDate.txt"

        $inputPricingMonth = $pricingMonth

        if ($includeSubs -eq "y" -or $includeSubs -eq "Y")
        {
            $pricingMonth = [string]$pricingMonth+"?includeSubAccounts=true"
            $subResponse = "sub accounts are included."
        }
        elseif ($includeSubs -eq "n" -or $includeSubs -eq "N" -or $includeSubs -eq $null)
        {
            $pricingMonth = [string]$pricingMonth+"?includeSubAccounts=false"
            # do nothing
            $subResponse = "sub accounts are not included."
        }

        $URL = "https://api.ctl.io/v2-experimental/internal/accounting/consumptiondetails/$alias/forUsagePeriod/$usageyear/$usagemonth/withPricingFrom/$pricingyear/$pricingmonth"
        Write-Host $URL
        try
        {
            $response = Invoke-RestMethod -Uri $URL -Headers $HeaderValue -Method Get
        }
        catch
        {
            $errorcode = 6
            stop
        }

        $response | out-file $tempFileName
        $csv = import-csv $tempFileName
        $sum = $csv.unitCost | measure-object -sum
        $sum = $sum.sum
        $totalRow = @{Account="Usage Total";UnitCost=$sum}
        $total = new-object Psobject -property $totalRow
        $csv | export-csv $filename -notypeinformation
        $total | export-csv $filename -append -force -notypeinformation



        <#
        # calculate support costs
        # you will need to add logic to detect support level and calculate this cost thusly
        $supportcosts = [int]$sum * $supportCost
        $supportrow = @{Account="Support Costs";UnitCost=$supportcosts}
        $support = new-object Psobject -property $supportrow
        $support | export-csv $filename -append -force -notypeinformation

        $finalTotal = [int]$sum + [int]$supportcosts
        $finalRow = @{Account="Total Bill";UnitCost=$finalTotal}
        $final = new-object Psobject -property $finalRow
        $final | export-csv $filename -append -force -notypeinformation
        #>
        try
        {
           #email the spreadsheet
           $User = 'platform-team@ctl.io'
            $SmtpServer = "smtp.dynect.net"
            $EmailFrom = "CenturyLink Cloud revenue details for $alias Jarvis <jarvis@ctl.io>"
            #$User = "MSCH1-relay@t3mx.com"
            #$SmtpServer = "relay.t3mx.com"
            #$EmailFrom = "CenturyLink Cloud revenue details for $alias <MSCH1-relay@t3mx.com>"
            $EmailTo = "<$email>"
            $PWord = loginCLCSMTP

            $Credential = New-Object –TypeName System.Management.Automation.PSCredential –ArgumentList $User, $PWord

            $EmailBody = "Attached is a CenturyLink Cloud revenue report for $alias with usage data from $usagemonth $usageyear and pricing data from $inputPricingMonth $pricingyear, $subresponse"

            Send-MailMessage -To $EmailTo -From $EmailFrom -Subject "CenturyLink Cloud Revenue Report for the sub account $alias" -Body $EmailBody -SmtpServer $SmtpServer -Port 25 -Credential $Credential -Attachments $filename
        }
        catch
        {
            $errorcode = 5
            stop
        }
        # Create a string for sending back to slack. * and ` are used to make the output look nice in Slack. Details: http://bit.ly/MHSlackFormat
        $result.output = "Revenue details for account Alias: *$($alias)* with usage from $usagemonth $usageyear and pricing from $inputPricingMonth $pricingyear have been sent to the e-mail address *$($email)*, $subresponse"
      
        # Set a successful result
        $result.success = $true
    }
    
    catch
    {
        if ($errorcode -eq 1)
        {
            $result.output = "You entered an account alias that was either too long or too short."
        }
        elseif ($errorcode -eq 2)
        {
            $result.output = "You did not specify whether or not to include sub accounts."
        }
        elseif ($errorcode -eq 3)
        {
            $result.output = 'You did not enter an authorized e-mail address. To request access, enter the command "@smtm authorize <email>" and your request will be reviewed. You will receieve an e-mail when access is granted.'
        }
        elseif ($errorcode -eq 4)
        {
            $result.output = "You did not enter an e-mail address."
        }
        elseif ($errorcode -eq 5)
        {
            $result.output = "Unable to send e-mail. Please try again."
        }
        elseif ($errorcode -eq 6)
        {
            $result.output = "Error retrieving data from consumption endpoint."
        }
        else
        {
        $result.output = "Failed to return revenue report for $($alias)."
        }
        
        # Set a failed result
        $result.success = $false
    }
    
   
    # Delete temp files
    dir $filename | Remove-Item -force
    dir $tempFileName | Remove-Item -force

    # Return the result and convert it to json

    return $result | ConvertTo-Json
}