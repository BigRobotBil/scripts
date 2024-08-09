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

<#
.SYNOPSIS
Create a string that represents the show that is safe to use a filename
.DESCRIPTION
Create a string that represents the show that is safe to use a filename
.PARAMETER showInfo
Custom object that has the required fields of showName and showNameSafe
.OUTPUTS
An updated showInfo object containing a modified showNameSafe field
.EXAMPLE
getSafeFileNameForShow $showInfo
#>
function getSafeFileNameForShow($showInfo) 
{
    # Convert Show Name to ensure it doesn't have illegal chars in it
    $showSafeName = $showInfo.name.PSObject.Copy()
    foreach ($entry in $illegalCharsMap.GetEnumerator())
    {
        $showSafeName = $showSafeName.Replace($entry.Name, $entry.Value)
    }

    $showInfo.safeName = $showSafeName
    return $showInfo
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
getSeasonDumpFromTMDB <custom object with the name of the show as showName> <your API key>
#>
function getShowInfo($showInfo, $tmdbKey)
{
    # Get the year.  I blame myself for not knowing Powershell and that it's nearly 1AM
    $showYearWithParen = $showInfo.name.Substring($showInfo.name.Length - 5)
    $showYear = $showYearWithParen.Substring(0, $showYearWithParen.Length -1)

    # Query is the show name, so lob off the year
    $Body = @{
        query = $showInfo.name.Substring(0, $showName.Length - 6)
        year = $showYear
        first_air_date_year = $showYear
    }
    Write-Host "Reaching out to TheMovieDB for '$($showInfo.name)'"
    $tvShowIdRes = Invoke-RestMethod -Headers @{Authorization = "Bearer $tmdbKey"} -Uri "https://api.themoviedb.org/3/search/tv" -Body $Body

    if ($tvShowIdRes.results.Count -gt 1)
    {
        Write-Host "More than one result was returned from TMDB for $($showInfo.name)"
        Read-Host -Prompt "Press any key to continue or CTRL+C to quit" | Out-Null
    }

    return $tvShowIdRes
}

<#
.SYNOPSIS
Prepares key/value file of show information in the style of <show name> : <ext id> for each entry
.DESCRIPTION
Prepares key/value file of show information in the style of <show name> : <ext id> for each entry
.PARAMETER showCacheFile
Name of the show cache json file, containing k/v of title/extId
.OUTPUTS
Hashtable of Show Name / Ext ID
.EXAMPLE
prepareShowCacheFile "D:\Video\showCache.json"
#>
function prepareShowCacheFile($showCacheFile)
{
    [System.Collections.HashTable]$showCache = New-Object -TypeName "System.Collections.HashTable"
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
        Write-Host "Show cache not found at location entered"
    }

    return $showCache
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
Updated showInfo object with Ext ID modified
.EXAMPLE
fetchShowExtId "Rocko's Modern Life (1993)"
#>
function fetchShowExtId($showCache, $showInfo, $tmdbKey, $showCacheFile)
{
    # Check if the show was already fetched
    if (!$showCache.ContainsKey($showInfo.name))
    {
        Write-Host "'$($showInfo.name)' was not previously cached by script, will look up"
        $showRes = getShowInfo $showInfo $tmdbKey

        # Add to cache, then write out to file
        $showCache.Add($showInfo.name, $showRes.results[0].id)
        $showId = $showRes.results[0].id
        $showCache | ConvertTo-Json -Depth 2 | Out-File $showCacheFile

        Write-Host "'$($showInfo.name)' added to cache, will not be fetched from API in the future"
    }
    else
    {
        $showId = $showCache[$showInfo.name]
        if ($showId.Length -gt 0)
        {
            Write-Host "'$($showInfo.name)' was found in cache.  ID is $showId"
        }
        else 
        {
            Write-Host "Somehow, despite '$($showInfo.name)' being in cache, no corresponding ID was found"
        }
        
    }

    $showInfo.extID = $showId

    return $showInfo
}