<#
.Synopsis
    Returns a revenue details for a given account alias, invoice month/year then e-mails the report to a given e-mail address.
.DESCRIPTION
    Returns a revenue details for a given account alias, invoice month/year then e-mails the report to a given e-mail address.
.EXAMPLE
    showMeTheMoneyv2 -alias MSCH -invoiceMonth 06 -invoiceYear 2016 -email matt.schwabenbauer@ctl.io

#>

function showMeTheMoneyv2
{
    [CmdletBinding()]
    Param
    (
        # Name of the Service
        [Parameter(Mandatory=$true)]
        $alias,
        [Parameter(Mandatory=$true)]
        $invoiceMonth,
        [Parameter(Mandatory=$true)]
        $invoiceYear,
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

        $AccountAlias = $alias

        $day = get-date -Uformat %d
        $month = get-date -Uformat %b
        $year = get-date -Uformat %Y
        $hours = get-date -Uformat %H
        $mins = get-date -Uformat %M
        $secs = get-date -Uformat %S
        $date = "$month-$day-$year"
        $tempDate = "$month-$day-$year-$hours-$mins-$secs"
        $filename = "C:\users\public\clc\$alias-RevenueDetails-InvoiceDate-$invoiceMonth-$invoiceYear-Generated-$date.csv"
        $tempFileName = "C:\Users\Public\CLC\$alias-RevenueDetails-temp-generated-$tempDate.txt"

        try
        {
            #$response = Invoke-RestMethod -Uri $URL -Headers $HeaderValue -Method Get
            $query =
            "SELECT * FROM consumption WHERE root_alias = '$($alias)' AND invoice_date = '$($invoiceYear)-$($invoiceMonth)-01';"

                    
            $import = "C:\users\administrator\JK\config.json"

            $config = get-content $import -Raw | convertfrom-json

            $JK6 = $config.jk6
            $JK8 = $config.jk8 | ConvertTo-SecureString
            $V2Credential = New-Object –TypeName System.Management.Automation.PSCredential –ArgumentList $JK6, $JK8
            $DecodePassword2 = $V2Credential.GetNetworkCredential().Password
 

            # SQL Connection Info
            $MySQLAdminUserName = "consumption"
            $MySQLAdminPassword = $DecodePassword2
            $MySQLDatabase = "consumption"
            $MySQLHost = "consumption.uc1.rdbs.ctl.io"
            $ConnectionString = "server=" + $MySQLHost + ";port=49357;uid=" + $MySQLAdminUserName + ";pwd=" + $MySQLAdminPassword + ";database="+$MySQLDatabase
            [void][System.Reflection.Assembly]::LoadWithPartialName("MySql.Data")
            $Connection = New-Object MySql.Data.MySqlClient.MySqlConnection
            $Connection.ConnectionString = $ConnectionString
            $Connection.Open()
            $Command = New-Object MySql.Data.MySqlClient.MySqlCommand($Query, $Connection)
            $DataAdapter = New-Object MySql.Data.MySqlClient.MySqlDataAdapter($Command)
            $DataSet = New-Object System.Data.DataSet
            $RecordCount = $dataAdapter.Fill($dataSet, "data")
        }
        catch
        {
            $errorcode = 6
            stop
        }
        finally
        {
             $Connection.Close()
        }

        try
        {
            $tables = $dataset.tables
            foreach($table in $tables)
            {
                $table | export-csv $filename -notypeinformation
            }
            $sum = $tables.cost | measure-object -sum
            $sum = $sum.sum
            $totalRow = @{alias="Usage Total";cost=$sum}
            $total = new-object Psobject -property $totalRow
            $total | export-csv $filename -append -force -notypeinformation
        }
        catch
        {
            $errorcode = 7
            stop
        }

        #>
        try
        {
           #email the spreadsheet
            $User = "a175c1c3db8f444804331808510f6456"
            $SmtpServer = "in-v3.mailjet.com"
            $EmailFrom = "CenturyLink Cloud revenue details for $alias <jarvis@ctl.io>"
            $EmailTo = "<$email>"
            #$PWordString = ''
            #$PWord = $PWordString | ConvertTo-SecureString
            $PWord = loginCLCSMTP

            $Credential = New-Object –TypeName System.Management.Automation.PSCredential –ArgumentList $User, $PWord

            $EmailBody = "Attached is a CenturyLink Cloud revenue report for $alias with and invoice month of $invoicemonth and year of $invoiceyear."

            Send-MailMessage -To $EmailTo -From $EmailFrom -Subject "CenturyLink Cloud Revenue Report for the sub account $alias" -Body $EmailBody -SmtpServer $SmtpServer -Port 25 -Credential $Credential -Attachments $filename
        }
        catch
        {
            $errorcode = 5
            stop
        }
        # Create a string for sending back to slack. * and ` are used to make the output look nice in Slack. Details: http://bit.ly/MHSlackFormat
        $result.output = "Revenue details for account Alias: *$($alias)* with an invoice date of $invoicemonth $invoiceyear have been sent to the e-mail address *$($email)*"
      
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
            $result.output = "Error when retrieving consumption data for alias $alias for year: $invoiceYear and month: $invoiceMonth."
        }
        elseif($errorcode -eq 7)
        {
            $result.output = "Error when exporting consumption data for alias $alias for year: $invoiceYear and month: $invoiceMonth. Please try again. If the issue persists please reach out to matt.schwabenbauer@ctl.io"
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

    # Return the result and convert it to json

    return $result | ConvertTo-Json
}