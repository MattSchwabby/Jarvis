<#
.Synopsis
    A user wants to know what parent accounts are above a given sub account.
.Description
    Grabs the CLC V1 API account details call and filters it for parent accounts.
.Author
    Matt Schwabenbauer
    Matt.Schwabenbauer@ctl.io
.Example
    getParents -alias MSCH
#>
function getParents
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
        $response = $Null
        $parents = $null
        $parent = $null

        do
        {
            $JSON = @{AccountAlias = $alias} | ConvertTo-Json 
            $response = Invoke-RestMethod -uri "https://api.ctl.io/REST/Account/GetAccountDetails/" -ContentType "Application/JSON" -Method Post -WebSession $session -Body $JSON 
            $parent = $response.AccountDetails.ParentAlias
            $parents += "$parent "
            $alias = $parent
        }
        while ($parent -ne $null)
        
        $result.output = "Alias *$($AccountAlias)* has the following parent accounts: ``````$parents``````"
        
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
            $result.output = "Failed to return parent accounts for $($AccountAlias)."
        }
        
        $result.success = $false
    }
    
    return $result | ConvertTo-Json
}