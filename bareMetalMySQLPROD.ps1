 <#
Synopsis
    The requester wants an overview of the available bare metal SKUs in each DC.
Description
    Gets available DCs from the CLC API, then queries the infra forecast DB for available bare metal SKUs in each of those DCs.
Author
    Matt Schwabenbauer
    Matt.Schwabenbauer@ctl.io
Example
    bareMetal
#>
 function bareMetal
 {
    [cmdletbinding()]
    Param()

    # Create a hashtable for the results
    $result = @{}

     <#
     ==============================
     FUNCTIONS
     ==============================
     #>
 
     # Function to return the latest availability record for a given bare metal config ID
    function queryBareMetalAvailability
    {
        [CmdletBinding()]
        Param
        (
            [Parameter(Mandatory=$true)]
            $config,
            [Parameter(Mandatory=$true)]
            $dataCenter
        )

         $query =
            "SELECT *
            FROM baremetal.avail WHERE config_id = $config AND datacenter = $dataCenter
            ORDER BY date_added DESC
            LIMIT 1
            ;"

        Try
        {
            [void][System.Reflection.Assembly]::LoadWithPartialName("MySql.Data")
            $Connection = New-Object MySql.Data.MySqlClient.MySqlConnection
            $Connection.ConnectionString = $ConnectionString
            $Connection.Open()
            $Command = New-Object MySql.Data.MySqlClient.MySqlCommand($Query, $Connection)
            $DataAdapter = New-Object MySql.Data.MySqlClient.MySqlDataAdapter($Command)
            $DataSet = New-Object System.Data.DataSet
            $RecordCount = $dataAdapter.Fill($dataSet, "data")
            #  $DataSet.Tables[0]
            $SQLresponse = $DataSet.Tables[0]
            $SQLresponse
        }

        Catch
        {
            $SQLresponse = "ERROR : Unable to run query : $query `n$Error[0]"
        }
        return $SQLresponse[0]
    } # end queryBareMetalAvailability

    <#
    ===================================
    MAIN SCRIPT
    ===================================
    #>

    #API V2 Login

    $HeaderValue = loginCLCAPIV2

    try
    {
        $DCURL = "https://api.ctl.io/v2/datacenters/CTL0"
        $datacenterList = Invoke-RestMethod -Uri $DCURL -ContentType "Application/JSON" -Headers $HeaderValue -Method Get
        $datacenterList = $datacenterList.id
    }

    catch
    {
        $result.success = $false
        $result.output = "Unable to return available data centers."
    }
    # NEXT LINE JUST FOR DEV DB. COMMENT IT OUT FOR PROD
    #$datacenterList = "lb1"


    # Create a hashtable and empty string for the results
    $result = @{}
    $stringOut = "Successfully retrieved available bare metal SKUs:`n"

    # Session variables
    $availability = @()
    $total = @()
    # $bareMetalDatacenters = "lb1,gb3,va1"

    $query =  "SELECT * FROM baremetal.configs;"

    $BMCreds = loginBMDB

    $MySQLAdminUserName = $BMCreds.BM1
    $MySQLAdminPassword = $BMCreds.BM2
    $MySQLDatabase = $BMCreds.BM3
    $MySQLHost = $BMCreds.BM4
    $ConnectionString = "server=" + $MySQLHost + ";port=49237;uid=" + $MySQLAdminUserName + ";pwd=" + $MySQLAdminPassword + ";database="+$MySQLDatabase

    Try
    {
        [void][System.Reflection.Assembly]::LoadWithPartialName("MySql.Data")
        $Connection = New-Object MySql.Data.MySqlClient.MySqlConnection
        $Connection.ConnectionString = $ConnectionString
        $Connection.Open()
        $Command = New-Object MySql.Data.MySqlClient.MySqlCommand($Query, $Connection)
        $DataAdapter = New-Object MySql.Data.MySqlClient.MySqlDataAdapter($Command)
        $DataSet = New-Object System.Data.DataSet
        $RecordCount = $dataAdapter.Fill($dataSet, "data")
        # $DataSet.Tables[0]
        $configs = $DataSet.Tables[0]
    
        foreach ($config in $configs)
        {
            foreach ($location in $datacenterList)
            {
                try
                {
                    $dc = $location
                    $location = '"' + $location + '"'
                    $thisAvailability = queryBareMetalAvailability -config $($config.id) -dataCenter $location
                    #        $availability += $($thisAvailability.available)
                    #        $total += $($thisAvailability.total)
                    $thisAvailability = $thisAvailability[0]
                    if($($config.alias))
                    {
                        
                    }
                    else
                    {
                        $config.alias = "Unnamed SKU"
                    }
                    $stringout += "*$($dc)* | *$($config.alias)* | $($config.vendor) $($config.model) | RAM: $($config.memory_capacity_gb) GB - CPUs: $($config.cpu_cps) | Available: *$($thisAvailability.available)* | Total:  $($thisAvailability.total)   `n"
                } # end try
                catch
                {
                    $result.success = $false
                    $result.output = "Unable to query bare metal DB."
                } # end catch
            } # end foreach location
        } # end foreach config
    } # end try

    Catch
    {
        $result.success = $false
        $result.output = "Unable to query bare metal DB."
     } # end catch

    <#
    Try
    {
        [void][System.Reflection.Assembly]::LoadWithPartialName("MySql.Data")
        $Connection = New-Object MySql.Data.MySqlClient.MySqlConnection
        $Connection.ConnectionString = $ConnectionString
        $Connection.Open()
        $Command = New-Object MySql.Data.MySqlClient.MySqlCommand($Query, $Connection)
        $DataAdapter = New-Object MySql.Data.MySqlClient.MySqlDataAdapter($Command)
        $DataSet = New-Object System.Data.DataSet
        $RecordCount = $dataAdapter.Fill($dataSet, "data")
        #  $DataSet.Tables[0]
        $available = $DataSet.Tables[0]
    }

    Catch
    {
        Write-Host "ERROR : Unable to run query : $query `n$Error[0]"
    }
    #>

    Finally
    {
            # Create a string for sending back to slack. * and ` are used to make the output look nice in Slack. Details: http://bit.ly/MHSlackFormat
        $result.output = $stringOut
        # Set a successful result
        $result.success = $true
        #$configs
        #$available
        $Connection.Close()
    }
    return $result | ConvertTo-Json
}