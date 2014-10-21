#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Res_Fileversion=1.0.0.163
#AutoIt3Wrapper_Res_Fileversion_AutoIncrement=y
#AutoIt3Wrapper_Res_Language=1033
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****
#NoAutoIt3Execute
#NoTrayIcon
Opt("TrayIconHide",1)

#include <_CommonFunctions.au3>
#include <Constants.au3>
#include <File.au3>
#include <Array.au3>

Global $Title = @ScriptName
Global $ScriptFullPathNoExt = StringTrimRight(@ScriptFullPath,4) ; ini, log and other suplement files will use the scripts file name and path
Global $LogLevel = IniRead ($ScriptFullPathNoExt&"_Settings.ini", "settings", "LogLevel", 3) ; we read log level early in case we want no logging at all, log level is 0 or >0 for now
Global $LogToFile = True
Global $NoChanges = Int(IniRead ($ScriptFullPathNoExt&"_Settings.ini", "settings", "NoChanges", 0))
If NOT @Compiled Then $NoChanges = 1

_ConsoleWrite("==="&$Title&" Start===")

OnAutoItExitRegister ( "_exit" )

If _OnlyInstance(0) Then ; We won't allow multiple instances of the script, instead we set a flag in the ini file that's checked at the end to determine If the script should be run again
	IniWrite ($ScriptFullPathNoExt&"_Settings.ini", "temp", "runagain", "1")
	_ConsoleWrite("Multiple instances, setting runagain flag and exiting")
	Exit
endif
Sleep(2000)

; read various values from the ini file
$FileSizeThreshold=IniRead ($ScriptFullPathNoExt&"_Settings.ini", "settings", "FileSizeThreshold", 30)
$ScanPath=IniRead ($ScriptFullPathNoExt&"_Settings.ini", "settings", "ScanPath", "")
$SeriesPath=IniRead ($ScriptFullPathNoExt&"_Settings.ini", "settings", "SeriesPath", "")
$MoviesPath=IniRead ($ScriptFullPathNoExt&"_Settings.ini", "settings", "MoviesPath", "")
$FileRemove=IniRead ($ScriptFullPathNoExt&"_Settings.ini", "settings", "FileRemove", 1)
$RunFileBot=IniRead ($ScriptFullPathNoExt&"_Settings.ini", "settings", "RunFileBot", 1)
$FileBotEpisodeFormat=IniRead ($ScriptFullPathNoExt&"_Settings.ini", "settings", "FileBotEpisodeFormat", "{n.space('.')}.{s00e00}.{airdate}.{t.space('.')}")
$SafeExtensions=StringSplit (IniRead ($ScriptFullPathNoExt&"_Settings.ini", "settings", "SafeExtensions", "avi,mp4,mkv,m4v,mpg,3g2,3gp,asf,asx,flv,mov,rm,swf,vob,wmv"), ",") ;Only these extensions will be

; check all user specified paths to make sure they are valid
If DriveStatus (StringLeft($ScanPath,3))<>"READY"  OR Not FileExists ($ScanPath) Then
	_ConsoleWrite("ScanPath doesn't exist: "&$ScanPath)
	Exit
endif
If DriveStatus (StringLeft($SeriesPath,3))<>"READY"  OR Not FileExists ($SeriesPath) Then
	_ConsoleWrite("SeriesPath doesn't exist: "&$SeriesPath)
	Exit
endif
If DriveStatus (StringLeft($MoviesPath,3))<>"READY"  OR Not FileExists ($MoviesPath) Then
	_ConsoleWrite("MoviesPath doesn't exist: "&$MoviesPath)
	Exit
endif

; if user specified to use filebot in any way then lets load the matches list
If $RunFileBot<>0 then
	Dim $aMatches
	_FileReadToArray($ScriptFullPathNoExt&"_Matches.txt", $aMatches) ; Matches are a list of files to run through FileBot, see notes later on when we actualy check against this list
	If @error Then
		_ConsoleWrite("Couldn't read matches file, continuing")
		$aMatches = ""
	endif
endif

; main script loop... we loop 'forever' so we can easily restart the entire script, If we are content to exit we need to do so manualy
While 1
	$List = _FileListToArray ($ScanPath, "*", 0) ; get an array of files from the specified path
	If @error Then
		If @error = 4 then
			_ConsoleWrite("No files")
		else
			_ConsoleWrite("File listing error")
		EndIf
		exit
	endif

	; loop through each file found in the scanpath
	for $f=1 to $List[0]
		$FilePath = $ScanPath&"\"&$List[$f]
		$sFileAttributes = FileGetAttrib ($FilePath) ; so we can determine If the we have a file, folder, system file or hidden file
		$RemoveSubDirectory = False

		_ConsoleWrite($FilePath&" ("&$sFileAttributes&")")

		If StringInStr($sFileAttributes, "S") OR StringInStr($sFileAttributes,"H") Then ContinueLoop ; If system or hidden file, skip to next file

		; If we are working with a directory lets scan inside to determine a file of interest
		If StringInStr($sFileAttributes, "D") Then
			$Array=_FileListToArray ($FilePath, "*", 1)
			If @error Then
				If @error = 4 then
					_ConsoleWrite("  No files")
				else
					_ConsoleWrite("  File listing error")
				EndIf
				ContinueLoop
			endif

			$c=0 ; counter for how many files of interest
			for $i=1 to $Array[0] ; loop through each file in subdirectory
				If FileGetSize($FilePath&"\"&$Array[$i]) > $FileSizeThreshold*1024*1024 Then ;If a file is large enough we must want it... needs to be rethought
					$c=$c+1
					$FilePath=$FilePath&"\"&$Array[$i]
				endif
			next
			If $c=1 then
				$RemoveSubDirectory = True ; since we had success lets delete this folder when we are done working with it... not very gracefull
				_ConsoleWrite("  Changed to file: "&$FilePath,3)
			elseIf $c>1 then
				_ConsoleWrite("  Too many matches inside directory")
				ContinueLoop
			elseIf $c=0 then
				_ConsoleWrite("  No matches inside directory")
				ContinueLoop
			endif
		endif

		; make sure we are not still working with a directory
		If NOT StringInStr(FileGetAttrib ($FilePath),"D") then
			$Path=StringTrimRight ($FilePath, StringLen($FilePath)-StringInStr ($FilePath, "\" , 0, -1)+1)
			$File=StringTrimLeft ($FilePath, StringInStr ($FilePath, "\" , 0, -1))

			;_ConsoleWrite("  File: "&$File)

			$Ext=StringTrimLeft($File,StringInStr($File,".",0,-1))
			If _ArraySearch($SafeExtensions,$Ext)=-1 Then continueloop ; skip this file If extention isnt in safe list

			; run file bot
			If $RunFileBot>0 then
				$ShowName=""
				If IsArray ($aMatches) Then ; if we have a list of file names to run though filebot
					for $m=1 to $aMatches[0]
						$aMatches_Line=StringSplit($aMatches[$m],",") ; interprit the list: the list is one show per line formated as [left part of file name string],[Show name on TVDB]
						$aMatches_Line[1]=StringStripWS ($aMatches_Line[1], 1+2)
						;_ConsoleWrite("  DebugA: "&$aMatches_Line[0]&" - "&$aMatches_Line[1])

						If $aMatches_Line[0]>1 Then ; optionaly a line can contain 1 value, If it does use have 2 values use the second one
							$aMatches_Line[2]=StringStripWS ($aMatches_Line[2], 1+2)
						Else ; didn't have a second value, using the first one
							ReDim $aMatches_Line[3]
							$aMatches_Line[2]=$aMatches_Line[1]
						endif
						;_ConsoleWrite("  DebugB: "&$aMatches_Line[0]&" - "&$aMatches_Line[1]&" - "&$aMatches_Line[2])

						If StringLeft($File, StringLen($aMatches_Line[1])) = $aMatches_Line[1] Or _ ;test to see If the first value in the line matches the left part of the filename
							StringLeft(StringReplace($File, "_", "."), StringLen($aMatches_Line[1])) = $aMatches_Line[1] Then
							$ShowName=$aMatches_Line[2] ; set showname so that filebot runs
							ExitLoop
						endif
					Next
				endif

				If $ShowName<>"" OR $RunFileBot=2 then
					If NOT _FileBot($FilePath, $ShowName, "TheTVDB", $FileBotEpisodeFormat) Then ; run file bot
						_ConsoleWrite("  FileBot failed, skipping to next file")
						ContinueLoop
					endif
				endif

				If NOT FileExists($FilePath) Then ; If filebot renamed a file we just stop everything and start the script over again in order to correct the entry in the file list array(s), surprisingly elegant except that filebot might run an extra time
					_ConsoleWrite("Renamed a file, starting over")
					ContinueLoop 2
				EndIf
			EndIf

			; now we try to get the episode, season and show name, we go from best formated to worst formated
			Dim $EpisodeStrings[2]
			$EpisodeStrings=StringRegExp($File,'(?P<show>.*?)[sS](?P<season>[0-9]+)[\._ ]*[eE](?P<ep>[0-9]+)([- ]?[Ee+](?P<secondEp>[0-9]+))?',1) ; S01E02 or S01E02-E03
			If @error Then
				$EpisodeStrings=StringRegExp($File,'(?P<show>.*?)(?P<season>[0-9]{1,2})[Xx](?P<ep>[0-9]+)(-[0-9]+[Xx](?P<secondEp>[0-9]+))?',1) ; 1x02
				If @error then
					$EpisodeStrings=StringRegExp($File,'(.*?)[^0-9a-z](?P<season>[0-9]{1,2})(?P<ep>[0-9]{2})([\.\-][0-9]+(?P<secondEp>[0-9]{2})([ \-_\.]|$)[\.\-]?)?([^0-9a-z%]|$)',1) ; .602.
					If @error=0 AND ($EpisodeStrings[1]="19" OR $EpisodeStrings[1]="20") then
						Dim $EpisodeStrings[2]
					endif
				endif
			endif

			_ConsoleWrite("  Episode strings: ("&_ArrayToString ($EpisodeStrings)&")")

			If StringInStr($File,".YIFY",1) Then ; must be YIFY movie... only uploader with movie naming convention i'm willing to rely on 100% ATM
				_ConsoleWrite("  Found YIFY movie")
				$aNewFileName=_MovieName($File)
				$DestinationFilePath=$MoviesPath&"\"&$aNewFileName[3]

			ElseIf IsArray($EpisodeStrings) and $EpisodeStrings[0]<>"" and $EpisodeStrings[1]<>"" Then ; must be episode
				_ConsoleWrite("  Found episode ["&$EpisodeStrings[0]&"] ["&$EpisodeStrings[1]&"]")
				$Folder=$EpisodeStrings[0]

				; instead of doing a string replace we will loop the string manualy so we can do some conditional formating (at some point)
				$aFolder=StringSplit($folder,"")
				for $z=1 to $aFolder[0]-1
					If $aFolder[$z]="." Then $aFolder[$z]=" "
					If $aFolder[$z]="_" Then $aFolder[$z]=" "
				next
				$Folder=_ArrayToString($aFolder,"",1)

 				for $x=@YEAR to @YEAR-80 Step -1
 					If StringInStr($Folder,String($x)) AND NOT StringInStr($Folder,"("&String($x)&")") then
 						_ConsoleWrite("  Added parenthsis to year in folder name ("&$x&")")
 						$Folder=StringReplace($Folder,String($x),"("&String($x)&")")
 						ExitLoop
 					endif
 				next

				If StringRight($Folder,1)="." Then $Folder=StringTrimRight($folder,1)
				$Folder=StringStripWS ($Folder, 1+2)
				$Folder=__StringProper($Folder)

				If $Folder = "Tosh 0" Then $Folder = "Tosh.0" ; havn't thought of a way to handle show names with a period in them

				_ConsoleWrite("  Destination folder: "&$Folder)

				If $EpisodeStrings[1]<>"" Then ; why did i care about this, could we of gotten this far without a
					If StringInStr(FileGetAttrib ($SeriesPath&"\"&$Folder&"\Season "&$EpisodeStrings[1]),"D") then
						$DestinationPath=$SeriesPath&"\"&$Folder&"\Season "&$EpisodeStrings[1]
					elseIf StringInStr(FileGetAttrib ($SeriesPath&"\"&$Folder&"\Season "&Abs($EpisodeStrings[1])),"D") then
						$DestinationPath=$SeriesPath&"\"&$Folder&"\Season "&Abs($EpisodeStrings[1])
					else
						If FileExists($SeriesPath&"\"&$Folder&"\Season 1") Then $EpisodeStrings[1]=Abs($EpisodeStrings[1])
						$DestinationPath=$SeriesPath&"\"&$Folder&"\Season "&$EpisodeStrings[1]
						_ConsoleWrite("  Creating directory: "&$DestinationPath)
						If $NoChanges then
							_ConsoleWrite("  ===!!!RUNNING AS SCRIPT WON'T MAKE THAT CHANGE!!!===")
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

			_ConsoleWrite("  Copying file to: "&$DestinationFilePath)
			If $NoChanges then
				_ConsoleWrite("  ===!!!RUNNING AS SCRIPT WON'T MAKE THAT CHANGE!!!===")

			ElseIf FileCopy($FilePath,$DestinationFilePath,1)=1 Then
				_ConsoleWrite("  Copy success, removing original...")
				FileSetAttrib ($DestinationFilePath, "-RASH")
				sleep(3000)

				If _FileInUseWait($FilePath, 10) then
					If $RemoveSubDirectory AND $Path<>$ScanPath AND DirGetSize($Path) - FileGetSize($FilePath) < $FileSizeThreshold*1024*1024 Then ; remove the subfolder the media file resides in
						If $FileRemove=2 and DirRemove($Path,1)=1 Then
							_ConsoleWrite("  Deleted folder")
						elseIf $FileRemove=1 and FileRecycle($Path)=1 Then
							_ConsoleWrite("  Recycled folder")
						Else
							_ConsoleWrite("  Couldn't remove folder")
						endif
					else ; remove the individual original media file
						If $FileRemove=2 and FileDelete($FilePath)=1 Then
							_ConsoleWrite("  Deleted file")
						elseIf $FileRemove=1 and FileRecycle($FilePath)=1 Then
							_ConsoleWrite("  Recycled file")
						Else
							_ConsoleWrite("  Couldn't remove file")
						endif
					endif
				else
					_ConsoleWrite("  File locked, can't remove file")
				endif

			Else
				_ConsoleWrite("  Copy Failed")
			endif

		endif
	next

	;If another proccess wasnt created during run Then exit, otherwise lets go again
	If IniRead ($ScriptFullPathNoExt&"_Settings.ini", "temp", "runagain", "0") = 1 Then
		_ConsoleWrite("Starting again (another instance tried to start during this run)")
		If IniWrite ($ScriptFullPathNoExt&"_Settings.ini", "temp", "runagain", "0") Then ContinueLoop
	endif

	exit
wend
;===============================================================================
; Function Name:    _MovieName
; Description:		Attempts to get a proper file name for a movie file
; Call With:		_MovieName($sString)
; Parameter(s):		$sFileName = Filename
; Return Value(s):  On Success - Array
;						[0] = Original name without extention
;						[1] = New name without extention
;						[2] = Extention with "."
;						[3] = New name with extention
; 					On Failure -
; Author(s):        JohnMC - www.TeamMC.cc
; Date/Version:		10/17/2014  --  v1.1
;===============================================================================
Func _MovieName($sFileName)
	Local $aSmart[4]
	Local $bFoundDate=False

	$aSmart[2] = StringLower(StringTrimLeft($sFileName,StringInStr($sFileName,".",0,-1)-1))
	$aSmart[0] = Stringleft($sFileName,StringInStr($sFileName,".",0,-1)-1)
	$aSmart[1] = $aSmart[0]

	For $iYear=@YEAR To @YEAR-80 Step - 1
		If StringInStr($aSmart[1],$iYear) then
			$aSmart[1]=StringLeft($aSmart[1],StringInStr($aSmart[1],$iYear)-1)
			$bFoundDate = True
			ExitLoop
		EndIf
	Next

	If StringInStr($aSmart[1],"DVDRip") Then $aSmart[1] = StringLeft( $aSmart[1],StringInStr($aSmart[1],".DVDRip")-1)
	If StringInStr($aSmart[1],"1080") Then $aSmart[1] = StringLeft( $aSmart[1],StringInStr($aSmart[1],"1080")-1)
	If StringInStr($aSmart[1],"720") Then $aSmart[1] = StringLeft( $aSmart[1],StringInStr($aSmart[1],"720")-1)
	If StringInStr($aSmart[1],"BluRay") Then $aSmart[1] = StringLeft( $aSmart[1],StringInStr($aSmart[1],"BluRay")-1)

	If StringInStr($aSmart[1],"[") Then $aSmart[1] = StringLeft( $aSmart[1],StringInStr($aSmart[1],"[")-1)
	If StringInStr($aSmart[1],"(") Then $aSmart[1] = StringLeft( $aSmart[1],StringInStr($aSmart[1],"(")-1)

	$aSmart[1]=StringReplace ($aSmart[1],"_"," ")
	$aSmart[1]=StringReplace ($aSmart[1],"."," ")
	$aSmart[1]=StringStripWS ($aSmart[1], 1+2+4)
	$aSmart[1]=__StringProper($aSmart[1])

	If $bFoundDate Then $aSmart[1] &= " (" & $iYear & ")"

	$aSmart[3] = $aSmart[1] & $aSmart[2]

	Return $aSmart
endfunc
;===============================================================================
; Function Name:    _FileBot
; Description:		Runs FileBot in order to ID and rename a file
; Call With:		_FileBot($sFilePath, $Search)
; Parameter(s):
; Return Value(s):  On Success - 1
; 					On Failure - 0
; Author(s):        JohnMC - www.TeamMC.cc
; Date/Version:		10/15/2014  --  v1.0
;===============================================================================
Func _FileBot($FilePath, $Search="", $DB="TheTVDB", $FileBotFormat="")
	Local $FileBotParameters = "-r -non-strict --db "&$DB&" --format """&$FileBotFormat&""""

	_ConsoleWrite("_FileBot ["&$FilePath&"] ["&$Search&"]")

	If _FileInUseWait($FilePath, 10) then
		If $NoChanges then
			_ConsoleWrite("  ===!!!RUNNING AS SCRIPT WON'T MAKE THAT CHANGE!!!===")
		else
			Local $Run = "filebot -rename """&$FilePath&""" --q """&$Search&""" "&$FileBotParameters
			_ConsoleWrite("  "&$Run)
			If NOT _RunWait($Run) Then
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
func _Exit()
	_ConsoleWrite("Finished")
	;sleep(20000)
endfunc