<#
Synopsis
    The user requests a server count for a given CenturyLink Cloud account alias.
Description
    Calls the CenturyLink Cloud V1 API for all servers by account hierarchy for a given account alias, and counts the total number of VMs.
Author
    Matt Schwabenbauer
    Matt.Schwabenbauer@ctl.io
Example
    serverCount -alias MSCH
#>
function serverCount
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
    
    # Use try/catch block            
    try
    {
        #check user input
        if ($alias.length -gt 4 -or $alias.length -lt 3 -or $alias -eq $null)
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

        $response = $null
        $allServers = @()

        Foreach ($i in $datacenterList)
        {
            $JSON = @{AccountAlias = $AccountAlias; Location = $i} | ConvertTo-Json 
            $response = Invoke-RestMethod -uri "https://api.ctl.io/REST/Server/GetAllServersForAccountHierarchy/" -ContentType "Application/JSON" -Method Post -WebSession $session -Body $JSON -errorAction stop
            $allServers += $response.AccountServers
        }

        if ($allServers)
        {
            $serverCount = $allServers.servers.count
        }
        else
        {
            $serverCount = 0
        }
        
        $result.output = "Alias $($alias) has *$($serverCount)* servers`."
        
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