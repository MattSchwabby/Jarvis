<#
.Synopsis
    A user wants to know what intra DC connectivity a given CenturyLink Cloud account has in place. Useful for verifying impact during intra DC Urgent Incidents.
.Description
    Gathers VMs from get servers by account hierarchy CLC V1 API call, then checks that against the cross dc connectivity V2 API call.
.Author
    Matt Schwabenbauer
    Matt.Schwabenbauer@ctl.io
.Example
    GetCrossDCs -alias MSCH
#>
function getCrossDCs
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

        # Define session variables
        $targets = $null
        $target = $null
        $i = $null
        $crossLinks = $null
        $newLink = $null
        $response = $null
        $allServers = @()
        $destDC = $null
        $redundancyChecker1 = $null
        $redundancyChecker2 = $null
        $piece1 = $null
        $piece2 = $null

        # Log in to APIs

        #API V1

        $global:session = loginCLCAPIV1

        #API V2

        $HeaderValue = loginCLCAPIV2

        $AccountAlias = $alias
        $DCURL = "https://api.ctl.io/v2/datacenters/$alias"
        $datacenterList = Invoke-RestMethod -Uri $DCURL -ContentType "Application/JSON" -Headers $HeaderValue -Method Get
        $datacenterList = $datacenterList.id

        Foreach ($i in $datacenterList)
        {
            $JSON = @{AccountAlias = $AccountAlias; Location = $i} | ConvertTo-Json 
            $response = Invoke-RestMethod -uri "https://api.ctl.io/REST/Server/GetAllServersForAccountHierarchy/" -ContentType "Application/JSON" -Method Post -WebSession $session -Body $JSON -errorAction stop
            $allServers += $response.AccountServers
        }

        if ($allservers)
        {
            $serverCount = $allServers.servers.count
            $allaliases = $allServers.accountalias
            $allaliases = $allaliases | select-Object -unique
        }
        else
        {
            $allaliases = $alias
        }

        Foreach ($i in $allaliases)
        {
        # call api
            Foreach ($j in $datacenterList)
            {
                $targets = $null
                $url = "https://api.ctl.io/v2-experimental/crossDcFirewallPolicies/$i/$j"
                try
                {
                    $response = Invoke-RestMethod -Uri $url -ContentType "Application/JSON" -Headers $HeaderValue -Method Get -ErrorAction Stop
                    if ($response -ne $null)
                    {
                        $targets = $response.destinationLocation
                    }
                }
                catch
                {
                }
                if ($targets -ne $null)
                {
                    $destDC = $null
                    Foreach ($h in $targets)
                    {
                        $target = $h.ToUpper()
                        $redundancyChecker1 = $null
                        $redundancyChecker2 = $null
                        $piece1 = $null
                        $piece2 = $null
                        $k = 5
                        do
                        {
                            $length1 = ($crosslinks.length - $k)
                            try
                            {
                                $piece1 = $crossLinks[$length1]
                                $redundancyChecker1 += "$piece1"
                            }# end try
                            catch
                            {
                            }# end catch
                            $k--
                        }# end do
                        until ($k -eq 2)
                        $k = 4
                        do
                        {
                            $length2 = ($destDC.length - $k)
                            try
                            {
                                $piece2 = $destDC[$length2]
                                $redundancyChecker2 += "$piece2"
                            }# end try
                            catch
                            {
                            }# end catch
                            $k--
                        }# end do
                        until ($k -eq 1)
                        if (($target -ne $redundancyChecker1) -and ($target -ne $redundancyChecker2))
                        {
                            $destDC += "$target "
                        }# end if
                    }# end for each h in targets
                    if ($destDC -ne $null)
                    {
                        $newLink = "$i : $j -> $destDC`n"
                        $crossLinks += $newLink
                    }
                } # end if $targets -ne $null
            }# end foreach data center
        }# end foreach alias

        #Log out of API
        $restreply = Invoke-RestMethod -uri "https://api.ctl.io/REST/Auth/Logout/" -ContentType "Application/JSON" -Method Post -SessionVariable session -errorAction Stop
        $global:session = $session

        $result.output = "Account *$($alias)* has the following intra data center connections:`n ``````Alias: DC1 -> DC2`n=================`n$crosslinks``````"
        
        $result.success = $true
    }
    catch
    {
        if ($errorcode -eq 2)
        {
            $result.output = "You entered an account alias that was either too long or too short. How do you even sleep at night?"
        }
        else
        {
            $result.output = "Failed to return cross data center info for $($alias)."
        }
        
        $result.success = $false
    }

    return $result | ConvertTo-Json
}