<#
.SYNOPSIS
Given an open directory link, traverse looking for files that match the types
.DESCRIPTION
Takes a link to an open directory, and will look through files in the given directory and the folders within to see if it can find files that match the filter (types) provided
.PARAMETER url
URL to start traversing
.PARAMETER types
Comma delimited list of file types ("mkv,mp4")
.PARAMETER filename
(Optional) Will output to a file instead of standard out
.OUTPUTS
List of files found to the terminal (unless filename is provided)
.EXAMPLE
 .\webFetch2.ps1' -url http://www.myexposedopendirectory.com/videos/ -types "mkv,mp4" -filename "output.txt"
#>
param(
    [Parameter(Mandatory=$true)] [String]$url,
    [Parameter(Mandatory=$true)] [String]$types,
    [Parameter(Mandatory=$false)] [String]$filename
)

$global:counter = 0

$fileTypesToFilterFor = $types -split ","

$matchClause = '(?:{0})' -f ($fileTypesToFilterFor -join '|')

function outputFolder($url, $listOfFiles) {
    # Write everything to a single file
    if($filename) {
        if (!(Test-Path $filename)) {
            New-Item -Path $filename
        }
        $listOfFiles | Out-File -FilePath $filename -Append
    } else {
        Write-Host "Current url: $url"
        foreach($i in $listOfFiles) {
            Write-Host $i
        }
    }
}

function traverseFolder($url, $matchClause) {
    $rootFolder = Invoke-WebRequest -Uri $url
    # Only get folders that _aren't_ the parent return link.  If that's included, we get into an infinite loop
    $folders = $rootFolder.Links | Where-Object {$_.innerText.EndsWith('/') -and !($_.innerText -eq '../')}

    foreach($i in $folders) {
        $output = New-Object -TypeName "System.Collections.ArrayList"
        $exec = $url + $i.href
        $newRoot = Invoke-WebRequest -Uri $exec
        #get all the links in here
        foreach($l in $newRoot.Links) {
            if($l.href -match $matchClause) {
                [void]$output.Add($exec + $l.href)
            }
        }

        #output current iteration to wherever
        outputFolder $exec $output

        #see if there are anymore folders
        traverseFolder $exec $matchClause
    }
}

try {    
    # for each folder, traverse through and see if there's matching items in addition to the original root dir
    traverseFolder $url $matchClause
} catch {
    Write-Host $_.Exception.Response
}
