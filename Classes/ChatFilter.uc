///////////////////////////////////////////////////////////////////////////////
// filename:    ChatFilter.uc
// version:     159
// author:      Michiel 'El Muerte' Hendriks <elmuerte@drunksnipers.com>
// purpose:     main filter class
// $Id: ChatFilter.uc,v 1.16 2004/01/15 08:59:14 elmuerte Exp $
///////////////////////////////////////////////////////////////////////////////

class ChatFilter extends BroadcastHandler;

const VERSION = 159;

var config bool bEnabled; // used to disable it via the WebAdmin

enum ChatFilterAction {CFA_Nothing, CFA_Kick, CFA_Ban, CFA_SessionBan, CFA_Defrag, CFA_Warn, CFA_Mute};
enum BNA {BNA_Kick, BNA_Request, BNA_Ban, BNA_SessionBan};

// Misc
var config bool bFriendlyMessage;
// SPAM check
var config float fTimeFrame;
var config int iMaxPerTimeFrame;
var config int iMaxRepeat;
var config int iScoreSpam;
// Foul language check
var config array<string> BadWords;
var config string CencorWord;
var config int iScoreSwear;
var config bool bUseReplacementTable; // BadWords=> replace;with
// Nickname check
var config bool bCheckNicknames;
var config BNA BadnickAction;
var config array<string> UnallowedNicks;
var config bool bWildCardNicks;
// Judgement actions
var config int iKillScore;
var config ChatFilterAction KillAction;
// CFA_Warn
var config string sWarningNotification; // printed on the abusers screen
var config string sWarningBroadcast; // broadcasted to eveybody
var config ChatFilterAction WarningAction; // action to take (only CFA_Nothing, CFA_Kick, CFA_Ban, CFA_SessionBan, CFA_Defrag)
var config int iMaxWarnings; // max warnings for a auto action
var config float fMinVote; // minimum percentage of votes needed for user action
// CFA_Mute
var config string sMuteMessage;
var config bool bShowMuted;
// logging
var config bool bLogChat;
var config string sLogDir;
var config string sFileFormat;
var string logname;
var FileLog logfile;

// message target filtering -- NOT IMPLEMENTED
const CD_P2P = 1; // player -> player
const CD_S2S = 2; // spectator -> spectator
const CD_P2S = 4; // player -> spectator
const CD_S2P = 8; // spectator -> player
const CD_A2A = 16; // admin -> all
var config byte ChatDirection;

var BroadcastHandler oldHandler;
struct ReplacementEntry
{
  var string from,to;
};
var array<ReplacementEntry> ReplacementTable;

struct ChatRecord
{
  var PlayerController Sender;
  var string LastMsg;
  var int count;
  var int msgCount;
  var int score;
  var int warnings;
  var bool bUserRequest;
  var bool bMuted;
  var MsgDispatcher Dispatcher;
  var string lastName;
};
var array<ChatRecord> ChatRecords;

// Find a player record and create a new one when needed
function int findChatRecord(Actor Sender, optional bool bCreate)
{
  local int i;
  if (PlayerController(Sender) == none) return -1;
  for (i = 0; i < ChatRecords.Length; i++)
  {
    if (ChatRecords[i].Sender == Sender) return i;
  }
  if (bCreate)
  {
    ChatRecords.Length = ChatRecords.Length+1;
    ChatRecords[ChatRecords.Length-1].Sender = PlayerController(Sender);
    if (bFriendlyMessage || bCheckNicknames)
    {
      if (ChatRecords[ChatRecords.Length-1].Dispatcher == none)
        ChatRecords[ChatRecords.Length-1].Dispatcher = spawn(class'ChatFilterMsg155.MsgDispatcher', Sender);  
    }
    return ChatRecords.Length-1;
  }
  return -1;
}

// Filter bad words out a string
function string filterString(coerce string Msg, int cr)
{
  local array<string> parts;
  local int i,j,k;

  if (cr == -1) return Msg;
  if (bUseReplacementTable) return filterStringTable(Msg, cr);
  if (split(msg," ", parts) == 0) return "";
  for (i=0; i<BadWords.Length; i++)
  {
    for (j = 0; j < parts.length; j++)
    {
      k = InStr(Caps(parts[j]), Caps(BadWords[i]));
      while (k > -1) 
      { 
        parts[j] = Left(parts[j], k)$CencorWord$Mid(parts[j], k+Len(BadWords[i]));
        ChatRecords[cr].score += iScoreSwear;
        k = InStr(Caps(parts[j]), Caps(BadWords[i]));
      }
    }
  }
  msg = parts[0];
  for (i = 1; i < parts.length; i++)
  {
    msg = msg@parts[i];
  }
  return Msg;
}

// Filter bad words out a string, using replacement table
function string filterStringTable(coerce string Msg, int cr)
{
  local array<string> parts;
  local int i,j,k;

  if (cr == -1) return Msg;
  if (split(msg," ", parts) == 0) return "";
  for (i=0; i<ReplacementTable.Length; i++)
  {
    for (j = 0; j < parts.length; j++)
    {
      k = InStr(Caps(parts[j]), Caps(ReplacementTable[i].from));
      while (k > -1) 
      { 
        parts[j] = Left(parts[j], k)$ReplacementTable[i].to$Mid(parts[j], k+Len(ReplacementTable[i].from));
        ChatRecords[cr].score += iScoreSwear;
        k = InStr(Caps(parts[j]), Caps(ReplacementTable[i].from));
      }
    }
  }
  msg = parts[0];
  for (i = 1; i < parts.length; i++)
  {
    msg = msg@parts[i];
  }
  return Msg;
}

// Write judgement to log
function judgeLog(string msg)
{
  log(msg, 'ChatFilter');
  if (logfile != none) logfile.Logf(Level.TimeSeconds$chr(9)$"JUDGE"$chr(9)$msg);
}

// Initial judge
function judge(PlayerController Sender, int cr)
{
  if ((Sender != none) && (MessagingSpectator(Sender) == none))
  {
    if (ChatRecords[cr].score > iKillScore)
    {
      ChatRecords[cr].score = 0;
      switch (KillAction)
      {
        case CFA_Nothing: return;
        case CFA_Kick:  judgeLog("Kicking player"@Sender.PlayerReplicationInfo.PlayerName);
                        if (bFriendlyMessage) ChatRecords[cr].Dispatcher.Dispatch(Sender, 1);
                        Level.Game.AccessControl.KickPlayer(Sender); 
                        return;
        case CFA_Ban: judgeLog("Banning player"@Sender.PlayerReplicationInfo.PlayerName);
                      if (bFriendlyMessage) ChatRecords[cr].Dispatcher.Dispatch(Sender, 2);
                      Level.Game.AccessControl.BanPlayer(Sender, false); 
                      return;
        case CFA_SessionBan:  judgeLog("Session banning player"@Sender.PlayerReplicationInfo.PlayerName);
                              if (bFriendlyMessage) ChatRecords[cr].Dispatcher.Dispatch(Sender, 3);
                              Level.Game.AccessControl.BanPlayer(Sender, true); 
                              return;
        case CFA_Defrag:  judgeLog("Defragging player"@Sender.PlayerReplicationInfo.PlayerName);
                          Sender.PlayerReplicationInfo.Score -= 1; 
                          return;
        case CFA_Warn:  judgeLog("Warning player"@Sender.PlayerReplicationInfo.PlayerName);
                        ChatRecords[cr].warnings++; 
                        judgeWarning(Sender, cr);
                        return;
        case CFA_Mute:  judgeLog("Muting player"@Sender.PlayerReplicationInfo.PlayerName);
                        Sender.ClearProgressMessages();
                        Sender.SetProgressTime(6);
                    		Sender.SetProgressMessage(0, sMuteMessage, class'Canvas'.Static.MakeColor(255,0,0));
                        ChatRecords[cr].bMuted = true;
                        if (bShowMuted) ChatRecords[cr].Dispatcher.MutedHud(Sender);
                        return;
      }
    }
  }
}

// Secondary judge on a CFA_Warn
function judgeWarning(PlayerController Sender, int cr)
{
  local string tmp;
  if ((Sender != none) && (MessagingSpectator(Sender) == none))
  {
    if ((ChatRecords[cr].warnings > iMaxWarnings) || ChatRecords[cr].bUserRequest)
    {      
      switch (WarningAction)
      {
        case CFA_Nothing: break;
        case CFA_Kick:  judgeLog("Kicking player"@Sender.PlayerReplicationInfo.PlayerName@"iMaxWarning exceeded:"@(ChatRecords[cr].warnings > iMaxWarnings)@"Requested:"@ChatRecords[cr].bUserRequest);
                        if (bFriendlyMessage) 
                        { 
                          if (ChatRecords[cr].bUserRequest) ChatRecords[cr].Dispatcher.Dispatch(Sender, 4);
                          else ChatRecords[cr].Dispatcher.Dispatch(Sender, 1);
                        }
                        Level.Game.AccessControl.KickPlayer(Sender); 
                        break;
        case CFA_Ban: judgeLog("Banning player"@Sender.PlayerReplicationInfo.PlayerName@"iMaxWarning exceeded:"@(ChatRecords[cr].warnings > iMaxWarnings)@"Requested:"@ChatRecords[cr].bUserRequest);
                      if (bFriendlyMessage) 
                      { 
                        if (ChatRecords[cr].bUserRequest) ChatRecords[cr].Dispatcher.Dispatch(Sender, 5);
                        else ChatRecords[cr].Dispatcher.Dispatch(Sender, 2);
                      }
                      Level.Game.AccessControl.BanPlayer(Sender, false); 
                      break;
        case CFA_SessionBan:  judgeLog("Session banning player"@Sender.PlayerReplicationInfo.PlayerName@"iMaxWarning exceeded:"@(ChatRecords[cr].warnings > iMaxWarnings)@"Requested:"@ChatRecords[cr].bUserRequest);
                              if (bFriendlyMessage) 
                              { 
                                if (ChatRecords[cr].bUserRequest) ChatRecords[cr].Dispatcher.Dispatch(Sender, 6);
                                else ChatRecords[cr].Dispatcher.Dispatch(Sender, 3);
                              }
                              Level.Game.AccessControl.BanPlayer(Sender, true); 
                              break;
        case CFA_Defrag:  judgeLog("Defragging player"@Sender.PlayerReplicationInfo.PlayerName@"iMaxWarning exceeded:"@(ChatRecords[cr].warnings > iMaxWarnings)@"Requested:"@ChatRecords[cr].bUserRequest);
                          Sender.PlayerReplicationInfo.Score -= 1; 
                          break;
        case CFA_Mute:  judgeLog("Muting player"@Sender.PlayerReplicationInfo.PlayerName@"iMaxWarning exceeded:"@(ChatRecords[cr].warnings > iMaxWarnings)@"Requested:"@ChatRecords[cr].bUserRequest);
                        Sender.ClearProgressMessages();
                        Sender.SetProgressTime(6);
                    		Sender.SetProgressMessage(0, sMuteMessage, class'Canvas'.Static.MakeColor(255,0,0));
                        ChatRecords[cr].bMuted = true;
                        //if (bShowMuted) Dispatcher.MuteHud(Sender);
                        break;
      }
      ChatRecords[cr].warnings = 0;
      ChatRecords[cr].bUserRequest = false;
      return;
    }
    else {
      if (sWarningNotification != "")
      {
        Sender.ClearProgressMessages();
        Sender.SetProgressTime(6);
	  		Sender.SetProgressMessage(0, sWarningNotification, class'Canvas'.Static.MakeColor(255,0,0));
      }
      if (sWarningBroadcast != "")
      {
        tmp = sWarningBroadcast;
        ReplaceText(tmp, "%s", Sender.PlayerReplicationInfo.PlayerName);
        ReplaceText(tmp, "%i", string(cr));
        if (oldHandler != none) oldHandler.Broadcast(none, tmp, '');
      }
    }
  }
}

// Write chat log
function WriteLog(PlayerController Sender, coerce string msg, coerce string tag)
{
  if (Sender != none)
  {
    if (logfile != none) 
    {
      logfile.Logf(Level.TimeSeconds$chr(9)$tag$chr(9)$Sender.PlayerReplicationInfo.PlayerName$chr(9)$msg);
    }
  }
}

// Check for foul nickname
function CheckNickname(PlayerController PC)
{
  local bool foulName, badName;
  local int i;

  foulName = false;
  badName = false;
  if (bUseReplacementTable)
  {
    for (i=0; i<ReplacementTable.Length; i++)
    {
      if (InStr(Caps(PC.PlayerReplicationInfo.PlayerName), Caps(ReplacementTable[i].from)) > -1)
      {
        foulName = true;
        break;
      }
    }
  }
  else {
    for (i=0; i<BadWords.Length; i++)
    {
      if (InStr(Caps(PC.PlayerReplicationInfo.PlayerName), Caps(BadWords[i])) > -1)
      {
        foulName = true;
        break;
      }
    }
  }
  if (!foulName)
  {
    for (i=0; i<UnallowedNicks.Length; i++)
    {
			if (bWildCardNicks && (InStr(UnallowedNicks[i], "*") > -1 || InStr(UnallowedNicks[i], "?") > -1))
			{
				if (class'wString'.static.MaskedCompare(PC.PlayerReplicationInfo.PlayerName, UnallowedNicks[i]))
				{
					badName = true;
				  break;
				}
			}
			else {
	      if (Caps(PC.PlayerReplicationInfo.PlayerName) == Caps(UnallowedNicks[i]))
		    {
			    badName = true;
				  break;
	      }
			}
    }
  }
  if (foulName || badName)
  {    
    i = findChatRecord(PC, true);
    if (i > -1)
    {
      if (ChatRecords[i].LastName == Caps(PC.PlayerReplicationInfo.PlayerName)) return;
      judgeLog("Bad nickname"@PC.PlayerReplicationInfo.PlayerName);
      if (BadnickAction == BNA_Kick)
      {            
        if (foulName) ChatRecords[i].Dispatcher.Dispatch(PC, 0);
        else if (badName) ChatRecords[i].Dispatcher.Dispatch(PC, 7);
        Level.Game.AccessControl.KickPlayer(PC); 
      }
      else if (BadnickAction == BNA_Request)
      {
        if (foulName) ChatRecords[i].Dispatcher.ChangeNamerequest(PC, 0);
        else if (badName) ChatRecords[i].Dispatcher.ChangeNamerequest(PC, 7);
      }
			else if ((BadnickAction == BNA_Ban) || (BadnickAction == BNA_SessionBan))
      {
				Level.Game.AccessControl.BanPlayer(PC, (BadnickAction == BNA_SessionBan));
        if (foulName) ChatRecords[i].Dispatcher.ChangeNamerequest(PC, 0);
        else if (badName) ChatRecords[i].Dispatcher.ChangeNamerequest(PC, 7);
      }
      ChatRecords[i].LastName = Caps(PC.PlayerReplicationInfo.PlayerName);
    }
  }
}

// check the chat direction
function bool mayChat(PlayerController Sender, PlayerController Receiver)
{
	/*
  if (ChatDirection == CD_All) return true;
  if (Sender.PlayerReplicationInfo.bAdmin && bAdminChatOverride) return true;
  if (Sender.PlayerReplicationInfo.bIsSpectator)
  {
    if (ChatDirection == CD_PrivateSpecator) return Receiver.PlayerReplicationInfo.bIsSpectator;
  }
  if (ChatDirection == CD_PrivatePlayer) return Receiver.PlayerReplicationInfo.bIsSpectator;
	*/
  return true;
}

function GameInformation()
{
	local string line, tmp;
  local Mutator M;
  line = "===";
  line = line$chr(9)$Level.Game.Class; // gametype
  line = line$chr(9)$Left(string(Level), InStr(string(Level), ".")); // map
  for (M = Level.Game.BaseMutator.NextMutator; M != None; M = M.NextMutator) 
  {
    if (tmp != "") tmp = tmp$",";
    tmp = tmp$(M.GetHumanReadableName());
  }
  line = line$chr(9)$tmp; // mutators

  logfile.Logf(line);
}

// default methods //

event PreBeginPlay()
{
  local int i,j;
  if (!bEnabled)
  {
    Self.Destroy();
    return;
  }
  log("[~] Loading Chat Filter version"@VERSION, 'ChatFilter');
  log("[~] Michiel 'El Muerte' Hendriks - elmuerte@drunksnipers.com", 'ChatFilter');
  log("[~] The Drunk Snipers - http://www.drunksnipers.com", 'ChatFilter');
  if (bLogChat)
  {
    logfile = spawn(class 'FileLog', Level);
    logname = LogFilename();
    logfile.OpenLog(logname);
    logfile.Logf("--- Log started on "$Level.Year$"/"$Level.Month$"/"$Level.Day@Level.Hour$":"$Level.Minute$":"$Level.Second);
    GameInformation();
  }
  if (!Level.Game.BroadcastHandler.IsA('ChatFilter'))
  {
    oldHandler = Level.Game.BroadcastHandler;
    Level.Game.BroadcastHandler = Self;
  }
  else {
    Self.Destroy();
    return;
  }
  if (KillAction == CFA_Warn)
  {
    log("[~] Launching warning mutator", 'ChatFilter');
    Level.Game.AddMutator("ChatFilter.WarningMut", true);
  }
  if (bUseReplacementTable)
  {
    log("[~] Converting BadWords to ReplacementTable", 'ChatFilter');
    ReplacementTable.Length = BadWords.Length;
    for (i = 0; i < BadWords.Length; i++)
    {
      j = InStr(BadWords[i], ";");
      if (j < 0) j = Len(BadWords[i]);
      ReplacementTable[i].from = Left(BadWords[i], j);
      ReplacementTable[i].to = Mid(BadWords[i], j+1);      
      if (ReplacementTable[i].to == "") ReplacementTable[i].to = CencorWord;
      log("[~]"@ReplacementTable[i].from@"=>"@ReplacementTable[i].to);
    }
  }
  SetTimer(fTimeFrame, true);
  enable('Tick');
}

event Timer()
{
  local int i;  
  // reset count
  for (i = 0; i < ChatRecords.Length; i++)
  {
    ChatRecords[i].msgCount = 0;
  }  
}

event Tick(float delta)
{
	local Controller C;
  if ((Level.NextURL != "") && (logfile != none))
  {
    logfile.Logf("--- Log closed on "$Level.Year$"/"$Level.Month$"/"$Level.Day@Level.Hour$":"$Level.Minute$":"$Level.Second);
    logfile.Destroy();
    logfile = none;
  }
	// check nickname
  if (bCheckNicknames)
  {
		for( C = Level.ControllerList; C != None; C = C.NextController )
		{
			if (C.PlayerReplicationInfo == none) continue;
			// nick change
			if (C.PlayerReplicationInfo.PlayerName != C.PlayerReplicationInfo.OldName)
	      if (!C.PlayerReplicationInfo.bBot && (MessagingSpectator(C) == none)) CheckNickname(PlayerController(C));
    }
  }
}

function Broadcast( Actor Sender, coerce string Msg, optional name Type )
{
  local int cr;
  cr = findChatRecord(Sender, true);
  if ((cr > -1) && (Type == 'Say'))
  {
    ChatRecords[cr].msgCount++;
    if (ChatRecords[cr].bMuted)
    {
      if (bLogChat) WriteLog(PlayerController(Sender), msg, "MUTE");
      return;
    }
    if (ChatRecords[cr].msgCount > iMaxPerTimeFrame)
    {
      if (bLogChat) WriteLog(PlayerController(Sender), msg, "SPAM");
      ChatRecords[cr].score += iScoreSpam;
      judge(PlayerController(Sender), cr);
      return; // max exceeded
    }
    if (ChatRecords[cr].LastMsg == Msg)
    {
      ChatRecords[cr].count++;      
      if (ChatRecords[cr].count > iMaxRepeat) 
      {
        if (bLogChat) WriteLog(PlayerController(Sender), msg, "SPAM");
        ChatRecords[cr].score += iScoreSpam;
        judge(PlayerController(Sender), cr);
        return; // max exceeded
      }
    }
    else {
      ChatRecords[cr].LastMsg = Msg;
      ChatRecords[cr].count = 0;
    }
  }
  if (bLogChat && (Type == 'Say')) WriteLog(PlayerController(Sender), msg, "CHAT");
  if (oldHandler != none) oldHandler.Broadcast(Sender, filterString(Msg, cr), Type);
  judge(PlayerController(Sender), cr);
}

function BroadcastTeam( Controller Sender, coerce string Msg, optional name Type )
{
  local int cr;
  cr = findChatRecord(Sender, true);
  if ((cr > -1) && (Type == 'TeamSay'))
  {
    ChatRecords[cr].msgCount++;
    if (ChatRecords[cr].bMuted)
    {
      if (bLogChat) WriteLog(PlayerController(Sender), msg, "MUTE");
      return;
    }
    if (ChatRecords[cr].msgCount > iMaxPerTimeFrame)
    {
      if (bLogChat) WriteLog(PlayerController(Sender), msg, "TEAMSPAM");
      ChatRecords[cr].score += iScoreSpam;
      judge(PlayerController(Sender), cr);
      return; // max exceeded
    }
    if (ChatRecords[cr].LastMsg == Msg)
    {
      ChatRecords[cr].count++;
      if (ChatRecords[cr].count > iMaxRepeat) 
      {
        if (bLogChat) WriteLog(PlayerController(Sender), msg, "TEAMSPAM");
        ChatRecords[cr].score += iScoreSpam;
        judge(PlayerController(Sender), cr);
        return; // max exceeded
      }
    }
    else {
      ChatRecords[cr].LastMsg = Msg;
      ChatRecords[cr].count = 0;
    }
  }
  if (bLogChat && (Type == 'TeamSay')) WriteLog(PlayerController(Sender), msg, "TEAMCHAT");
  if (oldHandler != none) oldHandler.BroadcastTeam(Sender, filterString(Msg, cr), Type);
  judge(PlayerController(Sender), cr);
}

function UpdateSentText()
{
	if (oldHandler != none) oldHandler.UpdateSentText();
}

function bool AllowsBroadcast( actor broadcaster, int Len )
{
	if (oldHandler != none) return oldHandler.AllowsBroadcast(broadcaster, len);
  return false;
}

function BroadcastText( PlayerReplicationInfo SenderPRI, PlayerController Receiver, coerce string Msg, optional name Type )
{
	if (oldHandler != none) oldHandler.BroadcastText(SenderPRI, Receiver, Msg, Type);
}

function BroadcastLocalized( Actor Sender, PlayerController Receiver, class<LocalMessage> Message, optional int Switch, optional PlayerReplicationInfo RelatedPRI_1, optional PlayerReplicationInfo RelatedPRI_2, optional Object OptionalObject )
{
	if (oldHandler != none) oldHandler.BroadcastLocalized( Sender, Receiver, Message, Switch, RelatedPRI_1, RelatedPRI_2, OptionalObject );
}

event AllowBroadcastLocalized( actor Sender, class<LocalMessage> Message, optional int Switch, optional PlayerReplicationInfo RelatedPRI_1, optional PlayerReplicationInfo RelatedPRI_2, optional Object OptionalObject )
{
	if (oldHandler != none) oldHandler.AllowBroadcastLocalized( Sender, Message, Switch, RelatedPRI_1, RelatedPRI_2, OptionalObject );
}

static function FillPlayInfo(PlayInfo PI)
{
  Super.FillPlayInfo(PI);
  PI.AddSetting("Chat Filter", "bFriendlyMessage", "Friendly messages", 10, 0, "check");

  PI.AddSetting("Chat Filter", "fTimeFrame", "Time frame", 10, 1, "Text", "5");
  PI.AddSetting("Chat Filter", "iMaxPerTimeFrame", "Max per time frame", 10, 2, "Text", "5");
  PI.AddSetting("Chat Filter", "iMaxRepeat", "Max repeats", 10, 3, "Text", "5");
  PI.AddSetting("Chat Filter", "iScoreSpam", "Spam score", 10, 4, "Text", "5");
  
  PI.AddSetting("Chat Filter", "CencorWord", "Censor replacement", 10, 5, "Text", "20");  
  PI.AddSetting("Chat Filter", "iScoreSwear", "Swear score", 10, 6, "Text", "5");
  //PI.AddSetting("Chat Filter", "BadWords", "Bad words", 10, 7, "Textarea", "");
  
  PI.AddSetting("Chat Filter", "iKillScore", "Kill score", 10, 8, "Text", "5");
  PI.AddSetting("Chat Filter", "KillAction", "Kill action", 10, 9, "Select", "CFA_Nothing;Nothing;CFA_Warn;Warn player;CFA_Kick;Kick player;CFA_Ban;Ban player;CFA_SessionBan;Ban player this session;CFA_Defrag;Remove one point;CFA_Mute;Mute player for this game");
  
  PI.AddSetting("Chat Filter", "bCheckNicknames", "Check nicknames", 10, 10, "check", "");
  PI.AddSetting("Chat Filter", "BadnickAction", "Bad nick action", 10, 10, "Select", "BNA_Kick;Kick the player;BNA_Request;Request a new nickname;BNA_Ban;Ban the player;BNA_SessionBan;Ban this player for this session only");
	PI.AddSetting("Chat Filter", "bWildCardNicks", "Bad nicks contain wildcards", 10, 10, "check", "");

  PI.AddSetting("Chat Filter", "sWarningNotification", "Warning notification", 10, 11, "Text");
  PI.AddSetting("Chat Filter", "sWarningBroadcast", "Warning broadcast", 10, 12, "Text");
  PI.AddSetting("Chat Filter", "WarningAction", "Warning action", 10, 13, "Select", "CFA_Nothing;Nothing;CFA_Kick;Kick player;CFA_Ban;Ban player;CFA_SessionBan;Ban player this session;CFA_Defrag;Remove one point;CFA_Mute;Mute player for this game");
  PI.AddSetting("Chat Filter", "iMaxWarnings", "Max warnings", 10, 14, "Text", "5");
  PI.AddSetting("Chat Filter", "fMinVote", "Min vote percentage", 10, 15, "Text", "5;0:1");

  PI.AddSetting("Chat Filter", "sMuteMessage", "Mute message", 10, 16, "Text");
  PI.AddSetting("Chat Filter", "bShowMuted", "Show muted", 10, 17, "Text");

  //CD_All;Public;CD_PrivateSpecator;Spectators are private;CD_PrivatePlayer;Specators and Players are private;

  PI.AddSetting("Chat Filter", "bLogChat", "Log chat", 10, 17, "check");
  PI.AddSetting("Chat Filter", "sFileFormat", "Filename format", 10, 18, "Text", "40");
  PI.AddSetting("Chat Filter", "sLogDir", "Log directory (must exist)", 10, 19, "Text", "40");
}

function string GetServerPort()
{
    local string S;
    local int i;
    // Figure out the server's port.
    S = Level.GetAddressURL();
    i = InStr( S, ":" );
    assert(i>=0);
    return Mid(S,i+1);
}

function string LogFilename()
{
  local string result;
  result = sFileFormat;
  ReplaceText(result, "%P", GetServerPort());
  ReplaceText(result, "%N", Level.Game.GameReplicationInfo.ServerName);
  ReplaceText(result, "%Y", Right("0000"$string(Level.Year), 4));
  ReplaceText(result, "%M", Right("00"$string(Level.Month), 2));
  ReplaceText(result, "%D", Right("00"$string(Level.Day), 2));
  ReplaceText(result, "%H", Right("00"$string(Level.Hour), 2));
  ReplaceText(result, "%I", Right("00"$string(Level.Minute), 2));
  ReplaceText(result, "%W", Right("0"$string(Level.DayOfWeek), 1));
  ReplaceText(result, "%S", Right("00"$string(Level.Second), 2));
  if (int(level.EngineVersion) > 2222)
  {
    if (sLogDir != "") Log("[E] sLogDir is no longer supported in UT2003 version 2222 and up", 'ChatFilter');
    return result;
  }
  else return sLogDir$result;
}

defaultproperties
{
  bHidden=true
  bEnabled=true
  bFriendlyMessage=false
  fTimeFrame=1.0000
  iMaxPerTimeFrame=2
  iMaxRepeat=1
  CencorWord="*****"
  iScoreSpam=1
  bUseReplacementTable=false
  iScoreSwear=1
  iKillScore=10
  KillAction=CFA_Nothing
  bCheckNicknames=false  
  BadnickAction=BNA_Kick
	bWildCardNicks=true
  sWarningNotification="ChatFilter: Please clean up your act"
  sWarningBroadcast="%s is chatting abusive, type 'mutate cf judge %i` to judge the player"
  WarningAction=CFA_Kick
  iMaxWarnings=2
  fMinVote=0.5000
  sMuteMessage="ChatFilter: You are muted the rest of the game"
  bShowMuted=false
  ChatDirection=255
  bLogChat=false
  sLogDir=""
  sFileFormat="ChatFilter_%P_%Y_%M_%D_%H_%I_%S"
}