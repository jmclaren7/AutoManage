#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_UseUpx=n
#AutoIt3Wrapper_Change2CUI=n
#AutoIt3Wrapper_Res_Fileversion=1.0.0.112
#AutoIt3Wrapper_Res_Fileversion_AutoIncrement=y
#AutoIt3Wrapper_Res_Language=1033
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****
#NoAutoIt3Execute
#NoTrayIcon
Opt("TrayIconHide",1)

#include <Constants.au3>
#include <File.au3>
#include <Array.au3>

Global $Title=@ScriptName
_ConsoleWrite("==="&$Title&" Start===")

OnAutoItExitRegister ( "_exit" )

If _only_instance(0) Then
	IniWrite (StringTrimRight(@ScriptFullPath,4)&"_Settings.ini", "temp", "runagain", "1")
	_ConsoleWrite("Multiple instances, setting runagain flag and exiting")
	Exit
endif
Sleep(2000)

$TopPath="H:\New Files"
$MediaDrive="M:"
$GoodExtensions=StringSplit ("avi,mp4,mkv,m4v,mpg,3g2,3gp,asf,asx,flv,mov,rm,,swf,vob,wmv", ",")

Dim $aMatches
_FileReadToArray(StringTrimRight(@ScriptFullPath,4)&"_Matches.txt", $aMatches)
if @error Then
	_ConsoleWrite("Couldn't Read Matches File")
	$aMatches = ""
endif

While 1
	$List = _FileListToArray ($TopPath, "*", 0)
	if @error Then
		if @error = 4 then
			_ConsoleWrite("No Files")
		else
			_ConsoleWrite("File Listing Error",2)
		EndIf
		exit
	endif

	for $f=1 to $List[0]
		$FilePath=$TopPath&"\"&$List[$f]
		$attrib=FileGetAttrib ($FilePath)
		$DeleteSubDirectory=false

		_ConsoleWrite($FilePath&" ("&$attrib&")",2)

		if StringInStr($attrib, "S") OR StringInStr($attrib,"H") then ContinueLoop

		if StringInStr($attrib, "D") then
			;scan directory and determine file of intrest
			$Array=_FileListToArray ($FilePath, "*", 1)
			if @error then ContinueLoop
			$c=0
			for $i=1 to $Array[0]
				if FileGetSize($FilePath&"\"&$Array[$i]) > 30*1024*1024 Then
					$c=$c+1
					$FilePath=$FilePath&"\"&$Array[$i]
				endif
			next
			if $c=1 then
				$DeleteSubDirectory=true
				_ConsoleWrite("  Changed To File: "&$FilePath,3)
			else
				if $c>1 then _ConsoleWrite("Too Many Matches Inside Directory",3)
				if $c=0 then _ConsoleWrite("No Matches Inside Directory",3)
				ContinueLoop
			endif
		endif

		if NOT StringInStr(FileGetAttrib ($FilePath),"D") then
			$Path=StringTrimRight ($FilePath, StringLen($FilePath)-StringInStr ($FilePath, "\" , 0, -1)+1)
			$File=StringTrimLeft ($FilePath, StringInStr ($FilePath, "\" , 0, -1))

			_ConsoleWrite("  File: "&$File)

			$Ext=StringTrimLeft($File,StringInStr($File,".",0,-1))
			if _ArraySearch($GoodExtensions,$Ext)=-1 then continueloop

			If IsArray ($aMatches)Then
				for $m=1 to $aMatches[0]
					$aMatches_Line=StringSplit($aMatches[$m],",")
					$aMatches_Line[1]=StringStripWS ($aMatches_Line[1], 1+2)
					If $aMatches_Line[0]>1 then
						$aMatches_Line[2]=StringStripWS ($aMatches_Line[2], 1+2)
					Else
						ReDim $aMatches_Line[3]
						$aMatches_Line[2]=$aMatches_Line[1]
					endif

					if StringLeft($File, StringLen($aMatches_Line[1])) = $aMatches_Line[1] Or _
						StringLeft(StringReplace($File, "_", "."), StringLen($aMatches_Line[1])) = $aMatches_Line[1] Then
						if NOT FileBot($FilePath, $aMatches_Line[2]) Then
							_ConsoleWrite("  FileBot failed, skipping to next file")
							ContinueLoop 2
						endif
					endif
				Next
			endif
 			if NOT FileExists($FilePath) then
				_ConsoleWrite("Renamed A File, Starting Over")
				ContinueLoop 2
			EndIf

			Dim $Breakdown[2]
			$Breakdown=StringRegExp($File,'(?P<show>.*?)[sS](?P<season>[0-9]+)[\._ ]*[eE](?P<ep>[0-9]+)([- ]?[Ee+](?P<secondEp>[0-9]+))?',1) ;S01E02-E03
			if @error Then
				$Breakdown=StringRegExp($File,'(?P<show>.*?)(?P<season>[0-9]{1,2})[Xx](?P<ep>[0-9]+)(-[0-9]+[Xx](?P<secondEp>[0-9]+))?',1) ;1x02
				if @error then
					$Breakdown=StringRegExp($File,'(.*?)[^0-9a-z](?P<season>[0-9]{1,2})(?P<ep>[0-9]{2})([\.\-][0-9]+(?P<secondEp>[0-9]{2})([ \-_\.]|$)[\.\-]?)?([^0-9a-z%]|$)',1) ;.602.
					if @error=0 AND ($Breakdown[1]="19" OR $Breakdown[1]="20") then
						Dim $Breakdown[2]
					endif
				endif
			endif

			_ConsoleWrite("  Breakdown done ("&IsArray($Breakdown)&") ("&$Breakdown&")")

			if StringInStr($File,".YIFY",1) then
				_ConsoleWrite("  Found YIFI Movie")
				$array=_MovieName($File)
				$DestinationFilePath=$MediaDrive&"\Movies\"&$array[1]&$array[2]

			elseif IsArray($Breakdown) and $Breakdown[0]<>"" and $Breakdown[1]<>"" Then
				_ConsoleWrite("  Found Episode ["&$Breakdown[0]&"] ["&$Breakdown[1]&"]")
				$Folder=$Breakdown[0]

				$aFolder=StringSplit($folder,"")
				for $z=1 to $aFolder[0]-1
					;if $aFolder[$z]="." AND NOT (Asc($aFolder[$z+1])>=48 AND Asc($aFolder[$z+1])<57) Then $aFolder[$z]=" "
					if $aFolder[$z]="." Then $aFolder[$z]=" "
					if $aFolder[$z]="_" Then $aFolder[$z]=" "
				next
				$Folder=_ArrayToString($aFolder,"",1)

 				for $x=@YEAR to @YEAR-80 Step -1
 					if StringInStr($Folder,String($x)) AND NOT StringInStr($Folder,"("&String($x)&")")then
 						_ConsoleWrite("  Added parenthsis to year in folder name ("&$x&")")
 						$Folder=StringReplace($Folder,String($x),"("&String($x)&")")
 						ExitLoop
 					endif
 				next

				if StringRight($Folder,1)="." then $Folder=StringTrimRight($folder,1)
				$Folder=StringStripWS ($Folder, 1+2)
				$Folder=__StringProper($Folder)

				If $Folder = "Tosh 0" Then $Folder = "Tosh.0"
				;If $Folder = "Doctor Who" Then $Folder = "Doctor Who (2005)"
				;If $Folder = "Conan" Then $Folder = "Conan (2010)"

				_ConsoleWrite("  Destination Folder: "&$Folder)

				If $Breakdown[1]<>"" then
					if StringInStr(FileGetAttrib ($MediaDrive&"\Series\"&$Folder&"\Season "&$Breakdown[1]),"D") then
						$DestinationPath=$MediaDrive&"\Series\"&$Folder&"\Season "&$Breakdown[1]
					elseif StringInStr(FileGetAttrib ($MediaDrive&"\Series\"&$Folder&"\Season "&Abs($Breakdown[1])),"D") then
						$DestinationPath=$MediaDrive&"\Series\"&$Folder&"\Season "&Abs($Breakdown[1])
					else
						if FileExists($MediaDrive&"\Series\"&$Folder&"\Season 1") then $Breakdown[1]=Abs($Breakdown[1])
						$DestinationPath=$MediaDrive&"\Series\"&$Folder&"\Season "&$Breakdown[1]
						_ConsoleWrite("  Creating Directory: "&$DestinationPath)
						if NOT @Compiled then
							_ConsoleWrite("  ===!!!RUNNING AS SCRIPT WONT MAKE THAT CHANGE!!!===")
						else
							DirCreate($DestinationPath)
						endif
					endif
				Else
					$DestinationPath=$MediaDrive&"\Series\"&$Folder
				endif
				$DestinationFilePath=$DestinationPath&"\"&$File

			Else
				_ConsoleWrite("  Didn't Match Anything")
				ContinueLoop
			EndIf

			_ConsoleWrite("  Copying File To: "&$DestinationFilePath)
			If NOT @Compiled then
				_ConsoleWrite("  ===!!!RUNNING AS SCRIPT WONT MAKE THAT CHANGE!!!===")

			Elseif FileCopy($FilePath,$DestinationFilePath,1)=1 Then
				FileSetAttrib ($DestinationFilePath, "-RASH")
				_ConsoleWrite("  Copy Success, Deleteing Original...")
				sleep(3000)
				if FileRecycle($FilePath)=1 Then
					_ConsoleWrite("  Deleted File")
				Else
					_ConsoleWrite("  Couldn't Delete File, Trying One More Time...")
					sleep(3000)
					if FileRecycle($FilePath)=1 Then
						_ConsoleWrite("  Deleted File")
					Else
						_ConsoleWrite("  Couldn't Delete File")
					endif
				endif

				if $DeleteSubDirectory AND DirGetSize($Path)<50*1000000 then
					_ConsoleWrite("  Deleting Folder: "&$Path)
					if DirRemove($Path,1)=1 Then
						_ConsoleWrite("  Deleted Folder")
					Else
						_ConsoleWrite("  Couldn't Delete Folder")
					endif
				endif

			Else
				_ConsoleWrite("  Copy Failed")
			endif

		endif
	next

	;if another proccess wasnt created during run then exit, otherwise lets go again
	if IniRead (StringTrimRight(@ScriptFullPath,4)&"_Settings.ini", "temp", "runagain", "0") = 1 Then
		_ConsoleWrite("Starting again (another instance tried to start during this run)")
		if IniWrite (StringTrimRight(@ScriptFullPath,4)&"_Settings.ini", "temp", "runagain", "0") then ContinueLoop
	endif

	exit
wend


Func _MovieName($string)
	local $smart[3], $founddate=False

	$smart[2]=StringLower(StringTrimLeft($string,StringInStr($string,".",0,-1)-1))
	$smart[0]=Stringleft($string,StringInStr($string,".",0,-1)-1)
	$smart[1]=$smart[0]

	for $x=@YEAR to @YEAR-80 Step -1
		if StringInStr($smart[1],$x) then
			$smart[1]=StringLeft($smart[1],StringInStr($smart[1],$x)-1)
			$founddate=true
			ExitLoop
		endif
	next

	if StringInStr($smart[1],".DVDRip") then $smart[1]=StringLeft( $smart[1],StringInStr($smart[1],".DVDRip")-1)
	if StringInStr($smart[1],"1080") then $smart[1]=StringLeft( $smart[1],StringInStr($smart[1],"1080")-1)
	if StringInStr($smart[1],"720") then $smart[1]=StringLeft( $smart[1],StringInStr($smart[1],"720")-1)
	if StringInStr($smart[1],"BluRay") then $smart[1]=StringLeft( $smart[1],StringInStr($smart[1],"BluRay")-1)

	if StringInStr($smart[1],"[") then $smart[1]=StringLeft( $smart[1],StringInStr($smart[1],"[")-1)
	if StringInStr($smart[1],"(") then $smart[1]=StringLeft( $smart[1],StringInStr($smart[1],"(")-1)

	$smart[1]=StringReplace ($smart[1],"_"," ")
	$smart[1]=StringReplace ($smart[1],"."," ")

	$smart[1]=StringStripWS ($smart[1], 1+2+4)

	$smart[1]=__StringProper($smart[1])

	if $founddate then $smart[1] = $smart[1] & " (" & $x & ")"

	return $smart
endfunc
Func _RunWait($Run, $Working="")
	Local $sData, $sStdOut, $iPid
	$iPid=Run($Run, $Working, @SW_HIDE, $STDERR_MERGED)
	If @error then
		_ConsoleWrite("_RunWait: Couldn't Run "&$Run)
		return 0
	endif
	ProcessWait($iPid,1)
	While ProcessExists($iPid)
		Sleep(10)
		$sStdOut = StdoutRead($iPid)
		If $sStdOut = "" Then ContinueLoop
		$sStdOut=StringReplace($sStdOut,@CR&@LF&@CR&@LF,@CR&@LF)
		_ConsoleWrite($sStdOut)
		$sData &= $sStdOut
	WEnd
	return $iPid
endfunc
Func FileBot($FilePath, $Search)
	Local $FileBotParameters = "-r --log warning -non-strict --format ""{n.space('.')}.{s00e00}.{airdate}.{t.space('.')}"""
	_ConsoleWrite("  Parsing With FileBot")
	if _FileUnlockWait($FilePath, 10) then
		if NOT @Compiled then
			_ConsoleWrite("  ===!!!RUNNING AS SCRIPT WONT MAKE THAT CHANGE!!!===")
		else
			if NOT _RunWait("filebot -rename """&$FilePath&""" --q """&$Search&""" "&$FileBotParameters) Then
				_ConsoleWrite("  Error running Filebot")
				return 0
			endif
		endif
	Else
		_ConsoleWrite("  File locked, not running FileBot")
		return 0
	endif
	return 1
endfunc
func _FileUnlockWait($File, $Timeout=0, $Sleep=2000)
	$Timeout=$Timeout*1000
	$Time=TimerInit ( )
	while 1
		if _FileInUse($FilePath) Then
			_ConsoleWrite("  File locked")
		Else
			Return 1
		endif
		if $Timeout > 0 AND $Timeout < TimerDiff($Time) then
			_ConsoleWrite("  Timeout, file locked")
			Return 0
		endif
		Sleep($Sleep)
	wend
endfunc
Func __StringProper($s_String)
	Local $iX = 0
	Local $CapNext = 1
	Local $s_nStr = ""
	Local $s_CurChar
	For $iX = 1 To StringLen($s_String)
		$s_CurChar = StringMid($s_String, $iX, 1)
		Select
			Case $CapNext = 1
				If StringRegExp($s_CurChar, '[a-zA-ZÀ-ÿšœžŸ]') Then
					$s_CurChar = StringUpper($s_CurChar)
					$CapNext = 0
				EndIf
			Case Not StringRegExp($s_CurChar, '[a-zA-ZÀ-ÿšœžŸ]') AND $s_CurChar <> "'"
				$CapNext = 1
			Case Else
				$s_CurChar = StringLower($s_CurChar)
		EndSelect
		$s_nStr &= $s_CurChar
	Next
	Return $s_nStr
EndFunc   ;==>_StringProper
Func _ConsoleWrite($sMessage,$Level=1)
	if Eval("LogLevel")="" then $LogLevel=3 ; If no level set max is used

	If $Level<=$LogLevel then
		$sMessage=StringReplace($sMessage,@CRLF&@CRLF,@CRLF) ;Remove Double CR
		If StringRight($sMessage,StringLen(@CRLF))=@CRLF Then $sMessage=StringTrimRight($sMessage,StringLen(@CRLF)) ; Remove last CR
		Local $sTime=@HOUR&":"&@MIN&":"&@SEC&"> " ; Generate Timestamp

		$sMessage=StringReplace($sMessage,@CRLF,@CRLF&$sTime)
		$sMessage=@CRLF&$sTime&$sMessage

		ConsoleWrite($sMessage)
		FileWrite(StringTrimRight(@ScriptFullPath,4)&"_Log.txt",$sMessage)
	endif

	Return $sMessage
EndFunc
Func _FileInUse($sFilename, $iAccess = 0)
    Local $aRet, $hFile, $iError, $iDA
    Local Const $GENERIC_WRITE = 0x40000000
    Local Const $GENERIC_READ = 0x80000000
    Local Const $FILE_ATTRIBUTE_NORMAL = 0x80
    Local Const $OPEN_EXISTING = 3
    $iDA = $GENERIC_READ
    If BitAND($iAccess, 1) <> 0 Then $iDA = BitOR($GENERIC_READ, $GENERIC_WRITE)
    $aRet = DllCall("Kernel32.dll", "hwnd", "CreateFile", _
                                    "str", $sFilename, _ ;lpFileName
                                    "dword", $iDA, _ ;dwDesiredAccess
                                    "dword", 0x00000000, _ ;dwShareMode = DO NOT SHARE
                                    "dword", 0x00000000, _ ;lpSecurityAttributes = NULL
                                    "dword", $OPEN_EXISTING, _ ;dwCreationDisposition = OPEN_EXISTING
                                    "dword", $FILE_ATTRIBUTE_NORMAL, _ ;dwFlagsAndAttributes = FILE_ATTRIBUTE_NORMAL
                                    "hwnd", 0) ;hTemplateFile = NULL
    $iError = @error
    If @error Or IsArray($aRet) = 0 Then Return SetError($iError, 0, -1)
    $hFile = $aRet[0]
    If $hFile = -1 Then ;INVALID_HANDLE_VALUE = -1
        $aRet = DllCall("Kernel32.dll", "int", "GetLastError")
        ;ERROR_SHARING_VIOLATION = 32 0x20
        ;The process cannot access the file because it is being used by another process.
        If @error Or IsArray($aRet) = 0 Then Return SetError($iError, 0, 1)
        Return SetError($aRet[0], 0, 1)
    Else
        ;close file handle
        DllCall("Kernel32.dll", "int", "CloseHandle", "hwnd", $hFile)
        Return SetError(@error, 0, 0)
    EndIf
EndFunc
;===============================================================================
; Function Name:    _only_instance()
; Description:		Checks to see if we are the only instance running
; Call With:		_only_instance($Flag)
; Parameter(s): 	$Flag
;						0 = Continue Anyway
;						1 = Exit Without Notification
;						2 = Exit After Notifying
;						3 = Prompt What To Do
;						4 = Close Other Proccesses
; Return Value(s):  On Success - 1 (Found Another Instance)
; 					On Failure - 0 (Didnt Find Another Instance)
; Author(s):        JohnMC - www.TeamMC.cc
; Date/Version:		01/29/2010  --  v1.0
;===============================================================================
func _only_instance($Flag);0=Continue 1=Exit 2=Inform/Exit 3=Prompt
	Local $ERROR_ALREADY_EXISTS = 183, $Handle, $LastError, $Message

	if @Compiled=0 then return 0

	$Handle = DllCall("kernel32.dll", "int", "CreateMutex", "int", 0, "long", 1, "str", @ScriptName)
	$LastError = DllCall("kernel32.dll", "int", "GetLastError")
	If $LastError[0] = $ERROR_ALREADY_EXISTS Then
		SetError($LastError[0], $LastError[0], 0)
		Switch $Flag
			case 0
				return 1
			case 1
				ProcessClose(@AutoItPID)
			case 2
				MsgBox(262144+48,@ScriptName,"The Program Is Already Running")
				ProcessClose(@AutoItPID)
			case 3
				if MsgBox(262144+256+48+4,@ScriptName, "The Program ("&@ScriptName&") Is Already Running, Continue Anyway?")=7 then ProcessClose(@AutoItPID)
			case 4
				;_ProcessCloseOthers()
		EndSwitch
		return 1
	EndIf
	return 0
endfunc
func _exit()
	_ConsoleWrite("Finished")
	;sleep(20000)
endfunc