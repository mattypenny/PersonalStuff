function promptx {
    <#
    .SYNOPSIS
    Sets the prompt

    .DESCRIPTION
    Sets the prompt either:
    - the GitShell prompt, but with only the last element of the folder name or
    - the get-date
    ...depending on whether I'm in the Git Shell or not

    Todo: show the time
    Todo: show the time of the last command

    This function is autoloaded by .matt.ps1

    .PARAMETER Folder
    Not yet implemented. Show the folder name in the prompt

    .INPUTS
    None. You cannot pipe objects to this function



    #>
    [CmdletBinding()]
    Param( [String] $Folder)

    $realLASTEXITCODE = $LASTEXITCODE

    # Reset color, which can be messed up by Enable-GitColors
    $Host.UI.RawUI.ForegroundColor = $GitPromptSettings.DefaultForegroundColor

    $FolderName = [System.IO.Path]::GetFileName($pwd.ProviderPath)

    Write-Host($FolderName) -nonewline

    try {
        Write-VcsStatus
    }
    catch {
        $PromptDate = get-date
        write-host " $PromptDate" -nonewline
    }
    $global:LASTEXITCODE = $realLASTEXITCODE
    return " $ "

}
#>

<#
.Synopsis
Move files to another folder with date on the front
.DESCRIPTION
Long description
.EXAMPLE
Move-ChildItemsAndDatePrefix -SourceFolder C:\Users\matty\OneDrive\music\tosort\GroverPro -TargetFolder C:\Users\matty\OneDrive\music\aardvark_old_podcasts 
#>
function Move-ChildItemsAndDatePrefix {

    [CmdletBinding()]
    param (
        [ValidateScript({
            if( -Not ($_ | Test-Path) ){
                throw "Source folder does not exist"
            }
            return $true
        })]
        [System.IO.FileInfo]$SourceFolder,
        
        [ValidateScript({
            if( -Not ($_ | Test-Path) ){
                throw "Target folder does not exist"
            }
            return $true
        })]
        [String]$TargetFolder,

        [switch]$Recurse = $true
    )
    
    $ChildItems = Get-ChildItem -Path $SourceFolder -Recurse:$Recurse -File | sort-object -Property Name

    foreach ($C in $ChildItems) {

        [string]$Fullname = $C.Fullname
        [string]$DirectoryNAme = $C.DirectoryName
        [string]$Name = $C.Name
        [datetime]$CreationTime = $C.CreationTime

        [string]$Prefix = $CreationTime.ToString('yyyyMMdd')

        [string]$TargetFileName = $TargetFolder + '\' +
                            $Prefix + '_' +
                            $Name

        $MoveCommand = @"
move-item -path '$Fullname' -Destination '$TargetFileName'
"@
        Write-Debug $MoveCommand

        move-item -path $Fullname -Destination $TargetFileName 
    }

}



function Get-CommandDefinition {
    [CmdletBinding()]
    param (
        $Command   
    )
    
    foreach ($C in $(get-command "$Command")) {

        $RetrievedCommand = get-command $C

        [string]$Name = $RetrievedCommand.Name

        [string]$Definition = $RetrievedCommand.Definition

        [string]$Result =  @"
$Result
$Name`:

$Definition

"@

    }
    return $Result

}
set-alias gcmdef Get-CommandDefinition
set-alias showme Get-CommandDefinition


function Write-CommentBasedHelpToMarkdownFile {
    <#
    .Synopsis
    Get name and synopsis from get-help for a module, or modules, and write to specified markdown file
    .DESCRIPTION
    This was either an example from some learning exercise or it was for some very specific purpose that I've forgotten.
    
    .EXAMPLE
    ipmo -force PersonalStuff ; Write-CommentBasedHelpToMarkdownFile -module SqlStuff,WindowsStuff,PersonalStuff,ShCommonFunctions -MarkDownFile C:\matt\temp\documentation\README.md

    .EXAMPLE
    ipmo -force PersonalStuff ; Write-CommentBasedHelpToMarkdownFile -module FromTheInternet,SqlStuff,PersonalStuff -MarkDownFile C:\matt\temp\documentation\README.md
    #>
    [CmdletBinding()]
    param (
        $Module,
        [string]$MarkDownFile       
    )
    
    $CommentBasedHelpFromModule = get-CommentBasedHelpFromModule -Module $Module

    $CommentsConvertedToMArkdown = $CommentBasedHelpFromModule | 
                                    Select-Object ModuleName, Name, 
                                        @{E={$_.synopsis -replace "`r`n",""};L='Synopsisx'} |
                                    Sort-Object -Property ModuleName, Name |                                    
                                    # select -first 5 |
                                    ConvertTo-Markdown 

    $SynopsisString = $CommentsConvertedToMArkdown


    <# [string]$FullHelpText   = $CommentBasedHelpFromModule | 
                                    Sort-Object -Property ModuleName, Name |
                                    Out-String
     #>
    [string]$MarkdownContent = @"
This page describes all the functions in Powershell modules what I have wrote. The first bit lists the functions, with a short description. The second bit is full help text. It's all derived from the Comment-Based Help, using Write-CommentBasedHelpToMarkdownFile (so don't edit it here) 

## Short description

$SynopsisString

## Full help text
....such as it is

"@
    
    $SynopsisString | out-file  -Encoding ascii  $MarkDownFile


}    


function get-CommentBasedHelpFromModule {
    <#
    .Synopsis
    Get all the help for all the functions in specified modules
    #>
    [CmdletBinding()]
    param (
        $Module
    )
    
    $Help = @()

    $ListOfModules = $Module
    foreach ($M in $ListOfModules) {

        [string]$Module = $M 

        $CommandsInModule= get-command -module $Module
        
        foreach ($C in $CommandsInModule) {

            [string]$Command = $C.Name

            $Help += get-help -full $Command

        }

    }

    $Help
}
    
    
    
<#
    .Synopsis
    Get files modified between specified dates [sh]
    .DESCRIPTION
    This was either an example from some learning exercise or it was for some very specific purpose that I've forgotten.

    .EXAMPLE
    get-childitembydate "*txt" 20 0
    #>
function get-childitembydate {
    [CmdletBinding()]

    Param
    (
        # Param1 help description
        $Filespec,

        # Param2 help description
        [int]
        $newer = 1000000,


        # Param2 help description
        [int]
        $older = 0
    )


    gci -recurse $Filespec | select lastwritetime, length, fullname |
        where-object {
        $_.Lastwritetime -ge (Get-Date).AddDays($newer * -1) -and
        $_.Lastwritetime -le (Get-Date).AddDays($older * -1)
    }

}




<#
    vim: tabstop=4 softtabstop=4 shiftwidth=4 expandtab
    #>

function Get-MTPGitAddAndRemoveCommands {
<#
.Synopsis
Generates a 'git add' or 'git rm' command for everything that has been changed but not added or removed and not rm-ed
.DESCRIPTION
.EXAMPLE
ggac

git add .gitignore function-convertto-twiki.ps1 function-edit-powershellref.ps1 function-get-gitaddcommand.ps1

#>
    [CmdletBinding()]
    [Alias()]
    [OutputType([int])]
    Param
    (
        [Parameter(Position = 0)]
        $FolderName = "."
    )

    cd $FolderName

    $GitStatusAsObjects = get-MTPGitStatusAsObjects

    foreach ($G in $($GitStatusAsObjects | Where-Object Status -ne 'D')) {

        [string]$Filename = $G.Filename

        Write-Output "git add $Filename"

    }

    foreach ($G in $($GitStatusAsObjects | Where-Object Status -eq 'D')) {

        [string]$Filename = $G.Filename

        Write-Output "git rm $Filename"

    }
}


function Invoke-MTPGitAddCommitPush {
    
        [CmdletBinding()]
        
        Param
        (
            [Parameter(Position = 0)]
            $FolderName = "."
        )
        
        cd $FolderName
    
        $GitStatusAsObjects = get-MTPGitStatusAsObjects
        
        foreach ($G in $($GitStatusAsObjects | Where-Object Status -ne 'D')) {
    
            [string]$Filename = $G.Filename
    
            git diff $Filename

            $Continue = Read-Host -Prompt "git add?" 

            if ($Continue -eq 'y') {
                
                git add $Filename
                
                $CommitMessage = Read-Host -Prompt "git message?" 

                $Continue = Read-Host -Prompt "git commit and push?" 

                if ($Continue -eq 'y') {

                    
                    git commit -m $CommitMessage
                    git push origin master

                }


            }
    
        }
        
        
}
set-alias ggacx Invoke-MTPGitAddCommitPush

function get-MTPGitStatusAsObjects
{
    [CmdletBinding()]
     Param
    (

    )

    $GitStatusAsString = git status -s

    $GitStatusAsSeperateLines = $GitStatusAsString | Select-String '^'


    $GitStatusAsObjects = @()
    foreach ($G in $GitStatusAsSeperateLines) {

        [string]$Line = $G.Line

        [string]$Status = $Line.Substring(0,2)

        $Status = $Status.Trim()

        $Filename = $Line.Substring(3, ($Line.Length-3))

        $GitStatusAsObjects += [PSCustomObject]@{
            Status = $Status
            Filename = $Filename
        }

    }

    $GitStatusAsObjects

}

set-alias ggac get-MTPgitaddandRemoveCommands


function get-toplevelfolders {
    <#
    .SYNOPSIS
      Get servers top level folders

    .DESCRIPTION
      Handy for looking to see where stuff is installed.
    .PARAMETER

    .EXAMPLE
      get-toplevelfolders server1

    .EXAMPLE
      gtlf server1 | select fullname
    #>
    [CmdletBinding()]
    Param( [string][Alias ("c")]$computername = "."  )

    write-debug "$(get-date -format 'hh:mm:ss.ffff') Function beg: $([string]$MyInvocation.Line) "

    $Drives = Get-WMIObject Win32_LogicalDisk -filter "DriveType=3" -computer $ComputerName

    foreach ($D in $Drives) {
        [string]$Drive = $D.DeviceID
        $Drive = $Drive.replace(":", "$")
        dir \\$ComputerName\$Drive
    }

    write-debug "$(get-date -format 'hh:mm:ss.ffff') Function end: $([string]$MyInvocation.Line) "

}

set-alias gtlf get-toplevelfolders

<#
    vim: tabstop=2 softtabstop=2 shiftwidth=2 expandtab
    #>

function import-mtpModule {
<#
.SYNOPSIS
    Shows module last update time, removes it if its already loaded then imports it
.DESCRIPTION
    Shows module last update time, removes it if its already loaded then imports it
    
.PARAMETER ModuleName
    List of Modules to load
.EXAMPLE
    Example of how to use this cmdlet
#>
    [CmdletBinding()]
    Param( [string][Alias ("module")]$ListOfModules = "Bounce-PCs"  )

    Import-Module Logging
    Import-Module MtpLogging

    write-startfunction

    foreach ($ModuleString in $ListOfModules) {

        Write-Debug "`$moduleString: $ModuleString"

        foreach ($ModuleObject in $(get-module -ListAvailable $ModuleString)) {

            Write-Debug "`$moduleObject: $ModuleObject"

            [string]$Path = $ModuleObject.path
            $FileDetails = dir $Path | select Lastwritetime, fullName

            [string]$LastWriteTime = $FileDetails.LastWriteTime
            [string]$Fullname = $FileDetails.Fullname

            write-hostlog "Loading $ModuleObject $LastWriteTime  $Fullname"

            remove-module $ModuleObject

            import-module $ModuleObject

        }

    }

    write-endfunction

}

set-alias temp get-template

<#
    vim: tabstop=4 softtabstop=4 shiftwidth=4 expandtab
    #>

# $QuickReferenceFolder = "c:\users\$($($Env:Username).trimend('2'))\Documents\QuickReference\"
function Get-QuickReferenceFolders
{
    [CmdletBinding()]
    Param
    (
    )

    $QuickReferenceFolders = @()
    if ($IsLinux)
    {
        $Main = "~/website/content/QuickReference"
    }
    else
    {
        $Main = "c:\matt\website\QuickReference"
        if (!(test-path $Main))
        {
            $Main = "c:\matt\QuickReference"
        }

    }

    $Staging = "C:\matt\QuickReferenceStaging"
    $ContextSpecific = "C:\matt\QuickReferenceContextSpecific"

    $QuickReferenceFolders += [PSCustomObject]@{
        Folder = $Main
    }
    $QuickReferenceFolders += [PSCustomObject]@{
        Folder = $Staging
    }
    $QuickReferenceFolders += [PSCustomObject]@{
        Folder = $ContextSpecific
    }
    
    $QuickReferenceFolders
}


$DefaultQuickReferenceFolders = Get-QuickReferenceFolders
$DefaultQuickReferenceFoldersCount = $( $DefaultQuickReferenceFolders | measure-object).count
write-dbg "`$DefaultQuickReferenceFoldersCount: <$DefaultQuickReferenceFoldersCount>"
    
function get-LineFromQuickReferenceFiles {
    <#
    .SYNOPSIS
    Does a grep on quickref files
    .DESCRIPTION
    
    .PARAMETER $Pattern
    What to grep for. e.g. databases
    .INPUTS
    None. You cannot pipe objects to this function
    .EXAMPLE
    qr jobs

    Line
    ----
    $JOB = dir Sqlserver:\sql\$Computername\default\Jobserver\jobs | where-object {$_.name -like '*big-job*'}
    dir Sqlserver:\sql\$Computername\default\Jobserver\Jobs | select name, lastrundate, nextrundate, currentrunstatus, lastrunoutcome | ft
    dir Sqlserver:\sql\$Computername\default\Jobserver\Jobs | ft @{Label ="Jobbie" ; Expression={$_.name} ; Width = 42 }, @{Label="Last run" ;

    #>
    [CmdletBinding()]
    Param( $QuickReferenceFolders = $DefaultQuickReferenceFolders,
        [String] $Pattern,
        [String] $FilePattern)
    
    

    if ($Pattern -ne $null) {
        foreach ($Q in $QuickReferenceFolders) {

            $QuickReferenceFolder = $Q.Folder

            select-string -Pattern $Pattern -path $QuickReferenceFolder\*$FilePattern*.md
        
        }
        
    }
    else {

        foreach ($Q in $QuickReferenceFolders) {

            $QuickReferenceFolder = $Q.Folder
            gc $QuickReferenceFolder\*.md
        }
    }

}


function show-quickref {
    <#
    .SYNOPSIS
    Does a grep on quickref files
    .DESCRIPTION
   
    .PARAMETER $Pattern
    What to grep for. e.g. insert
    .PARAMETER $FilePattern
    File to grep in. e.g. power
    .EXAMPLE
    qr jobs

    Line
    ----
    $JOB = dir Sqlserver:\sql\$Computername\default\Jobserver\jobs | where-object {$_.name -like '*big-job*'}
    dir Sqlserver:\sql\$Computername\default\Jobserver\Jobs | select name, lastrundate, nextrundate, currentrunstatus, lastrunoutcome | ft
    dir Sqlserver:\sql\$Computername\default\Jobserver\Jobs | ft @{Label ="Jobbie" ; Expression={$_.name} ; Width = 42 }, @{Label="Last run" ;

    #>
    [CmdletBinding()]

    Param([Parameter(Mandatory = $False, Position = 1)] [String] $Pattern,
        [Parameter(Mandatory = $False, Position = 2)][Alias ("f", "file")] [String] $FilePattern)

    get-LineFromQuickReferenceFiles -pattern $Pattern -filepattern $FilePattern | select line | ft -wrap

}
set-alias qr show-quickref



function set-LocationToQuickReference {
    cd $QuickReferenceFolder
}
set-alias cdqr set-LocationToQuickReference

function edit-quickref
<#
    Edit the quick reference document
    #> {
    [CmdletBinding()]

    Param( [Parameter(Mandatory = $False, Position = 2)][Alias ("f", "file")] [String] $FilePattern)

    if ($FilePattern) {
        gvim "$QuickReferenceFolder\\*$FilePattern*.md"
    }
    else {
        gvim "$QuickReferenceFolder\\unsorted.md"
    }
}
set-alias gqr edit-quickref
set-alias eqr edit-quickref
set-alias qrg edit-quickref

<#
    vim: tabstop=2 softtabstop=2 shiftwidth=2 expandtab
    #>




# ------------------------------
# save-history
# ------------------------------
function save-history {
    <#
    .Synopsis


    #>

    $folder = "c:\powershell\history\"
    foreach ($H in $(get-history -count 10000)) {
        [datetime]$StartExecutionTime = $H.StartExecutionTime;

        $FileName = $StartExecutionTime.ToString("yyyyMMdd")

        $FileName = "$FileName.txt"

        $H | select EndExecutionTime, ExecutionStatus, CommandLine | fl  >> $folder\$Filename

    }

}
set-alias shh save-history

<#
    function get-historymatchingstringfromsavefiles
    {
        [CmdletBinding()]
        [OutputType([int])]
        Param
        (
            $Pattern = "*"
        )
        write-verbose $Pattern
        select-string $Pattern c:\powershell\history\*

    }

    set-alias hhh get-historymatchingstringfromsavefiles



    <#
    function get-historymatchingstring
    {
        [CmdletBinding()]
        [OutputType([int])]
        Param
        (
            # Param1 help description
            $Pattern = "*",
            $Tail = 5000
        )
        write-verbose $Pattern
        Get-History -count $Tail | Where-Object {$_.CommandLine -like "*$Pattern*"}

    }
    #>

function get-MTPHistory {
    <#
    .SYNOPSIS
      Search through history
    #>
    [CmdletBinding()]
    Param ($Pattern = "*",
        $Tail = 50)

    if ($Pattern -eq "*") {
        Get-History -count $Tail |  select Commandline
    }
    else {
        Get-History | Where-Object CommandLine -like "*$Pattern*" | select Commandline
    }

}
Set-Alias -Name hh -Value get-MTPHistory
    
    
    

# Not setting an alias here for 'dbg' because I'm intending to use that
# in the code

<#
    vim: tabstop=2 softtabstop=2 shiftwidth=2 expandtab
    #>


# ----------------------------------------------------------------------
# Function: vidate - edit-filewithbackup
#
#           This function copies the existing file to old\<filename>_<date>
#           This function is autoloaded
# ----------------------------------------------------------------------
function edit-filewithbackup {
    <#
    .SYNOPSIS
    Copies the target file to an 'old' directory (creates the old directory if there isn't one) and then edits it
    
    .DESCRIPTION
    The edit-filewithbackup function 'backs up' the target file to an 'old' directory. It creates the 'old' directory under the directory of the target file if it doesn't exist. The backup copy is suffixed with the date and time.

    .PARAMETER FILE_TO_EDIT
    The file you want to back up and edit, with the full filepath

    .EXAMPLE
    vidate g:\my_scripts\x.txt

    .LINK
    Online list: http://ourwiki/twiki501/bin/view/Main/DBA/PowershellFunctions

    #>
    Param( [String] $FILE_TO_EDIT)

    write-debug "vidate-ing $FILE_TO_EDIT"
    #
    # Work out what the 'old' folder would be
    $FS_FILE_TO_EDIT = "Filesystem::$FILE_TO_EDIT"
    $OLD_FOLDER = $(gci $FS_FILE_TO_EDIT).directory
    $OLD_FOLDER = "Filesystem::$OLD_FOLDER\old"
    write-debug "Old folder is $OLD_FOLDER"

    # If 'old' folder doesn't exist, create it
    $OLD_FOLDER_EXISTS = test-path $OLD_FOLDER
    if ($OLD_FOLDER_EXISTS -eq $FALSE) {
        mkdir $OLD_FOLDER
    }

    # get the date in YYYYMMDD format
   $DATE_SUFFIX = get-date -uformat "%Y%m%d"

    # get the filename without the folder
    $FILENAME = $(gci $FS_FILE_TO_EDIT).name
    write-debug "FILENAME is $FILENAME"

    # copy the existing file to the 'old' directory
    $OLD_FILE = $OLD_FOLDER + "\" + $FILENAME + "_" + $DATE_SUFFIX
    write-debug "OLD_FILE is $OLD_FILE"
    copy $FS_FILE_TO_EDIT $OLD_FILE

    # edit the file you first thought of (the out-null makes it wait)
    gvim "$FILE_TO_EDIT" | out-null

    # show the file edited, and its backup copies
    dir $FILE_TO_EDIT | select fullname, lastwritetime | ft -a
    dir $OLD_FOLDER\$FILENAME* | select fullname, lastwritetime | ft -a
}
set-alias vidate edit-filewithbackup
set-alias vd edit-filewithbackup

# vim: set softtabstop=2 shiftwidth=2 expandtab

function get-ContentFromLastFile {
    <#
    .SYNOPSIS
        Show content of last file for filespec
    .DESCRIPTION
        Longer description
        
    
    .PARAMETER
        Filespec e.g. c:\temp\*.log
    .EXAMPLE
        get-contentfromlastfile c:\temp\*.log

    #>
    [CmdletBinding()]
    Param( [string]$FileSpecification = "C:\temp\*.log" )

    write-startfunction

    $LatestFile = Get-ChildItem $FileSpecification | sort-object -property lastwritetime | select -last 1 | select fullname
    write-debug "`$LatestFile: <$LatestFile>"

    get-content $LatestFile.fullname

    write-endfunction

}

set-alias gcflf get-ContentFromLastFile

function edit-ContentFromLastFile {
    <#
    .SYNOPSIS
        Edit content of last file for filespec
    .DESCRIPTION
  
    
    .PARAMETER
        Filespec e.g. c:\temp\*.log
    .EXAMPLE
        get-contentfromlastfile c:\temp\*.log

    #>
    [CmdletBinding()]
    Param( [string]$FileSpecification = "C:\temp\*.log" )

    write-startfunction

    $LatestFile = Get-ChildItem $FileSpecification | sort-object -property lastwritetime | select -last 1 | select fullname


    gvim $LatestFile.fullname

    write-endfunction

}
set-alias ecflf edit-ContentFromLastFile
set-alias eflf edit-ContentFromLastFile

function edit-CopiedVersionOfLastFileWithPsEdit {
    <#
    .SYNOPSIS
        Edit content of last file for filespec
    .DESCRIPTION
        Find the last file for the given filespec, and open it with psedit

    .PARAMETER
        Filespec e.g. c:\temp\*.log
    .EXAMPLE
        get-contentfromlastfile c:\temp\*.log

    #>
    [CmdletBinding()]
    Param( [string]$FileSpecification = "C:\temp\*.log",
        [string][ValidateSet('Manager', 'Job', 'Department', 'All')]$Option )



    $LatestFile = Get-ChildItem $FileSpecification | sort-object -property lastwritetime | select -last 1

    [string]$Fullname = $LatestFile.FullName
    [string]$Name = $LatestFile.Name
    Write-Debug "`$Fullname: <$Fullname>"

    $NewName = $Name -replace 'txt', 'ps1'
    $NewName = "c:\temp\" + $NewName
    Write-Debug "`$NewName: <$NewName>"

    copy-item $Fullname $NewName

    psedit $NewName



}
set-alias psflf edit-CopiedVersionOfLastFileWithPsEdit
set-alias pflf edit-CopiedVersionOfLastFileWithPsEdit

function get-ContentFromLastFileTailAndWait {
    <#
    .SYNOPSIS
       Show content of last file for filespec
    .DESCRIPTION
        Longer description

    
    .PARAMETER
        Filespec e.g. c:\temp\*.log
    .EXAMPLE
        get-contentfromlastfile c:\temp\*.log

    #>
    [CmdletBinding()]
    Param( [string]$FileSpecification = "C:\temp\*.log" )

    write-startfunction

    $LatestFile = Get-ChildItem $FileSpecification | sort-object -property lastwritetime | select -last 1 | select fullname


    Get-Content  -Tail 200 -Wait  -Path $LatestFile.fullname

    write-endfunction

}

set-alias tcflf get-ContentFromLastFileTailAndWait
set-alias tflf get-ContentFromLastFileTailAndWait




function get-HelpSummary {
    <#
    .SYNOPSIS
        get synopsis and examples in a format that can be converted to Markdown
    .DESCRIPTION
        todo: needs finishing. Needs to be either a specific command OR all commands within a specific module
    .PARAMETER

    .EXAMPLE
        Example of how to use this cmdlet

    .EXAMPLE
        Another example of how to use this cmdlet
    #>
    [CmdletBinding()]
    Param( [string]$module = "*",
        [string]$name = "*"  )

    write-startfunction

    $CmdletDetails = foreach ($C in $(get-command -module $Module -name $name )) {

        # $C = "get-topprocesses"

        $Help = get-help $C

        [string]$FunctionName = $C.Name

        [string]$Synopsis = $Help.Synopsis

        $Examples = get-help -examples $C | select -expandproperty Examples | select -ExpandProperty example | select code, title

        [string]$ExampleString = ""
        Foreach ($E in $(get-help -examples $C | select -expandproperty Examples | select -ExpandProperty example | select code, title)) {

            [string]$Title = $E.title
            [string]$Code = $E.code

            write-debug "`$Title: <$Title>"
            write-debug "`$Code: <$code>"

            $ExampleString = @"
    $ExampleString
    $Title
    $Code
"@
        }

        write-debug "`$FunctionName : <$FunctionName>"
        write-debug "`$Synopsis: <$Synopsis>"
        write-debug "`$ExampleString : <$ExampleString>"

        [PSCustomObject]@{  Name = $FunctionName
            Synopsis = $Synopsis
            Examples = $ExampleString
        }

    }

    return $CmdLetDetails

    write-endfunction

}

<#
    vim: tabstop=4 softtabstop=4 shiftwidth=4 expandtab
    #>

function select-StringsFromCode {
    <#
    .SYNOPSIS
    Searches for specified text in functions folder
    #>
    param ($SearchString)
    $DownloadedModules = @("EnhancedHTML2", "Pester", "OperationValidation", "PSRemoteRegistry", "PSScriptAnalyzer", "xNetworking")
    
    $Result = @()
    
    $Result += select-string $SearchString $FunctionsFolder\*.ps1 | select path, line
    
    foreach ($M in $(dir -recurse $Modules *.p*1 -exclude $DownloadedModules)) {
        [string]$fullname = $M.fullname
        $Result += select-string $SearchString $fullname | select path, line
    }
    
    foreach ($M in $(dir -recurse C:\powershell\scripts *.p*1 )) {
        [string]$fullname = $M.fullname
        $Result += select-string $SearchString $fullname | select path, line
    }
    
    $Result += select-string $SearchString $UnGithubbedFunctionsFolder\*.ps1 | select path, line
    
    $Result += select-string $SearchString c:\powershell\boneyard\*.ps1 | select path, line

    $Result
}

set-alias sfs select-StringsFromCode
set-alias gfs sfs

function New-PSCustomObjectStatementFromObject {
    <#
    .SYNOPSIS
        Saves some typing if you want to reverse engineer object-creation. Or something like that.
    .DESCRIPTION
        Longer description
    .PARAMETER ObjectArray
    Object that you want the statememt for
    
    .EXAMPLE
        Example of how to use this cmdlet
    #>
    [CmdletBinding()]
    Param
    (
        $ObjectArray,
        [ValidateSet('FromObject', 'ReplaceString', 'Variable')]$EqualsWhat = 'ReplaceString'
    )
    write-startfunction

    $Members = $ObjectArray[0] | get-member

    write-output "`$ReplaceThis = [PSCustomObject]@{``"
    foreach ($M in $($Members | where memberType -in ("NoteProperty", "Property", "ScriptProperty"))) {
        [string]$Name = $M.name

        switch ($EqualsWhat) {
            'FromObject' {
                $EqualsString = "`$ReplaceThis.$Name"
            }
            'ReplaceString' {
                $EqualsString = "`"ReplaceThis`""
            }
            'Variable' {
                $EqualsString = "`$$Name"
            }
        }

        write-output "    $Name = $EqualsString"

    }

    Write-Output "}"

    write-endfunction

}




function cdd {
    <#
    .SYNOPSIS
        Implements $CDPATH-like functionality
    .DESCRIPTION
        Downloaded from https://stackoverflow.com/questions/7236594/cdpath-functionality-in-powershell
        Written by https://stackoverflow.com/users/526535/manojlds
    .PARAMETER Path
        Folder to search and cd to
    .EXAMPLE
        cd CheckSystems
    #>
    [CmdletBinding()]

    param($path,
        $CdPath = "c:\powershell;c:\powershell\modules;c:\powershell\scripts;c:\")
    if (-not $path) {return; }

    if ((test-path $path) -or (-not $CDPATH)) {
        Set-Location $path
        return
    }
    $cdpath = $CDPATH.split(";") | % { $ExecutionContext.InvokeCommand.ExpandString($_) }
    $npath = ""
    foreach ($p in $cdpath) {
        $tpath = join-path $p $path
        if (test-path $tpath) {$npath = $tpath; break; }
    }
    if ($npath) {
        write-host -fore yellow "Using CDPATH. Going to $npath"
        Set-Location $npath
        return
    }

    set-location $path

}

function move-MtpCrudFilesToCrudFolder {
    <#
    .SYNOPSIS
        Moves files ending in ~ or .swp to a crud folder. These files are created by vim
    .DESCRIPTION
        Moves files ending in ~ or .swp to a crud folder. These files are created by vim
    .PARAMETER FolderName
        Defaults to current folder
    .EXAMPLE
        Example of how to use this cmdlet
    #>
    [CmdletBinding()]
    Param
    (
        [string]$Folder = "."

    )
    write-startfunction

    if (! (test-path -PathType Container -Path $Folder)) {
        throw "$folder doesnt exist. Or it isn't a folder"
    }

    $DateNow = Get-Date -format "yyyyMMddHHmm"

    $CrudFolder = "$Folder\crud\$DateNow"
    mkdir -force $CrudFolder | out-null

    write-debug "move-item $folder/*.swp $CrudFolder -Verbose"
    move-item $folder/*.swp $CrudFolder -Verbose
    move-item $folder/*~  $CrudFolder  -verbose

    write-endfunction

}

function blank-template {
    <#
    .SYNOPSIS
      One-line description

    .DESCRIPTION
      Longer description

    .PARAMETER

    .EXAMPLE
      Example of how to use this cmdlet

    .EXAMPLE
      Another example of how to use this cmdlet
    #>
    write-output "This is an intentionally useless function, that just serves to serve the about help topic"
}

function about_Markdown {
    <#
    .SYNOPSIS
      Syntax for .md files

    .DESCRIPTION

      # The largest heading (an <h1> tag)
      ## The second largest heading (an <h2> tag)
      > Blockquotes
      *italic* or _italic_
      **bold** or __bold__
      * Item (no spaces before the *) or
      - Item (no spaces before the -)
     1. Item 1
        1. A corollary to the above item.
        2. Yet another point to consider.
      2. Item 2
      3. Item 3
      `monospace` (backticks)
      ```` begin/end code block
      [Visit GitHub!](https://www.github.com).

    #>
    write-output "This is an intentionally useless function, that just serves to serve the about help topic"
}

export-modulemember -alias * -function *

function Get-ExtendedFileProperties {
<#
    .Synopsis
       Short description
    .DESCRIPTION
       This code is based on Shaun Cassells Get-Mp3FilesLessThan which I found at:
       http://myitforum.com/myitforumwp/2012/07/24/music-library-cleaning-with-powershell-identifying-old-mp3-files-with-low-bitrates/
    .EXAMPLE
       Example of how to use this cmdlet
   .EXAMPLE
       Another example of how to use this cmdlet
    #>

    [CmdletBinding()]
    [Alias()]
    Param( [string]$folder = "$pwd" )

    Begin {
        $CurrentlyKnownTags =
        "Name",
        "Size",
        "Item type",
        "Date modified",
        "Date created",
        "Date accessed",
        "Attributes",
        "Availability",
        "Perceived type",
        "Owner",
        "Kind",
        "Contributing artists",
        "Album",
        "Year",
        "Genre",
        "Rating",
        "Authors",
        "Title",
        "Comments",
        "#",
        "Length",
        "Bit rate",
        "Protected",
        "Total size",
        "Computer",
        "File extension",
        "Filename",
        "Space free",
        "Shared",
        "Folder name",
        "Folder path",
        "Folder",
        "Path",
        "Type",
        "Link status",
        "Space used",
        "Sharing status"

        write-verbose "$CurrentlyKnownTags $CurrentlyKnownTags"
    }


    Process {

        $shellObject = New-Object -ComObject Shell.Application


        $Files = Get-ChildItem $folder -recurse

        foreach ( $file in $Files ) {

            write-verbose "Processing file $file"

            $directoryObject = $shellObject.NameSpace( $file.Directory.FullName )

            $fileObject = $directoryObject.ParseName( $file.Name )
            $RawFileProperties = New-Object PSObject

            for ( $index = 0 ; $index -lt 1000; ++$index ) {

                $name = $directoryObject.GetDetailsOf( $directoryObject.Items, $index )

                $value = $directoryObject.GetDetailsOf( $fileObject, $index )

                if ($name -ne "") {
                    Add-Member -InputObject $RawFileProperties -MemberType NoteProperty -Name $name.replace(" ", "") -value "$value"
                    write-debug "Adding Member -Name $name -value $value"

                    # todo: Check for unknown attributes (will also check for a typical mp3 attributes). Logging both to some sort of error log
                    #
                    # if not in array
                    # then
                    #   write to errorlog file
                    #
                }
            }

            return $RawFileProperties

        }

    }
    End {
    }
}

<#
    .SYNOPSIS
       Short description

    .DESCRIPTION
       This code is based on Shaun Cassells Get-Mp3FilesLessThan which I found at:
       http://myitforum.com/myitforumwp/2012/07/24/music-library-cleaning-with-powershell-identifying-old-mp3-files-with-low-bitrates/

    .EXAMPLE
       Example of how to use this cmdlet

    .EXAMPLE
       Another example of how to use this cmdlet
    #>
function Get-Mp3Poperties
{
    [CmdletBinding()]
    [Alias()]
    Param( [string]$folder = "$pwd" )

    Begin {
    }


    Process {

        # Todo: Need to remember/work out how to pass switches betwwen functions i.e. -verbose and -recurse
        Get-ExtendedFileProperties -folder $folder


        $Files = Get-ChildItem $folder -recurse

        foreach ( $file in $Files ) {

            write-verbose "Processing file $file"

            $Mp3Object = New-Object -PSObject -Property @{}

            return $Mp3Object

        }

    }
    End {
    }
}

# todo: function to just extract the mp3 stuff
#


# $X = Get-ExtendedFileProperties -folder "D:\music\Desm*" -verbose
# $X | select Size, Album
# vim: set softtabstop=2 shiftwidth=2 expandtab

function get-duplicates {

    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $True,
            ValueFromPipeline = $True,
            ValueFromPipelineByPropertyName = $True,
            HelpMessage = 'What folder(s) would you like to target?')]
        [string[]]$folders,

        [string]$check_method = 'S'
    )


    function validate-folder {
        param ($p_folder)

        write-verbose "Validating folder $p_folder"

        # if not valid folder...
        if ($(test-path $p_folder) -eq $TRUE) {
            write-verbose "Folder $p_folder is hunky-dory"
        }
        else {
            write-host "$p_folder isn't valid"
        }

    }

    function get-filelist {
        parameter ($p_folders)

        write-verbose "Validating folder $p_folders"

    }

    # Validate each folder
    foreach ($folder in $folders) {
        validate-folder $folder
        $FILE_LIST += gci -recurse $folder
    }

    foreach ($FILE in $FILE_LIST) {
        $SORT_KEY = $FILE.fullname
        $SORT_KEY.toupper()

    }
    # sort the list as specified by the parameter
    $SORTED_FILE_LIST = $FILE_LIST | sort-object -property length

    foreach ($FILE in $SORTED_FILE_LIST) {
        # For each file, check whether it's key is the same as the previous key

        if ($LAST.length -eq $FILE.length ) {
            $LAST
        }
        $LAST = $FILE
    }

}

function dirod {
    <#
    .SYNOPSIS
    Does an equivalent of ls -ltr or dir /od
    .DESCRIPTION
    See synopsis
    #>
    Param ($DirName = "." );

    get-childitem $DirName | sort-object -property lastwritetime |  select lastwritetime, length, mode, fullname
}
  
function get-MtpChildItemInGb {
    <#
    .SYNOPSIS
    Does an equivalent of ls -ltr or dir /od
    .DESCRIPTION
    See synopsis
    #>
    Param ( [string]$Path = ".",
            [switch]$Recurse = $False,
            [switch]$Force = $False )
    
    get-childitem $Path -Recurse:$Recurse -force:$Force |  
        select lastwritetime, 
            @{Label = "T"; Expression = {$_.mode.Substring(0,1).replace('-','f')  }   },        
            @{Label = "SzGb"; Expression = {[math]::Round($_.length / 1Gb,1 ) }},    
            fullname
}
Set-Alias dirx get-MtpChildItemInGb
Set-Alias lsx  get-MtpChildItemInGb
Set-Alias DirGb get-MtpChildItemInGb
Set-Alias LsGb get-MtpChildItemInGb

function get-MtpChildItemInMb {
    <#
    .SYNOPSIS
    Does an equivalent of ls -ltr or dir /od
    .DESCRIPTION
    See synopsis
    #>
    Param ( [string]$Path = ".",
            [switch]$Recurse = $False,
            [switch]$Force = $False )
    
    get-childitem $Path -Recurse:$Recurse -force:$Force |  
        select lastwritetime, 
            @{Label = "T"; Expression = {$_.mode.Substring(0,1).replace('-','f')  }   }, 
            @{Label = "SzMb"; Expression = {[math]::Round($_.length / 1Mb,1 ) }},                           
            fullname
}

Set-Alias DirMb get-MtpChildItemInMb
Set-Alias LsMb get-MtpChildItemInMb

function lsltr {
    <#
    .SYNOPSIS
    Does an equivalent of ls -ltr or dir /od
    #>
    Param ($DirName = "." ); dir $DirName | sort-object -property lastwritetime
}

function wcl {
    <#
    .SYNOPSIS
    Does an equivalent of wc 0k
    #>
    Param ($FileName = "$PROFILE" ); gc $Filename | measure-object -line
}
    
function gvimx {
<#
.SYNOPSIS
Edits file and returns control to Powershell command line
.EXAMPLE
gvim x
#> 
    [CmdletBinding()]
    param ($FileNames)


    foreach ($F in $FileNames) {
        & "C:\Program Files (x86)\vim\vim74\gvim.exe" $F
        write-verbose "Edited $(dir $F | select fullname, lastwritetime, length | ft -a)"
    }

}

function convert-MtpObjectToHashTables {
    <#
    .SYNOPSIS
    Convert object to hash table. Particularly useful for Pester-izing
    #> 
    [CmdletBinding()]
    param (
        $InputObject
    )


    $HashTableCollection = @()

    foreach ($D in $InputObject) {

        $HashTable = @{}

        $NamesAndValues = $($D).psobject | select -expand properties | select name, value

        foreach ($N in $NamesAndValues) {

            $HashTable."$($N.Name)" = $N.Value

        }

        $HashTableCollection += $HashTable
    }

    $HashTableCollection

}

function get-GeneratedSplatLines {
    [CmdletBinding()]
    param (
        [string]$Function = "get-service"
    )

    [string]$SplatString = @"
`$SplatParams = @{
"@

    $Parameters = get-command $Function | Select-Object -ExpandProperty Parameters

    $CommonParameters = 'Verbose',
    'Debug',
    'ErrorAction',
    'WarningAction',
    'InformationAction',
    'ErrorVariable',
    'WarningVariable',
    'InformationVariable',
    'OutVariable',
    'OutBuffer',
    'PipelineVariable',
    'WhatIf',
    'Confirm'
    
    
    ForEach ($P in $Parameters.Keys) {
        [string]$Key = $P

        if ($CommonParameters -notcontains $Key) {

            $SplatString = @"
$SplatString
    $Key = `$$Key
"@

        }

    }

    $SplatString = @"
$SplatString
}

$Function @SplatParams
"@

    $SplatString

}
    
function invoke-PesterReturnFailures {
    [CmdletBinding()]
    
    param(
                    [Parameter(Position = 0, Mandatory = 0)]
                    [Alias('Path', 'relative_path')]
                    [object[]]$Script = '.',

                    [Parameter(Position = 1, Mandatory = 0)]
                    [Alias("Name")]
                    [string[]]$TestName,

                    [Parameter(Position = 2, Mandatory = 0)]
                    [switch]$EnableExit,

                    [Parameter(Position = 4, Mandatory = 0)]
                    [Alias('Tags')]
                    [string[]]$Tag,

                    [string[]]$ExcludeTag,

                    # [switch]$PassThru,

                    [object[]] $CodeCoverage = @(),

                    [string] $CodeCoverageOutputFile,

                    [ValidateSet('JaCoCo')]
                    [String]$CodeCoverageOutputFileFormat = "JaCoCo",

                    [Switch]$Strict,

                    [Parameter(Mandatory = $false, ParameterSetName = 'NewOutputSet')]
                    [string] $OutputFile,

                    [Parameter(ParameterSetName = 'NewOutputSet')]
                    [ValidateSet('NUnitXml')]
                    [string] $OutputFormat = 'NUnitXml',

                    [Switch]$Quiet,

                    [object]$PesterOption,

                    $Show = 'NotPassed'
    )
    
    
    $PesterResults = invoke-pester @PSBoundParameters -passthru  

    if ($Show -eq 'All') {
        $PesterResults | 
            select -expandproperty testresult | 
            select Describe, Name, Result
    } else {
        $PesterResults | 
            select -expandproperty testresult | 
            where result -ne 'Passed' | 
            select Describe, Name, Result
    }

    
}

set-alias ip invoke-PesterReturnFailures
set-alias pesterize invoke-PesterReturnFailures

function gvimx
<#
    .SYNOPSIS
    Edits file and returns control to Poswershell command line
    #> {
    [CmdletBinding()]
    param ($FileNames)
    
    
    foreach ($F in $FileNames) {
        & "C:\Program Files (x86)\vim\vim74\gvim.exe" $F
        write-verbose "Edited $(dir $F | select fullname, lastwritetime, length | ft -a)"
    }
    
}

<#
.Synopsis
   Get-CommandExcludingSomeModules
.EXAMPLE
   Get-CommandExcludingSomeModules vi
.EXAMPLE
   gcmx vi
#>
function Get-CommandExcludingSomeModules
{
    [CmdletBinding()]
    
    Param
    (
        # Param1 help description
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        $Name

    )
    $Modules = Get-Module |
        where Name -NotMatch "^Az" |
        where Name -NotMatch "ISE"


    get-command -Module $Modules -Name "*$Name*"
}
set-alias gcmx Get-CommandExcludingSomeModules


function get-CommandFromSpecifiedModules {
    [CmdletBinding()]
    
    Param
    (
        # Param1 help description
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        $Name,
        [string[]]$Module = ('dbatools')
    )

    get-command -module $Module -name "*$Name*"

}

Set-Alias gcmd get-CommandFromSpecifiedModules
Set-Alias gcmdba get-CommandFromSpecifiedModules

export-modulemember -alias * -function *
