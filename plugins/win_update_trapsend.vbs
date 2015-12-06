'==============================================================================
'win_update_trapsend.vbs 1.0  @2009 by Frank4dd       http://nagios.fm4dd.com/
'
'This script checks if updates are waiting to be applied and reports it through
'trapgen.exe to Nagios. It should run through Windows scheduler on a permanent
'i.e. daily basis.
'Run: cscript.exe -NoLogo win_update_trapsend.vbs > win_update_trapsend.log
'
'For better reference and insight, the script additionally identifies the
'Windows Version and the configured update service as Nagios performance data.
'
'Original authors and code references:
' - check_windows_updates.wsf
' - check_windows_updates (nrpe_nt-plugin) 1.3
'   (Micha Jankowski - fooky@pjwstk.edu.pl)
' - check_msupdates (nrpe_nt-plugin) 1.0 (coswal).
' All these programs are available at http://www.nagiosexchange.org/
'
'The nagios plugins come with ABSOLUTELY NO WARRANTY. You may redistribute
'copies of the plugins under the terms of the GNU General Public License.
'==============================================================================

'======================================================================
' Global Constants and Variables
'======================================================================
Const pluginVer  = "1.0"

'Const for calling snmp trapgen.exe
Const trapCmdBin = "C:\update-monitor\trapgen.exe"
Const trapCmdDst = "-d 192.168.103.34"
Const trapCmdCom = "-c SECtrap"
Const trapCmdOid = "-v 1.3.6.1.4.1.2854"
Const trapCmdTyp = "STRING"

'Const for return val's
Const intOK       = 0
Const intWarning  = 1
Const intCritical = 2
Const intUnknown  = 3

' Const for FSO
Const ForReading = 1
Const ForWriting = 2
Dim updatesNamesCritical, updatesNamesSoftware
Dim trapCmdStr, trapCmd, wshShell
Dim strOS, strVerKey, strVersion
Dim updateServer, sendMessage

'======================================================================
' RegistryKeyExists(): checks if a registry key exists
'======================================================================
Function RegistryKeyExists(LNGHKEY, strKey, strSubkey)
  Const HKLM    = &H80000002
  Const HKCR    = &H80000000
  Const HKCU    = &H80000001
  Const HKUSERS = &H80000003
  RegistryKeyExists = False
  Dim hkroot
  If LNGHKEY = "HKLM" Then hkRoot = HKLM
  If LNGHKEY = "HKCU" Then hkRoot = HKCU
  If LNGHKEY = "HKCR" Then hkRoot = HKCR
  If LNGHKEY = "HKUSERS" Then hkRoot = HKUSERS
  strComputer = "."
  Set objRegistry = GetObject("winmgmts:\\" & strComputer & "\root\default:StdRegProv")
  objRegistry.GetStringValue hkroot,strKey,strSubkey,dwValue

  If IsNull(dwValue) Then
    RegistryKeyExists = False
  Else
    RegistryKeyExists = True
  End If
End Function    

'======================================================================
' getUpdateSource(): Is WSUS or the MS online update service set up ?
'======================================================================
Function getUpdateSource()
  Const wsusRegKey = "HKLM\SOFTWARE\Policies\Microsoft\windows\WindowsUpdate\WUServer"

  Set wshShell = CreateObject("WScript.Shell")
  ' This registry key checks the GPO setting for WSUS server
    
  If RegistryKeyExists("HKLM", "SOFTWARE\Policies\Microsoft\windows\WindowsUpdate\", "WUServer") = True Then
    updateServer = "WU " & wshShell.regread(wsusRegKey)
  Else
    updateServer = "MS Online Update Service"
  End if
  set wshShell=nothing
END Function

'======================================================================
' getWindowsVersion() collects the OS version from the system we run on
'======================================================================
Function getWindowsVersion()

Set objAutoUpdate = CreateObject("Microsoft.Update.AutoUpdate")

  Set wshShell = CreateObject("WScript.Shell")
  strOS = wshShell.ExpandEnvironmentStrings("%OS%")
  If strOS = "Windows_NT" Then
    strVerKey = "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\"
    strVersion = wshShell.regread(strVerKey & "ProductName") & " " & wshShell.regread(strVerKey & "CurrentVersion") & "." & wshShell.regread(strVerkey & "CurrentBuildNumber")
  Else
    strVerKey = "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\"
    strVersion = wshShell.regread(strVerKey & "ProductName") & " " & wshShell.regread(strVerKey & "VersionNumber")
  End if
  ' For debug, we can output the version to a message box
  'MsgBox strVersion
  set wshShell=nothing
END Function

'=======================================================================
' SendTrap(trapCmdStr): creates the data string and sends it to traphost
'=======================================================================
Function SendTrap(trapCmdStr)

  set wshShell = CreateObject("WSCript.shell")  
  set wshnetwork=createobject("wscript.network")
  scomputername=wshnetwork.computername & ": "
  set wshnetwork=nothing
  
  trapCmd = trapCmdBin & " " & trapCmdDst & " " & trapCmdCom & " " & trapCmdOid & " " & trapCmdTyp & " " & chr(34) & scomputername & trapCmdStr & chr(34)
  'Debug -  echo the command to local output
  WScript.Echo trapCmd

  ' call trapgen and minimize the shell window, we dont't need it
  wshShell.Run trapCmd,2,TRUE
  set wshShell = nothing
End Function

'=======================================================================
' End Function Defs, Start Main
'=======================================================================

' Get cmdline params and initialize variables
If Wscript.Arguments.Named.Exists("h") Then
	Wscript.Echo "Usage: cscript.exe -NoLogo win_update_trapsend.vbs /w:1 /c:2"
  Wscript.Echo "version " & pluginVer
	WScript.Quit(intOK)
End If

trapCmdStr = "No trap data set."
sendMessage = "No message yet."

' Just in case we later need a different routine to find the update
' config, based on the Windows version we are running. So far it is
' identical for Windows XP, Windows 2000 and Windows 2003
getWindowsVersion()

' debug: msgBox("OS version: " & strVersion)

' Check if the automatic update service is enabled
Set objAutoUpdate = CreateObject("Microsoft.Update.AutoUpdate")

intResultDetect = objAutoUpdate.DetectNow
If intResultDetect = 0 Then
Else
  SendTrap("WARNING: Unable to detect Automatic Updates. | Windows Version: " & strVersion & " Update Service: none")
  Wscript.Quit(intUnknown)
End If

' get the update settings
Set objSettings = objAutoUpdate.Settings
If (objSettings.NotificationLevel < 1) Or (objSettings.NotificationLevel > 4) Then
  SendTrap("WARNING: Automatic Updates running but not configured. | Windows Version: " & strVersion & " Update Service: unset")
End If

' return the WSUS server if found, otherwise its the Windows online service.
getUpdateSource()

' debug: msgBox("Update Server: " & updateServer)

' Now check for a list of outstanding patches, if any
Set objSession = CreateObject("Microsoft.Update.Session")
Set objSearcher = objSession.CreateUpdateSearcher

intUncompletedCritical = 0
intUncompletedSoftware = 0

Set objSysInfo = CreateObject("Microsoft.Update.SystemInfo")
If objSysInfo.RebootRequired Then
  SendTrap("WARNING: System needs Reboot. | Windows Version: " & strVersion & " Update Service: unset")
  Wscript.Quit(intWarning)
End If

Set result = objSearcher.Search("IsInstalled = 0 and IsHidden = 0")
Set colDownloads = result.Updates

For i = 0 to colDownloads.Count - 1
  If colDownloads.Item(i).AutoSelectOnWebsites Then
    updatesNamesCritical   = " " & colDownloads.Item(i).Title & updatesNamesCritical
    intUncompletedCritical = intUncompletedCritical + 1
  Else
    updatesNamesSoftware   = " " & colDownloads.Item(i).Title & updatesNamesSoftware
    intUncompletedSoftware = intUncompletedSoftware + 1
  End If
Next

If intUncompletedCritical > 0 Then
  If intUncompletedSoftware > 0 Then
    sendMessage = "WARNING: " & intUncompletedCritical & " Critical Update(s):" & updatesNamesCritical & " | Windows Version: " & strVersion & ", Update Service: " & updateServer & ", " & intUncompletedSoftware & " Update(s): " & updatesNamesSoftware
    SendTrap(sendMessage)
    'msgBox(sendMessage)
    Wscript.Quit(intWarning)
  Else
    sendMessage = "WARNING: " & intUncompletedCritical & " Critical Update(s):" & updatesNamesCritical & " | Windows Version: " & strVersion & ", Update Service: " & updateServer
    SendTrap(sendMessage)
    'msgBox(sendMessage)
    Wscript.Quit(intWarning)
  End If
Else
  If intUncompletedSoftware > 0 Then
    sendMessage = "OK: No critical updates. | Windows Version: " & strVersion & ", Update Service: " & updateServer & ", " & intUncompletedSoftware & " Update(s):" & updatesNamesSoftware
    SendTrap(sendMessage)
    'msgBox(sendMessage)
    Wscript.Quit(intOK)
  Else
    sendMessage = "OK: No critical updates. | Windows Version: " & strVersion & ", Update Service: " & updateServer
    SendTrap(sendMessage)
    'msgBox(sendMessage)
    Wscript.Quit(intOK)
  End If
End If
'=======================================================================
' End Main
'=======================================================================
