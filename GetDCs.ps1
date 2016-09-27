<#
.Synopsis
    A user wants to see what data centers a given CenturyLink Cloud account alias is in, as well as the number of VMs in each DC.
.Description
    Returns the number of servers a given alias has in each DC.
.Author
    Matt Schwabenbauer
    Matt.Schwabenbauer@ctl.io
.Example
    getDCs -alias MSCH
#>
function getDCs
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
        #define session variables
        $data = @()
        $allServers = @()
        $dcList = @()
        $this = $null

        # Log in to APIs

        #API V1

        $global:session = loginCLCAPIV1

        #API V2

        $HeaderValue = loginCLCAPIV2

        $AccountAlias = $alias
        $DCURL = "https://api.ctl.io/v2/datacenters/$alias"
        $datacenterList = Invoke-RestMethod -Uri $DCURL -ContentType "Application/JSON" -Headers $HeaderValue -Method Get
        $datacenterList = $datacenterList.id
        $date = Get-Date -Format Y

        #get server data from API
        Foreach ($i in $datacenterList)
        {
            $JSON = @{AccountAlias = $AccountAlias; Location = $i} | ConvertTo-Json 
            $data = Invoke-RestMethod -uri "https://api.ctl.io/REST/Server/GetAllServersForAccountHierarchy/" -ContentType "Application/JSON" -Method Post -WebSession $session -Body $JSON -errorAction Stop
            #$data.AccountServers.Servers | Export-Csv g:\CustomerServerData\RawData.csv -Append -force -ErrorAction ignore -NoTypeInformation
            $allServers += $data.AccountServers.servers
        }

        #parse data center info from server data
        Foreach ($i in $datacenterList)
        {
            $this = $allServers | Select-Object | Where-Object {$_.Location -eq "$i"}
            $thisrow = New-object system.object
            $thisrow | Add-Member -MemberType NoteProperty -Name "Location" -value $i
            $thisrow | Add-Member -MemberType NoteProperty -Name "Server Count" -value $this.count
            $dcList += $thisrow
        }

        $dcList = $dcList | Select-Object | Where-Object {$_."Server Count" -gt 0}
        $stringOut = ""

        Foreach ($i in $dcList)
        {
            $l = $i.location
            $s = $i."Server Count"
            $stringOut += "$l : $s`n"
        }

        $restreply = Invoke-RestMethod -uri "https://api.ctl.io/REST/Auth/Logout/" -ContentType "Application/JSON" -Method Post -SessionVariable session -errorAction Stop
        $global:session = $session

        $result.output = "Alias *$($alias)* has the following data center footprint:`n ``````DC  : Server count`n==================`n$stringOut``````"
        
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
            $result.output = "Failed to return data center info for $($alias)."
        }
        
        $result.success = $false
    }
    
    return $result | ConvertTo-Json
}