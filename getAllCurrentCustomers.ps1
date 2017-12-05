<#
.Synopsis
    A user wants a list of all CenturyLink Cloud customers in a given data center.
.Description
    Calls the consumption API for a list of active customers. Parses that list for non demo accounts and by data center. Then the customer information API is called to generate the final list.
.Author
    Matt Schwabenbauer
    Matt.Schwabenbauer@ctl.io
.Example
    getAllCurrentCustomers -email Matt.Schwabenbauer@ctl.io
#>
function getAllCurrentCustomers
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true)]
        $email
    )
try
{

    # Create a hashtable for the results
    $result = @{}
    $errorcode = $null

    # Hash table for the final list
    $customers = @()

    # File name for final list to be exported to
    $day = get-date -Format ddd
    $month = get-date -Format MMM
    $date = get-date -Format dd
    $year = get-date -Format yyyy
    $hour = get-date -Format HH
    $minutes = get-date -Format mm
    $seconds = get-date -Format ss

    $currentDateTime = "$day-$month-$date-$year-$hour-$minutes-$seconds"
    $filename = "c:\users\public\CenturyLinkCloud-AllCustomers-$currentDateTime.csv"

    # Log in to consumption api
    $HeaderValue = loginConsumptionApi

    
    <#===============================
    Find latest consumption data
    ================================#>
    $currentMonth = get-date -Format MM
    $currentYear = get-Date -Format yyyy

    $URL = "https://api.ctl.io/v2-experimental/internal/accounting/allconsumptiondetails/forUsagePeriod/$currentYear/$currentMonth/withPricingFrom/$currentYear/$currentMonth"

    try
    {
        $response = Invoke-RestMethod -Uri $URL -Headers $HeaderValue -Method Get
    }
    catch
    {
        stop
    }
    
    # Create variable for data centers

    $DCURL = "https://api.ctl.io/v2/datacenters/CTLX"
    $datacenterList = Invoke-RestMethod -Uri $DCURL -ContentType "Application/JSON" -Headers $HeaderValue -Method Get
    $datacenterList = $datacenterList.id

    $day = get-date -Format ddd
    $month = get-date -Format MMM
    $date = get-date -Format dd
    $year = get-date -Format yyyy
    $hour = get-date -Format HH
    $minutes = get-date -Format mm
    $seconds = get-date -Format ss

    $currentDateTime = "$day-$month-$date-$year-$hour-$minutes-$seconds"

    $tempConsumptionFileName = "c:/ConsumptionDump-$currentDateTime.csv"

    $response | out-file "c:/ConsumptionDump-$currentDateTime.csv"
    $consumption = import-csv "c:/ConsumptionDump-$currentDateTime.csv"

    $consumption = $consumption | where-object {$_.Status -eq "Active"}
    $consumption = $consumption | where-object {$_.Type -eq "Billable" -or $_.Type -eq "Reseller"}

    $aliases = $consumption."Alias"
    $aliases = $aliases | select -Unique
    
    # Log in to V1 API
    $global:session = loginclcAPIv1
    foreach ($alias in $aliases)
    {
        
        $JSON = @{AccountAlias = $alias} | ConvertTo-Json 
        $accountInfo = Invoke-RestMethod -uri "https://api.ctl.io/REST/Account/GetAccountDetails/" -ContentType "Application/JSON" -Method Post -WebSession $session -Body $JSON
        $businessName = $accountInfo.AccountDetails.BusinessName
        $thisCustomer = new-object PSObject
        $thiscustomer | Add-Member -MemberType NoteProperty -name "Customer Alias" -value $alias
        $thiscustomer | Add-Member -MemberType NoteProperty -name "Business Name" -value $businessName
        $customers += $thisCustomer
        #Log out of V1 API
        
    }
    $logoutURL = "https://api.ctl.io/REST/Auth/Logout/"
    $restreply = Invoke-RestMethod -uri $logoutURL -ContentType "Application/JSON" -Body $body -Method Post -SessionVariable session
    $customerCount = $customers | measure-Object
    $customerCount = $customerCount.count

    $customers | export-csv $filename -NoTypeInformation

    # E-mail the report

    $User = 'a175c1c3db8f444804331808510f6456'
    $SmtpServer = "in-v3.mailjet.com"
    $EmailFrom = "Jarvis <jarvis@ctl.io>"
    $EmailTo = "<$email>"
    $PWord = loginCLCSMTP
    $Credential = New-Object –TypeName System.Management.Automation.PSCredential –ArgumentList $User, $PWord

    $EmailBody = "Attached is a CenturyLink Cloud Customer List generated on $month $day, $year. $customerCount customers found.

    Summary:
    
        The attached spreadsheet contains two columns: Customer Alias and Business Name. The Customer Alias column contains the two to four character CenturyLink Coud account alias for the specific customer, and the Business Name column has the actual name of the customer.

        "

    Send-MailMessage -To $EmailTo -From $EmailFrom -Subject "CenturyLink Cloud Customer List" -Body $EmailBody -SmtpServer $SmtpServer -Port 25 -Credential $Credential -Attachments $filename
            
    $result.output = "CenturyLink Cloud Customer List has been emailed to *$($email)*`. *$($customerCount)* customers were found."
        
    $result.success = $true

    dir $filename | Remove-Item -Force
    dir $tempConsumptionFileName | Remove-Item -Force
    }
    catch
    {
        if ($errorcode -eq 1)
        {
            $result.output = "Operation failed."
        }
        else
        {
            $result.output = "Failed to generate a customer list."
        }
        
            $result.success = $false
    }
    finally
    {

    }
    return $result | ConvertTo-Json
}