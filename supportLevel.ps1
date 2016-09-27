<#
.Synopsis
    Returns the support level for a given CenturyLink Cloud account alias.
.Description
    Calls the CenturyLink Cloud V1 API for account info and parses the support level.
.Author
    Matt Schwabenbauer
    Matt.Schwabenbauer@ctl.io
.Example
    supportLevel -alias MSCH
#>
function supportLevel
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

        #call the account details API
        $JSON = @{AccountAlias = $AccountAlias} | ConvertTo-Json 
        $response = Invoke-RestMethod -uri "https://api.ctl.io/REST/Account/GetAccountDetails/" -ContentType "Application/JSON" -Method Post -WebSession $session -Body $JSON -errorAction stop
        
        $result.output = "Alias *$($alias)* has a support level of *$($response.AccountDetails.SupportLevel)*`."
        
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