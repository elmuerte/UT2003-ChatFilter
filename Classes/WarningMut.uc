///////////////////////////////////////////////////////////////////////////////
// filename:    WarningMut.uc
// version:     100
// author:      Michiel 'El Muerte' Hendriks <elmuerte@drunksnipers.com>
// purpose:     for mutate commands
///////////////////////////////////////////////////////////////////////////////

class WarningMut extends Mutator;

var ChatFilter cf;

struct JudgeMent
{
  var array<PlayerController> Jury;
  var int total;
};
var array<JudgeMent> JudgeMents;

event PreBeginPlay()
{
  local ChatFilter A;
	foreach Level.AllActors( class'ChatFilter', A )
  {
    if (String(A.Class) == "ChatFilter.ChatFilter")
    {   
      cf = A;
    }
	}
}

function judgeMentVote(PlayerController Sender, int offset)
{
  local int i;
  if (cf.ChatRecords.Length > offset)
  {
    if (cf.ChatRecords[offset].warnings > 0)
    {
      if (JudgeMents.Length <= offset) 
      {
        JudgeMents.Length = offset+1;
        JudgeMents[offset].total = 0;
      }
      for (i = 0; i < JudgeMents[offset].Jury.Length; i++)
      {
        if (JudgeMents[offset].Jury[i] == Sender) return;
      }
      JudgeMents[offset].Jury.Length = i+1;
      JudgeMents[offset].Jury[i] = Sender;
      JudgeMents[offset].total++;
      if ((JudgeMents[offset].total/Level.Game.NumPlayers) >= cf.fMinVote)
      {
        cf.ChatRecords[offset].bUserRequest = true;
        cf.judgeWarning(cf.ChatRecords[offset].Sender, offset);
        JudgeMents[offset].total = 0;
        JudgeMents[offset].Jury.Length = 0;
      }
    }
  }
}

function Mutate(string MutateString, PlayerController Sender)
{
  local array<string> parts;  
  if (split(MutateString, " ", parts) > 2)
  {
    if (parts[0] ~= "cf")
    {
      if (parts[1] ~= "judge")
      {
        judgeMentVote(Sender, int(parts[2]));
      }
    }
  }
	if ( NextMutator != None )
		NextMutator.Mutate(MutateString, Sender);
}

function GetServerDetails( out GameInfo.ServerResponseLine ServerState )
{
	// don't append the mutator name.
}

defaultproperties
{
     FriendlyName="ChatFilter"
     Description="Clean up server chatting"
     GroupName="ChatFilter"
}