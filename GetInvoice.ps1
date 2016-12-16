<#
.Synopsis
    A user requests invoice data for a given month, year and CenturyLink Cloud account alias.
.Description
    Returns invoice data for a specified month, year and account alias from control. E-mails it to a given email address.
.Author
    Matt Schwabenbauer
    Matt.Schwabenbauer@ctl.io
.Example
    getInvoice -alias MSCH -month 06 -year 2016 -email Matt.Schwabenbauer@ctl.io
#>
function getInvoice
{
    [CmdletBinding()]
    Param
    (
        # Customer Alias
        [Parameter(Mandatory=$true)]
        $alias,
        [Parameter(Mandatory=$true)]
        $month,
        [Parameter(Mandatory=$true)]
        $year,
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

        if ($month -eq $null)
        {
            $errorcode = 3
            stop
        }

        $currentMonth = Get-Date -UFormat %m
        if ($month -eq $currentMonth)
        {
            $errorcode = 7
            stop
        }
        
        if ($year -eq $null)
        {
            $errorcode = 4
            stop
        }
                if ($email -eq $null)
        {
            # fail the script
            $errorcode = 6
            stop
        }

        # Log in to APIs

        # API V1

        $global:session = loginCLCAPIV1

        # API V2

        $HeaderValue = loginCLCAPIV2
        
        # Create directory for temp file
        New-Item -ItemType Directory -Force -Path c:\Users\Public\Jarvis\Temp | Out-Null

        # Session variables

        $AccountAlias = $alias

        # Get data centers
        $DCURL = "https://api.ctl.io/v2/datacenters/$alias"
        $datacenterList = Invoke-RestMethod -Uri $DCURL -ContentType "Application/JSON" -Headers $HeaderValue -Method Get
        $datacenterList = $datacenterList.id

        $billtmp1 = "c:\Users\Public\Jarvis\Temp\billtmp1.csv"
        $billtmp2 = "c:\Users\Public\Jarvis\Temp\billtmp2.csv"
        $billtmp3 = "c:\Users\Public\Jarvis\Temp\billtmp3.csv"
        $billtmp4 = "c:\Users\Public\Jarvis\Temp\billtmp4.csv"

        $response = $null
        $allServers = @()
        $invoiceData = @()

        Foreach ($i in $datacenterList)
        {
            $JSON = @{AccountAlias = $AccountAlias; Location = $i} | ConvertTo-Json 
            $response = Invoke-RestMethod -uri "https://api.ctl.io/REST/Server/GetAllServersForAccountHierarchy/" -ContentType "Application/JSON" -Method Post -WebSession $session -Body $JSON -errorAction stop
            $allServers += $response.AccountServers
        }

        if ($allServers)
        {   
            $serverCount = $allServers.servers.count
            $allAliases = $allServers.AccountAlias
            $allAliases = $allAliases | Select -Unique
        }
        else
        {
            $AllAliases = $alias
        }

        Foreach ($i in $AllAliases)
        {
           $data = @()
           $url = "https://api.ctl.io/v2/invoice/$i/$year/$month/?pricingAccount=$i"
           try
           {
                $data = Invoke-RestMethod -Uri $url -ContentType "Application/JSON" -Headers $HeaderValue -Method Get -ErrorAction SilentlyContinue
                $data | Export-csv -Path $billtmp1 -notypeinformation -force
                $invoicedata1 = import-csv $billtmp1 | select @{Expression={$_."accountAlias"};Label="Account Alias"},@{Expression={$_."invoiceDate"};Label="Invoice Date"},@{Expression={$_."totalAmount"};Label="Total Amount"},@{Expression={$_."id"};Label="Bill ID"}
                $invoicedata1 | Add-Member -MemberType NoteProperty -Name "Billing Item" -value $_
                $invoicedata1 | Add-Member -MemberType NoteProperty -Name "Quantity" -value $_
                $invoicedata1 | Add-Member -MemberType NoteProperty -Name "Unit Cost" -value $_
                $invoicedata1 | Add-Member -MemberType NoteProperty -Name "Item Total" -value $_
                $invoicedata1 | Add-Member -MemberType NoteProperty -Name "Service Location" -value $_
                $invoicedata1 | Add-Member -MemberType NoteProperty -Name "Line Item" -value $_
                $invoicedata1 | Add-Member -MemberType NoteProperty -Name "Line Item Total" -value $_
                $invoicedata1 | export-csv $billtmp4 -append -notypeinformation
                $lineItems = $data.lineitems
                Foreach ($i in $lineItems)
                {
                    $i | Export-csv -Path $billtmp2 -notypeinformation
                    $invoicedata2 = import-csv $billtmp2 | select @{Expression={$_."quantity"};Label="Quantity"},@{Expression={$_."description"};Label="Billing Item"},@{Expression={$_."unitCost"};Label="Unit Cost"},@{Expression={$_."itemTotal"};Label="Item Total"},@{Expression={$_."serviceLocation"};Label="Service Location"}
                    $invoicedata2 | export-csv $billtmp4 -append -notypeinformation -force
                    if ($i.itemDetails -ne $null)
                    {
                        $i.itemDetails | Export-csv -Path $billtmp3 -notypeinformation -Force
                        $invoicedata3 = import-csv $billtmp3 | select @{Expression={$_."description"};Label="Line Item"},@{Expression={$_."cost"};Label="Line Item Total"}
                        $invoicedata3 | export-csv $billtmp4 -append -notypeinformation -force
                    } # end if
                }# end foreach
           }# end try
           catch
           {
           }
            $invoiceData += $data
        }# End foreach

        # Calculate MRR on Spreadsheet
        $finalImport = import-csv $billtmp4
        $totalMRR = $finalImport."Total Amount" | measure-object -sum
        $totalMRR = $totalMRR.sum
        $todayDate = $finalImport."Invoice Date"[0]
        $MRRRow = new-object system.object
        $MRRRow | Add-Member -type NoteProperty -name "Account Alias" -value "Total Bill"
        $MRRRow | Add-Member -type NoteProperty -name "Invoice Date" -value $todayDate
        $MRRRow | Add-Member -type NoteProperty -name "Total Amount" -value $totalMRR
        $MRRRow | export-csv $billtmp4 -append -notypeinformation -force

        $filename = "c:\Users\Public\Jarvis\$accountalias-CLCBillingData-$month-$year.csv"

        import-csv $billtmp4 | export-csv $filename -NoTypeInformation

        # Email the spreadsheet
        $User = 'a175c1c3db8f444804331808510f6456'
        $SmtpServer = "in-v3.mailjet.com"
        $EmailFrom = "Jarvis SMTP Relay - PLEASE DO NOT REPLY <matt.schwabenbauer@ctl.io>"
        $EmailTo = "<$email>"
        $PWord = loginCLCSMTP
        $Credential = New-Object –TypeName System.Management.Automation.PSCredential –ArgumentList $User, $PWord

        $EmailBody = "Attached is a CenturyLink Cloud invoice for $alias for the $month $year billing period."

        Send-MailMessage -To $EmailTo -From $EmailFrom -Subject "CenturyLink Cloud $month $year invoice for $alias" -Body $EmailBody -SmtpServer $SmtpServer -Port 25 -Credential $Credential -Attachments $filename

        # Calculate MRR in code
        $mrr = $invoiceData.totalamount | measure-object -sum
        $mrr = $mrr.sum
        $mrr = "{0:N0}" -f $mrr
       
        # Count sub accounts
        $subs = $allAliases | measure-object
        $subs = $subs.count

        $result.output = "Invoice for *$($month)* *$($year)* with $*$MRR* MRR for account alias *$($alias)* has been emailed to *$($email)*`."
        
        $result.success = $true
    }
    catch
    {
        if ($errorcode -eq 2)
        {
            $result.output = "You entered an account alias that was either too long or too short."
        }
        elseif ($errorcode -eq 3)
        {
            $result.output = "You entered a month that has either too many or too few characters."
        }
        elseif ($errorcode -eq 4)
        {
            $result.output = "You entered a year that has either too many or too few characters."
        }
        elseif ($errorcode -eq 6)
        {
            $result.output = "You didn't enter an e-mail address."
        }
        elseif ($errorcode -eq 7)
        {
            $result.output = "Cannot generate an invoice for the current calendar month because the billing data has not yet processed. Please request an estimate instead. (Example: @jarvis estimate mrr $($alias))"
        }
        else
        {
        $result.output = "Failed to generate an invoice for $($alias)."
        }
        $result.success = $false
    }

    # Delete temp files
    dir $billtmp1 | Remove-Item -force
    dir $billtmp2 | Remove-Item -force
    dir $billtmp3 | Remove-Item -force
    dir $billtmp4 | Remove-Item -force
    dir $filename | Remove-Item -force

    return $result | ConvertTo-Json
}