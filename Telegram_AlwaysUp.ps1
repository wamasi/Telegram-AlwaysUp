param (
    [Parameter(Mandatory = $false)]
    [Alias('NC')]
    [switch]$NewConfig
)
function Get-Day {
    return (Get-Date -Format 'yy-MM-dd')
}
function Get-TimeStamp {
    return (Get-Date -Format 'yy-MM-dd HH-mm-ss')
}
function Get-Time {
    return (Get-Date -Format 'MMddHHmmss')
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
        $msg = $AlwaysUpResponse.content
        return $msg
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
        $return.status = $APStatusRepsonse.state
        $return.msg = $msg
        return $return
    }
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
        return 'TGFail'
    }
}
function SendTGMessage {
    #Send Message to Telegram Service
    param(
        $Messagetext,
        $ChatID
    )
    Write-Host "$(Get-Timestamp) - Preparing to send TG Message" 
    Write-Host '----------------- Message that will be sent ----------------'
    Write-Host $Messagetext
    Write-Host ' ---------------- End of Message ---------------------------'
    Invoke-WebRequest -Uri "$($TelegramBase)sendMessage?chat_id=$($ChatID)&text=$($Messagetext)&parse_mode=html"
    Write-Host "$(Get-Timestamp) - Message should be sent"
}
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
        Write-Output "$(Get-Timestamp) - $ConfigPath File Created successfully."
        $xmlconfig | Set-Content $ConfigPath
        exit
    }
    else {
        Write-Output "$(Get-Timestamp) - $ConfigPath File Exists."
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
while ($true) {
    Start-Sleep 1
    $messages = ReadTGMessage
    $msgText = $messages[0].message.text
    $msgId = $messages[0].message.message_id
    $msgTime = Get-MsgTime $messages[0].message.date
    if ($messages -like 'TGFail') {
        Write-Host "$(Get-Timestamp) - Issue fetching message. Check the authentication Key..."
        Start-Sleep -Seconds 10
    }
    if ($msgText -match '/.*' -and ($InitialChatId -eq $Telegramchatid) -and ($msgTime -gt $InitialMsgTime) -and ($msgId -gt $InitialMsgID)) {
        # get-status, restart, start, stop, reboot(!PC!)
        Write-Host "$(Get-Timestamp) - Recieved: $msgText"
        if ($msgText -match '/.*') {
            $textcmd = ($msgText -replace '/').TrimStart()
            $acceptableStates = @{}
            $APT = ''
            $CMD = $textcmd -split ' '
            $cmdAction = [string]$CMD[0]
            $cmdParam = [string]$CMD[1]
            if ($cmdParam -notin $validApps.appAlias -and $cmdAction -ne 'status') {
                $StatusAU = "($cmdAction) or ($cmdParam) is not a valid command combination."
                SendTGMessage -Messagetext $StatusAU -ChatID $Telegramchatid
                
            }
            $AppDetails = $ConfigFile.configuration.Commands.cmd | Where-Object { $_.appAlias.ToLower() -eq $cmdParam.ToLower() } | Select-Object Program, appAlias, appName, description
            $appProgram = $AppDetails.Program
            $AppName = $AppDetails.appName
            if ($null -eq $AppName -and $cmdAction -ne 'status') {
                Write-Host "$cmdParam is invalid."
            }
            if ( $appProgram -eq 'Alwaysup') {
                $PreCheck = Get-AlwaysUpResponse -AppFunction 'get-status' -AppName $AppName -AppTag $APT
                $PrecheckState = $PreCheck.status
                switch ($cmdAction) {
                    start { $actionType = 'start'; $acceptableStates = 'Stopped' }
                    stop { $actionType = 'stop'; $acceptableStates = 'Running', 'Waiting' }
                    restart { $actionType = 'restart'; $acceptableStates = 'Running', 'Waiting' }
                    reboot { $actionType = 'reboot' }
                    status { $actionType = 'get-status' }
                    default { $actionType = ''; "$cmdAction is invalid." ; break }
                }
                if (( $PrecheckState -in $acceptableStates -and $actionType -ne '')) {
                    $actionMsg = '{0} - {1} is currently in "{2}" status. Command executing "{3}".' -f $appProgram, $AppName, $PrecheckState, $actionType
                    $StatusAU = Get-AlwaysUpResponse -AppFunction $actionType -AppName $AppName
                    SendTGMessage -Messagetext $actionMsg -ChatID $Telegramchatid
                    $PostCheck = Get-AlwaysUpResponse -AppFunction 'get-status' -AppName $AppName -AppTag $APT
                    $PostCheckStatus = $PostCheck.status
                    while ($true) {
                        if ($PrecheckState -eq $PostCheckStatus -and $actionType -ne 'restart') {
                            $PostCheck = Get-AlwaysUpResponse -AppFunction 'get-status' -AppName $AppName -AppTag $APT
                            $PostCheckStatus = $PostCheck.status
                            continue
                        }
                        elseif ($PrecheckState -ne $PostCheckStatus -and $actionType -eq 'restart') {
                            $PostCheck = Get-AlwaysUpResponse -AppFunction 'get-status' -AppName $AppName -AppTag $APT
                            $PostCheckStatus = $PostCheck.status
                            continue
                        }
                        else {
                            $actionMsg = '{0} - {1} is now in "{2}" status. Command executed.' -f $appProgram, $AppName, $PostCheckStatus, $actionType
                            SendTGMessage -Messagetext $actionMsg -ChatID $Telegramchatid
                            Write-Host $actionMsg
                            break
                        }
                        Start-Sleep -Milliseconds 500
                    }
                }elseif ($actionType -eq '') {
                    $StatusAU = 'Incorrect command'
                    SendTGMessage -Messagetext $StatusAU -ChatID $Telegramchatid
                }
                else {
                    $astatelist = [String]::Join(', ', $acceptableStates);
                    $actionMsg = '{0} - {1} is currently in "{2}" status. Was expecting {4} status(es). Not executing command "{3}".' -f $appProgram, $AppName, $PrecheckState, $actionType, $astatelist
                    $StatusAU = 'Incorrect command parameter'
                    SendTGMessage -Messagetext $actionMsg -ChatID $Telegramchatid
                    Write-Host $actionMsg
                }
            }
            elseif ($cmdAction -eq 'status') {
                $actionType = 'get-status'
                $actionMsg = '{0} - {1}. Sending status of all AlwaysUp objects' -f $appProgram, $actionType
                $StatusAU = Get-AlwaysUpResponse -AppFunction $actionType
                $StatusAU.msg
                SendTGMessage -Messagetext $StatusAU.msg -ChatID $Telegramchatid
                Write-Host $actionMsg
            }
            else {
                $msg = 'Incorrect command.'
                SendTGMessage -Messagetext $msg -ChatID $Telegramchatid
            }
        }
        else {
            $msg = 'Incorrect command parameter'
            SendTGMessage -Messagetext $msg -ChatID $Telegramchatid
        }
        <# TO DO:
        Logs
        #>
        $msgTime = $InitialMsgTime
        $InitialMsgID = $msgId
    }
    elseif ( ($msgText.trim() -ne '' -or $null -eq $msgText) -and ($msgText -notmatch '/.*') -and ($InitialChatId -eq $Telegramchatid) -and ($msgTime -gt $InitialMsgTime) -and ($msgId -gt $InitialMsgID)) {
        $msg = 'Not a valid command.'
        SendTGMessage -Messagetext $msg -ChatID $Telegramchatid
        $msgTime = $InitialMsgTime
        $InitialMsgID = $msgId
    }
}