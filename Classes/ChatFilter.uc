///////////////////////////////////////////////////////////////////////////////
// filename:    ChatFilter.uc
// version:     100
// author:      Michiel 'El Muerte' Hendriks <elmuerte@drunksnipers.com>
// purpose:     main filter class
///////////////////////////////////////////////////////////////////////////////

class ChatFilter extends BroadcastHandler;

const VERSION = 100;

var config bool bEnabled;

var config int iMaxRepeat;
var config array<string> BadWords;
var config string CencorWord;
var config int iScoreSpam;
var config int iScoreSwear;
var config int iKillScore;
enum ChatFilterAction {CFA_Nothing, CFA_Kick, CFA_Ban, CFA_SessionBan, CFA_Defrag};
var config ChatFilterAction KillAction;

var BroadcastHandler oldHandler;

struct ChatRecord
{
  var Actor Sender;
  var string LastMsg;
  var int count;
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

function string iReplaceText(coerce string text, coerce string replace, coerce string with, int cr)
{
  local array<string> parts;
  local int i;
  split(text," ", parts);
  text = "";
  for (i = 0; i < parts.length; i++)
  {
    if (parts[i] ~= replace) 
    {
      parts[i] = with;
      ChatRecords[cr].score += iScoreSwear;
    }
    text = text$parts[i]$" ";
  }
  return text;
}

function string filterString(coerce string Msg, int cr)
{
  local int i;
  for (i=0; i<BadWords.Length; i++)
  {
    msg = iReplaceText(msg, BadWords[i], CencorWord, cr);
  }
  return Msg;
}

function judge(Actor Sender, int cr)
{
  if (PlayerController(Sender) != none)
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

event PreBeginPlay()
{
  log("[~] Loading ChatFilter version"@VERSION);
  log("[~] Michiel 'El Muerte' Hendriks - elmuerte@drunksnipers.com");
  log("[~] The Drunk Snipers - http://www.drunksnipers.com");
  oldHandler = Level.Game.BroadcastHandler;
  Level.Game.BroadcastHandler = Self;  
}

function Broadcast( Actor Sender, coerce string Msg, optional name Type )
{
  local int cr;
  cr = findChatRecord(Sender, true);
  if (cr > -1)
  {
    if (ChatRecords[cr].LastMsg == Msg)
    {
      ChatRecords[cr].count++;      
      if (ChatRecords[cr].count > iMaxRepeat) 
      {
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
  if (oldHandler != none) oldHandler.Broadcast(Sender, filterString(Msg, cr), Type);
  judge(Sender, cr);
}

function BroadcastTeam( Controller Sender, coerce string Msg, optional name Type )
{
  local int cr;
  cr = findChatRecord(Sender, true);
  if (cr > -1)
  {
    if (ChatRecords[cr].LastMsg == Msg)
    {
      ChatRecords[cr].count++;
      if (ChatRecords[cr].count > iMaxRepeat) 
      {
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
  PI.AddSetting("Chat Filter", "iMaxRepeat", "Max repeats", 10, 1, "Text", "5");
  PI.AddSetting("Chat Filter", "iScoreSpam", "Spam score", 10, 2, "Text", "5");
  PI.AddSetting("Chat Filter", "CencorWord", "Cencor replacement", 10, 3, "Text", "10");
  PI.AddSetting("Chat Filter", "iScoreSwear", "Swear score", 10, 4, "Text", "5");
  PI.AddSetting("Chat Filter", "iKillScore", "Kill score", 10, 5, "Text", "5");
  PI.AddSetting("Chat Filter", "KillAction", "Kill actions", 10, 6, "Select", "CFA_Nothing;Nothing;CFA_Kick;Kick player;CFA_Ban;Ban player;CFA_SessionBan;Ban player this session;CFA_Defrag;Remove one point;");
}

defaultproperties
{
  bEnabled=true
  iMaxRepeat=1
  CencorWord="*****"
  iScoreSpam=1
  iScoreSwear=1
  iKillScore=10
  KillAction=CFA_Nothing
}