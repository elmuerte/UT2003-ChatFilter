# UT2003-ChatFilter

ChatFilter is a server add-on to clean up the chatting on a server. ChatFilter has the power to reduce spamming on a server, it can also filter bad words from the line. On bad behavior the player will get a score assigned on a defined level actions can taken against the player.

### New in version 101:
- added the option to save the chat to a log. for some reason ChatFilter doesn't get the destroyed event so I can't close the log file the normal way, because of this you will see a lot "Opening user log" messages in the server log file

### New in version 102:
- Bad words inside words are now also replaced: shithead -> *****head
- added a new spam protection to allow a maximum number of lines per time frame, use fTimeFrame and iMaxPerTimeFrame to control the settings
- The log format was changed a bit, lines are now prefixed with the number of seconds since the game was on.

### New in version 103:
- Check on BadWords in a players nick name. For this to work you need to add ChatFilter to the ServerPackages. If you have ConfigManager loaded it will automatically added when this feature is enabled, but it will not be removed when it's disabled.
- Fixed the output to the log file, it now no longer opens/closes the file on each line.

### New in version 104:
- When you use ConfigManager the ServerPackage will automatically be added or removed when needed.
- Fixed the TeamSay message

### New in version 150:
- Add a new option: bFriendlyMessage with this a player will get a dialog with the reason why he/she was removed from the server. This requires ChatFilterMsg to be in the ServerPackages list (ConfigManager will do this automatically). Default is off.
- Create a seperate ServerPackage called ChatFilterMsg
- Added a new kill option: CFA_Warn, this will warn the player about his chat behavior and notify the other players. The other players can vote to punish the player by. New config options for this:
   - sWarningNotification message the player will get
   -sWarningBroadcast message all players will get
   -WarningAction The action to take when player need to be punished
   -iMaxWarnings maximum number of warning before the server auto matically punishes the player
   -fMinVote percentage of players required to vote before the player is punished
- Added a new kill option: CFA_Mute, this will mute the player for the rest of the game.
New config options for this:
   -sMuteMessage the message the player will get
- Player punishments are now logged to the chat log

### New in version 151:
- fixed the bug in the 'mutate cf judge' command - added a new feature: check for unallowed nicknames. Sometimes you don't want some names to be used: Admin or Player
Config option: UnallowedNicks
- added a new feature to bCheckNicknames: BadnickAction
By default this is: BNA_Kick , this will kick the user when it has a bad nick name. You can also set it to BNA_Request. This will pop up a message to change the nickname while remain connected to the server.
- Note: from now on you should use "ChatFilterMsg151" as server package This is to prevent version issues. Remove the old "ChatFilterMsg" line

### New in version 152:
- bShowMuted, When this is true a player will keep seeing (on his HUD) that he has been muted for the rest of the game.
- Seperate messages for foul words in the nick or unallowed nick
- Changed the nick check routine, and hopefully fixed a problem with it
- Note: from now on you should use "ChatFilterMsg152" as server package This is to prevent version issues. Remove the old "ChatFilterMsg" and "ChatFilterMsg151" line

### New in version 153:
- Added server info (gametype map mutators) on the second line after the "Log started" message, prefixed with "==="
- Added an optional replacement table that will allow you to set per bad word replacements. To use this set the following config variable:
   - bUseReplacementTable=true
   - To set diffirent replacement for a word you have to enter it as follows:
```
BadWords=shit;sh*t
BadWords=fuck;f#ck
BadWords=uses default replacement
```

### New in version 154:
- fixed the "Muted hud" it's removed now at the end of the game Note that you have to remove the old ChatFilterMsg152 from the ServerPackages and add ChatFilterMsg154

### New in version 155:
- Fixed all gui stuff, I forgot to update the references to the new package name.
Note that you have to remove the old ChatFilterMsg154 from the ServerPackages and add ChatFilterMsg155 - Fixed the appearing "lizard" head

### New in version 156: 
- Added BadNickActions: BNA_Ban and BNA_SessionBan to ban a player from the server, or just this game

### New in version 157: 
- UnallowedNicks may now contain wild cards: '*' for zero or more characters, and '?' for a single character.
For example: *_[TDS]
Installation
Copy the .u and .int files to the UT2003 System directory. If you have ConfigManager installed on your server you just have to restart the server and ChatFilter will automatically be installed. If you don't have ConfigManager installed do the following:

Open up your server configuration (UT2003.ini) and add the following line:

```
  [Engine.GameEngine]
  ServerActors=ChatFilter.ChatFilter
```

Now when you start your server you should see the following lines in the log:

```
  [~] Loading ChatFilter version 153
  [~] Michiel 'El Muerte' Hendriks - ...
  [~] The Drunk Snipers - http://www.drunksnipers.com
```

Configuration
The configuration of the behavior of ChatFilter resides in the server configuration file (UT2003.ini). Add the following lines to the file:

```
  [ChatFilter.ChatFilter]
  bFriendlyMessage=false
  fTimeFrame=1.0000
  iMaxPerTimeFrame=2
  iMaxRepeat=1
  iScoreSpam=1
  CencorWord=*****
  iScoreSwear=1
  iKillScore=10
  KillAction=CFA_Nothing
  BadWords=asshole
  BadWords=fuck
  ...
  bUseReplacementTable=false
  bCheckNicknames=false
  sWarningNotification="ChatFilter: Please clean up your act"
  sWarningBroadcast="%s is chatting abusive, type 
		      'mutate cf judge %i` to judge the player"
  WarningAction=CFA_Kick
  iMaxWarnings=2
  fMinVote=0.5000
  sMuteMessage="ChatFilter: You are muted the rest of the game"
  bLogChat=false
  sLogDir=""
  sFileFormat="ChatFilter_%P_%Y_%M_%D_%H_%I_%S"
```

### bFriendlyMessage
Display a friendly message window when a player gets removed from the server. When you enable this feature you must add ChatFilterMsg to the ServerPackages list.
    
### fTimeFrame
Set the number of seconds of a single time frame

### iMaxPerTimeFrame
Maximum number of lines allowed per time frame

### iMaxRepeat
The maximum times a player can say the same line in a row

### iScoreSpam
The score to add when a player exceeds the iMaxRepeat value

### CencorWord
Text to replace BadWords with

### iScoreSwear
The score to add for every bad word

### iKillScore
The maximum score a player may have before actions will be taken

### KillAction
Action to take against the player:

- CFA_Nothing do nothing
- CFA_Kick kick the player
- CFA_Ban ban the player
- CFA_SessionBan ban the player for this game
- CFA_Defrag remove one point of the players score
- CFA_Warn the player will be warned
- CFA_Mute the player will be muted for the rest of the game 

### BadWords
Words that are considderd bad/swearing. By default no words are added

### bUseReplacementTable
Uses the a per badword replacement, BadWords have to be divided with a ; to change the replacement, or the default if omitted. For example:

```
BadWords=shit;sh*t
BadWords=hate;love
```

### bCheckNicknames
Check the players nick name for BadWords. When you enable this feature you must add ChatFilterMsg to the ServerPackages list.

### sWarningNotification
The message a player will get when he gets warned

### sWarningBroadcast
The message all players get when somebody get's warned. "%s" is replaced by the player name, and "%i" is replaced by the filter record contain information about this user, required for the `mutate cf judge` command

### WarningAction
The action to take when a player get's voted off or exceeds the maximum warnings. You can choose from the same actions as KillAction, except CFA_Warn ofcourse

### iMaxWarnings
The maximum number of warnings before the server automatically takes action

### fMinVote
The minimum percentage of players on the server that have to vote before actions are taken against the warned player

### sMuteMessage
The message a player get's when he's muted for the rest of the game

### bLogChat
Save the chat to a log file

### bLogDir
The directory where to store the log files, this has to end with a slash, and the directory has to exist before your start UT2003

### sFileFormat
The format for the log filename. You can use the following replacements:
- %P server Port
- %Y current Year
- %M current Month
- %Y current Day
- %H current Hour
- %I current mInute
- %S current Second
- %N server Name 

Not all characters are supported in the filename, for example '.', these will be translated to an underscore '_' 

The log file generated will start with a line with the date the log started:

```
  --- Log started on 2003/2/28 21:17:40
```

After that you will get the log files in there field (seperated by tabs)

```
  time  tag  playername  message
```

Tag is one of the following: CHAT, TEAMCHAT, SPAM, TEAMSPAM, MUTE, TEAMMUTE

The lines are uncensored (the bad words are not filtered) 
