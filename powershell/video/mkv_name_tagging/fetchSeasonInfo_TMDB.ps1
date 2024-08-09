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
Load any/all cached seasons for a specific show
.DESCRIPTION
Load any/all cached seasons for a specific show
.PARAMETER seasonCacheDir
Directory that contains the season json cache
.PARAMETER showInfo
Custom object that has the required fields of showName and showNameSafe
.OUTPUTS
An updated showInfo object containing a modified showNameSafe field
.EXAMPLE
loadCachedSeasons $showInfo "D:\Video\seasonCache"
#>
function loadCachedSeasons($showInfo, $seasonCacheDir) 
{
    # Check to see if we've previously gotten anything with this show
    # Force to always be an array
    [System.Collections.ArrayList]$cachedSeasonsLoad = @(Get-ChildItem $seasonCacheDir -Filter *.json | Where-Object {$_.Name.Contains($showInfo.safeName)})
    [System.Collections.HashTable]$cachedSeasons = New-Object -TypeName "System.Collections.HashTable"
    foreach($i in $cachedSeasonsLoad)
    {
        # Expect JSON format should match TMDB's output.  Format has 'season_number' at root
        $tmp = Get-Content -Raw -LiteralPath $i.FullName | ConvertFrom-Json
        $cachedSeasons.Add($tmp.season_number, $tmp)
    }

    Write-Host "The following cached seasons in reference to '$($showInfo.name)' were loaded: '$($cachedSeasons.Keys)'"

    return $cachedSeasons
}

<#
.SYNOPSIS
Load all numerical season representations in a given folder
.DESCRIPTION
Load all numerical season representations in a given folder
.PARAMETER workingDir
Directory that contains the mkv files that are notated with S##E##
.OUTPUTS
A hashtable containing a list of keys that represent the seasons in the provided directory
.EXAMPLE
determineSeasonsInDir "D:\Video\Rockos Modern Life (1993)"
#>
function determineSeasonsInDir($workingDir)
{
    # See what all seasons are in directory
    $fileNames = Get-ChildItem $workingDir -Filter *.mkv | ForEach-Object { $_.Name }
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

    return $seasonsInFileNames
}

<#
.SYNOPSIS
Get list of seasons missing from the cache that are needed
.DESCRIPTION
Get list of seasons missing from the cache that are needed
.PARAMETER seasonsInFileNames
Hashtable of all found season numbers in the files names from the directory
.PARAMETER cachedSeasons
All seasons currently in the cache
.OUTPUTS
Arraylist of all missing seasons
.EXAMPLE
determineMissingSeasonsInCache <hashtable of season numerical value> <hashtable of season numerical value>
#>
function determineMissingSeasonsInCache($seasonsInFileNames, $cachedSeasons)
{
    $missingSeasons = New-Object -TypeName "System.Collections.ArrayList"
    foreach($seasonNum in $seasonsInFileNames.Keys)
    {
        if (!$cachedSeasons.containsKey($seasonNum))
        {
            # Season is missing, add it to an array of ones to fetch
            # redirect to null since otherwise we'll get the add operation itself adding to the arraylist on the return
            $missingSeasons.Add($seasonNum) | Out-Null
        }
    }

    return $missingSeasons
}

<#
.SYNOPSIS
For any missing seasons, add them to the season cache directory
.DESCRIPTION
For any missing seasons, add them to the season cache directory
.PARAMETER missingSeasons
Arraylist of missing seasons by numerical value
.PARAMETER tmdbkey
Private key for interacting with the external provider
.PARAMETER seasonCacheDir
Location of the season cache directory
.PARAMETER showInfo
Custom object with the required field of showName, showNameSafe, and showExtID
.OUTPUTS
N/A
.EXAMPLE
updateCachedSeasons @[2,6,8] <api key> "D:\Video\seasonCache" <custom object>
#>
function updateCachedSeasons($missingSeasons, $tmdbKey, $seasonCacheDir, $showInfo)
{
    # Iterate over each detected season to see if it's something we have cached already
    foreach($seasonNum in $missingSeasons) 
    {
        Write-Host "$($showInfo.name) - Season $seasonNum was not found in cache, will reach out to TMDB for Season $seasonNum"
        $tmdbSeason = getSeasonDumpFromTMDB $showInfo.extID $seasonNum $tmdbKey
        
        # Save off for later to reduce API hits
        $cacheFileNameComplete = $seasonCacheDir + "\" + $showInfo.safeName + " - Season " + $seasonNum + ".json"
        # Due to possible usage of brackets, need to use -LiteralPath: https://github.com/PowerShell/PowerShell/issues/16076
        $tmdbSeason | ConvertTo-Json | Out-File -LiteralPath $cacheFileNameComplete
    }
}