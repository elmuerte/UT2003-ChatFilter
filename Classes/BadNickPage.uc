///////////////////////////////////////////////////////////////////////////////
// filename:    BadNickPage.uc
// version:     100
// author:      Michiel 'El Muerte' Hendriks <elmuerte@drunksnipers.com>
// purpose:     displays a "bad nick" message
//              for this to work ChatFilter must be a ServerPackage
//              this code is "borrowed" from UTSecure
///////////////////////////////////////////////////////////////////////////////

class BadNickPage extends GUIPage;

function InitComponent(GUIController MyController, GUIComponent MyOwner)
{
	Super.InitComponent(MyController, MyOwner);
  GUIButton(Controls[3]).OnClick=Ok;
  GUIScrollTextBox(Controls[2]).SetContent("Your nickname contains foul words (as defined by the server admin)||To play on this server you MUST change your nickname.");
  GUIScrollTextBox(Controls[2]).MyScrollText.EndScrolling();
  OnPreDraw = PreDraw;
}

function bool PreDraw(Canvas Canvas)
{
	if (Controller.ActivePage != Self)
    Controller.CloseMenu();
  return false;
}

function bool Ok(GUIComponent Sender)
{
	Controller.CloseMenu();
  return true;
}

defaultproperties
{
	Begin Object Class=GUIImage name=BadBackground
		bAcceptsInput=false
		bNeverFocus=true
    Image=Material'InterfaceContent.Menu.SquareBoxA'
    ImageStyle=ISTY_Stretched
    WinWidth=1
    WinLeft=0
    WinHeight=1
    WinTop=0
    bBoundToParent=true
    bScaleToParent=true;
	End Object
	Controls(0)=GUIImage'BadBackground'

	Begin Object class=GUILabel Name=BadTitle
		Caption="Chat Filter"
		TextALign=TXTA_Center
		TextColor=(R=255,G=0,B=0,A=255)
		WinWidth=1
		WinHeight=32.000000
		WinLeft=0
		WinTop=0.02
    bBoundToParent=true
    bScaleToParent=true;
    TextFont="UT2MenuFont"
	End Object
	Controls(1)=GUILabel'BadTitle'

  Begin Object Class=GUIScrollTextBox Name=BadText
		WinWidth=0.8
		WinHeight=0.6
		WinLeft=0.1
		WinTop=0.2
		CharDelay=0.0025
		EOLDelay=0
    bBoundToParent=true
    bScaleToParent=true;
		StyleName="RoundButton"
    bNoTeletype=true
	End Object
	Controls(2)=GUIScrollTextBox'BadText'

	Begin Object class=GUIButton Name=BadOK
		WinWidth=0.2
		WinHeight=0.15
		WinLeft=0.4
		WinTop=0.85
		Caption="OK"
    bBoundToParent=true
    bScaleToParent=true;
	End Object
	Controls(3)=GUIButton'BadOK'

	bRequire640x480=false
	bAllowedAsLast=false
  WinLeft=0.25
  WinWidth=0.5
  WinTop=0.35
  WinHeight=0.3
}