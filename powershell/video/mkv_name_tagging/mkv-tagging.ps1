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
function modifyTitleField($showInfo, $cachedSeasons)
{
    $epsMkvTitleMod = Get-ChildItem $showInfo.directory -Filter *.mkv

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
            $mkvTitleField = $showInfo.name + " - " + $seasonEpisode.toUpper() + " - " + $tmdbEpisodeName
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

<#
.SYNOPSIS
Renames a file to the title field from the MKV file
.DESCRIPTION
Renames a file to the title field from the MKV file, removing any illegal characters before actually renaming
.PARAMETER showInfo
The horrible object that knows everything
.OUTPUTS
None
.EXAMPLE
modifyFileNameToMatchTitleField <showInfo, containing a directory property to fetch the mkv files>
#>
function modifyFileNameToMatchTitleField($showInfo) {

    $epsMkvTitleMod = Get-ChildItem $showInfo.directory -Filter *.mkv
    # https://stackoverflow.com/a/23067832
    $invalidChars = [IO.Path]::GetInvalidFileNameChars() -join ''
    $re = "[{0}]" -f [RegEx]::Escape($invalidChars)
    foreach ($ep in $epsMkvTitleMod)
    {
        $currJson = (mkvmerge.exe -J $ep.FullName) -join "`n" | ConvertFrom-Json
        $titleName = $currJson.container.properties.title + ".mkv"
        $noInvalid = $titleName -replace $re

        # check to see if the file name already matches
        if ($noInvalid -cne $ep.Name) {
            Rename-Item $ep.FullName -NewName $noInvalid
        }
    }
}