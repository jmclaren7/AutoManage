#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_UseUpx=n
#AutoIt3Wrapper_Change2CUI=n
#AutoIt3Wrapper_Res_Fileversion=1.0.0.121
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
Global $ScriptFullPathNoExt=StringTrimRight(@ScriptFullPath,4) ; ini, log and other suplement files will use the scripts file name and path
Global $LogLevel=IniRead ($ScriptFullPathNoExt&"_Settings.ini", "settings", "LogLevel", 3) ; we read log level early in case we want no logging at all, log level is 0 or >0 for now

_ConsoleWrite("==="&$Title&" Start===")

OnAutoItExitRegister ( "_exit" )

If _only_instance(0) Then ; We wont allow multiple instances of the script, instead we set a flag in the ini file that's checked at the end to determine if the script should be run again
	IniWrite ($ScriptFullPathNoExt&"_Settings.ini", "temp", "runagain", "1")
	_ConsoleWrite("Multiple instances, setting runagain flag and exiting")
	Exit
endif
Sleep(2000)

; read various values from the ini file
$FileSizeThreshold=IniRead ($ScriptFullPathNoExt&"_Settings.ini", "settings", "FileSizeThreshold", 30)
$ScanPath=IniRead ($ScriptFullPathNoExt&"_Settings.ini", "settings", "ScanPath", "")
$SeriesPath=IniRead ($ScriptFullPathNoExt&"_Settings.ini", "settings", "SeriesPath", "")
$Moviespath=IniRead ($ScriptFullPathNoExt&"_Settings.ini", "settings", "MoviesPath", "")
$FileDelete=IniRead ($ScriptFullPathNoExt&"_Settings.ini", "settings", "FileDelete", 0)
$RunFileBot=IniRead ($ScriptFullPathNoExt&"_Settings.ini", "settings", "RunFileBot", 1)
$SafeExtensions=StringSplit (IniRead ($ScriptFullPathNoExt&"_Settings.ini", "settings", "SafeExtensions", "avi,mp4,mkv,m4v,mpg,3g2,3gp,asf,asx,flv,mov,rm,swf,vob,wmv"), ",") ;Only these extensions will be

if $RunFileBot<>0 then
	Dim $aMatches
	_FileReadToArray($ScriptFullPathNoExt&"_Matches.txt", $aMatches) ; Matches are a list of files to run through FileBot, see notes later on when we actualy check against this list
	if @error Then
		_ConsoleWrite("Couldn't read matches file, continuing")
		$aMatches = ""
	endif
endif

While 1 ; we loop 'forever' so we can easily restart the entire script, if we are content to exit we need to do so manualy
	$List = _FileListToArray ($ScanPath, "*", 0) ; get an array of files from the specified path
	if @error Then
		if @error = 4 then
			_ConsoleWrite("No Files")
		else
			_ConsoleWrite("File Listing Error",2)
		EndIf
		exit
	endif

	for $f=1 to $List[0] ; loop through each file in scanpath
		$FilePath=$ScanPath&"\"&$List[$f]
		$attrib=FileGetAttrib ($FilePath) ; so we can determine if the we have a file, folder, system file or hidden file
		$RemoveSubDirectory=false

		_ConsoleWrite($FilePath&" ("&$attrib&")",2)

		if StringInStr($attrib, "S") OR StringInStr($attrib,"H") then ContinueLoop ; if system or hidden file, skip to next file

		if StringInStr($attrib, "D") then ; if directory lets scan inside to determine a file of interest
			$Array=_FileListToArray ($FilePath, "*", 1)
			if @error Then
				if @error = 4 then
					_ConsoleWrite("  No Files")
				else
					_ConsoleWrite("  File Listing Error",2)
				EndIf
				ContinueLoop
			endif

			$c=0 ; counter for how many files of interest
			for $i=1 to $Array[0] ; loop through each file in subdirectory
				if FileGetSize($FilePath&"\"&$Array[$i]) > $FileSizeThreshold*1024*1024 Then ;if a file is large enough we must want it... needs to be rethought
					$c=$c+1
					$FilePath=$FilePath&"\"&$Array[$i]
				endif
			next
			if $c=1 then
				$RemoveSubDirectory=true ; since we had success lets delete this folder when we are done working with it... not very gracefull
				_ConsoleWrite("  Changed To File: "&$FilePath,3)
			elseif $c>1 then
				_ConsoleWrite("  Too Many Matches Inside Directory",3)
				ContinueLoop
			elseif $c=0 then
				_ConsoleWrite("  No Matches Inside Directory",3)
				ContinueLoop
			endif
		endif

		if NOT StringInStr(FileGetAttrib ($FilePath),"D") then
			$Path=StringTrimRight ($FilePath, StringLen($FilePath)-StringInStr ($FilePath, "\" , 0, -1)+1)
			$File=StringTrimLeft ($FilePath, StringInStr ($FilePath, "\" , 0, -1))

			_ConsoleWrite("  File: "&$File)

			$Ext=StringTrimLeft($File,StringInStr($File,".",0,-1))
			if _ArraySearch($SafeExtensions,$Ext)=-1 then continueloop ; skip this file if extention isnt in safe list

			if $RunFileBot>0 then
				$ShowName=""
				If IsArray ($aMatches) Then ; if we have a list of file names to run though filebot
					for $m=1 to $aMatches[0]
						$aMatches_Line=StringSplit($aMatches[$m],",") ; interprit the list: the list is one show per line formated as [left part of file name string],[Show name on TVDB]
						$aMatches_Line[1]=StringStripWS ($aMatches_Line[1], 1+2)
						If $aMatches_Line[0]>1 then ; optionaly a line can contain 1 value, if it does use that value for both comparison and lookup
							$aMatches_Line[2]=StringStripWS ($aMatches_Line[2], 1+2)
						Else
							ReDim $aMatches_Line[3]
							$aMatches_Line[2]=$aMatches_Line[1]
						endif

						if StringLeft($File, StringLen($aMatches_Line[1])) = $aMatches_Line[1] Or _ ;test to see if the first value in the line matches the left part of the filename
							StringLeft(StringReplace($File, "_", "."), StringLen($aMatches_Line[1])) = $aMatches_Line[1] Then
							$ShowName=$aMatches_Line[2] ; set showname so that filebot runs
						endif
					Next
				endif

				if $ShowName<>"" OR $RunFileBot=2 then
					if NOT FileBot($FilePath, $ShowName) Then ; run file bot
						_ConsoleWrite("  FileBot failed, skipping to next file")
						ContinueLoop
					endif
				endif

				if NOT FileExists($FilePath) then ; if filebot renamed a file we just stop everything and start the script over again in order to correct the entry in the file list array(s), surprisingly elegant except that filebot might run an extra time
					_ConsoleWrite("Renamed A File, Starting Over")
					ContinueLoop 2
				EndIf
			EndIf

			; now we try to get the episode, season and show name, we go from best formated to worst formated
			Dim $EpisodeStrings[2]
			$EpisodeStrings=StringRegExp($File,'(?P<show>.*?)[sS](?P<season>[0-9]+)[\._ ]*[eE](?P<ep>[0-9]+)([- ]?[Ee+](?P<secondEp>[0-9]+))?',1) ; S01E02 or S01E02-E03
			if @error Then
				$EpisodeStrings=StringRegExp($File,'(?P<show>.*?)(?P<season>[0-9]{1,2})[Xx](?P<ep>[0-9]+)(-[0-9]+[Xx](?P<secondEp>[0-9]+))?',1) ; 1x02
				if @error then
					$EpisodeStrings=StringRegExp($File,'(.*?)[^0-9a-z](?P<season>[0-9]{1,2})(?P<ep>[0-9]{2})([\.\-][0-9]+(?P<secondEp>[0-9]{2})([ \-_\.]|$)[\.\-]?)?([^0-9a-z%]|$)',1) ; .602.
					if @error=0 AND ($EpisodeStrings[1]="19" OR $EpisodeStrings[1]="20") then
						Dim $EpisodeStrings[2]
					endif
				endif
			endif

			_ConsoleWrite("  Episode Strings: ("&IsArray($EpisodeStrings)&") ("&$EpisodeStrings&")")

			if StringInStr($File,".YIFY",1) then ; must be YIFY movie... only uploader with movie naming convention i'm willing to rely on 100% ATM
				_ConsoleWrite("  Found YIFY Movie")
				$array=_MovieName($File)
				$DestinationFilePath=$MoviesPath&"\"&$array[1]&$array[2]

			elseif IsArray($EpisodeStrings) and $EpisodeStrings[0]<>"" and $EpisodeStrings[1]<>"" Then ; must be episode
				_ConsoleWrite("  Found Episode ["&$EpisodeStrings[0]&"] ["&$EpisodeStrings[1]&"]")
				$Folder=$EpisodeStrings[0]

				; instead of doing a string replace we will loop the string manualy so we can do some conditional formating (at some point)
				$aFolder=StringSplit($folder,"")
				for $z=1 to $aFolder[0]-1
					if $aFolder[$z]="." Then $aFolder[$z]=" "
					if $aFolder[$z]="_" Then $aFolder[$z]=" "
				next
				$Folder=_ArrayToString($aFolder,"",1)

 				for $x=@YEAR to @YEAR-80 Step -1
 					if StringInStr($Folder,String($x)) AND NOT StringInStr($Folder,"("&String($x)&")") then
 						_ConsoleWrite("  Added parenthsis to year in folder name ("&$x&")")
 						$Folder=StringReplace($Folder,String($x),"("&String($x)&")")
 						ExitLoop
 					endif
 				next

				if StringRight($Folder,1)="." then $Folder=StringTrimRight($folder,1)
				$Folder=StringStripWS ($Folder, 1+2)
				$Folder=__StringProper($Folder)

				If $Folder = "Tosh 0" Then $Folder = "Tosh.0" ; havn't thought of a way to handle show names with a period in them

				_ConsoleWrite("  Destination Folder: "&$Folder)

				If $EpisodeStrings[1]<>"" then ; why did i care about this, could we of gotten this far without a
					if StringInStr(FileGetAttrib ($SeriesPath&"\"&$Folder&"\Season "&$EpisodeStrings[1]),"D") then
						$DestinationPath=$SeriesPath&"\"&$Folder&"\Season "&$EpisodeStrings[1]
					elseif StringInStr(FileGetAttrib ($SeriesPath&"\"&$Folder&"\Season "&Abs($EpisodeStrings[1])),"D") then
						$DestinationPath=$SeriesPath&"\"&$Folder&"\Season "&Abs($EpisodeStrings[1])
					else
						if FileExists($SeriesPath&"\"&$Folder&"\Season 1") then $EpisodeStrings[1]=Abs($EpisodeStrings[1])
						$DestinationPath=$SeriesPath&"\"&$Folder&"\Season "&$EpisodeStrings[1]
						_ConsoleWrite("  Creating Directory: "&$DestinationPath)
						if NOT @Compiled then
							_ConsoleWrite("  ===!!!RUNNING AS SCRIPT WONT MAKE THAT CHANGE!!!===")
						else
							DirCreate($DestinationPath)
						endif
					endif
				Else
					$DestinationPath=$SeriesPath&"\"&$Folder
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
				_ConsoleWrite("  Copy Success, Removing Original...")
				FileSetAttrib ($DestinationFilePath, "-RASH")
				sleep(3000)

				for $l=1 to 3 ; remove the individual original media file
					if $RemoveSubDirectory AND $Path<>$ScanPath AND DirGetSize($Path) < $FileSizeThreshold*1024*1024 then ; remove the subfolder the media file resides in
						if $FileDelete=1 and DirRemove($Path,1)=1 Then
							_ConsoleWrite("  Deleted Folder")
							ExitLoop
						elseif $FileDelete=0 and FileRecycle($Path)=1 Then
							_ConsoleWrite("  Recycled Folder")
							ExitLoop
						Else
							_ConsoleWrite("  Couldn't Delete Folder")
						endif
					else
						if $FileDelete=1 and FileDelete($FilePath)=1 Then
							_ConsoleWrite("  Deleted File")
							ExitLoop
						elseif $FileDelete=0 and FileRecycle($FilePath)=1 Then
							_ConsoleWrite("  Recycled File")
							ExitLoop
						Else
							_ConsoleWrite("  Couldn't Delete File")
						endif
					endif
					sleep(3000)
				next

			Else
				_ConsoleWrite("  Copy Failed")
			endif

		endif
	next

	;if another proccess wasnt created during run then exit, otherwise lets go again
	if IniRead ($ScriptFullPathNoExt&"_Settings.ini", "temp", "runagain", "0") = 1 Then
		_ConsoleWrite("Starting again (another instance tried to start during this run)")
		if IniWrite ($ScriptFullPathNoExt&"_Settings.ini", "temp", "runagain", "0") then ContinueLoop
	endif

	exit
wend
;===============================================================================
;===============================================================================
;===============================================================================
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
;===============================================================================
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
;===============================================================================
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
;===============================================================================
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
;===============================================================================
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
;===============================================================================
Func _ConsoleWrite($sMessage,$Level=1)
	if Eval("LogLevel")="" then $LogLevel=3 ; If no level set max is used

	If $Level<=$LogLevel then
		$sMessage=StringReplace($sMessage,@CRLF&@CRLF,@CRLF) ;Remove Double CR
		If StringRight($sMessage,StringLen(@CRLF))=@CRLF Then $sMessage=StringTrimRight($sMessage,StringLen(@CRLF)) ; Remove last CR
		Local $sTime=@HOUR&":"&@MIN&":"&@SEC&"> " ; Generate Timestamp

		$sMessage=StringReplace($sMessage,@CRLF,@CRLF&$sTime)
		$sMessage=@CRLF&$sTime&$sMessage

		ConsoleWrite($sMessage)
		FileWrite($ScriptFullPathNoExt&"_Log.txt",$sMessage)
	endif

	Return $sMessage
EndFunc
;===============================================================================
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
;===============================================================================
func _exit()
	_ConsoleWrite("Finished")
	;sleep(20000)
endfunc