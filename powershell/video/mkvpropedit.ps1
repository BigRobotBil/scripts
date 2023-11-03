$files = Get-ChildItem -Filter *.mkv

foreach($f in $files) {
    mkvpropedit.exe $f.Name --edit track:s1 --set flag-forced=0
}