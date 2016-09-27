<#
.Synopsis
    A user wants to quickly see the latest MRR for a given account alias.
.Description
    Returns the MRR for a given account alias by parsing the CLC V2 API invoice call for the previous month.
.Author
    Matt Schwabenbauer
    Matt.Schwabenbauer@ctl.io
.Example
   getMRR -alias MSCH
#>
function getMRR
{
    [CmdletBinding()]
    Param
    (
        # Name of the Service
        [Parameter(Mandatory=$true)]
        $alias
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
            $allAliases = $allServers.AccountAlias
            $allAliases = $allAliases | Select -Unique
        }
        else
        {
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
        }<# end foreach #>

        #Calculate MRR
        $mrr = $invoiceData.totalamount | measure-object -sum
        $mrr = $mrr.sum

        #calculate MRR by DC
        $total = 0
        $final = @()

        $locations = $invoiceData.lineItems.servicelocation | select-object -unique | Where-Object {$_ -ne ""}

        foreach ($j in $locations)
        {
            $total = 0
            foreach ($i in $invoiceData.lineItems)
            {
                if ($i.servicelocation -eq $j)
                {
                    $total += $i.ItemTotal
                }
            }
            $thisrow = new-object System.Object
            $thisrow | Add-Member -MemberType NoteProperty -name "Location" -value $j
            $thisrow | Add-Member -MemberType NoteProperty -name "MRR" -value $total
            $final += $thisrow
        }

        $stringOut = ""
        Foreach ($i in $final)
        {
            $l = $i.Location
            $s = $i.MRR
            $stringOut += "$l : $s`n"
        }

        $result.output = "``````DC  : MRR`n==================`n$stringOut`````` `n Alias *$($alias)* had $*$($mrr)* MRR last month."
        
        $result.success = $true
    }
    catch
    {
        if ($errorcode -eq 2)
        {
            $result.output = "You entered an account alias that was either too long or too short. Get your life together, dude."
        }
        else
        {
            $result.output = "Failed to return account info for $($alias)."
        }
        
        $result.success = $false
    }

    return $result | ConvertTo-Json
}