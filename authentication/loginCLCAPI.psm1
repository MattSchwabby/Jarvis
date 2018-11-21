function loginCLCAPIV1
{
    [CmdletBinding()]
    Param
    (
    )

    
    $import = "C:\users\administrator\JK\config.json"

    $config = get-content $import -Raw | convertfrom-json

    $JK1 = $config.jk1
    $JK2 = $config.jk2 | ConvertTo-SecureString


    $V1Credential = New-Object –TypeName System.Management.Automation.PSCredential –ArgumentList $JK1, $JK2
    $DecodePassword1 = $V1Credential.GetNetworkCredential().Password

    $json = @"
    { 'APIKey': '$JK1', 'Password': '$DecodePassword1' }
"@

    try
    {
        $restreply = Invoke-RestMethod -uri "https://api.ctl.io/REST/Auth/Logon/" -ContentType "Application/JSON" -Body $json -Method Post -SessionVariable session -errorAction Stop
        return $session 
    }
    catch
    {
        return "error"
    }
}

function loginCLCAPIV2
{
    [CmdletBinding()]
    Param
    (
    )

    $import = "C:\users\administrator\JK\config.json"

    $config = get-content $import -Raw | convertfrom-json

    $JK3 = $config.jk3
    $JK4 = $config.jk4 | ConvertTo-SecureString

    $V2Credential = New-Object –TypeName System.Management.Automation.PSCredential –ArgumentList $JK3, $JK4
    $DecodePassword2 = $V2Credential.GetNetworkCredential().Password

    $json = @"
    { 'username':'$JK3', 'password':'$DecodePassword2' }
"@

    try
    {
        $global:resttoken = Invoke-RestMethod -uri "https://api.ctl.io/v2/authentication/login" -ContentType "Application/JSON" -Body $json -Method Post 
        $HeaderValue = @{Authorization = "Bearer " + $resttoken.bearerToken}
        return $HeaderValue
    }
    catch
    {
        return "error"
    }
}

function loginCLCSMTP
{
    [CmdletBinding()]
    Param
    (
    )

    $import = "C:\users\administrator\JK\config.json"

    $config = get-content $import -Raw | convertfrom-json

    $JK5 = $config.jk5 | ConvertTo-SecureString

    return $JK5
}

function loginBMDB
{
    [CmdletBinding()]
    Param
    (
    )

    $import = "C:\users\administrator\JK\config.json"

    $config = get-content $import -Raw | convertfrom-json

    return $config
}

function loginConsumptionAPI
{
    [CmdletBinding()]
    Param
    (
    )

    $import = "C:\users\administrator\JK\config.json"

    $config = get-content $import -Raw | convertfrom-json

    $JK6 = $config.jk6
    $JK7 = $config.jk7 | ConvertTo-SecureString


    $V2Credential = New-Object –TypeName System.Management.Automation.PSCredential –ArgumentList $JK6, $JK7
    $DecodePassword2 = $V2Credential.GetNetworkCredential().Password

    $json = @"
    { 'username':'$JK6', 'password':'$DecodePassword2' } 
"@

    try
    {
        $global:resttoken = Invoke-RestMethod -uri "https://api.ctl.io/v2/authentication/login" -ContentType "Application/JSON" -Body $json -Method Post 
        $HeaderValue = @{Authorization = "Bearer " + $resttoken.bearerToken}
        return $HeaderValue
    }
    catch
    {
        return "error"
    }

}

function consumptionDBLogin
{
    [CmdletBinding()]
    Param
    (
    )

    $import = "C:\users\administrator\JK\config.json"

    $config = get-content $import -Raw | convertfrom-json

    $JK8 = $config.jk8

    return $JK8

}

export-modulemember -function loginCLCAPIV1
export-modulemember -function loginCLCAPIV2
export-modulemember -function loginCLCSMTP
export-modulemember -function loginBMDB
export-modulemember -function loginConsumptionAPI
export-modulemember -function consumptionDBLogin