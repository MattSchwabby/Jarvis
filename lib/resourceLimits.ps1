<#
.Synopsis
    The requester wants a view of a given customer account's resource utilization vs. the limits currently set in Control.
.Description
    Parses the resource limit v2 API endpoint for inherited account resource limits. If none are available, it defaults to the highest customer-set resource limit.
.Author
    Matt Schwabenbauer
    Matt.Schwabenbauer@ctl.io
.Example
    resourceLimits -alias MSCH
#>
function resourceLimits
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true)]
        $alias
    )
    
    try
    {
        # Check input
        if ($alias.length -gt 4 -or $alias.length -lt 2 -or $alias -eq $null)
        {
            # Fail the script
            $errorcode = 2
            stop
        }
     
        #API V1

        $global:session = loginCLCAPIV1

        #API V2

        $HeaderValue = loginCLCAPIV2

        # Create result variable
        $result = @{}

        $DCURL = "https://api.ctl.io/v2/datacenters/$alias"
        $getDCs = Invoke-RestMethod -Uri $DCURL -ContentType "Application/JSON" -Headers $HeaderValue -Method Get
        $dcs = $getDCs.id

        $allServers = @()

        Foreach ($i in $dcs)
        {
            $JSON = @{AccountAlias = $alias; Location = $i} | ConvertTo-Json 
            $response = Invoke-RestMethod -uri "https://api.ctl.io/REST/Server/GetAllServersForAccountHierarchy/" -ContentType "Application/JSON" -Method Post -WebSession $session -Body $JSON -errorAction stop
            $allServers += $response.AccountServers
        }

        # Create variable to count total public IPs
        $publicIPs = 0
        
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

            Foreach($i in $allServers)
            {
                Foreach($j in $i.servers.IPAddresses)
                {
                    if ($j.AddressType -eq "MIP")
                    {   
                        $publicIPs++
                    }
                }
            }
        }
        else
        {
            $serverCount = 0
            $CPUs = 0
            $RAM = 0
            $publicIPs = 0
            $storage = 0
            $AllAliases = $alias
        }

        $stringOut = ""
        $cpuObject = @()
        $ramObject = @()
        $hdObject = @()
        $ipObject = @()

        Foreach ($i in $dcs)
        {
            $limitURL = "https://api.ctl.io/v2/datacenters/$alias/$i/computeLimits"
            $computeLimit = Invoke-RestMethod -Uri $limitURL -ContentType "Application/JSON" -Headers $HeaderValue -Method Get

            if($($computeLimit.cpu.inherited))
            {
                $cpuLimit = $($computeLimit.cpu.value) 
            }

            if($($computeLimit.memoryGB.inherited))
            {
                $ramLimit = $($computeLimit.memoryGB.value) 
            }

            if($($computeLimit.storageGB.inherited))
            {
                $hdLimit = $($computeLimit.storageGB.value) 
            }

            if($($computeLimit.publicIPs.inherited))
            {
                $ipLimit = $($computeLimit.publicIPs.value) 
            }

            $cpuObject += $($computeLimit.cpu)
            $ramObject += $($computeLimit.memoryGB)
            $hdObject += $($computeLimit.storageGB)
            $ipObject += $($computeLimit.publicIPs)

        }

        if(!$cpuLimit)
        {
            $highestCPU = $cpuObject.value
            $highestCPU = $highestCPU | measure -Maximum
            $cpuLimit = $highestCPU.Maximum
        }

        if(!$ramLimit)
        {
            $highestRAM = $ramObject.value
            $highestRAM = $highestRAM | measure -Maximum
            $ramLimit = $highestRAM.Maximum
        }

        if(!$hdLimit)
        {
            $highestHD = $hdObject.value
            $highestHD = $highestHD | measure -Maximum
            $hdLimit = $highestHD.Maximum
        }

        if(!$ipLimit)
        {
            $highestIP = $ipObject.value
            $highestIP = $highestIP | measure -Maximum
            $ipLimit = $highestIP.Maximum
        }

        # Create a string for sending back to slack. * and ` are used to make the output look nice in Slack. Details: http://bit.ly/MHSlackFormat
        $result.output = "Resource utilization for account alias *$($alias)* : *$($CPUs)* / *$($cpuLimit)* VCPUs | *$($ram)* GB / *$($ramLimit)* GB RAM | *$($storage)* / *$($hdLimit)* GB HD | *$($publicIPs)* / *$($ipLimit)* Public IPs."
      
        # Set a successful result
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
        $result.output = "Failed to return account info for $($alias)."
        }
        
        $result.success = $false
    }
    return $result | ConvertTo-Json
}