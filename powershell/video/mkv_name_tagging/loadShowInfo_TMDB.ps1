. .\mkv-tagging.ps1
. .\fetchShowInfo_TMDB.ps1
. .\fetchSeasonInfo_TMDB.ps1

function loadShowInfo($tmdbKey, $rootDir, $showDirectory, $showName)
{
    # Get show name to parse
    # Have all of these overrideable and based on input
    # Only require the input of name and directory if others aren't provided
    $showInfo = [PSCustomObject]@{
        name = 'Law & Order: Special Victims Unit (1999)'
        safeName = ''
        extID = ''
        directory = 'D:\Video\Law and Order Special Victims Unit (1999)'
    }

    $showInfo.name = $showName
    $showInfo.directory = $showDirectory

    # SHOW METADATA START
    $showCache = prepareShowCacheFile "$rootDir\showCache.json"
    $showInfo = fetchShowExtId $showCache $showInfo $tmdbKey "$rootDir\showCache.json"
    $showInfo = getSafeFileNameForShow $showInfo

    # At this point, the showInfo object should be populated with the Safe Name and the Ext ID

    # SEASON METADATA START
    $seasonCacheDir = "$rootDir\seasonCache"
    $seasonCache = loadCachedSeasons $showInfo $seasonCacheDir
    $seasonsInFileNames = determineSeasonsInDir $showInfo.directory
    $missingSeasons = determineMissingSeasonsInCache $seasonsInFileNames $seasonCache
    if ($missingSeasons.count -gt 0) {
        Write-Host "The following seasons need to be fetch '[$missingSeasons]'"
        updateCachedSeasons $missingSeasons $tmdbKey $seasonCacheDir $showInfo
        # Reload any newly cached seasons
        $seasonCache = loadCachedSeasons $showInfo $seasonCacheDir
    }

    # At this point, all season information should be accounted for
    return $showInfo, $seasonCache
}