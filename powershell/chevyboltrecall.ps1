# I believe this no longer works, but here you go

function boltRecall($vin)
{
    $rootUrl = "https://www.chevrolet.com/electric/api/vin-recalls"
    Write-Host "Hitting " $rootUrl/$vin
    $res = Invoke-WebRequest $rootUrl/$vin | Select-Object -ExpandProperty Content | ConvertFrom-Json
    Write-Host "VIN: " $res.vin
    Write-Host "Make & Model: " $res.make $res.model

    $recalls = [System.Collections.ArrayList]::new()
    foreach ($i in $res.gfas)
    {
        [void]$recalls.Add($i.gfaNumber)
    }

    Write-Host "Recalls currently against " $res.vin ": " $recalls.Count

    #iterate through, see if any end in *881

    foreach ($i in $recalls)
    {
        Write-Host $i
        if ($i -eq "N212343881" -or $i -eq "N212345941")
        {
            Write-Host "- You should call a Chevy dealer for your battery recall"
        }

        if ($i -eq "N212343883")
        {
            Write-Host "- Software update that will, this time for sure, not let the car burst into flames"
        }
    }
}