# AlwaysUp-Telegram
 
#### Powershell script used with Alwaysup Web API to check on status or to start/stop/restart a service through Telegram.

## Prerequisites

Powershell
- Tested with 7.2+

AlwaysUp
- Need AlwaysUp and AlwaysUp Web installed on machine

Telegram
- Used to send out a message of videos successfully downloaded to a group chat.
- Personal account
- Bot account
- group chat

## Script Setup/Execution Walkthrough:
1. Run `path\to\Telegram_AlwaysUp.ps1 -nc`
2. Fill out xml with
   - Telegram tokenId and chatId
   - AlwaysUp Commmands paramters.
     - ex.: `<cmd Program="AlwaysUp" appAlias="Plex" appName="Plex Media Server" description="" />`
   - AlwaysUp Credentials
     - Note: Password setup through AlwaysUp Web API service is used in its MD5 hash not the original password you created.
 3. Run `path\to\Telegram_AlwaysUp.ps1`
   - If configured correctly you should see it checking for messages from the chat group.
