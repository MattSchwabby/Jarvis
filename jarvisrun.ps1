$dir = [System.IO.Path]::GetDirectoryName($MyInvocation.MyCommand.Source)
[void][System.Reflection.Assembly]::LoadFrom("$dir\Microsoft.ServiceBus.5.2.0.dll")
[void][System.Reflection.Assembly]::LoadFrom("$dir\Microsoft.Bot.Schema.4.3.2.dll")
[void][System.Reflection.Assembly]::LoadFrom("$dir\Microsoft.Rest.ClientRuntime.2.3.20.dll")
Add-Type -AssemblyName System.Net.Http
Import-Module (Resolve-Path('msbotmodule.psm1')) -Force


function getConnectionString
{
    [CmdletBinding()]
    Param
    (
    )
    
    $import = "C:\users\administrator\JK\config.json"

    $config = get-content $import -Raw | convertfrom-json

    $JK1 = $config.jk1
    $JK9 = $config.jk9 | ConvertTo-SecureString


    $V1Credential = New-Object –TypeName System.Management.Automation.PSCredential –ArgumentList $JK1, $JK9
    return $V1Credential.GetNetworkCredential().Password
}

$ConnStr = getConnectionString

function New-AzureServiceBusQueueClient {
<#
.SYNOPSIS
    Create new ServiceBus queue client from a ConnectionString.
.DESCRIPTION
    Author  : Dmitry Gancho/Trevor Huff
    Created : 5/1/2019
    Updated : 10/08/2019
.EXAMPLE
    # Using ServiceBus connection string and Queue name.
    New-AzureServiceBusQueueClient -ServiceBusConnectionString CONNSTR -EntityPath QUEUENAME
.EXAMPLE
    # Using ServiceBus Queue connection string.
    New-AzureServiceBusQueueClient -ServiceBusQueueConnectionString CONNSTR
.LINK
    https://docs.microsoft.com/en-us/azure/service-bus-messaging/
.LINK
    https://docs.microsoft.com/en-us/dotnet/api/microsoft.servicebus.messaging.messagingfactory.createqueueclient
.NOTES
#>
    [CmdLetBinding()]
    param (
        [Parameter(Mandatory, ParameterSetName = 'SBQueueConnectionString')]
        [Alias('QueueConnectionString')]
        [string]$ServiceBusQueueConnectionString,
        [Parameter(Mandatory, ParameterSetName = 'SBConnectionString')]
        [Alias('ConnectionString')]
        [string]$ServiceBusConnectionString,
        [Parameter(Mandatory, ParameterSetName = 'SBConnectionString')]
        [Alias('Queue')]
        [string]$EntityPath,
        [Parameter()]
        [Microsoft.ServiceBus.Messaging.ReceiveMode]$ReceiveMode = ([Microsoft.ServiceBus.Messaging.ReceiveMode]::ReceiveAndDelete)
    )
    switch ($PSCmdlet.ParameterSetName) {
        SBQueueConnectionString {
            # remove EntityPath from ConnectionString
            $dict = [System.Collections.Generic.Dictionary[string, string]]::new()
            $ServiceBusQueueConnectionString.Split(';').ForEach{
                $key, $value = $_.Split('=', 2)
                $dict.Add($key, $value)
            }
            $ServiceBusConnectionString = @(
                "Endpoint={0}"            -f $dict.Endpoint
                "SharedAccessKeyName={0}" -f $dict.SharedAccessKeyName
                "SharedAccessKey={0}"     -f $dict.SharedAccessKey
            ) -join ';'
            $EntityPath = $dict.EntityPath
        }
    }
    $nsmanager = [Microsoft.ServiceBus.NamespaceManager]::CreateFromConnectionString($ServiceBusConnectionString)
    $settings  = [Microsoft.ServiceBus.Messaging.MessagingFactorySettings]::new()
    $settings.TokenProvider = $nsmanager.Settings.TokenProvider
    $settings.NetMessagingTransportSettings.BatchFlushInterval = 2
    $factory = [Microsoft.ServiceBus.Messaging.MessagingFactory]::Create($nsmanager.Address, $settings)
    $factory.CreateQueueClient($EntityPath, $ReceiveMode)
}

$SbClient   = New-AzureServiceBusQueueClient -ServiceBusQueueConnectionString $ConnStr -ReceiveMode ReceiveAndDelete

$wait = [timespan]::FromSeconds([uint32]::MaxValue)
#Set this on while debugging so you don't have to message jarvis...
#$wait = [timespan]::FromSeconds(30)

while($true){

Write-Host "Listening..."
# blocking
[Microsoft.ServiceBus.Messaging.BrokeredMessage]$brokeredMessage = $SbClient.Receive($wait)

# read 
$flags    = [System.Reflection.BindingFlags]'Public, Instance'
$msgType  = $brokeredMessage.GetType()
$method   = $msgType.GetMethod('GetBody', $flags, $null, @(), $null)
$contType = [type]::GetType($brokeredMessage.ContentType, $false, $true)
$message = if ($contType) {
    $genMethod = $method.MakeGenericMethod($contType)
    $genMethod.Invoke($BrokeredMessage, $null)
}
else {
    #$stream = Invoke-GenericMethod -InputObject $message -MethodName GetBody -GenericType System.IO.Stream
    $genMethod = $method.MakeGenericMethod([System.IO.Stream])
    $stream    = $genMethod.Invoke($brokeredMessage, $null)
    $reader    = [System.IO.StreamReader]::new($stream)
    $reader.ReadToEnd()
    $stream.Dispose()
    $reader.Dispose()
}
if ($SbClient.Mode -eq [Microsoft.ServiceBus.Messaging.ReceiveMode]::PeekLock) {
    $brokeredMessage.Complete()
}

$jsonMessage = $message | ConvertFrom-Json
$cmd = {
param($1)
$jsonMessage = $1;
Write-Output $jsonMessage 
#Hardcoded for convienence, sorry.
$dir = "C:\\Users\Administrator\Documents\Jarvis"
[void][System.Reflection.Assembly]::LoadFrom("$dir\Microsoft.ServiceBus.5.2.0.dll")
[void][System.Reflection.Assembly]::LoadFrom("$dir\Microsoft.Bot.Schema.4.3.2.dll")
[void][System.Reflection.Assembly]::LoadFrom("$dir\Microsoft.Rest.ClientRuntime.2.3.20.dll")
Add-Type -AssemblyName System.Net.Http
Import-Module (Resolve-Path('Jarvis\msbotmodule.psm1')) -Force
Import-Module (Resolve-Path('Jarvis\lib\accountInfo.ps1')) -Force
Import-Module (Resolve-Path('Jarvis\lib\bareMetalMySQLPROD.ps1')) -Force
Import-Module (Resolve-Path('Jarvis\lib\customerSearch.ps1')) -Force
Import-Module (Resolve-Path('Jarvis\lib\getAliases.ps1')) -Force
Import-Module (Resolve-Path('Jarvis\lib\getAllCurrentCustomers.ps1')) -Force
Import-Module (Resolve-Path('Jarvis\lib\getContactInfo.ps1')) -Force
Import-Module (Resolve-Path('Jarvis\lib\GetCrossDCs.ps1')) -Force
Import-Module (Resolve-Path('Jarvis\lib\getCurrentCustomers.ps1')) -Force
Import-Module (Resolve-Path('Jarvis\lib\GetDCs.ps1')) -Force
Import-Module (Resolve-Path('Jarvis\lib\GetEstimate.ps1')) -Force
Import-Module (Resolve-Path('Jarvis\lib\GetInventory.ps1')) -Force
Import-Module (Resolve-Path('Jarvis\lib\GetInvoice.ps1')) -Force
Import-Module (Resolve-Path('Jarvis\lib\getMRR.ps1')) -Force
Import-Module (Resolve-Path('Jarvis\lib\getParents.ps1')) -Force
Import-Module (Resolve-Path('Jarvis\lib\GetTwoWeekReport.ps1')) -Force
Import-Module (Resolve-Path('Jarvis\lib\resourceLimits.ps1')) -Force
Import-Module (Resolve-Path('Jarvis\lib\serverCount.ps1')) -Force
Import-Module (Resolve-Path('Jarvis\lib\supportLevel.ps1')) -Force
Import-Module (Resolve-Path('Jarvis\lib\showMeTheMoneyv2.ps1')) -Force
Import-Module (Resolve-Path('Jarvis\lib\showMeTheMoney.ps1')) -Force
Import-Module (Resolve-Path('Jarvis\lib\GetConsumptionReport.ps1')) -Force
Import-Module (Resolve-Path('C:\\Windows\System32\WindowsPowerShell\v1.0\Modules\loginCLCAPI\loginCLCAPI.psm1')) -Force
Import-Module (Resolve-Path('Jarvis\lib\prettyPrint.ps1')) -Force

#debug receive message
#Write-Host $message
#Write-Host $jsonMessage.text
#Write-Host $jsonMessage.conversation.id

#Null text check
if($jsonMessage.text -ne $null){
try{

$incomingText = $jsonMessage.text -split(" ")

#If you're speaking directly to jarvis or not.
if ($incomingText[0] -Match "Jarvis"){
$offset = 1
}else{
$offset = 0
}
$currentCommand = $incomingText[$offset]

Write-Output $CurrentCommand
switch($currentCommand){
   {$currentCommand -Match "account"} {
     $alias = $incomingText[2+$offset].Trim()
     New-TeamsMessage -Text "Getting the MRR, server count, support level, home data center, business name, number of sub accounts and compute resource consumption for the account alias $alias..." -Team 'Development Sandbox' -Channel 'Testing' -ConversationId $jsonMessage.conversation.id ;
     $resultMessage = doPrettyPrint (accountInfo -alias $alias);
     New-TeamsMessage -Text $resultMessage -Team 'Development Sandbox' -Channel 'Testing' -ConversationId $jsonMessage.conversation.id;}

   {$currentCommand -Match "bare"} {New-TeamsMessage -Text 'Getting the available bare metal SKUs in each data center....' -Team 'Development Sandbox' -Channel 'Testing' -ConversationId $jsonMessage.conversation.id;
     $bareMetalServers = bareMetal;
     New-TeamsMessage -Text $bareMetalServers -Team 'Development Sandbox' -Channel 'Testing' -ConversationId $jsonMessage.conversation.id}

   {$currentCommand -Match "contact"} {
     $alias = $incomingText[2+$offset].Trim()
     New-TeamsMessage -Text "Getting the account administrators for account alias $alias..." -Team 'Development Sandbox' -Channel 'Testing' -ConversationId $jsonMessage.conversation.id
     $resultMessage = doPrettyPrint (getContactInfo -alias $alias);
     New-TeamsMessage -Text $resultMessage -Team 'Development Sandbox' -Channel 'Testing' -ConversationId $jsonMessage.conversation.id}

   {$currentCommand -Match "cross"} {
     $alias = $incomingText[2+$offset].Trim()
     New-TeamsMessage -Text "Getting the information for cross data center connectivity for account alias $alias..." -Team 'Development Sandbox' -Channel 'Testing' -ConversationId $jsonMessage.conversation.id
     $resultMessage = doPrettyPrint (GetCrossDCs -alias $alias);
     New-TeamsMessage -Text $resultMessage -Team 'Development Sandbox' -Channel 'Testing' -ConversationId $jsonMessage.conversation.id}

   {$currentCommand -Contains "customer"} {
     $query = $incomingText[2+$offset].Trim()
     New-TeamsMessage -Text "Searching for an account alias that matches the given query: $query" -Team 'Development Sandbox' -Channel 'Testing' -ConversationId $jsonMessage.conversation.id
     $resultMessage = doPrettyPrint (customerSearch -customerQuery $query);
     New-TeamsMessage -Text $resultMessage.replace('\u0027', '*') -Team 'Development Sandbox' -Channel 'Testing' -ConversationId $jsonMessage.conversation.id}

   {$currentCommand -Contains "customers"} {
     $datacenter = $incomingText[1+$offset].Trim()
     $email = $incomingText[2+$offset].Trim()
     New-TeamsMessage -Text "Creating a list of customers in datacenter $datacenter to be e-mailed to $email. This may take me a little while..." -Team 'Development Sandbox' -Channel 'Testing' -ConversationId $jsonMessage.conversation.id
     $resultMessage = doPrettyPrint (getCurrentCustomers -datacenter $datacenter -email $email);
     New-TeamsMessage -Text $resultMessage -Team 'Development Sandbox' -Channel 'Testing' -ConversationId $jsonMessage.conversation.id}

   {$currentCommand -Match "dcs"} {
     $alias = $incomingText[1+$offset].Trim()
     New-TeamsMessage -Text "Getting the data center footprint for the given alias $alias..." -Team 'Development Sandbox' -Channel 'Testing' -ConversationId $jsonMessage.conversation.id
     $resultMessage = doPrettyPrint (getDCs -alias $alias);
     New-TeamsMessage -Text $resultMessage -Team 'Development Sandbox' -Channel 'Testing' -ConversationId $jsonMessage.conversation.id}
     
   {$currentCommand -Match "estimate"} {
     $alias = $incomingText[2+$offset].Trim()
     New-TeamsMessage -Text "Calculating the estimated MRR and month to date billing figure for the account alias $alias. For larger accounts, this may take about fifteen minutes or longer..." -Team 'Development Sandbox' -Channel 'Testing' -ConversationId $jsonMessage.conversation.id
     $resultMessage = doPrettyPrint (getEstimate -alias $alias);
     New-TeamsMessage -Text $resultMessage -Team 'Development Sandbox' -Channel 'Testing' -ConversationId $jsonMessage.conversation.id}

   {$currentCommand -Match "inventory"} {
     $alias = $incomingText[1+$offset].Trim()
     $email = $incomingText[2+$offset].Trim()
     New-TeamsMessage -Text "Sending a server inventory for the $alias account to $email. If this is a large account, it might take me a couple minutes..." -Team 'Development Sandbox' -Channel 'Testing' -ConversationId $jsonMessage.conversation.id
     $resultMessage =  doPrettyPrint (getInventory -alias $alias -email $email);
     New-TeamsMessage -Text $resultMessage -Team 'Development Sandbox' -Channel 'Testing' -ConversationId $jsonMessage.conversation.id}
     
   {$currentCommand -Match "invoice"} {
     $alias = $incomingText[1+$offset].Trim()
     $month = $incomingText[2+$offset].Trim()
     $year = $incomingText[3+$offset].Trim()
     $email = $incomingText[4+$offset].Trim()
     New-TeamsMessage -Text "Sending the $month $year invoice for the $alias account to $email" -Team 'Development Sandbox' -Channel 'Testing' -ConversationId $jsonMessage.conversation.id
     $resultMessage = doPrettyPrint (getInvoice -alias $alias -month $month -year $year -email $email);
     New-TeamsMessage -Text $resultMessage -Team 'Development Sandbox' -Channel 'Testing' -ConversationId $jsonMessage.conversation.id}

   {$currentCommand -Match "mrr"} {
     $alias = $incomingText[1+$offset].Trim()
     New-TeamsMessage -Text "Getting the most recent MRR for the account alias $alias..." -Team 'Development Sandbox' -Channel 'Testing' -ConversationId $jsonMessage.conversation.id
     $resultMessage = doPrettyPrint (getMRR -alias $alias);
     New-TeamsMessage -Text $resultMessage -Team 'Development Sandbox' -Channel 'Testing' -ConversationId $jsonMessage.conversation.id}

   {$currentCommand -Match "parents"} {
     $alias = $incomingText[1+$offset].Trim()
     New-TeamsMessage -Text "Getting a list of parent accounts that are above the $alias account..." -Team 'Development Sandbox' -Channel 'Testing' -ConversationId $jsonMessage.conversation.id
     $resultMessage = doPrettyPrint (getParents -alias $alias);
     New-TeamsMessage -Text $resultMessage -Team 'Development Sandbox' -Channel 'Testing' -ConversationId $jsonMessage.conversation.id}

   {$currentCommand -Match "resource"} {
     $alias = $incomingText[2+$offset].Trim()
     New-TeamsMessage -Text "Getting the virtual resource consumption vs. account resource limits for the account alias $alias..." -Team 'Development Sandbox' -Channel 'Testing' -ConversationId $jsonMessage.conversation.id
     $resultMessage = doPrettyPrint (resourceLimits -alias $alias);
     New-TeamsMessage -Text $resultMessage -Team 'Development Sandbox' -Channel 'Testing' -ConversationId $jsonMessage.conversation.id}

   {$currentCommand -Match "server"} {
     $alias = $incomingText[2+$offset].Trim()
     New-TeamsMessage -Text "Getting the server count for all accounts rolling up to the parent account alias $alias..." -Team 'Development Sandbox' -Channel 'Testing' -ConversationId $jsonMessage.conversation.id
     $resultMessage = doPrettyPrint (serverCount -alias $alias);
     New-TeamsMessage -Text $resultMessage -Team 'Development Sandbox' -Channel 'Testing' -ConversationId $jsonMessage.conversation.id}

   {$currentCommand -Match "subs"} {
     $alias = $incomingText[1+$offset].Trim()
     New-TeamsMessage -Text "Getting a list of sub accounts that are under the alias $alias..." -Team 'Development Sandbox' -Channel 'Testing' -ConversationId $jsonMessage.conversation.id
     $resultMessage = doPrettyPrint (getAliases -alias $alias);
     New-TeamsMessage -Text $resultMessage -Team 'Development Sandbox' -Channel 'Testing' -ConversationId $jsonMessage.conversation.id}

   {$currentCommand -Match "support"} {
     $alias = $incomingText[2+$offset].Trim()
     New-TeamsMessage -Text "Getting the support level for the account alias $alias..." -Team 'Development Sandbox' -Channel 'Testing' -ConversationId $jsonMessage.conversation.id
     $resultMessage = doPrettyPrint (supportLevel -alias $alias);
     New-TeamsMessage -Text $resultMessage -Team 'Development Sandbox' -Channel 'Testing' -ConversationId $jsonMessage.conversation.id}

   {$currentCommand -Match "utilization"} {
     $alias = $incomingText[2+$offset].Trim()
     $email = $incomingText[3+$offset].Trim()
     New-TeamsMessage -Text "Sending a two week utilization report for the $alias account to the email $email. This will take several minutes or longer, depending on the amount of sub accounts and assets in the account..." -Team 'Development Sandbox' -Channel 'Testing' -ConversationId $jsonMessage.conversation.id
     $resultMessage = doPrettyPrint (getTwoWeekReport -alias $alias -email $email);
     New-TeamsMessage -Text $resultMessage -Team 'Development Sandbox' -Channel 'Testing' -ConversationId $jsonMessage.conversation.id}

     #----SMTM----- 

   {$currentCommand -Match "report"} {
     $alias = $incomingText[1+$offset].Trim()
     $month = $incomingText[2+$offset].Trim()
     $year = $incomingText[3+$offset].Trim()
     $email = $incomingText[4+$offset].Trim()
     New-TeamsMessage -Text "Getting revenue report for the account $alias for the invoice $month $year and sending it to the email $email..." -Team 'Development Sandbox' -Channel 'Testing' -ConversationId $jsonMessage.conversation.id
     $resultMessage = doPrettyPrint (showMeTheMoneyv2 -alias $alias  -invoiceMonth $month -invoiceYear $year -email $email);
     New-TeamsMessage -Text $resultMessage -Team 'Development Sandbox' -Channel 'Testing' -ConversationId $jsonMessage.conversation.id}

   {$currentCommand -Match "specify"} {
     $alias = $incomingText[2+$offset].Trim()
     $usageMonth = $incomingText[3+$offset].Trim()
     $usageYear = $incomingText[4+$offset].Trim()
     $pricingMonth = $incomingText[5+$offset].Trim()
     $pricingYear = $incomingText[6+$offset].Trim()
     $includeSubs = $incomingText[7+$offset].Trim()
     $email = $incomingText[8+$offset].Trim()
     New-TeamsMessage -Text "Requesting a revenue report for account $alias with usage from $usageMonth $usageYear and pricing from $pricingMonth $pricingYear with a subaccount toggle of $includeSubs and sending it to the email address $email..." -Team 'Development Sandbox' -Channel 'Testing' -ConversationId $jsonMessage.conversation.id
     $resultMessage = doPrettyPrint (showMeTheMoney -alias $alias  -usageMonth $usageMonth -usageYear $usageYear -pricingMonth $pricingMonth -pricingYear $pricingYear -includeSubs $includeSubs -email $email);
     New-TeamsMessage -Text $resultMessage -Team 'Development Sandbox' -Channel 'Testing' -ConversationId $jsonMessage.conversation.id}

   {$currentCommand -Match "consumption"} {
     $alias = $incomingText[2+$offset].Trim()
     $start = $incomingText[3+$offset].Trim()
     $end = $incomingText[4+$offset].Trim()
     $reseller= $incomingText[5+$offset]
     $email = $incomingText[6+$offset].Trim()
     New-TeamsMessage -Text "Requesting a consumption report for customer $alias with a start date $start and an end date $end with a reseller toggle $reseller and send it to the email address $email..." -Team 'Development Sandbox' -Channel 'Testing' -ConversationId $jsonMessage.conversation.id
     $resultMessage = doPrettyPrint (getConsumptionReport -alias $alias  -start $start -end $end -reseller $reseller -email $email);
     New-TeamsMessage -Text $resultMessage -Team 'Development Sandbox' -Channel 'Testing' -ConversationId $jsonMessage.conversation.id}

   {$currentCommand -Match "help"} {
   $grave = [char]0x0060
   New-TeamsMessage -Text "$grave @jarvis account info <alias> $grave - Returns the MRR, server count, support level, home data center, business name, number of sub accounts and compute resource consumption for a given account alias (server count includes templates and machines that are powered off).`n
$grave @jarvis bare metal $grave - Returns the available Bare Metal SKUs in each data center, as well as the remaining available amounts..`n
$grave @jarvis contact info <alias> $grave - Returns a list of account administrators containing names, email addresses, phone numbers and titles for a given account alias.`n
$grave @jarvis cross dcs <alias> $grave- returns the cross data center connectivity for all accounts rolling up to a given parent alias.`n
$grave @jarvis customer search <search query> (example: @jarvis customer search P&G) $grave- Search for a customer account alias by company name.`n
$grave @jarvis customers <data center> <email> (example: @jarvis customers VA1 trevor.huff@ctl.io) $grave- Sends the requester a list of customers for a given CLC data center to a given e-mail address.`n
$grave @jarvis dcs <alias> $grave- Returns the data center footprint of the given account alias.`n
$grave @jarvis estimate mrr <alias> $grave- Returns the estimated MRR and month to date billing figure of a given account alias.`n
$grave @jarvis inventory <alias> <email> $grave- Emails the requester a server inventory rolling up all sub accounts to a given parent alias (includes templates and machines that are powered off).`n
$grave @jarvis invoice <alias> <month (ex: 03)> <year (ex: 2016)> <email> $grave- Emails the requester a usage invoice for a given account alias, month and year. (Note: This data is pulled directly from the API and has not been processed through BRM or Vantive).`n
$grave @jarvis mrr <alias> $grave- Returns the most recent MRR for a given account alias. Will display a chart breaking down the spend per data center (Note: This data is pulled from the API and has not processed through BRM or Vantive).`n
$grave @jarvis parents <alias> $grave- Returns a list of parent accounts for the given alias.`n
$grave @jarvis resource limits <alias> $grave- Returns the aggregate consumed resources in a given account alias vs the limits set at the account level in the Platform.`n
$grave @jarvis server count <alias> $grave- Returns the amount of servers in a given account alias (includes templates and machines that are powered off).`n
$grave @jarvis subs <alias> $grave- Returns a list of sub accounts for the given alias.`n
$grave @jarvis support level <alias> $grave- Returns the support level for a given account alias (does not analyze sub accounts).`n
$grave @jarvis utilization report <alias> <email> - Emails the requester a two week CenturyLink Cloud utilization report for a given account alias $grave- rolls up all sub accounts (does not include machines that are powered off or templates).`n
$grave @jarvis report <alias> <invoiceMonth (ex: 06)> <invoiceYear (ex: 2016)> <email> $grave- Returns a revenue report for account alias for the invoice month and yearto be e-mailed.`n
$grave @jarvis specify pricing <alias> <usage month (ex. 06)> <usage year (ex. 2016)> <pricing month (ex. 12)> <pricing year (ex. 2016)> <sub accounts (y/n)> <email> $grave- Returns a revenue report for account alias with usage from usageMonth usageYear and pricing from pricingMonth pricingYear with a subaccount toggle of includeSubs to be e-mailed.`n
$grave @jarvis consumption report <alias> <start date (ex. 2016-10-01)> <end date (ex. 2016-11-01)> <reseller toggle (y/n)> <e-mail (ex. trevor.huff@ctl.io)> $grave- Returns a consumption report for customer alias with a start date and an end date  with a reseller toggle to be emailed. `n
$grave @jarvis help $grave- Displays all of the commands that Jarvis knows about." -Team 'Development Sandbox' -Channel 'Testing' -ConversationId $jsonMessage.conversation.id}
   default { New-TeamsMessage -Text "Sorry I don't understand that command." -Team 'Development Sandbox' -Channel 'Testing' -ConversationId $jsonMessage.conversation.id }
}}catch{Write-Output "crashed"
Write-Output $ErrorMessage = $_.Exception.Message}
}
}
$job = Start-Job -ScriptBlock $cmd -ArgumentList @($jsonMessage)

#If you want to see a single job or all jobs
#$result = Receive-Job -Job $job
#$allResults = Get-Job
#Write-Host $results
#Write-Output $allResults

#Delete completed jobs after X amount of jobs
$maxNumberOfJobs = 10
If($allResults.Count -ge $maxNumberOfJobs){
foreach ($curJob in $allResults) {
   if($curJob.State -eq "Completed"){
      Remove-Job -Id $curJob.Id
     }
}
}
} 


