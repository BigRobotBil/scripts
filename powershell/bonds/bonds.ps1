# TODO:
# - Sanity check CSV to ensure it has the proper fields before starting
# - Sanity check that each bond has the Type/Amount/Serial/Month/Year before trying to execute
# - Don't shortcut the PSCustomObject for "bond" via the imported CSV
# - Use the "Hidden Items" object on the page instead, now that we know what the secret is to the Month/Year situation
# - Actually parse the HTML like a sane person and not the awful string regex approach that could easily break

<#
.SYNOPSIS
Fetch bond information from TreasuryDirect using a pre-formatted CSV file
.DESCRIPTION
Using a CSV file of pre-populated information regarding bonds, fetch information for each one from TreasuryDirect using REST requests,
afterwards combining the data in a new CSV file with all of the attributes returned from TreasuryDirect
.PARAMETER inputFile
CSV file to read in.  Defaulted to local directory with filename "bonds.csv" if not provided.
Must be formatted with the following headers: Type,Amount,Serial,Month,Year,Next Accrual,Final Maturity,Issue Price,Interest Accumulated,Interest Rate,Present Value
.PARAMETER outputFile
Where to save the results
.OUTPUTS
Saves new CSV with populated information to $outputFile
.EXAMPLE
.\bonds.ps1 -inputFile ".\bonds.csv" -outputFile ".\updated.csv"
#>
param(
    [Parameter(Mandatory=$false)] [String]$inputFile,
    [Parameter(Mandatory=$false)] [String]$outputFile
)

<#
.SYNOPSIS
Sends a REST request via Invoke-RestMethod to the Treasury Direct's site using a single bond
.DESCRIPTION
Sends a REST request via Invoke-RestMethod to the Treasury Direct's site using a single bond
.PARAMETER bond
A PSObject containing the Month/Year of issue, type, amount, and serial number
.OUTPUTS
The entire HTML result of the request without parsing
.EXAMPLE
sendRequest [PSObject with the attributes "Month", "Year", "Type", "Amount", "Serial"]
#>
function sendRequest($bond) {
    $issueDate = "$($bond.Month)/$($bond.Year)"
    
    # build the body
    $body = @{
        RedemptionDate = $redemptionDate
        Series = $bond.Type
        Denomination = $bond.Amount
        SerialNumber = $bond.Serial
        IssueDate = $issueDate
        "btnAdd.x" = "CALCULATE"
    }

    return Invoke-RestMethod -Uri "https://treasurydirect.gov/BC/SBCPrice" -ContentType "application/x-www-form-urlencoded" -Body $body
}

if ($inputFile.Length -gt 0) {
    Write-Host "Input file: $inputFile"
} else {
    Write-Host "Input file not provided, defaulting to 'bonds.csv'"
    $inputFile = ".\bonds.csv"
}

if ($outputFile.Length -gt 0) {
    Write-Host "Output file: $outputFile"
} else {
    Write-Host "Output file not provided, defaulting to 'updated.csv'"
    $outputFile = ".\updated.csv"
}

Write-Host "Verify all the above is to your liking before continuing"
Read-Host -Prompt "Press any key to continue or CTRL+C to quit" | Out-Null


# globals
$redemptionDate = Get-Date -Format "MM/yyyy"

### SCRIPT START

$bonds = Import-Csv $inputFile

foreach($bond in $bonds) {
    # fetch the calc from TreasuryDirect
    $html = sendRequest $bond 
    # $html = Get-Content ".\bonds\example.html"
    # The table with human readable values for the dates are in the <td> tags after the bond itself
    # Context allows us to get x amount of values /after/ the bond, so we don't have to manually search for each one
    $items = ($html -split '\r?\n').Trim() | Select-String "<td class=`"lft`">$($bond.Serial)</td>" -Context 0,9

    if ($items.Context.PostContext.Count -eq 9) {
        # the order on the page is always:
        # series (I, EE)
        # Denomenation
        # Issue Date
        # Next Accrual
        # Final Maturity
        # Issue Price
        # Interest accumulated
        # Interest Rate
        # Current Value as of today
        
        $bond.'Next Accrual' = $items.Context.PostContext[3].Replace("<td>", "").Replace("</td>", "")
        $bond.'Final Maturity' = $items.Context.PostContext[4].Replace("<td>", "").Replace("</td>", "")
        $bond.'Issue Price' = $items.Context.PostContext[5].Replace("<td>", "").Replace("</td>", "")
        $bond.'Interest Accumulated' = $items.Context.PostContext[6].Replace("<td>", "").Replace("</td>", "")
        $bond.'Interest Rate' = $items.Context.PostContext[7].Replace("<td>", "").Replace("</td>", "")
        $bond.'Present Value' = $items.Context.PostContext[8].Replace("<td>", "").Replace("</td>", "").Replace("<strong>", "").Replace("</strong>", "")
        Write-Host "$($bond.Serial) fetched successfully"

        $bond | Export-CSV $outputFile -Append -NoTypeInformation -Force
    } else {
        Write-Host "$($bond.Serial) failed to fetch proper information"
    }
}
