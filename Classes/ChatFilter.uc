///////////////////////////////////////////////////////////////////////////////
// filename:    ChatFilter.uc
// version:     104
// author:      Michiel 'El Muerte' Hendriks <elmuerte@drunksnipers.com>
// purpose:     main filter class
///////////////////////////////////////////////////////////////////////////////

class ChatFilter extends BroadcastHandler;

const VERSION = 104;

var config bool bEnabled;

var config float fTimeFrame;
var config int iMaxPerTimeFrame;
var config int iMaxRepeat;
var config array<string> BadWords;
var config string CencorWord;
var config int iScoreSpam;
var config int iScoreSwear;
var config int iKillScore;
enum ChatFilterAction {CFA_Nothing, CFA_Kick, CFA_Ban, CFA_SessionBan, CFA_Defrag};
var config ChatFilterAction KillAction;
var config bool bCheckNicknames;

// logging
var config bool bLogChat;
var config string sLogDir;
var config string sFileFormat;
var string logname;
var FileLog logfile;

var BroadcastHandler oldHandler;

struct ChatRecord
{
  var Actor Sender;
  var string LastMsg;
  var int count;
  var int msgCount;
  var int score;
};
var array<ChatRecord> ChatRecords;

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
    ChatRecords[ChatRecords.Length-1].Sender = Sender;
    return ChatRecords.Length-1;
  }
  return -1;
}

function string filterString(coerce string Msg, int cr)
{
  local array<string> parts;
  local int i,j,k;

  if (cr == -1) return Msg;
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

function judge(Actor Sender, int cr)
{
  if ((PlayerController(Sender) != none) && (MessagingSpectator(Sender) == none))
  {
    if (ChatRecords[cr].score > iKillScore)
    {
      ChatRecords[cr].score = 0;
      switch (KillAction)
      {
        case CFA_Nothing: return;
        case CFA_Kick:  log("Kicking player"@PlayerController(Sender).PlayerReplicationInfo.PlayerName, 'ChatFilter');
                        Level.Game.AccessControl.KickPlayer(PlayerController(Sender)); 
                        return;
        case CFA_Ban: log("Banning player"@PlayerController(Sender).PlayerReplicationInfo.PlayerName, 'ChatFilter');
                      Level.Game.AccessControl.BanPlayer(PlayerController(Sender), false); 
                      return;
        case CFA_SessionBan:  log("Session banning player"@PlayerController(Sender).PlayerReplicationInfo.PlayerName, 'ChatFilter');
                              Level.Game.AccessControl.BanPlayer(PlayerController(Sender), true); 
                              return;
        case CFA_Defrag:  log("Defragging player"@PlayerController(Sender).PlayerReplicationInfo.PlayerName, 'ChatFilter');
                          PlayerController(Sender).PlayerReplicationInfo.Score -= 1; 
                          return;
      }
    }
  }
}

function WriteLog(Actor Sender, coerce string msg, coerce string tag)
{
  if (PlayerController(Sender) != none)
  {
    if (logfile != none) 
    {
      logfile.Logf(Level.TimeSeconds$chr(9)$tag$chr(9)$PlayerController(Sender).PlayerReplicationInfo.PlayerName$chr(9)$msg);
    }
  }
}

simulated function BadNick(PlayerController PC)
{
  PC.ClientOpenMenu("ChatFilter.BadNickPage");
}

function CheckNickname(PlayerController PC)
{
  local bool nameOk;
  local int i;
  nameOk = true;
  for (i=0; i<BadWords.Length; i++)
  {
    if (InStr(Caps(PC.PlayerReplicationInfo.PlayerName), Caps(BadWords[i])) > -1)
    {
      nameOk = false;
      break;
    }
  }
  if (!nameOk)
  {
    BadNick(PC);
    Level.Game.AccessControl.KickPlayer(PC); 
  }
}

// default methods

event PreBeginPlay()
{
  if (!bEnabled)
  {
    Self.Destroy();
    return;
  }
  log("[~] Loading Chat Filter version"@VERSION);
  log("[~] Michiel 'El Muerte' Hendriks - elmuerte@drunksnipers.com");
  log("[~] The Drunk Snipers - http://www.drunksnipers.com");
  if (bLogChat)
  {
    logfile = spawn(class 'FileLog', Level);
    logname = LogFilename();
    logfile.OpenLog(logname);
    logfile.Logf("--- Log started on "$Level.Year$"/"$Level.Month$"/"$Level.Day@Level.Hour$":"$Level.Minute$":"$Level.Second);
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
  SetTimer(fTimeFrame, true);
  enable('Tick');
}

event Timer()
{
  local int i;
  local PlayerController PC;
  // reset count
  for (i = 0; i < ChatRecords.Length; i++)
  {
    ChatRecords[i].msgCount = 0;
  }
  // check nickname
  if (bCheckNicknames)
  {
    ForEach DynamicActors(class'PlayerController', PC)
    {
      if (!PC.PlayerReplicationInfo.bBot && (MessagingSpectator(PC) == none)) CheckNickname(PC);
    }
  }
}

event Tick(float delta)
{
  if ((Level.NextURL != "") && (logfile != none))
  {
    logfile.Logf("--- Log closed on "$Level.Year$"/"$Level.Month$"/"$Level.Day@Level.Hour$":"$Level.Minute$":"$Level.Second);
    logfile.Destroy();
    logfile = none;
  }
}

function Broadcast( Actor Sender, coerce string Msg, optional name Type )
{
  local int cr;
  cr = findChatRecord(Sender, true);
  if ((cr > -1) && (Type == 'Say'))
  {
    ChatRecords[cr].msgCount++;
    if (ChatRecords[cr].msgCount > iMaxPerTimeFrame)
    {
      if (bLogChat) WriteLog(Sender, msg, "SPAM");
      ChatRecords[cr].score += iScoreSpam;
      judge(Sender, cr);
      return; // max exceeded
    }
    if (ChatRecords[cr].LastMsg == Msg)
    {
      ChatRecords[cr].count++;      
      if (ChatRecords[cr].count > iMaxRepeat) 
      {
        if (bLogChat) WriteLog(Sender, msg, "SPAM");
        ChatRecords[cr].score += iScoreSpam;
        judge(Sender, cr);
        return; // max exceeded
      }
    }
    else {
      ChatRecords[cr].LastMsg = Msg;
      ChatRecords[cr].count = 0;
    }
  }
  if (bLogChat && (Type == 'Say')) WriteLog(Sender, msg, "CHAT");
  if (oldHandler != none) oldHandler.Broadcast(Sender, filterString(Msg, cr), Type);
  judge(Sender, cr);
}

function BroadcastTeam( Controller Sender, coerce string Msg, optional name Type )
{
  local int cr;
  cr = findChatRecord(Sender, true);
  if ((cr > -1) && (Type == 'Say'))
  {
    ChatRecords[cr].msgCount++;
    if (ChatRecords[cr].msgCount > iMaxPerTimeFrame)
    {
      if (bLogChat) WriteLog(Sender, msg, "TEAMSPAM");
      ChatRecords[cr].score += iScoreSpam;
      judge(Sender, cr);
      return; // max exceeded
    }
    if (ChatRecords[cr].LastMsg == Msg)
    {
      ChatRecords[cr].count++;
      if (ChatRecords[cr].count > iMaxRepeat) 
      {
        if (bLogChat) WriteLog(Sender, msg, "TEAMSPAM");
        ChatRecords[cr].score += iScoreSpam;
        judge(Sender, cr);
        return; // max exceeded
      }
    }
    else {
      ChatRecords[cr].LastMsg = Msg;
      ChatRecords[cr].count = 0;
    }
  }
  if (bLogChat && (Type == 'Say')) WriteLog(Sender, msg, "TEAMCHAT");
  if (oldHandler != none) oldHandler.BroadcastTeam(Sender, filterString(Msg, cr), Type);
  judge(Sender, cr);
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
  PI.AddSetting("Chat Filter", "fTimeFrame", "Time frame", 10, 0, "Text", "5");
  PI.AddSetting("Chat Filter", "iMaxPerTimeFrame", "Max per time frame", 10, 0, "Text", "5");
  PI.AddSetting("Chat Filter", "iMaxRepeat", "Max repeats", 10, 1, "Text", "5");
  PI.AddSetting("Chat Filter", "iScoreSpam", "Spam score", 10, 2, "Text", "5");
  PI.AddSetting("Chat Filter", "CencorWord", "Censor replacement", 10, 3, "Text", "20");
  //PI.AddSetting("Chat Filter", "BadWords", "Bad words", 10, 3, "Textarea", "20");
  PI.AddSetting("Chat Filter", "iScoreSwear", "Swear score", 10, 4, "Text", "5");
  PI.AddSetting("Chat Filter", "iKillScore", "Kill score", 10, 5, "Text", "5");
  PI.AddSetting("Chat Filter", "KillAction", "Kill actions", 10, 6, "Select", "CFA_Nothing;Nothing;CFA_Kick;Kick player;CFA_Ban;Ban player;CFA_SessionBan;Ban player this session;CFA_Defrag;Remove one point;");
  PI.AddSetting("Chat Filter", "bCheckNicknames", "Check nicknames (requires ServerPackage)", 10, 7, "check", "");
  PI.AddSetting("Chat Filter", "bLogChat", "Log chat", 10, 7, "check", "");
  PI.AddSetting("Chat Filter", "sFileFormat", "Filename format", 10, 8, "Text", "40");
  PI.AddSetting("Chat Filter", "sLogDir", "Log directory (must exist)", 10, 9, "Text", "40");
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
  return sLogDir$result;
}

defaultproperties
{
  bEnabled=true
  fTimeFrame=1.0000
  iMaxPerTimeFrame=2
  iMaxRepeat=1
  CencorWord="*****"
  iScoreSpam=1
  iScoreSwear=1
  iKillScore=10
  KillAction=CFA_Nothing
  bCheckNicknames=false

  bLogChat=false
  sLogDir=""
  sFileFormat="ChatFilter_%P_%Y_%M_%D_%H_%I_%S"
}