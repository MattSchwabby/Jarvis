<#
.CompanyName
    CenturyLink Cloud

.Author
    Dmitry Gancho

.Description
    Collection of functions to work with MS Teams.

.RequiredModules

.RequiredAssemblies
    System.Net.Http

.FunctionsToExport
    # TEAMS API
    Get-TeamsChannel
    Get-TeamsChannelMember
    Send-TeamsMessage
    Send-MyTeamsMessage

    # SLACK MATCH
    New-TeamsMessage

.SERVICE
    Publish-Module

#>

#Requires -Version 5.0


#region SERVICE FUNCTIONS

function InvokeHttpRequest {
    [CmdletBinding()]

    param (
        [Parameter(Mandatory)]
        [uri]$Url,

        [Parameter()]
        [object]$Payload,

        [Parameter()]
        [string]$Token,

        [Parameter()]
        [Alias('to')]
        [uint16]$Timeout
    )

    function SetTypeToLowercase ([string]$json) {
        $pattern = '"Type":(\s*"\w+")'
        $match = [regex]::Match($json, $pattern, 'IgnoreCase')
        $json -replace $pattern, $match.Value.ToLower()
    }

    function ConvertToJson ($object) {
        if ($object -is [string]) {
            SetTypeToLowercase -json $object
        }

        else {
            $json = $object | ConvertTo-Json -Depth 10 #-Compress
            SetTypeToLowercase -json $json
        }
    }

    # only TLSv1.2 is supported: Test-SSLSupport smba.trafficmanager.net
    [System.Net.ServicePointManager]::SecurityProtocol = 'tls12'
    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = $null

    # replace '//' with '/' except 'https://'
    $Url = $Url -replace '([^:]\/)\/', '$1'

    $client = [System.Net.Http.HttpClient]::new()

    if ($Token) {
        $header = [System.Net.Http.Headers.AuthenticationHeaderValue]::new('Bearer', $Token)
        $client.DefaultRequestHeaders.Authorization = $header
    }

    $task = if ($Payload) {
        $call = "POST $Url"
        $call | Write-Verbose

        $json = ConvertToJson -object $Payload
        $json | Write-Verbose

        $content = [System.Net.Http.StringContent]::new($json, [System.Text.Encoding]::UTF8, 'application/json')
        $client.PostAsync($Url, $content)
    }

    else {
        $call = "GET $Url"
        $call | Write-Verbose

        $client.GetAsync($Url)
    }

    $response = if ($Timeout) {
        if ($task.Wait($Timeout)) {
            $task.Result
        }

        else {
            "Http request timed out in {0} ms.`n{1}" -f $Timeout, $call | Write-Error
            return
        }
    }

    else {
        $task.GetAwaiter().GetResult()
    }

    $client.Dispose()
    $response | Write-Verbose

    $content = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()

    if ($content) {
        "Response content:`n$content" | Write-Verbose
    }

    if ($response.IsSuccessStatusCode) {
        if ($content) {
            try {
                DeserialializeJson -json $content
            }

            catch {
                try {
                    $content | ConvertFrom-Json
                }

                catch {
                    $_.Exception.Message | Write-Warning
                    $content
                }
            }
        }
    }

    else {
        $code = [uint16]$response.StatusCode
        $desc = [string]$response.ReasonPhrase
        "$call`nBODY:$json`nRESPONSE:($code) $desc`nCONTENT:$content" | Write-Error
    }
}

function DeserialializeJson ([string]$json) {
<#
.SYNOPSIS
    Deserialize complex .json string, such as response to Receive-DirectLineActivity

.DESCRIPTION
    Author  : Dmitry Gancho
    Created : 6/15/2019
    Updated : 6/16/2019

#>

    function GetDeserializeSettings {
        $s = [Newtonsoft.Json.JsonSerializerSettings]::new()
        $s.NullValueHandling = [Newtonsoft.Json.NullValueHandling]::Ignore
        $s.DefaultValueHandling = [Newtonsoft.Json.DefaultValueHandling]::Ignore
        $s.Formatting = [Newtonsoft.Json.Formatting]::Indented
        $s.MaxDepth = 10
        $s
    }

    function ConvertFromJArray ([Newtonsoft.Json.Linq.JArray]$obj) {
        $list = [System.Collections.ArrayList]::new()

        foreach($item in $obj.GetEnumerator()) {
            $value = ConvertFromJToken -obj $item

            if ($value) {
                [void]$list.Add($value)
            }
        }

        , $list
    }

    function CovertFromJObject ([Newtonsoft.Json.Linq.JObject]$obj) {
        $hash = [ordered]@{}

        foreach($kvp in $obj.GetEnumerator()) {
            $value = ConvertFromJToken -obj $kvp.Value

            if ($value) {
                $hash.Add($kvp.key, $value)
            }
        }

        [pscustomobject]$hash
    }

    function ConvertFromJValue ([Newtonsoft.Json.Linq.JValue]$obj) {
        $obj.Value
    }

    function ConvertFromJToken ([Newtonsoft.Json.Linq.JToken]$obj) {
        if ($obj -is [Newtonsoft.Json.Linq.JArray]) {
            ConvertFromJArray -obj $obj
        }

        elseif ($obj -is [Newtonsoft.Json.Linq.JObject]) {
            CovertFromJObject -obj $obj
        }

        elseif ($obj -is [Newtonsoft.Json.Linq.JValue]) {
            ConvertFromJValue -obj $obj
        }

        else {
            $obj
        }
    }

    $set = GetDeserializeSettings
    $obj = [Newtonsoft.Json.JsonConvert]::DeserializeObject($json, [Newtonsoft.Json.Linq.JObject], $set)
    ConvertFromJToken -obj $obj
}

#endregion



#region TEAMS API

function Get-TeamsChannel {
<#
.SYNOPSIS
    Get Channel(s) of a Teams Team.
    TeamID is required. See Get-AzureGroup.

.DESCRIPTION
    Author  : Dmitry Gancho
    Created : 7/17/2019
    Updated : 7/17/2019

.EXAMPLE
    # All channels.
    $appcred = icr Azure.ChatOpsBots -As HashTable
    $appauth = New-AzureAppAuthentication -GrantType ClientCredentials -Tenant $appcred.TenantName -AppID $appcred.AppID -AppSecret $appcred.AppPassword
    $team    = Get-AzureGroup -Name 'Development Sandbox' -Token $appauth.access_token
    Get-TeamsChannel -TeamId $team.id -Token $appauth.access_token

.EXAMPLE
    # Specified channel.
    $appcred = icr Azure.ChatOpsBots -As HashTable
    $appauth = New-AzureAppAuthentication -GrantType ClientCredentials -Tenant $appcred.TenantName -AppID $appcred.AppID -AppSecret $appcred.AppPassword
    $team    = Get-AzureGroup -Name 'Development Sandbox' -Token $appauth.access_token
    Get-TeamsChannel -Name 'Testing' -TeamId $team.id -Token $appauth.access_token

#>

    [CmdletBinding()]

    param (
        [Parameter()]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$TeamId,

        [Parameter(Mandatory)]
        [string]$Token
    )

    # set url
    $url = "https://graph.microsoft.com/beta/teams/$TeamId/channels"

    # add filter
    if ($Name) {
        $url += "?filter=displayName eq '$Name'"
    }

    # invoke
    do {
        $r = InvokeHttpRequest -Url $url -Token $Token
        $r.value
        $url = $r.'@odata.nextLink'
    } while ($url)
}


function Get-TeamsChannelMember {
<#
.SYNOPSIS
    Get member(s) of a Teams Channel.
    TeamID and ChannelID are required. See Get-AzureGroup and Get-TeamsChannel.
    NOTE: Member ID(s) are Bot-specific.

.DESCRIPTION
    Author  : Dmitry Gancho
    Created : 7/17/2019
    Updated : 7/17/2019

.EXAMPLE
    # All members.
    $botcred = icr Azure.ClcInculert -As HashTable
    $botauth = New-AzureAppAuthentication -GrantType ClientCredentials -Tenant $botcred.TenantName -AppID $botcred.AppID -AppSecret $botcred.AppPassword -Authority Botframework
    Get-TeamsChannelMember -ChannelId $channel.id -Token $botauth.access_token

.EXAMPLE
    # Specified member.
    $botcred = icr Azure.ClcInculert -As HashTable
    $botauth = New-AzureAppAuthentication -GrantType ClientCredentials -Tenant $botcred.TenantName -AppID $botcred.AppID -AppSecret $botcred.AppPassword -Authority Botframework
    Get-TeamsChannelMember -Id dmitry.gancho -ChannelId $channel.id -Token $botauth.access_token

#>

    [CmdletBinding()]

    param (
        [Parameter()]
        [string]$Id,

        [Parameter(Mandatory)]
        [string]$ChannelId,

        [Parameter(Mandatory)]
        [string]$Token
    )

    # filter does not work here
    $url = "https://smba.trafficmanager.net/amer/v3/conversations/$ChannelId/members"
    $members = InvokeHttpRequest -Url $url -Token $Token

    if ($Id) {
        $members | where userPrincipalName -match ^$Id
    }

    else {
        $members
    }
}


function Send-TeamsMessage {
<#
.SYNOPSIS
    Send a message to Teams.
    MAX TEXT LENGTH: 28572 chars

    Options:
    - via the FunctionApp as a Bot
    - via a Webhook
    - Bot-to-User
    - Bot-to-Channel
    - App-as-User

.DESCRIPTION
    Author  : Dmitry Gancho
    Created : 7/17/2019
    Updated : 7/25/2019

.EXAMPLE
    # Via the FunctionApp as a Bot.
    # 1a. Start a channel conversation with a new message.
    $convo = 'Hello Channel (FunctionApp)' | Send-TeamsMessage -BotName tb        -ChannelName Testing -TeamName 'Development Sandbox'
    $convo = 'Hello Channel (FunctionApp)' | Send-TeamsMessage -BotName Inculert  -ChannelName Testing -TeamName 'Development Sandbox'
    $convo = 'Hello Channel (FunctionApp)' | Send-TeamsMessage -BotName Frank     -ChannelName Testing -TeamName 'Development Sandbox'
    $convo = 'Hello Channel (FunctionApp)' | Send-TeamsMessage -BotName AliceMaid -ChannelName Testing -TeamName 'Development Sandbox'
    $convo = 'Hello Channel (FunctionApp)' | Send-TeamsMessage -BotName Skynet    -ChannelName Testing -TeamName 'Development Sandbox'

    # 1b. Reply in a channel conversation.
    'Hello again (FunctionApp, reply)' | Send-TeamsMessage -BotName $convo.BotName -ConversationId $convo.ConversationId -Verbose

    # 2a. Start a direct conversation with a User.
    $convo = 'Hello User (FunctionApp)' | Send-TeamsMessage -BotName tb        -ChannelName Testing -TeamName 'Development Sandbox' -MemberName ccs123
    $convo = 'Hello User (FunctionApp)' | Send-TeamsMessage -BotName Inculert  -ChannelName Testing -TeamName 'Development Sandbox' -MemberName ccs123
    $convo = 'Hello User (FunctionApp)' | Send-TeamsMessage -BotName Frank     -ChannelName Testing -TeamName 'Development Sandbox' -MemberName ccs123
    $convo = 'Hello User (FunctionApp)' | Send-TeamsMessage -BotName AliceMaid -ChannelName Testing -TeamName 'Development Sandbox' -MemberName ccs123
    $convo = 'Hello User (FunctionApp)' | Send-TeamsMessage -BotName Skynet    -ChannelName Testing -TeamName 'Development Sandbox' -MemberName ccs123

    # 2b. Send Typing activity to a conversation with a User.
    Send-TeamsMessage -BotName $convo.BotName -ConversationId $convo.ConversationId -ActivityType Typing

    # 2c. Continue direct conversation with a user.
    'Hello again (FunctionApp, continue)' | Send-TeamsMessage -BotName $convo.BotName -ConversationId $convo.ConversationId

.EXAMPLE
    # Via a Webhook. Webhook is Team/Channel/Connector specific. Can't post replies (?)
    # https://docs.microsoft.com/en-us/microsoftteams/platform/concepts/connectors/connectors-using
    $tenantId = '72b17115-9915-42c0-9f1b-4f98e5a4bcd2' # centurylink.com
    $teamId   = '15fd8009-aec3-4257-b914-fa274588a5b7' # 'Development Sandbox'
    $whUrl    = "https://outlook.office.com/webhook/$teamId@$tenantId/IncomingWebhook/51afe10e38374dc19b0eb02fe8e3ec6e/eec9d3c8-0df2-4e79-a44f-ce1dd3df6953"
    Send-TeamsMessage -Text 'Hello Channel (via Webohhok)' -Webhook $whUrl

.EXAMPLE
    # Bot message to a User in direct chat (BotToUser).
    $appcred = icr Azure.ChatOpsBots -As HashTable
    $appauth = New-AzureAppAuthentication -GrantType ClientCredentials -Tenant $appcred.TenantName -AppID $appcred.AppID -AppSecret $appcred.AppPassword
    $team    = Get-AzureGroup -Name 'Development Sandbox' -Token $appauth.access_token
    $channel = Get-TeamsChannel -Name 'Testing' -TeamId $team.id -Token $appauth.access_token
    $botcred = icr Azure.ClcInculert -As HashTable
    $botauth = New-AzureAppAuthentication -GrantType ClientCredentials -Tenant $botcred.TenantName -AppID $botcred.AppID -AppSecret $botcred.AppPassword -Authority Botframework
    $member  = Get-TeamsChannelMember -Id dmitry.gancho -ChannelId $channel.id -Token $botauth.access_token
    Send-TeamsMessage -Text 'Hello User (BotToUser)' -MemberID $member.id -TenantID $botauth.tenant_id -Token $botauth.access_token -ver

.EXAMPLE
    # Bot message to a Channel (BotToChannel).
    $appcred = icr Azure.ChatOpsBots -As HashTable
    $appauth = New-AzureAppAuthentication -GrantType ClientCredentials -Tenant $appcred.TenantName -AppID $appcred.AppID -AppSecret $appcred.AppPassword
    $team    = Get-AzureGroup -Name 'Development Sandbox' -Token $appauth.access_token
    $channel = Get-TeamsChannel -Name 'Testing' -TeamId $team.id -Token $appauth.access_token
    $botcred = icr Azure.ClcToolbot -As HashTable
    $botauth = New-AzureAppAuthentication -GrantType ClientCredentials -Tenant $botcred.TenantName -AppID $botcred.AppID -AppSecret $botcred.AppPassword -Authority Botframework
    Send-TeamsMessage -Text 'Hello Channel (BotToChannel)' -ChannelID $channel.id -Token $botauth.access_token

.EXAMPLE
    # App message to a Channel as a User (AppAsUser).
    # https://docs.microsoft.com/en-us/graph/api/channel-post-messages
    $appcred  = icr Azure.ChatOpsBots -As HashTable
    $appauth  = New-AzureAppAuthentication -GrantType ClientCredentials -Tenant $appcred.TenantName -AppID $appcred.AppID -AppSecret $appcred.AppPassword
    $team     = Get-AzureGroup -Name 'Development Sandbox' -Token $appauth.access_token
    $channel  = Get-TeamsChannel -Name 'Testing' -TeamId $team.id -Token $appauth.access_token
    $usercred = icr Office365 -As HashTable
    $userauth = New-AzureAppAuthentication -GrantType AuthorizationCode -Tenant $usercred.TenantName -AppId $appcred.AppID -AppSecret $appcred.AppPassword -RefreshToken $usercred.RefreshToken
    Send-TeamsMessage -Text 'Hello Channel (AppAsUser)' -TeamId $team.id -ChannelId $channel.id -Token $userauth.access_token -Verb
  
#>

    [CmdletBinding()]

    param (
        [Parameter(ValueFromPipeline)]
        [string]$Text,

        [Parameter()]
        [ValidateSet('plain', 'markdown', 'xml')]
        [string]$TextFormat = 'plain',

        [Parameter()]
        [ValidateSet('Message', 'Typing')]
        [Alias('type')]
        [string]$ActivityType = 'Message',

        [Parameter(Mandatory, ParameterSetName = 'FunctionApp')]
        [ValidateSet('tb', 'Inculert', 'Frank', 'AliceMaid', 'Skynet')]
        [string]$BotName,

        [Parameter(ParameterSetName = 'FunctionApp')]
        [Alias('UserName', 'User')]
        [string]$MemberName,

        [Parameter(ParameterSetName = 'FunctionApp')]
        [string]$ChannelName,

        [Parameter(ParameterSetName = 'FunctionApp')]
        [string]$TeamName,

        [Parameter(ParameterSetName = 'FunctionApp')]
        [string]$ConversationId,

        [Parameter(Mandatory, ParameterSetName = 'Webhook')]
        [string]$Webhook,

        [Parameter(Mandatory, ParameterSetName = 'BotToUser')]
        [string]$TenantId,

        [Parameter(Mandatory, ParameterSetName = 'AppAsUser')]
        [string]$TeamId,

        [Parameter(Mandatory, ParameterSetName = 'BotToChannel')]
        [Parameter(Mandatory, ParameterSetName = 'AppAsUser')]
        [string]$ChannelId,

        [Parameter(Mandatory, ParameterSetName = 'BotToUser')]
        [string]$MemberId,

        [Parameter(Mandatory, ParameterSetName = 'BotToChannel')]
        [Parameter(Mandatory, ParameterSetName = 'AppAsUser')]
        [Parameter(Mandatory, ParameterSetName = 'BotToUser')]
        [string]$Token
    )

    switch ($PSCmdlet.ParameterSetName) {

        FunctionApp {
            $activity = @{
                type           = $ActivityType
                text           = $Text
                textFormat     = $TextFormat
                botName        = $BotName
                memberName     = $MemberName
                channelName    = $ChannelName
                teamName       = $TeamName
                conversationId = $ConversationId
                token          = $Token
            }

#            $url = 'https://chatopsbots.azurewebsites.net/api/OutgoingActivityHandler?code=vvz044ZkMdDwpJjr4sAsl7lkxPWfjadu7syTvsU8wZBrKhowTvWoOQ=='
            $url = 'https://chatopsbots.azurewebsites.net/root/message'
            InvokeHttpRequest -Url $url -Payload $activity
        }

        Webhook {
            # only body/text is mandatory
            $activity = @{
                text = $Text
            }

            InvokeHttpRequest -Url $Webhook -Payload $activity
        }

        BotToChannel {
            if ($ChannelId.Split(';').Count -eq 2) {
                # contains messageid: reply to it (existing conversation)
                # ex: 19:673be8bb3a5a43fd93da2dee45c0d1da@thread.skype;messageid=1563324826950
                $activity = @{
                    text       = $Text
                    textFormat = $TextFormat
                    type       = $ActivityType
                }

                $url = "https://smba.trafficmanager.net/amer/v3/conversations/$ChannelId/activities/"
                InvokeHttpRequest -Url $url -Payload $activity -Token $Token
            }

            else {
                # no messageid: start new conversation
                # ex: 19:673be8bb3a5a43fd93da2dee45c0d1da@thread.skype 
                $activity = @{
                    text       = $Text
                    textFormat = $TextFormat
                    type       = $ActivityType
                }

                $payload = @{
                    activity    = $activity
                    channelData = @{
                        channel = @{
                            id = $ChannelId
                        }
                    }
                }

                $url = "https://smba.trafficmanager.net/amer/v3/conversations"
                InvokeHttpRequest -Url $url -Payload $payload -Token $Token
            }
        }

        BotToUser {
            # start conversation
            $payload = @{
                isGroup = $false
                members = @(
                    @{
                        id = $MemberId
                    }
                )
                channelData = @{
                    tenant = @{
                        id = $TenantId
                    }
                }
            }

            $url = "https://smba.trafficmanager.net/amer/v3/conversations/"
            $convo   = InvokeHttpRequest -Url $url -Payload $payload -Token $Token
            $convoId = $convo.id

            # post activity
            $activity = @{
                text       = $Text
                textFormat = $TextFormat
                type       = $ActivityType
            }

            $url = "https://smba.trafficmanager.net/amer/v3/conversations/$convoId/activities/"
            $act = InvokeHttpRequest -Url $url -Payload $activity -Token $Token

            [PSCustomObject]@{
                id         = $convoId
                activityId = $act.id
            }
        }

        AppAsUser {
            # https://docs.microsoft.com/en-us/graph/api/channel-post-messages
            # https://docs.microsoft.com/en-us/graph/api/resources/chatmessage
            # only body/content is mandatory
            $payload = @{
                body = @{
                    contentType = 'html'
                    content = $Text
                }
            }

            $url = "https://graph.microsoft.com/beta/teams/$TeamId/channels/$ChannelId/messages"
            InvokeHttpRequest -Url $url -Payload $payload -Token $Token
        }
    }
}


function Send-MyTeamsMessage {
<#
.SYNOPSIS
    Send a message to Teams on behalf of a User.
    Prereq: Locally saved creds must contain:
    - Azure.ChatOpsBots : TenantName, AppID, AppPassword
    - Office365         : RefreshToken

.DESCRIPTION
    Author  : Dmitry Gancho
    Created : 7/18/2019
    Updated : 7/18/2019

.EXAMPLE
    # By names:
    Send-MyTeamsMessage -Text 'Good morning. <tt>New-Shift</tt>' -Team 'Customer Care' -Channel 'Speakeasy'
    Send-MyTeamsMessage -Text 'Normal text. <tt>monospace text</tt>' -Team 'Development Sandbox' -Channel 'Testing'

.EXAMPLE
    # By IDs (slightly faster):
    $text = 'Normal <font face="verdana" size="2" color="red">verdana red <font color="blue"><tt>monospace blue</tt></font>'
    Send-MyTeamsMessage -Text $text -Team 15fd8009-aec3-4257-b914-fa274588a5b7 -Channel 19:673be8bb3a5a43fd93da2dee45c0d1da@thread.skype

#>

    [CmdletBinding()]

    param (
        [Parameter(Mandatory)]
        [string]$Text,

        [Parameter(Mandatory)]
        [string]$Team,

        [Parameter(Mandatory)]
        [string]$Channel
    )

    $appCred = Import-Credential -FriendlyName Azure.ChatOpsBots -As HashTable
    $tenant  = $appCred.TenantName
    $appId   = $appCred.AppId
    $appPass = $appCred.AppPassword

    $token    = Import-Credential -FriendlyName Office365 -EntryName RefreshToken
    $userAuth = New-AzureAppAuthentication -GrantType AuthorizationCode -Tenant $tenant -AppId $appId -AppSecret $appPass -RefreshToken $token

    # get TeamID
    $teamId = if ([guid]::TryParse($Team, [ref][guid]::Empty)) {
        $Team
    }

    else {
        $appAuth = New-AzureAppAuthentication -Tenant $tenant -AppID $appId -AppSecret $appPass
        $teamObj = Get-AzureGroup -Name $Team -Token $appAuth.access_token
        $teamObj.id
    }

    # get ChannelID 19:673be8bb3a5a43fd93da2dee45c0d1da@thread.skype
    $channelId = if ($Channel -match '^\d{2}:\w{10,}@thread.skype$') {
        $Channel
    }

    else {
        if (-not $appAuth) {
            $appAuth = New-AzureAppAuthentication -Tenant $tenant -AppID $appId -AppSecret $appPass
        }

        $channelObj = Get-TeamsChannel -Name $Channel -TeamId $teamId -Token $appAuth.access_token
        $channelObj.id
    }

    Send-TeamsMessage -Text $Text -TeamId $teamId -ChannelId $channelId -Token $userAuth.access_token
    Send-TeamsMessage -Text $Text -Token
}

#endregion



#region SLACK MATCH

function New-TeamsMessage {
<#
.SYNOPSIS
    Post a message to Teams via Azure OutgoingActivityHandle function.
    This function is intended to match New-SlackMessage as close as possible.

.DESCRIPTION
    Author  : Dmitry Gancho
    Created : 7/22/2019
    Updated : 7/22/2019

.EXAMPLE
    # Post message to a channel. Returns conversation id (unsure how to use it).
    New-TeamsMessage -Text TEST -Team 'Development Sandbox' -Channel 'Testing'

.EXAMPLE
    # Post direct message to a user. Returns ???
    New-TeamsMessage -Text TEST -User dmitry.gancho

.EXAMPLE
    # Post message and a follow up reply to a channel.
    $conversation = New-TeamsMessage -Text 'Main message' -Team 'Development Sandbox' -Channel 'Testing'
    New-TeamsMessage -Text 'Reply message' -Team 'Development Sandbox' -Channel 'Testing' -ConversationId $conversation.id

.NOTES
{
  "type": "message",
  "text": "Hello world"
  "from": {
    "name": "tb"
  },
  "conversation": {
    "id": "19:673be8bb3a5a43fd93da2dee45c0d1da@thread.skype"
  },
  "serviceUrl": "https://smba.trafficmanager.net/amer/",
}

New-TeamsMessage -Text TEST -Team 'Development Sandbox' -Channel 'Testing' -Verbose
#>

    [CmdletBinding()]

    param (
        [Parameter(ValueFromPipeline)]
        [string]$Text,

        [Parameter(Mandatory, ParameterSetName = 'ToChannel')]
        [string]$Channel,

        [Parameter(ParameterSetName = 'ToChannel')]
        [string]$ConversationId,

        [Parameter(Mandatory, ParameterSetName = 'ToChannel')]
        [string]$Team,

        [Parameter(Mandatory, ParameterSetName = 'ToUser')]
        [string]$User,

        [Parameter(ParameterSetName = 'FunctionApp')]
        [ValidateSet('jarvis')]
        [string]$BotName = 'jarvis'
    )
    if($ConversationId -eq $null){
        $ConversationId = "a:1Lt_pLZAahTJBXKImnMxB62aX7ojkkAPW5ZoXcRtQOITRB1_wLywKDSflsezZFsoaAJiHpUb4tVNVAWXm1o-jq0BbonN8ZVDsDknBk27RqcM619vRj_Du6TRf66B5d70v"
    }
    # build json
    $obj = switch ($PSCmdlet.ParameterSetName) {
        ToChannel {
            @{
                type = 'message'
                text = $Text
                from = @{
                    name = $BotName
                }
                conversation = @{
                    id = $ConversationId
                    #id = '1:1EjLwE4fvL6ETnEhC8aAkaC4WAUEdr_eV-bkF9SbkpmM'
                }
                serviceUrl = 'https://smba.trafficmanager.net/amer/'
            }
        }

        ToUser {
        }
    }
    
    $json = $obj | ConvertTo-Json -Depth 10
    $json | Write-Verbose

    # Azure function url (hardcoded)
    $url = 'https://chatopsbots.azurewebsites.net/root/message'

    InvokeHttpRequest -Url $url -Payload $json
}

#endregion