<#
.SYNOPSIS
Takes a directory of ripped MKV files and converts them accordingly
.DESCRIPTION
Takes mkv files and names the internal title field and the file name to the format of "<Show Name> <Year> - S##E## - <Episode Name>"
.PARAMETER baseDir
Base dir for caches
.PARAMETER showDir
The location of the mkv files corresponding to the show that will be parsed
.PARAMETER showName
The name of the show (with year)
.PARAMETER tmdbApiKey
(Optional) API key for TheMovieDb
.OUTPUTS
The full path to the new folder <directory>\<dirName>, essentially
.EXAMPLE
 .\runner.ps1 baseDir "D:\Video"  -showDir "D:\Video\Rocko's Modern Life (1993)" -showName "Rocko's Modern Life (1993)""
#>
param(
    [Parameter(Mandatory=$true)] [String]$baseDir,
    [Parameter(Mandatory=$true)] [String]$showDir,
    [Parameter(Mandatory=$true)] [String]$showName,
    [Parameter(Mandatory=$false)] [String]$tmdbApiKey
)

. .\loadShowInfo_TMDB.ps1

# Get the TMDB API Key

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

#$showInfo, $seasonCache = loadShowInfo $tmdbKey "D:\Video" "D:\Video\Law and Order Special Victims Unit (1999)" "Law & Order: Special Victims Unit (1999)"
$showInfo, $seasonCache = loadShowInfo $tmdbKey $baseDir $showDir $showName

# MKV OPERATIONS START

modifyTitleField $showInfo $seasonCache

modifyFileNameToMatchTitleField $showInfo