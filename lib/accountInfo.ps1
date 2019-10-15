<#
.Synopsis
    The requester wants a brief financial and technical view of a given CenturyLink Cloud account.
.Description
    Parses compute/storage/vm counts, last invoice data, support level and home data center information from both CenturyLink Cloud APIs.
.Author
    Matt Schwabenbauer
    Matt.Schwabenbauer@ctl.io
.Example
    accountInfo -alias MSCH
#>
function accountInfo
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true)]
        $alias
    )

    # Create a hashtable for the results
    $result = @{}
    $errorcode = $null
    
    # Use try/catch block            
    try
    {
        # Check input
        if ($alias.length -gt 4 -or $alias.length -lt 2 -or $alias -eq $null)
        {
            # Fail the script
            $errorcode = 2
            stop
        }

        # Log in to APIs

        #API V1

        $global:session = loginCLCAPIV1

        #API V2

        $HeaderValue = loginCLCAPIV2

        $AccountAlias = $alias

        $DCURL = "https://api.ctl.io/v2/datacenters/$alias"
        $datacenterList = Invoke-RestMethod -Uri $DCURL -ContentType "Application/JSON" -Headers $HeaderValue -Method Get
        $datacenterList = $datacenterList.id

        $genmonth = Get-Date -Uformat %m
        $genyear = Get-Date -Uformat %Y
        $billmonth = $genmonth -1

        if ($billmonth -eq 0)
        {
            $billmonth = 12
            $genyear = $genyear -1
        }

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
            $CPUs = $allServers.Servers.cpu | Measure-Object -sum
            $cpus = $cpus.sum
            $RAM = $allServers.Servers.memorygb | measure-object -sum
            $ram = $ram.sum
            $storage = $allServers.Servers.TotalDiskSpaceGB | measure-object -sum
            $storage = $storage.sum
            $allAliases = $allServers.AccountAlias
            $allAliases = $allAliases | Select -Unique
        }
        else
        {
            $serverCount = 0
            $CPUs = 0
            $RAM = 0
            $storage = 0
            $AllAliases = $alias
        }

        $data = @()
        Foreach ($i in $AllAliases)
        {
            $data = @()
            $url = "https://api.ctl.io/v2/invoice/$i/$genyear/$billmonth/?pricingAccount=$i"
            try
            {
                $data = Invoke-RestMethod -Uri $url -ContentType "Application/JSON" -Headers $HeaderValue -Method Get -ErrorAction SilentlyContinue
            }
            catch
            {
            }
            $invoiceData += $data
        }# End foreach

        # Calculate MRR
        $mrr = $invoiceData.totalamount | measure-object -sum
        $mrr = $mrr.sum
        $mrr = "{0:N0}" -f $mrr
        
        # Count sub accounts
        $subs = $allAliases | measure-object
        $subs = $subs.count

        # Call the account details API
        $JSON = @{AccountAlias = $AccountAlias} | ConvertTo-Json 
        $response = Invoke-RestMethod -uri "https://api.ctl.io/REST/Account/GetAccountDetails/" -ContentType "Application/JSON" -Method Post -WebSession $session -Body $JSON -errorAction stop

        # Find support level
        $supportLevel = $response.AccountDetails.SupportLevel

        # Find home data center
        $location = $response.AccountDetails.Location

        # Find business name
        $businessName = $response.AccountDetails.BusinessName

        # Create a string for sending back to slack. * and ` are used to make the output look nice in Slack. Details: http://bit.ly/MHSlackFormat
        $result.output = "Alias: *$($alias)* | Business name: *$($businessName)* | Accounts (including sub accounts and parent): *$($subs)* | MRR: $*$($mrr)* | Home data center: *$($location)* | Support Level: *$($supportLevel)* `nVMs: *$($serverCount)* | VCPUs: *$($cpus)* | RAM (GB): *$($RAM)* | Storage (GB): *$($storage)*  "
      
        # Set a successful result
        $result.success = $true
    }

    # Catch some errors and send a failed response
    catch
    {
        if ($errorcode -eq 2)
        {
            $result.output = "You entered an account alias that was either too long or too short."
        }
        else
        {
        $result.output = "Failed to return account info for $($alias)."
        }
        
        $result.success = $false
    }
    return $result | ConvertTo-Json
}