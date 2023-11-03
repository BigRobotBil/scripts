# TODO update this dumb thing to support if there's multiple GPUs
# this script's primary function to replace the 3D information in the DLLs doesn't actually work yet lmao

function fetchDrivers() {
    # Each GPU has an identifier, for example the 2080 Ti is 877
    # Each version of Windows has an identifier, for example Win10 64bit is 57
    # There's a toggle for DCH, either 0 or 1
    # https://gfwsl.geforce.com/services_toolkit/services/com/nvidia/services/AjaxDriverService.php?func=DriverManualLookup&pfid=877&osID=57&dch=1

}
function testDriverVersion($valid3DVisionDriverList, $currDriver)
{
    foreach ($driverNum in $valid3DVisionDriverList)
    {
        if ($driverNum -eq $currDriver) 
        { 
           return $true
        }
    }

    return $false
}

function checkIfFileHasPattern($path, $pattern) {
    # This method will just be for passing in a dll, and seeing if the proper hex edit is in there or not
    # https://devblogs.microsoft.com/scripting/use-powershell-and-regular-expressions-to-search-binary-data/
    $file = Get-Content -Encoding Byte $path
    $matches = $pattern.Matches($file)

    Write-Host "File '$path' has the following number of matches for '$pattern': $($matches.Count)"
}

# Get the current version of the driver
# https://www.reddit.com/r/PowerShell/comments/5uh5ou/getting_currently_installed_nvidia_gpu_driver/
$driver = Get-WmiObject win32_VideoController | Where-Object {$_.Name.contains("NVIDIA")}

# What this is doing (based on the reddit thread):
# Take the original DriverVersion, and replace all intances of '.' with nothing
# [-5..-1] is a Range statement (https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_operators?view=powershell-5.1#range-operator-) (https://learn.microsoft.com/en-us/powershell/scripting/learn/deep-dives/everything-about-arrays?view=powershell-7.3#special-index-tricks)
# When we get the range, everything's going to be spaced out, so join the result together via ''
# Since we want a period before the last two, insert a period at index 3
$driverVersion = ($driver.DriverVersion.Replace('.', '')[-5..-1] -join '').Insert(3, '.')

Write-Host "Detected Driver Version: $driverVersion.  Detected GPU: $($driver.Name)"

# Determine if this is a valid driver version for 3D Vision
# the output of the $driverVersion will be a string
$valid3DVisionDriverList = New-Object -TypeName "System.Collections.ArrayList"
$valid3DVisionDriverList.Add("452.06")
$valid3DVisionDriverList.Add("425.31")

$isValidDriver = testDriverVersion $valid3DVisionDriverList $driverVersion

if ($isValidDriver) {
    Write-Host "3D Vision is supported in this driver version, congrats"
    # Detect if 3D is setup
    # # Have toggle
    # Detect if Driver Hack is enabled
    # https://www.mtbs3d.com/phpbb/viewtopic.php?t=23352
    # # Have toggle

    $nvwgf2umModdedPattern = [Regex] '\xB0\x08\xEB\x0C'
    $nvwgf2umOriginalPattern = [Regex] '\x83\xF8\x07\x0F\x87\xD3\x01\x00\x00\xFF\x24\x85'
    $nvwgf2umxModdedPattern = [Regex] '\xB0\x08\xEB\x05'
    $nvwgf2umxOriginalPattern = [Regex] '\x83\xF8\x07\x0F\x8F\x97\x01\x00\x00'
    checkIfFileHasPattern ".\nvidia\nvwgf2um_modified.dll" $nvwgf2umModdedPattern
    checkIfFileHasPattern ".\nvidia\nvwgf2um_modified.dll" $nvwgf2umOriginalPattern
    checkIfFileHasPattern ".\nvidia\nvwgf2um_orig.dll" $nvwgf2umModdedPattern
    checkIfFileHasPattern ".\nvidia\nvwgf2um_orig.dll" $nvwgf2umOriginalPattern
    checkIfFileHasPattern ".\nvidia\nvwgf2umx_modified.dll" $nvwgf2umModdedPattern
    checkIfFileHasPattern ".\nvidia\nvwgf2umx_modified.dll" $nvwgf2umOriginalPattern
    checkIfFileHasPattern ".\nvidia\nvwgf2umx_orig.dll" $nvwgf2umxModdedPattern
    checkIfFileHasPattern ".\nvidia\nvwgf2umx_orig.dll" $nvwgf2umxOriginalPattern
    # C:\Windows\System32\DriverStore\FileRepository\nv_dispi.inf_amd64_b2dd7130a686a22f
} else {
    Write-Host "3D Vision is not supported in this driver version, get bent"
}