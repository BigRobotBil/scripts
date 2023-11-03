
function fetchTitleCard($directory, $outputDir, $format, $filename, $timestamp)
{
    # usage:  fetchTitleCard "Z:\VIDEO\TV\Rocko's Modern Life (1993)\Season 1\" "D:\Video\Rocko's Modern Life (1993)\titlecards" "jpeg" "S01E23" "48"
    $fileToParse = $directory + "\" + $fileName + ".mkv"
    $outputFile = $outputDir + "\" + $filename + "-thumb." + $format
    ffmpeg.exe -ss $timestamp -i $fileToParse -vframes 1 -r 1 -y $outputFile
}

function createTitleCards($directory, $evenTimestamp, $oddTimestamp)
{
    $titlecardDir = $directory + "titlecards"
    if (!(Test-Path -Path $titlecardDir))
    {
        New-Item -Path $directory -Name "titlecards" -ItemType Directory | Out-Null
    }
    
    $episodesToGetTitleCards = Get-ChildItem $directory -Filter *.mkv

    foreach ($ep in $episodesToGetTitleCards)
    {
        #get the episode number.  Generally, if it's odd, there's the intro sequence.  If it's even, there is no intro sequence
        
        $epNumWithE = Select-String -Pattern '[E]\d\d' -InputObject $ep.Basename | ForEach-Object { $_.matches } | ForEach-Object { $_.Value }
        $epNum = [int]$epNumWithE.Substring(1)

        if (($epNum % 2) -eq 0)
        {
            fetchTitleCard $directory $titlecardDir "jpg" $ep.BaseName $evenTimestamp
        }
        else
        {
            fetchTitleCard $directory $titlecardDir "jpg" $ep.BaseName $oddTimestamp
        }
    }
}