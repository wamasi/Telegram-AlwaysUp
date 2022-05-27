param (
    [Parameter(Mandatory = $false)]
    [Alias('NC')]
    [switch]$NewConfig
)
function Write-ConsoleMessage {
    param (
        [Parameter(Mandatory = $true)]
        [string]$ConsoleMsg
    )
    Write-Host "$(Get-Timestamp) - $ConsoleMsg"
    Write-Output "$(Get-Timestamp) - $ConsoleMsg" | Out-File $TelegramAlwaysUpLog -Append
}
function Get-TimeStamp {
    return (Get-Date -Format 'yy-MM-dd HH-mm-ss')
}
function Resolve-Command {
    param (
        [Parameter(Mandatory = $true)]
        [string]$cmdText
    )
    if ($cmdText -match ' ') {
        $cmdValue = $cmdText -split ' '
    }
    else {
        $cmdValue = $cmdText
    }
    return $cmdValue
}
function Get-AlwaysUpResponse {
    param (
        [Parameter(Mandatory = $false)]
        [string]$AppFunction,
        [Parameter(Mandatory = $false)]
        [string]$AppName,
        [Parameter(Mandatory = $false)]
        [string]$AppTag
    )
    [hashtable]$return = @{}
    $APStatusRepsonse = ''
    $AN = "&application=$($AppName)"
    $AT = "&tag=$($AppTag)"
    $AURI = "$($AlwaysUpBase)$($AppFunction)?password=$($AlwaysUpKey)$($AN)$($AT)&verbose=true"
    $AlwaysUpResponse = Invoke-WebRequest -Uri $AURI
    if ($Appfunction -ne 'get-status' ) {
        $return.content = $AlwaysUpResponse.content
        $return.StatusCode = $AlwaysUpResponse.StatusCode
        $return.StatusDescription = $AlwaysUpResponse.StatusDescription
        return $return
    }
    if ($AppFunction -eq 'get-status') {
        $AlwaysUpXML = [xml]$AlwaysUpResponse
        $APStatusRepsonse = $AlwaysUpXML.'alwaysup-get-status-response'.applications.application | Select-Object name, state, tags | Sort-Object tags
        $msg = '<b>STATUS:</b>' + "`n"
        $AppList = ''
        $SEL
        $APStatusRepsonse | Select-Object name, state | ForEach-Object {
            $AppList = '<b>App: </b>' + $_.name + "`n<b>Status: </b>" + $_.state + "`n"
            $msg += $AppList + "`n"
        }
        $return.msg = $msg
        $return.state = $APStatusRepsonse.state
        return $return
    }
}
function Invoke-AlwaysUp {
    param (
        [Parameter(Mandatory = $true)]
        $msgTextAU,
        [Parameter(Mandatory = $true)]
        $cmdActionAU,
        [Parameter(Mandatory = $true)]
        $cmdParamAU,
        [Parameter(Mandatory = $true)]
        $appProgramAU,
        [Parameter(Mandatory = $true)]
        $AppNameAU,
        [Parameter(Mandatory = $true)]
        $APTAU
    )
    $PreCheck = Get-AlwaysUpResponse -AppFunction 'get-status' -AppName $AppName -AppTag $APT
    $PrecheckState = $PreCheck.state
    switch ($cmdAction) {
        start { $actionType = 'start'; $acceptableStates = 'Stopped' }
        stop { $actionType = 'stop'; $acceptableStates = 'Running', 'Waiting' }
        restart { $actionType = 'restart'; $acceptableStates = 'Running', 'Waiting' }
        default { $actionType = ''; "$cmdAction is invalid." ; break }
    }
    if (( $PrecheckState -in $acceptableStates -and $actionType -ne '')) {
        $actionMsg = '{0} - {1} is currently in "{2}" status. Command executing "{3}".' -f $appProgram, $AppName, $PrecheckState, $actionType
        $StatusAU = Get-AlwaysUpResponse -AppFunction $actionType -AppName $AppName
        Write-ConsoleMessage "$appProgram Response: StatusCode: $($StatusAU.StatusCode) - Status: $($StatusAU.StatusDescription) - Content: $($StatusAU.content)."
        SendTGMessage -Messagetext $actionMsg -ChatID $Telegramchatid
        $PostCheck = Get-AlwaysUpResponse -AppFunction 'get-status' -AppName $AppName -AppTag $APT
        $PostCheckStatus = $PostCheck.state
        while ($true) {
            if ($PrecheckState -eq $PostCheckStatus -and $actionType -ne 'restart') {
                $PostCheck = Get-AlwaysUpResponse -AppFunction 'get-status' -AppName $AppName -AppTag $APT
                $PostCheckStatus = $PostCheck.state
                continue
            }
            elseif ($PrecheckState -ne $PostCheckStatus -and $actionType -eq 'restart') {
                $PostCheck = Get-AlwaysUpResponse -AppFunction 'get-status' -AppName $AppName -AppTag $APT
                $PostCheckStatus = $PostCheck.state
                continue
            }
            else {
                $actionMsg = '{0} - {1} is now in "{2}" status. Command executed.' -f $appProgram, $AppName, $PostCheckStatus, $actionType
                SendTGMessage -Messagetext $actionMsg -ChatID $Telegramchatid
                Write-ConsoleMessage $actionMsg
                break
            }
            Start-Sleep -Milliseconds 1
        }
    }
    elseif ($actionType -eq '') {
        $StatusAU = "$($msgText) Incorrect command."
        SendTGMessage -Messagetext $StatusAU -ChatID $Telegramchatid
    }
    else {
        $astatelist = [String]::Join(', ', $acceptableStates);
        $actionMsg = '{0} - {1} is currently in "{2}" status. Was expecting {4} status(es). Not executing command "{3}".' -f $appProgram, $AppName, $PrecheckState, $actionType, $astatelist
        $StatusAU = 'Incorrect command parameter'
        SendTGMessage -Messagetext $actionMsg -ChatID $Telegramchatid
        Write-ConsoleMessage $actionMsg
    }
}
function Invoke-Sonarr {
    param (
        [Parameter(Mandatory = $true)]
        $msgTextAU,
        [Parameter(Mandatory = $true)]
        $cmdActionAU,
        [Parameter(Mandatory = $true)]
        $cmdParamAU,
        [Parameter(Mandatory = $true)]
        $appProgramAU,
        [Parameter(Mandatory = $true)]
        $AppNameAU,
        [Parameter(Mandatory = $true)]
        $APTAU
    )
}
function Invoke-Radarr  {
    param (
        [Parameter(Mandatory = $true)]
        $msgTextAU,
        [Parameter(Mandatory = $true)]
        $cmdActionAU,
        [Parameter(Mandatory = $true)]
        $cmdParamAU,
        [Parameter(Mandatory = $true)]
        $appProgramAU,
        [Parameter(Mandatory = $true)]
        $AppNameAU,
        [Parameter(Mandatory = $true)]
        $APTAU
    )
}
function Invoke-Prowlarr {
    param (
        [Parameter(Mandatory = $true)]
        $msgTextAU,
        [Parameter(Mandatory = $true)]
        $cmdActionAU,
        [Parameter(Mandatory = $true)]
        $cmdParamAU,
        [Parameter(Mandatory = $true)]
        $appProgramAU,
        [Parameter(Mandatory = $true)]
        $AppNameAU,
        [Parameter(Mandatory = $true)]
        $APTAU
    )
}
function Get-MsgTime {
    param (
        [Parameter(Mandatory = $true)]
        [int]$Epoc
    )
    $oUNIXDate = (Get-Date 01.01.1970) + ([System.TimeSpan]::fromseconds($Epoc))
    $finalDate = Get-Date $oUNIXDate -Format u #display value
    $finalDate
}
function ReadTGMessage {
    #Read Incomming message
    try {
        $inMessage = Invoke-RestMethod -Method Get -Uri ( $TelegramBase + 'getUpdates?offset=-1') -ErrorAction Stop
        $inMessageResult = $inMessage.result[-1]
        Write-Host "$(Get-Timestamp) - Checking for new Messages $inMessageResult"
        return $inMessageResult
    }
    Catch {
        Write-Host $_.exception.message -ForegroundColor red
        return 'TelegramFail'
    }
}
function SendTGMessage {
    #Send Message to Telegram Service
    param(
        $Messagetext,
        $ChatID
    )
    $MessageTextFormat = ''
    $TGMessage = "Preparing to send Telegram Message`n"
    $TGMessage += "$(Get-Timestamp) - ----------------- Message that will be sent ----------------`n"
    if ($Messagetext -match "`n") {
        $MessageTextFormat = $Messagetext -split "`n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
        foreach ($line in $MessageTextFormat) {
            $TGMessage += "$(Get-TimeStamp) - $line`n"
        }
    }
    else {
        $TGMessage += "$(Get-Timestamp) - $Messagetext"
    }
    $TGMessage = $TGMessage.Trim()
    $TGMessage += "`n$(Get-Timestamp) - ---------------- End of Message ---------------------------"
    Write-ConsoleMessage "$($TGMessage.Trim())"
    Invoke-WebRequest -Uri "$($TelegramBase)sendMessage?chat_id=$($ChatID)&text=$($Messagetext)&parse_mode=html" | Out-Null
    Write-ConsoleMessage 'Message has been sent.'
}
# Setup
$ScriptDirectory = $PSScriptRoot
$ConfigPath = "$ScriptDirectory\config.xml"
$xmlConfig = @'
<?xml version="1.0" encoding="utf-8"?>
<configuration>
    <Telegram>
        <token tokenId="" chatid="" />
    </Telegram>
    <Commands>
        <cmd Program="" type="" cmd="" description="" />
        <cmd Program="" type="" cmd="" description="" />
        <cmd Program="" type="" cmd="" description="" />
        <cmd Program="" type="" cmd="" description="" />
        <cmd Program="" type="" cmd="" description="" />
        <cmd Program="" type="" cmd="" description="" />
        <cmd Program="" type="" cmd="" description="" />
    </Commands>
    <credentials>
        <site siteName="" username="" password="" baseIP="" basePort ="" />
        <site siteName="" username="" password="" baseIP="" basePort ="" />
        <site siteName="" username="" password="" baseIP="" basePort ="" />
        <site siteName="" username="" password="" baseIP="" basePort ="" />
    </credentials>
    <Logs>
        <keeplog emptylogskeepdays="0" filledlogskeepdays="7" />
    </Logs>
</configuration>
'@
if ($NewConfig) {
    if (!(Test-Path $ConfigPath -PathType Leaf) -or [String]::IsNullOrWhiteSpace((Get-Content $ConfigPath))) {
        New-Item $ConfigPath -ItemType File -Force
        Write-ConsoleMessage "$ConfigPath File Created successfully."
        $xmlconfig | Set-Content $ConfigPath
        exit
    }
    else {
        Write-ConsoleMessage "$ConfigPath File Exists."
        exit
    }
}
$ConfigFile = [xml](Get-Content -Path $ConfigPath)
$Telegramtoken = $ConfigFile.configuration.Telegram.token.tokenId
$Telegramchatid = $ConfigFile.configuration.Telegram.token.chatid
$TelegramBase = "https://api.telegram.org/bot$($Telegramtoken)/"
$validApps = $ConfigFile.configuration.Commands.cmd | Where-Object { $_.appAlias.trim() -ne '' } | Select-Object Program, appAlias, appName, description
$AlwaysUpKey = $ConfigFile.configuration.credentials.site | Where-Object { $_.siteName.ToLower() -eq 'AlwaysUp' } | Select-Object -ExpandProperty password
$AlwaysUpBaseIP = $ConfigFile.configuration.credentials.site | Where-Object { $_.siteName.ToLower() -eq 'AlwaysUp' } | Select-Object -ExpandProperty baseIp
$AlwaysUpBasePort = $ConfigFile.configuration.credentials.site | Where-Object { $_.siteName.ToLower() -eq 'AlwaysUp' } | Select-Object -ExpandProperty basePort
$AlwaysUpBase = "http://$($AlwaysUpBaseIP):$($AlwaysUpBasePort)/api/"
$intialMessage = ReadTGMessage
$InitialMsgID = $intialMessage[0].message.message_id
$InitialMsgTime = Get-MsgTime $intialMessage[0].message.date
$InitialChatId = $intialMessage[0].message.chat.id
$TelegramAlwaysUpLog = "$ScriptDirectory\TelegramAlwaysUp.log"
if (!(Test-Path $TelegramAlwaysUpLog -PathType Leaf)) {
    New-Item $TelegramAlwaysUpLog -ItemType File -Force
    Write-ConsoleMessage "$TelegramAlwaysUpLog File Created successfully."
    Write-ConsoleMessage "New Message Time: $msgTime. New MessageID: $InitialMsgID."
}
else {
    $startUpMsg = @"
--------------------- $(Get-TimeStamp) ---------------------
$(Get-TimeStamp) - $TelegramAlwaysUpLog script starting up.
$(Get-TimeStamp) - New Message Time: $InitialMsgTime. New MessageID: $InitialMsgID.
$(Get-TimeStamp) - ------------------------------------------------------------
"@
    Write-ConsoleMessage $startUpMsg
    SendTGMessage -Messagetext 'Script starting up.' -ChatID $Telegramchatid
}
# Main
while ($true) {
    Start-Sleep 1
    $messages = ReadTGMessage
    $msgText = $messages[0].message.text
    $msgId = $messages[0].message.message_id
    $msgTime = Get-MsgTime $messages[0].message.date
    if ($messages -like 'TelegramFail') {
        Write-ConsoleMessage 'Issue fetching message. Check the authentication Key...'
        Start-Sleep -Seconds 10
    }
    if ($msgText -match '/.*' -and ($InitialChatId -eq $Telegramchatid) -and ($msgTime -gt $InitialMsgTime) -and ($msgId -gt $InitialMsgID)) {
        Write-ConsoleMessage "Telegram recieved: $msgText"
        if ($msgText -match '/.*') {
            $textcmd = ($msgText -replace '/').TrimStart()
            $acceptableStates = @{}
            $APT = ''
            $CMD = $textcmd -split ' '
            $cmdAction = [string]$CMD[0]
            $cmdParam = [string]$CMD[1]
            if ($cmdParam -notin $validApps.appAlias -and $cmdAction -notin 'status', 'reboot') {
                $StatusAU = "($msgText) is not a valid."
                SendTGMessage -Messagetext $StatusAU -ChatID $Telegramchatid
                Write-ConsoleMessage $StatusAU
            }
            elseif ($cmdAction -eq 'status') {
                $actionType = 'get-status'
                $actionMsg = "AlwaysUp - $actionType - Sending status of all AlwaysUp objects."
                $StatusAU = Get-AlwaysUpResponse -AppFunction $actionType
                SendTGMessage -Messagetext $StatusAU.msg -ChatID $Telegramchatid
                Write-ConsoleMessage $actionMsg
            }
            elseif ($cmdAction -eq 'reboot') {
                $actionType = 'reboot'
                $actionMsg = "AlwaysUp - $actionType - Sending computer reboot command."
                $StatusAU = Get-AlwaysUpResponse -AppFunction $actionType
                Write-ConsoleMessage "$appProgram Response: StatusCode: $($StatusAU.StatusCode) - Status: $($StatusAU.StatusDescription) - Content: $($StatusAU.content)."
                SendTGMessage -Messagetext $StatusAU.msg -ChatID $Telegramchatid
                Write-ConsoleMessage $actionMsg
            }
            else {
                $AppDetails = $ConfigFile.configuration.Commands.cmd | Where-Object { $_.appAlias.ToLower() -eq $cmdParam.ToLower() } | Select-Object Program, appAlias, appName, description
                $appProgram = $AppDetails.Program
                $AppName = $AppDetails.appName
                if ($null -eq $AppName -or $null -eq $appProgram) {
                    Write-ConsoleMessage "$cmdParam is invalid."
                }
                else {
                    if ( $appProgram -eq 'Alwaysup') {
                        Invoke-AlwaysUp $msgText $cmdAction $cmdParam $appProgram $AppName $APT
                    }
                    elseif ( $appProgram -eq 'Sonarr') {
                        Invoke-Sonarr $msgText $cmdAction $cmdParam $appProgram $AppName $APT
                    }
                    elseif ( $appProgram -eq 'Radarr') {
                        Invoke-Radarr $msgText $cmdAction $cmdParam $appProgram $AppName $APT
                    }
                    elseif ( $appProgram -eq 'Prowlarr') {
                        Invoke-Prowlarr $msgText $cmdAction $cmdParam $appProgram $AppName $APT
                    }
                    else {
                        $msg = "Incorrect command($msgText)."
                        SendTGMessage -Messagetext $msg -ChatID $Telegramchatid
                        Write-ConsoleMessage $msg
                    }
                }
            }
        }
        else {
            $msg = "Incorrect command parameter($msgText)."
            SendTGMessage -Messagetext $msg -ChatID $Telegramchatid
            Write-ConsoleMessage $msg
        }
        $msgTime = $InitialMsgTime
        $InitialMsgID = $msgId
        Write-ConsoleMessage "New Message Time: $msgTime. New MessageID: $InitialMsgID."
    }
    elseif ( ($msgText.trim() -ne '' -or $null -eq $msgText) -and ($msgText -notmatch '/.*') -and ($InitialChatId -eq $Telegramchatid) -and ($msgTime -gt $InitialMsgTime) -and ($msgId -gt $InitialMsgID)) {
        $msg = 'Not a valid command.'
        SendTGMessage -Messagetext $msg -ChatID $Telegramchatid
        $msgTime = $InitialMsgTime
        $InitialMsgID = $msgId
        Write-ConsoleMessage $msg
        Write-ConsoleMessage "New Message Time: $msgTime. New MessageID: $InitialMsgID."
    }
}