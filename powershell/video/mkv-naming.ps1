<# TODO:
- Break up functions into seperate files.  All functions should be self contained without the need of global vars, effectively making a single "master" script that calls the other functions
- Have option of FFMpeg instead of Handbrake
- Place converted videos into proper season subfolder
- Support scanning files in Kodi-like directory structure (<show>\Season #)
- Option to name files like MKV title field (need to ensure illegal characters are replaced before renaming)
- Reorder params on functions to make some sense
- Make splitting not awful.  Try to support more than one split, essentially (take in param of which -### should be deleted, in the event that intro sequences are chapter'd, or something)

.\mkv-naming.ps1 -directory "D:\Video\Rocko's Modern Life (1993)" -splitParams "chapters:3" -handbrakePresetsFile "G:\Applications\HandBrake\presets.json" -handbrakeProfile "Grainy Cartoons - H.265" -shutdownPC
#>

<#
.SYNOPSIS
Takes a directory of ripped MKV files and converts them accordingly
.DESCRIPTION
Takes a directory that has a name of '<Show Title> (<year>)', and all files within following the naming structure of S##E##, and optionally S##E##E## (similar to https://kodi.wiki/view/Naming_video_files/TV_shows).
For files named S##E##E##, split operations will be applied.  All MKV operations leverage mkvtools (https://mkvtoolnix.download).  Episode information is fetched from themoviedb.org, and you must have an API key 
in your environment variables as TMDB_API_KEY, or supply one via 'tmdbApiKey'.  After splitting MKV files occurs (verify that the splitting procedure applies to your set of files),  files are internally named to '<Show Title> (<year>) - S##E## - <Episode Title>.
Once that is finished, files are then plugged into Handbrake with a specific preset, being stored in a folder named 'convert' within the originally supplied directory
.PARAMETER directory
Folder to work in that contains the mkv files to manage.  Folder must be named <Show Title> (<year>).  Episodes must either be S##E## or S##E##E##
.PARAMETER scriptMainDir
(Optional, defaults to current working directory) Folder where the script itself lives.
.PARAMETER workDir
(Optional, defaults to show directory) Directory to do any/all work related operations (splitting files, converting files, etc)
.PARAMETER showCacheFilename
(Optional, defaults to 'showCache.json') File that holds the show cache in json format
.PARAMETER handbrakePresetsFile
Full path to handbrake presets file (Ex: 'C:\dev\presets.json')
.PARAMETER handbrakeProfile
Handbrake profile to use in supplied presets
.PARAMETER splitParams
Parameters to give mkvmerge's split operation
.PARAMETER showName
(Optional, sourced from parent folder if not provided) name of the show.  Must be in the format of <Show Name> '(<year>)'
.PARAMETER tmdbApiKey
(Optional, default to env var) Personal API key to themoviedb.org if you don't wanna set the env var of $TMDB_API_KEY
.PARAMETER deleteAfterConvert
(Optional, default to false) Delete the original files after conversion with handbrake
.PARAMETER prompts
(Optional, default false) Turn off any prompts that pause and wait (aside from a few).  Useful for debugging; most prompts are before file operations (writing/renaming/moving/deleting)
.PARAMETER shutdownPC
(Optional, default $false) Shutdown the computer once done
.OUTPUTS
The full path to the new folder <directory>\<dirName>, essentially
.EXAMPLE
 .\mkv-naming.ps1 -directory "D:\Video\Rocko's Modern Life (1993)" -splitParams "chapters:3,4" -handbrakeProfile "Grainy Cartoons - H.265"
#>
param(
    [Parameter(Mandatory=$true)] [String]$directory,
    [Parameter(Mandatory=$false)] [String]$scriptMainDir,
    [Parameter(Mandatory=$false)] [String]$workDir,
    [Parameter(Mandatory=$false)] [String]$showCacheFilename,
    [Parameter(Mandatory=$false)] [String]$handbrakePresetsFile,
    [Parameter(Mandatory=$false)] [String]$handbrakeProfile,
    [Parameter(Mandatory=$false)] [String]$splitParams,
    [Parameter(Mandatory=$false)] [String]$showName,
    [Parameter(Mandatory=$false)] [String]$tmdbApiKey,
    [Parameter(Mandatory=$false)] [switch]$deleteAfterConvert=$false,
    [Parameter(Mandatory=$false)] [switch]$prompts=$false,
    [Parameter(Mandatory=$false)] [switch]$shutdownPC=$false
)

# Mapping for illegal characters since we use the Show Name as the main filename for seasons
# Could instead use the ShowID for filenames, but that will make the script /really/ dependent on the
# provider
[System.Collections.HashTable]$illegalCharsMap = New-Object -TypeName "System.Collections.HashTable"
$illegalCharsMap.Add("<", "[LESS_THAN]")
$illegalCharsMap.Add(">", "[GREATER_THAN]")
$illegalCharsMap.Add(":", "[COLON]")
$illegalCharsMap.Add("/", "[FSLASH]")
$illegalCharsMap.Add("\", "[BSLASH]")
$illegalCharsMap.Add("|", "[PIPE]")
$illegalCharsMap.Add("?", "[QMARK]")
$illegalCharsMap.Add("*", "[AST]")

function pauseForPrompt($ignore)
{
    if ($prompts -Or $ignore)
    {
        Read-Host -Prompt "Press any key to continue or CTRL+C to quit" | Out-Null
    }
}

<#
.SYNOPSIS
Checks to see if external applications required by script are on path
.DESCRIPTION
Checks to see if external applications required by script are on path
.PARAMETER requiredApplications
Arraylist of executables
.OUTPUTS
List of missing applications
.EXAMPLE
testRequiredApplications @("mkvmerge.exe", "HandbrakeCLI.exe")
#>
function testRequiredApplications($requiredApplications)
{
    $failures = New-Object -TypeName "System.Collections.ArrayList"
    foreach ($app in $requiredApplications)
    {
        if ($null -eq (Get-Command $app -ErrorAction SilentlyContinue)) 
        { 
           $failures.Add($app)
        }
    }

    return $failures
}

<#
.SYNOPSIS
Tries to make a directory with the given name
.DESCRIPTION
Tries to make a directory underneath the global param directory 
.PARAMETER operation
Used for logging; intent of folder (splitting, converting, adding, merging, etc)
.PARAMETER folderCheck
Check if the folder already exists and prompt for input to continue
.PARAMETER dirName
The actual name to use under the parent folder for the new directory name
.OUTPUTS
The full path to the new folder <directory>\<dirName>, essentially
.EXAMPLE
makeDirectory "Converting" "convert"
#>
function makeDirectory($rootDir, $operation, $folderCheck, $dirName)
{
    Write-Host "Creating $operation directory as $rootDir\$dirName"
    $newDir = "$rootDir\$dirName"
    
    if (($folderCheck -eq $true) -And (Test-Path -Path $newDir))
    {
        Read-Host -Prompt "$operation directory already exists.  Files within may be overwritten and/or mangled.  Press any key to continue or CTRL+C to quit" | Out-Null
    }
    else 
    {
        # You may ask why I'm essentially doing this twice, and that is a fantastic question to ponder over sometime
        # But it's because I want a prompt for /certain/ dirs, but not others
        if (Test-Path -Path $newDir)
        {
            Write-Host "Directory '$newDir' already exists"
        }
        else
        {
            # Out-Null to avoid the giant block of text that comes out of this
            New-Item -Path $rootDir -Name $dirName -ItemType Directory | Out-Null
        }
    }
    
    if (!(Test-Path -Path $newDir))
    {
        Read-Host -Prompt "$operation directory '$newDir' could not be created. :( Give up? Press any key to continue or CTRL+C to quit" | Out-Null
    }
    
    Write-Host "Using directory for $operation : $newDir"

    return $newDir
}

<#
.SYNOPSIS
Given a list of filenames, will try to split them according to rules
.DESCRIPTION
Given a list of filenames, will create split mkv files using mkvmerge.  If prompts are enabled,
then most actions will be paused until user input is engaged
.PARAMETER episodesToSplit
Array of files (episodes) to iterate over with the filename pattern of S##E##E##
.PARAMETER workDir
Directory to do any/all work related operations (the actual splitting of files)
.PARAMETER outputDir
Directory to put finished files
.OUTPUTS
None
.EXAMPLE
splitOperations <array of filenames with the pattern of S##E##E##>
#>
function splitOperations($episodesToSplit, $workDir, $outputDir) 
{
    Write-Host "Episodes that will be parsed for splitting: $episodesToSplit"
    
    ##### Setup a directory for splitting up mkvs
    $splitDir = makeDirectory $workDir "Spliting" $true "split"
    ##### End setup
    foreach ($ep in $episodesToSplit) 
    {
        Write-Host "Current file is: $ep"
    
        # File name should be formatted as S##E##E##
        $seEpEpName = Select-String -Pattern '[S]\d\dE\d\dE\d\d' -InputObject $ep.BaseName | ForEach-Object { $_.matches } | ForEach-Object { $_.Value }
        $season = $seEpEpName.Substring(0,3)
        $episode1 = $seEpEpName.Substring(3,3)
        $episode2 = $seEpEpName.Substring(6,3)
        Write-Host "Current file detected to have two episodes in $season, episodes are: $episode1 and $episode2"

        Write-Host "Calling split command for mkvmerge.exe with params --split $splitParams $($ep.FullName) -o $splitDir\$($ep.Name)"
        
        pauseForPrompt

        mkvmerge.exe --split $splitParams $ep.FullName -o $splitDir\$($ep.Name)

        pauseForPrompt

        # There will be three files outputted: episode1, emptiness, episode2
        # <original filename>-001 <original filename>-002 <original filename>-003
        # We want to delete the emptiness, and rename the files to match the S##E## format

        #### Emptiness
        <#  $episode1Name = $ep.Name.Substring(0, $ep.Name.length - 4) + "-001.mkv"
        $emptinessName = $ep.Name.Substring(0, $ep.Name.length - 4) + "-002.mkv"
        $episode2Name = $ep.Name.Substring(0, $ep.Name.length - 4) + "-003.mkv" #>

        $episode1Name = $ep.Name.Substring(0, $ep.Name.length - 4) + "-001.mkv"
        $episode2Name = $ep.Name.Substring(0, $ep.Name.length - 4) + "-002.mkv"

        Write-Host "Names: $episode1Name $episode2Name"

        # Remove-Item "$splitDir\$emptinessName"

        # Rename the other two files
        $ep1CombName = $season + $episode1 + ".mkv"
        $ep2CombName = $season + $episode2 + ".mkv"
        Write-Host "Will rename '$splitDir\$episode1Name' to $ep1CombName"
        Write-Host "Will rename '$splitDir\$episode2Name' to $ep2CombName"

        pauseForPrompt
        
        Rename-Item "$splitDir\$episode1Name" -NewName $ep1CombName
        Rename-Item "$splitDir\$episode2Name" -NewName $ep2CombName

        pauseForPrompt

        # move the split files back to the parent dir, so they can be parsed with the rest of the group
        Move-Item -Path "$splitDir\$ep1CombName" -Destination $directory\$ep1CombName
        Move-Item -Path "$splitDir\$ep2CombName" -Destination $directory\$ep2CombName

        # Delete the original, since we don't need it anymore
        Remove-Item $ep.FullName
    }

    Write-Host "Done splitting for $episodesToSplit, will delete $splitDir"
    Remove-Item $splitDir
}

<#
.SYNOPSIS
Reaches out to themoviedb.org API to get TV show information
.DESCRIPTION
Reaches out to themoviedb.org API to get TV show information.
.PARAMETER showName
Name of show as '<Show Name> (<year>)' . This will be used for querying
.PARAMETER tmdbKey
API key for themoviedb
.OUTPUTS
Season information in JSON format
.EXAMPLE
getSeasonDumpFromTMDB "Rocko's Modern Life (1993)" <your API key>
#>
function getShowInfo($showName, $tmdbKey)
{
    # Get the year.  I blame myself for not knowing Powershell and that it's nearly 1AM
    $showYearWithParen = $showName.Substring($showName.Length - 5)
    $showYear = $showYearWithParen.Substring(0, $showYearWithParen.Length -1)

    # Query is the show name, so lob off the year
    $Body = @{
        query = $showName.Substring(0, $showName.Length - 6)
        year = $showYear
        first_air_date_year = $showYear
    }
    Write-Host "Reaching out to TheMovieDB for '$showName'"
    pauseForPrompt
    $tvShowIdRes = Invoke-RestMethod -Headers @{Authorization = "Bearer $tmdbKey"} -Uri "https://api.themoviedb.org/3/search/tv" -Body $Body

    if ($tvShowIdRes.results.Count -gt 1)
    {
        Write-Host "More than one result was returned from TMDB for $showName"
        Read-Host -Prompt "Press any key to continue or CTRL+C to quit" | Out-Null
    }

    return $tvShowIdRes
}

<#
.SYNOPSIS
Reaches out to themoviedb.org API to get episode information
.DESCRIPTION
Reaches out to themoviedb.org API to get episode information
.PARAMETER showId
TMDB ID of the show
.PARAMETER seasonNum
Season number
.PARAMETER tmdbKey
API key for themoviedb
.OUTPUTS
Season information in JSON format
.EXAMPLE
getSeasonDumpFromTMDB 657 1
#>
function getSeasonDumpFromTMDB($showId, $seasonNum, $tmdbKey)
{
    # Have the ID, which means we can get the season information
    $seasonResp = Invoke-RestMethod -Headers @{Authorization = "Bearer $tmdbKey"} -Uri "https://api.themoviedb.org/3/tv/$($showId)/season/$($seasonNum)?language=en-US"

    return $seasonResp
}

<#
.SYNOPSIS
Checks already cached items for show information, and will call out to themoviedb.org for missing ones that are detected
.DESCRIPTION
Checks already cached items for show information, and will call out to themoviedb.org for missing ones that are detected
.PARAMETER showCacheFile
Name of the show cache json file
.PARAMETER showName
Name of show as '<Show Name> (<year>)' .  Used to identify in existing cache and check against themoviedb
.OUTPUTS
Hashtable of season information, where key matches $showName and value is the information in themoviedb API format for the show (raw)
.EXAMPLE
prepareShowCache "Rocko's Modern Life (1993)"
#>
function prepareShowCache($showCacheFile, $showName, $tmdbKey)
{
    [System.Collections.HashTable]$showCache = New-Object -TypeName "System.Collections.HashTable"
    $showId = 0
    # Load cached show information
    if (Test-Path -Path $showCacheFile)
    {
        Write-Host "Show Cache found at '$showCacheFile'"
        $loaded = Get-Content $showCacheFile | ConvertFrom-Json
        
        foreach($prop in $loaded.psobject.Properties)
        {
            $showCache[$prop.Name] = $prop.Value
        }
    }
    else
    {
        Write-Host "Show cache not found at location entered, will create new cache at '$showCacheFile'"
    }

    # Check if the show was already fetched
    if (!$showCache.ContainsKey($showName))
    {
        Write-Host "'$showName' was not previously cached by script, will look up"
        pauseForPrompt
        $showRes = getShowInfo $showName $tmdbKey

        # Add to cache, then write out to file
        $showCache.Add($showName, $showRes.results[0].id)
        $showCache | ConvertTo-Json -Depth 2 | Out-File $showCacheFile

        Write-Host "'$showName' added to cache, will not be fetched from API in the future"
    }
    else
    {
        $showId = $showCache[$showName]
        if ($showId.Length -gt 0)
        {
            Write-Host "'$showName' was found in cache.  ID is $showId"
        }
        else 
        {
            Write-Host "Somehow, despite '$showName' being in cache, no corresponding ID was found"
        }
        
    }

    return $showCache
}

<#
.SYNOPSIS
Checks already cached items for season information, and will call out to themoviedb.org for missing ones that are detected
.DESCRIPTION
Checks already cached items for season information, and will call out to themoviedb.org for missing ones that are detected
.PARAMETER rootDir
Directory to load and/or store the cache in
.PARAMETER directory
Directory containing files to parse
.PARAMETER showName
Name of show as '<Show Name> (<year>)' . Used for logging
.PARAMETER showId
ThemovieDB ID of the show. This will be used for querying if season was not previously cached
.OUTPUTS
Hashtable of season information, where key is the season number and value is the information in themoviedb API format for seasons
.EXAMPLE
prepareSeasonCache "D:\Video\Rocko's Modern Life (1993)" "Rocko's Modern Life (1993)"
#>
function prepareSeasonCache($rootDir, $directory, $showName, $showId, $tmdbKey)
{
    # Create directory to hold cache of TV show information if it doesn't already exist
    # TV show json should be in the format of <show name> (<year>) - Season <season ##>.json
    $seasonCacheDir = makeDirectory $rootDir "TMDB Cache" $false "seasonCache"

    # Convert Show Name to ensure it doesn't have illegal chars in it
    $showNameSafe = $showName.PSObject.Copy()
    foreach ($entry in $illegalCharsMap.GetEnumerator())
    {
        $showNameSafe = $showNameSafe.Replace($entry.Name, $entry.Value)
    }

    # Check to see if we've previously gotten anything with this show
    # Force to always be an array
    [System.Collections.ArrayList]$cachedSeasonsLoad = @(Get-ChildItem $seasonCacheDir -Filter *.json | Where-Object {$_.Name.Contains($showNameSafe)})
    [System.Collections.HashTable]$cachedSeasons = New-Object -TypeName "System.Collections.HashTable"
    foreach($i in $cachedSeasonsLoad)
    {
        # Expect JSON format should match TMDB's output.  Format has 'season_number' at root
        $tmp = Get-Content -Raw -LiteralPath $i.FullName | ConvertFrom-Json
        $cachedSeasons.Add($tmp.season_number, $tmp)
    }

    Write-Host "The following cached seasons in reference to '$showName' were loaded: '$($cachedSeasons.Keys)'"

    # See what all seasons are in directory
    $fileNames = Get-ChildItem $directory -Filter *.mkv | ForEach-Object { $_.Name }
    # abuse hashtables since powershell doesn't have sets, and I don't wanna call a de-dupe function on arrays
    [System.Collections.HashTable]$seasonsInFileNames = New-Object -TypeName "System.Collections.HashTable"
    foreach($file in $fileNames)
    {
        $somethingAlright = Select-String -Pattern '[S]\d\d' -InputObject $file | ForEach-Object { $_.matches } | ForEach-Object { $_.Value }
        #should be "S##", remove the "S" via substring
        $tmp = [int]$somethingAlright.Substring(1)
        if (!$seasonsInFileNames.ContainsKey(($tmp)))
        {
            $seasonsInFileNames.Add($tmp, "")
        }
    }

    foreach($seasonNum in $seasonsInFileNames.Keys) 
    {
        if (!$cachedSeasons.containsKey($seasonNum))
        {
            Write-Host "$showName - Season $seasonNum was not found in cache, will reach out to TMDB for Season $seasonNum"
            $tmdbSeason = getSeasonDumpFromTMDB $showId $seasonNum $tmdbKey
            
            # Save off for later to reduce API hits
            $cacheFileNameComplete = $seasonCacheDir + "\" + $showNameSafe + " - Season " + $seasonNum + ".json"
            # Due to possible usage of brackets, need to use -LiteralPath: https://github.com/PowerShell/PowerShell/issues/16076
            $tmdbSeason | ConvertTo-Json | Out-File -LiteralPath $cacheFileNameComplete

            $cachedSeasons.Add($seasonNum, $tmdbSeason)
        }
        else
        {
            Write-Host "$showName - Season $seasonNum was found in the cache, will not reach out"
        }
    }

    return $cachedSeasons
}

<#
.SYNOPSIS
Update the title field of an MKV file
.DESCRIPTION
Updates the title field of an MKV file to be in a standard format of "<Show Name> (<year>) - S##E## - <Episode Title>"
.PARAMETER directory
Directory that files are in
.PARAMETER cachedSeasons
Hashtable of season information, where key is the season number and value is the information in themoviedb API format for seasons
.OUTPUTS
None
.EXAMPLE
modifyTitleField "D:\Video\Rocko's Modern Life (1993)" <hashtable of seasons>
#>
function modifyTitleField($directory, $cachedSeasons)
{
    $epsMkvTitleMod = Get-ChildItem $directory -Filter *.mkv

    foreach ($ep in $epsMkvTitleMod)
    {
        # Get the season
        $currSeason = Select-String -Pattern '[S]\d\d' -InputObject $ep.Basename | ForEach-Object { $_.matches } | ForEach-Object { $_.Value }
        
        # result will be in the form of S##, we'll need to remove the "S" and convert to an actual digit
        $tmp = [int]$currSeason.Substring(1)

        $season = $cachedSeasons[$tmp]
        
        # Filename should be formatted as S##E##, and we just want the digits after E
        $epNumWithE = Select-String -Pattern '[E]\d\d' -InputObject $ep.Basename | ForEach-Object { $_.matches } | ForEach-Object { $_.Value }
        $epNum = [int]$epNumWithE.Substring(1)
        $tmdbEpisodeMatch = $season.episodes | Where-Object { $_.episode_number -eq $epNum }
        
        $seasonEpisode = $currSeason + $epNumWithE
        if ($tmdbEpisodeMatch)
        {
            $tmdbEpisodeName = $tmdbEpisodeMatch.name
            $mkvTitleField = $showName + " - " + $seasonEpisode.toUpper() + " - " + $tmdbEpisodeName
            # Check to see if MKV already has a matching name to avoid doing extra work
            $jsonInfoForEp = (mkvmerge.exe -J $ep.FullName) -join "`n" | ConvertFrom-Json
            $internalTitle = $jsonInfoForEp.container.properties.title
    
            if ($internalTitle.Length -gt 0 -And $internalTitle -eq $mkvTitleField)
            {
                Write-Host "$($ep.Name) already has valid name of '$internalTitle', will not update" 
            } 
            else
            {
                Write-Host "Writing the following the mkv title field: $mkvTitleField"
    
                mkvpropedit.exe $ep.FullName -e info -s title=$($mkvTitleField)
            }
        }
        else 
        {
            Write-Host "Failed to find corresponding episode in season cache for $($ep.Name)"    
        }
    }
}

##### SCRIPT START

$requiredApplications = New-Object -TypeName "System.Collections.ArrayList"
$requiredApplications.Add("mkvmerge.exe")
$requiredApplications.Add("mkvpropedit.exe")
$requiredApplications.Add("HandbrakeCLI.exe")

$failures = testRequiredApplications $requiredApplications

if ($failures.Count -gt 0)
{
    Write-Host "Could not find the following required applications on PATH: $failures"
    exit
}

if ($workDir.Length -eq 0)
{
    $workDir = $directory.PSObject.Copy()
}

if ($showName.Length -eq 0)
{
    $showName = $directory | Split-Path -leaf
}

if ($showCacheFilename.Length -eq 0)
{
    $showCacheFilename = "showCache.json"
}

if ($scriptMainDir.Length -eq 0)
{
    $scriptMainDir = ".\"
}

$tmdbKey = $env:TMDB_API_KEY

# Optionally use a key given as param
if ($tmdbApiKey.Length -gt 0)
{
    Write-Host "Using provided key instead of environment variable for TMDB"
    $tmdbKey = $tmdbApiKey
} elseif ($env:TMDB_API_KEY.length -eq 0)
{
    Write-Host "Environment Variable TMDB_API_KEY is empty, cannot use TMDB lookup.  Will exit"
    exit
}

Write-Host "Root directory of script set to '$scriptMainDir'"
Write-Host "Work directory set to '$workDir'"
Write-Host "Show Cache filename set to '$showCacheFilename'"
Write-Host "Handbrake presets.json located at '$handbrakePresetsFile'"
Write-Host "Handbrake Profile set to '$handbrakeProfile'"
Write-Host "Split Params set to '$splitParams'"
Write-Host "Show name set to '$showName'"
Write-Host "Prompts set to '$prompts'"
Write-Host "Deletion of source files after conversion set to '$deleteAfterConvert'"
Write-Host "ShutdownPC set to '$shutdownPC'"
Write-Host "Directory with episodes to parse is set to '$directory' (directory's final folder MUST match <name of show> (<year>) if showName param not used!)"

if ($shutdownPC)
{
    Write-Host "PC WILL BE SHUTDOWN UPON SCRIPT COMPLETION.  ENSURE THIS IS WHAT YOU WANT BEFORE CONTINUING"
}

Write-Host "Verify all the above is to your liking before continuing"
pauseForPrompt $true

$showCacheFile = $scriptMainDir + "\" + $showCacheFilename

$showCache = prepareShowCache $showCacheFile $showName $tmdbKey

if ($null -eq $showCache)
{
    Write-Host "Show cache could not be loaded.  Exiting"
    exit
}

$showId = 0
if ($showCache.ContainsKey($showName))
{
    $showId = $showCache[$showName]
    Write-Host "'$showName' has the TMDB ID of '$showId'"
}
else
{
    Write-Host "'$showName' does not have a corresponding show ID"
    exit
}

$cachedSeasons = prepareSeasonCache $scriptMainDir $directory $showName $showId $tmdbKey

if ($null -eq $cachedSeasons)
{
    Write-Host "Unable to load seasons for show.  Exiting"
    exit
}

[System.Object]$episodesToSplit = Get-ChildItem $directory -Filter *.mkv | Where-Object {$_ -match '[S]\d\dE\d\dE\d\d'}

if ($splitParams.Length -eq 0 -And $episodesToSplit.Count -gt 0)
{
    Write-Host "Detected episodes needing to be split, but no split params given.  Exiting"
    exit
}

if ($episodesToSplit.Count -gt 0)
{
    Write-Host "Detected that there are $($episodesToSplit.Count) episode(s) that need to be split"
    splitOperations $episodesToSplit $workDir $directory
}

# At this point, any episodes that should have been split are split, and everything in the original directory folder should be ready for renaming and whatnot
modifyTitleField $directory $cachedSeasons

if ($handbrakePresetsFile.Length -gt 0 -And $handbrakeProfile.Length -gt 0)
{
    $epsToHandbrake = Get-ChildItem $directory -Filter *.mkv

    ##### Setup a directory for containing converted mkvs
    $convertDir = makeDirectory $workDir "Converting" $true "convert"
    ##### End setup

    foreach ($ep in $epsToHandbrake)
    {
        # Run Handbrake
        $outputName = $convertDir + "\" + $ep.Name
        HandBrakeCLI.exe --audio-lang-list "English,eng" -E "opus" --subtitle-lang-list "English,eng" -N "eng" --preset-import-file $handbrakePresetsFile -Z $handbrakeProfile -i $ep.FullName -o $outputName

        if ($deleteAfterConvert)
        {
            Remove-Item $ep.FullName
        }
    }
}
else
{
    Write-Host "Handbrake options not specified, skipping"
}

if ($shutdownPC) 
{
    shutdown /s
}