<#
.Synopsis
    A user wants find the account alias for a CenturyLink Cloud customer.
.Description
    Searches the consumption database for any text matching the users query.
.Author
    Matt Schwabenbauer
    Matt.Schwabenbauer@ctl.io
.Example
    customerSearch -query 'Coca Cola'
#>
function customerSearch
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true)]
        $customerQuery
    )

    # Create a hashtable for the results
    $result = @{}
    $errorcode = $null

    $escapeCharCheck = $null
    $escapeCharCheck = $($customerQuery)
    $escapeCharCheck = $escapeCharCheck -replace "\\","\\"
    $escapeCharCheck = $escapeCharCheck -replace "'","''"
    $escapeCharCheck = $escapeCharCheck -replace '"','""'
    $escapeCharCheck = $escapeCharCheck -replace "%","\%"
    $escapeCharCheck = $escapeCharCheck -replace "_","\_"
    $customerQuery = $escapeCharCheck
    
    # Use try/catch block            
    try
    {
        $query = "SELECT * FROM consumption.customers WHERE customer_name LIKE '%$($customerQuery)%' ORDER BY valid_as_of DESC LIMIT 1
        ;"
        
        try
        {
            $MySQLAdminUserName = "consumption"
            $consumptionDBLogin = consumptionDBLogin | ConvertTo-SecureString
            $credential = New-Object –TypeName System.Management.Automation.PSCredential –ArgumentList $consumptionDBLogin, $consumptionDBLogin
            $MySQLAdminPassword = $credential.GetNetworkCredential().Password
            $MySQLDatabase = "consumption"
            $MySQLHost = "consumption.uc1.rdbs.ctl.io"
            $ConnectionString = "server=" + $MySQLHost + ";port=49357;uid=" + $MySQLAdminUserName + ";pwd=" + $MySQLAdminPassword + ";database="+$MySQLDatabase
            [void][System.Reflection.Assembly]::LoadWithPartialName("MySql.Data")
            $Connection = New-Object MySql.Data.MySqlClient.MySqlConnection
            $Connection.ConnectionString = $ConnectionString
            $Connection.Open()
            $Command = New-Object MySql.Data.MySqlClient.MySqlCommand($Query, $Connection)
            $DataAdapter = New-Object MySql.Data.MySqlClient.MySqlDataAdapter($Command)
            $DataSet = New-Object System.Data.DataSet
            $RecordCount = $dataAdapter.Fill($dataSet, "data")
            $response = $dataset.tables
            $nullcheck = $response.alias
        }
        catch
        {
            $SQLresponse = "ERROR : Unable to run query : $query `n$Error[0]"
        }
        finally
        {
            $Connection.Close()
        }
      
        if(!$nullcheck)
        {
            # Create a string for sending back to slack. * and ` are used to make the output look nice in Slack. Details: http://bit.ly/MHSlackFormat
            $result.output = "Unable to find a search result for query: '$($customerQuery)'."
      
            # Set a successful result
            $result.success = $false
        }
        else
        {
            # Create a string for sending back to slack. * and ` are used to make the output look nice in Slack. Details: http://bit.ly/MHSlackFormat
            $result.output = "Customer search result for query '$($customerQuery)': Account alias: *$($response.alias)*, Business name: *$($response.customer_name)*"
      
            # Set a successful result
            $result.success = $true
        }


    }

    # Catch some errors and send a failed response
    catch
    {
        $result.output = "Failed to return query for $($customerQuery). $SQLResponse."
       
        $result.success = $false
    }
    return $result | ConvertTo-Json
}