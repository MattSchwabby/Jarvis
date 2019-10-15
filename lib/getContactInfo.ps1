<#
.Synopsis
    The requester wants a list of account administrators for a given CenturyLink Cloud parent account alias.
.Description
    Returns the account administrator, home DC, phone number and e-mail for a given alias, rolls up sub accounts. Uses get users, account info, and servers by hierarchy CLC API calls.
.Author
    Matt Schwabenbauer
    Matt.Schwabenbauer@ctl.io
.Example
    getContactInfo -alias MSCH
#>
function getContactInfo
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
        #check input
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

        # Get data centers
        $DCURL = "https://api.ctl.io/v2/datacenters/$alias"
        $datacenterList = Invoke-RestMethod -Uri $DCURL -ContentType "Application/JSON" -Headers $HeaderValue -Method Get
        $datacenterList = $datacenterList.id
        
        $AccountAlias = $alias

        # Get account aliases for given parent
        Foreach ($i in $datacenterList)
        {
            $JSON = @{AccountAlias = $AccountAlias; Location = $i} | ConvertTo-Json 
            $response = Invoke-RestMethod -uri "https://api.ctl.io/REST/Server/GetAllServersForAccountHierarchy/" -ContentType "Application/JSON" -Method Post -WebSession $session -Body $JSON -errorAction stop
            $allAliases += $response.AccountServers

        }

        if ($allAliases)
        {
            $allAliases = $allAliases.AccountAlias
            $allAliases = $allAliases | Select -Unique
        }
        else
        {
            $allaliases = $alias
        }

        # Iterate through account aliases and get account info

        $adminsExist = $false
        $counter = 1
        $output = $null
        Foreach ($alias in $allAliases)
        {
            # Get Account Info
            $JSON = @{AccountAlias = $alias} | ConvertTo-Json 
            $accountInfo = Invoke-RestMethod -uri "https://api.ctl.io/REST/Account/GetAccountDetails/" -ContentType "Application/JSON" -Method Post -WebSession $session -Body $JSON

            $location = $accountInfo.AccountDetails.Location
            $telephone = $accountInfo.AccountDetails.Telephone
            $businessName = $accountInfo.AccountDetails.BusinessName

            if($counter -eq 1)
            {
                $parentBusinessName = $businessname
                $parentphone = $telephone
                $parentlocation = $location
            }
            # Get users
            $JSON = @{AccountAlias = $alias} | ConvertTo-Json 
            $response = Invoke-RestMethod -uri "https://api.ctl.io/REST/User/GetUsers/" -ContentType "Application/JSON" -Method Post -WebSession $session -Body $JSON

            $targetUsers = $response.users | Where-Object {$_.roles -eq 9}

            if ($targetUsers -eq $null)
            {
                #$output += "Account $alias has no Acccount Administrators on file. `n"
            }
            else
            {
                $adminsExist = $true
            }

            Foreach ($i in $targetUsers)
            {
                $first = $i.FirstName
                if ($first -eq $null)
                {
                    $first = "No first name on file"
                }
                $last = $i.LastName
                if ($last -eq $null)
                {
                    $last = "No last name on file"
                }
                $email = $i.EmailAddress
                if ($email -eq $null)
                {
                    $email = "No E-mail address on file"
                }
                $phone = $i.MobileNumber
                if ($phone -eq $null)
                {
                    $phone = "No phone number on file, please see billing phone number below"
                }
                $title = $i.Title
                if ($title -eq $null)
                {
                    $title = "No title on file"
                }
                $title = "$title."
                $output += "$counter. Name: $first $last | E-mail: $email | Phone number: $phone | Title: $title | Account alias: $alias`n"
                $counter++
            }
        } # End foreach account alias
        if($adminsExist -eq $false)
        {
            $output = "Account $Accountalias has no Acccount Administrators on file. "
        }
        $result.output = "Account alias *$($accountAlias)* has the following account administrator(s):`n $output Business name: *$($parentBusinessName)* | Billing phone number: *$($parentphone)*."

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
        $result.output = "Failed to return contact info for $($alias)."
        }
        
        $result.success = $false
    }
    
    return $result | ConvertTo-Json
}