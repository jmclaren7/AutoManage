# AutoManage
Automatically manage video files that have standard naming conventions.

## Downloads
Latest Beta Release: 
Latest Stable Release: 

## About
This project is an AutoIT script that scans a specified folder for media files. The media files names are read and used to determine the files destination.
The project is in early development (and might stay that way) and is sure to have many issues aside from the obvious filename match issues, i have tried to add as much logging as possible and will continue to do so. I will also be adding more and more code notes as the code gets cleaner.


Some highlights:

* Multiple regex methods to breakdown series episode and season numbers.
* Optionaly uses FileBot to rename predetermined files.
* Episodes and movies in subfolders will have their folder deleted if no file over a specified size exists.
* Other stuff?

## Instructions
* The matches list file is formated with one "match" per line formated as: [left part of file name string],[Show name on TVDB]

## Notes
* This script performs FileRecycle operations instead of delete, the FileRecycle operations target subfolders that media came in, these folders may contain srt or other files that arn't factored into this script, 
the only two safeties are the use of FileRecycle and a folder size check, if the folder is still larger then "FileSizeThreshold" (settings.ini) it wont be deleted, this could be an issue with samples.


## Source Files & Compiling
* Getting AutoIt & Scite:
   Visit http://autoitscript.com and navigate to the AutoIt3 download section. Scroll down to the first download items "AutoIt Full Installation" and "AutoIt Script Editor." download and install these, follow any directions provided by the installation packages.
   Note: The script editor is needed to utilize all the compile directives.


* Getting the source:
   Visit https://github.com/jmclaren7/AutoManage

* Viewing Source/Making Adjustments:
To view the source, install AutoIT and navigate to the new folder you unziped the source to, you should be able to right click on the ".au3" file and then "edit script". 

* A Note About AutoIt, Compressed Builds and Antivirus:
*Compressing an executable AutoIT file with UPX is never recomended, this will result in increased false positives with some antivirus software.
*Somtimes Antivirus software has a hard time determining if an AutoIT script is safe or malicious, if you are in a production eviroment and want to avoid false positives, consider code signing or running AutoIT scripts without compiling.
*It can take a long time for Antivirus software to catch up with the newest AutoIT versions so I recomend experimenting with older versions of AutoIT if you have any issues.

## Changes


	*10-12-14 - 1.0.0.114
		* First release/upload, many things to do...