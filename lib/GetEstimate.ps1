<#
.Synopsis
    A user wants to see the estimated and month to date MRR for a parent account alias, with subs rolling up.
.Description
    Returns MRR estimate and MTD spend data from control for a given alias, using the get group billing estimate API V2 call.
.Author
    Matt Schwabenabuer
    Matt.Schwabenbauer@ctl.io
.Example
    getEstimate -alias MSCH
#>
function getEstimate
{
    [CmdletBinding()]
    Param
    (
        # Customer Alias
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
        
        #session variables
        $AccountAlias = $alias
        $allServers = @()
        $allEstimates = @()
        $aliases = @()
        $groups = @()
        $serverNames = @()
        $DCURL = "https://api.ctl.io/v2/datacenters/$alias"
        $datacenterList = Invoke-RestMethod -Uri $DCURL -ContentType "Application/JSON" -Headers $HeaderValue -Method Get
        $datacenterList = $datacenterList.id

        Foreach ($i in $datacenterList)
        {
            $JSON = @{AccountAlias = $AccountAlias; Location = $i} | ConvertTo-Json 
            $response = Invoke-RestMethod -uri "https://api.ctl.io/REST/Server/GetAllServersForAccountHierarchy/" -ContentType "Application/JSON" -Method Post -WebSession $session -Body $JSON -errorAction stop
            $allServers += $response.AccountServers
        }

        if ($allServers)
        {
            $aliases = $allServers.AccountAlias
            $aliases = $aliases | Select -Unique
        }
        else
        {
            $aliases = $alias
        }

        $genday = Get-Date -Uformat %a
        $genmonth = Get-Date -Uformat %b
        $genyear = Get-Date -Uformat %Y
        $genhour = Get-Date -UFormat %H
        $genmins = Get-Date -Uformat %M
        $gensecs = Get-Date -Uformat %S

        $gendate = "Generated-$genday-$genmonth-$genyear-$genhour-$genmins-$gensecs"

        $thisServer = $null

        # Get group estimates
        Foreach ($h in $datacenterList)
        {
            Foreach ($i in $aliases)
            {
                $groups = @()
                $serverNames = @()
                $response = @()
                $JSON = @{AccountAlias = $i; Location = $h} | ConvertTo-Json
                $response = Invoke-RestMethod -uri "https://api.ctl.io/REST/Server/GetAllServersForAccountHierarchy/" -ContentType "Application/JSON" -Method Post -WebSession $session -Body $JSON -errorAction stop
                $groups = $response.AccountServers.Servers.HardwareGroupUUID
                $groups = $groups | Select -Unique
                $serverNames = $response.AccountServers.Servers.Name
                $serverNames = $serverNames | Select -Unique
                Foreach ($j in $groups)
                {
                    try
                    {
                        $response = @()
                        $url = "https://api.ctl.io/v2/groups/$i/$j/billing"
                        $response = Invoke-RestMethod -Uri $url -ContentType "Application/JSON" -Headers $HeaderValue -Method Get -ErrorAction SilentlyContinue
                    }
                    catch
                    {
                    }
                    Foreach ($k in $serverNames)
                    {
                        $data = $k
                        $thisServer = $response.groups.$j.servers.$data
                        if ($thisServer -eq $null)
                        {
                            # Do nothing                
                        }
                        else
                        {
                            $thisserver | Add-Member -Membertype NoteProperty -Name "Server Name" -Value $data -Force
                            $allEstimates += $thisserver | select "Server Name",templateCost,archiveCost,monthToDate,monthlyEstimate
                        } # End else
                   } # End foreach server name
                } # End foreach group
            } # End foreach alias
        } # End foreach data center

        $monthlyEstimate = $allEstimates
        $monthlyEstimateSum = $monthlyEstimate.monthlyEstimate | measure-object -sum
        $monthlyEstimateSum = $monthlyEstimateSum.sum
        $monthlyEstimateSum = "{0:N0}" -f $monthlyEstimateSum
        $monthToDateSum = $monthlyEstimate.monthToDate | measure-object -sum
        $monthToDateSum = $monthToDateSum.sum
        $monthToDateSum = "{0:N0}" -f $monthToDateSum

        if ($monthlyEstimateSum -eq $null)
        {
            $monthlyEstimateSum = "0"
        }

        if ($monthToDateSum -eq $null)
        {
            $monthToDateSum = "0"
        }

        $result.output = "*$($alias)* has an estimated MRR of $*$monthlyEstimateSum* and a month to date MRR of $*$monthToDateSum* for *$($genmonth)* *$($genyear)*`."
        
        $result.success = $true
    }
    catch
    {
        if ($errorcode -eq 2)
        {
            $result.output = "You entered an account alias that was either too long or too short."
        }
        else
        {
            $result.output = "Failed to generate an MRR estimate for $($alias)."
        }
        $result.success = $false
    }

    return $result | ConvertTo-Json
}