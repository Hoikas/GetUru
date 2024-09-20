#    This file is part of GetUru.
#
#    GetUru is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    GetUru is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with GetUru.  If not, see <http://www.gnu.org/licenses/>.

$DownloadDir = "$InstallDir/downloads"
$AssetsDir = "$InstallDir/downloads/moul-assets"
$ClientDir = "$InstallDir/client"
$ClientShortcutPath = "$InstallDir/Start Uru.lnk"

$GitDownloadURL = "https://github.com/git-for-windows/git/releases/download/v2.45.2.windows.1/MinGit-2.45.2-busybox-32-bit.zip"
$GitDownloadFilename = "MinGit-2.45.2-busybox-32-bit.zip"
$GitHash = "9e8ede5629d928f943909f0f3225b27716bdaa95018a3c6cf6276fbc99ee19da"
$GitPath = "cmd/git.exe"

$Client32DownloadURL = "https://github.com/H-uru/Plasma/releases/download/last-successful/plasma-windows-x86-internal-release.zip"
$Client32DownloadFilename = "plasma-windows-x86-internal-release.zip"
$Client64DownloadURL = "https://github.com/H-uru/Plasma/releases/download/last-successful/plasma-windows-x64-internal-release.zip"
$Client64DownloadFilename = "plasma-windows-x64-internal-release.zip"

$AssetsRevFile = "$DownloadDir/moul-assets.rev"

function Install-Program($cmd, $forcedl, $name, $url, $filename, $hash, $cmdpath) {
    Write-Host -ForegroundColor Cyan "Checking for $name..."
    if (!$forcedl) {
        try {
            $maybecmd = Get-Command $cmd
            Write-Host -ForegroundColor Green "... found $($maybecmd.Path)"
            return $maybecmd.Path
        } catch {
            # No worries, we'll handle not finding the command later.
        }
    }

    try {
        Push-Location $DownloadDir

        if (Test-Path $filename -PathType Leaf) {
            Write-Host -ForegroundColor Yellow "... already downloaded $filename"
        } else {
            Write-Host -ForegroundColor Cyan "... downloading $name"
            Invoke-WebRequest $url -OutFile $filename | Write-Output
            $filehash = $(Get-FileHash $filename).Hash
            if ($filehash -ne $hash) {
                Remove-Item $filename
                throw "Hash validation failure for $filename$newline`Expected: $hash$newline`Actual: $filehash";
            }
        }

        $zipname = (Get-Item $filename).BaseName
        $progpath = "$zipname/$cmdpath"
        if (Test-Path $progpath -PathType Leaf) {
            Write-Host -ForegroundColor Green "... found $progpath"
            return "$(Get-Location)/$progpath"
        } elseif (Test-Path $zipname -PathType Container) {
            Write-Host -ForegroundColor Yellow "... already extracted $zipname but the program is missing? Deleting..."
            Remove-Item $zipname -Recurse
        }

        Expand-Archive -Path $filename -DestinationPath $zipname | Write-Output
        return "$(Get-Location)/$progpath"
    } finally {
        Pop-Location
    }
}


function New-Shortcut($Path, $Target, $Arguments) {
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($Path)
    $shortcut.TargetPath = $Target
    $shortcut.Arguments = $Arguments
    $shortcut.WorkingDirectory = $(Get-Item $Target).Directory.FullName
    $shortcut.Save()
}

function Move-DirSafe($Path, $Destination) {
    if (!(Test-Path -PathType Container -Path $Destination)) {
        New-Item -ItemType Directory -Path $Destination | Out-Null
    }
    Move-Item -Path $Path -Destination $Destination -Force
}
