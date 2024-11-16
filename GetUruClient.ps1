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

param(
    [string]$InstallDir = "$(Get-Location)",

    [switch]$Destiny,

    [switch]$ForceMinGit,

    [switch]$ForceLocalLfs,

    [switch]$Force32Bit,

    [switch]$Clean
)

# Enable for prod
$ErrorActionPreference = "Stop"

# Windows PowerShell (version 5.1 and lower) are really slow to display
# progress bars. So, disable them. The batch file will help us with this
# by running PowerShell Core (versions 6+), if available.
if ($PSVersionTable.PSVersion.Major -le 5) {
    $ProgressPreference = "SilentlyContinue"
}

# Pull in common definitions and functions.
Import-Module -Force "$PSScriptRoot/Common.ps1"

# Decide whether or not we should use the 32 or 64 bit clients.
if ($Force32Bit -or ($Env:PROCESSOR_ARCHITECTURE -eq "X86")) {
    Write-Host -ForegroundColor Yellow "Selecting 32-bit Uru Client..."
    $ClientDownloadFilename = $Client32DownloadFilename
    $ClientDownloadURL = $Client32DownloadURL
} elseif ($Env:PROCESSOR_ARCHITECTURE -eq "AMD64") {
    Write-Host -ForegroundColor Yellow "Selecting 64-bit Uru Client..."
    $ClientDownloadFilename = $Client64DownloadFilename
    $ClientDownloadURL = $Client64DownloadURL
} else {
    throw "Unsupported processor architecture $Env:PROCESSOR_ARCHITECTURE"
}

# Bombs away!
if ($Clean) {
    Write-Host -ForegroundColor Yellow "Cleaning..."
    if (Test-Path -PathType Container -Path $ClientDir) {
        Remove-Item $ClientDir -Recurse -Force | Out-Null
    }
    if (Test-Path -PathType Container -Path $DownloadDir) {
        Remove-Item $DownloadDir -Recurse -Force | Out-Null
    }
}

# Prepare output directories before we get started.
if (!(Test-Path -Path  $InstallDir -PathType Container)) {
    throw "The specified install directory '$InstallDir' does not exist!"
}
if (Test-Path -Path $DownloadDir -PathType Leaf) {
    throw "Install directory failed validation!"
}
if (Test-Path -Path $AssetsDir -PathType Leaf) {
    throw "Install directory failed validation!"
}
if (!(Test-Path -Path $DownloadDir -PathType Container)) {
    New-Item -ItemType Directory -Path $DownloadDir | Out-Null
}

# The goal here is to *install* Uru. While we will be using git to facilitate acquiring
# files, we don't actually care about maintaining a copy of the repos themselves. So,
# if they already exist, nuke them. An potential improvement would be to let the
# empty sparse checkout remain behind and check for updates as needed.
if (Test-Path -Path $AssetsDir -PathType Container) {
    Write-Host -ForegroundColor Yellow "Deleting stale game assets directory $AssetsDir"
    Remove-Item -Force -Recurse -Path $AssetsDir | Out-Null
}

# Check for git. If we don't have git installed, then we need to download it.
$GitExe = Install-Program "git" $ForceMinGit "Git" $GitDownloadURL $GitDownloadFilename $GitHash $GitPath
$GitLfsExe = Install-Program "git-lfs" $ForceLocalLFS "Git-LFS" $GitLfsDownloadURL $GitLfsDownloadFilename $GitLfsHash $GitLfsPath

# Download the latest game client.
$ClientZipPath = "$DownloadDir/$ClientDownloadFilename"
if (Test-Path -Path $ClientZipPath -PathType Leaf) {
    Write-Host -ForegroundColor Yellow "Deleting stale Plasma download $((Get-Item $ClientZipPath).BaseName)..."
    Remove-Item $ClientZipPath | Out-Null
}

Write-Host -ForegroundColor Cyan "Downloading Plasma from $ClientDownloadURL..."
Invoke-WebRequest $ClientDownloadURL -OutFile $ClientZipPath
if (!(Test-Path -Path $ClientDir -PathType Container)) {
    New-Item -ItemType Directory $ClientDir | Out-Null
}

$ClientUnzipPath = "$DownloadDir/$((Get-Item $ClientZipPath).BaseName)"
if (Test-Path -Path $ClientUnzipPath -PathType Container) {
    Write-Host -ForegroundColor Cyan "Removing stale Plasma directory $ClientUnzipPath..."
    Remove-Item $ClientUnzipPath -Recurse | Out-Null
}

Expand-Archive -Path $ClientZipPath -DestinationPath $ClientUnzipPath -Force

# Copy only the client files over
Write-Host -ForegroundColor Cyan "Copying game client..."
Copy-Item -Path "$ClientUnzipPath/client/*" -Destination $ClientDir -Recurse -Force
Write-Host -ForegroundColor Green "... game client copied to $ClientDir"

# Grab the assets
Write-Host -ForegroundColor Cyan "Updating game assets..."
&$GitExe clone "https://github.com/H-uru/moul-assets.git" --no-checkout $AssetsDir --depth 1
try {
    Push-Location $AssetsDir
    $OldPath = $Env:PATH

    # Ensure that git-lfs (the one we care about) is on the PATH.
    $Env:PATH = "$(Split-Path -Parent -Path $GitLfsExe);$Env:PATH"

    # Before we check out (read: download) all of the assets, compare the HEAD revision with the last
    # revision that we fetched. Only checkout if the revision is different.
    $CurrAssetsRev = &$GitExe rev-parse HEAD
    if (Test-Path -PathType Leaf -Path $AssetsRevFile) {
        $PrevAssetsRev = Get-Content $AssetsRevFile
    } else {
        $PrevAssetsRev = "(none)"
    }

    Write-Host -ForegroundColor Yellow "Comparing assets repository revisions..."
    Write-Host -ForegroundColor Yellow "... Latest revision: $CurrAssetsRev"
    Write-Host -ForegroundColor Yellow "... Previous revision: $PrevAssetsRev"

    if ($CurrAssetsRev -ne $PrevAssetsRev) {
        Write-Host -ForegroundColor Cyan "... downloading new game assets revision..."
        &$GitExe lfs install --local
        &$GitExe sparse-checkout init
        &$GitExe sparse-checkout set compiled/avi compiled/dat compiled/sfx
        &$GitExe checkout
        Write-Host -ForegroundColor Green "... downloaded game assets to $AssetsDir"

        # Move assets from the git repo into the client directory. Again, we don't care about
        # a repository - we just want to install... Well, we would *like* to move. Unfortunately,
        # the Move-Item cmdlet chokes on subfolders. So, we move the folders manually.
        Write-Host -ForegroundColor Cyan "... installing game assets"
        Move-DirSafe -Path "$AssetsDir/compiled/avi/*" -Destination "$ClientDir/avi"
        Move-DirSafe -Path "$AssetsDir/compiled/dat/*" -Destination "$ClientDir/dat"
        Move-DirSafe -Path "$AssetsDir/compiled/sfx/*" -Destination "$ClientDir/sfx"

        # Cache the assets revision so we don't have to keep redownloading.
        Out-File -FilePath $AssetsRevFile -InputObject $CurrAssetsRev
    } else {
        Write-Host -ForegroundColor Green "... game assets already up-to-date!"
    }
} finally {
    $Env:PATH = $OldPath
    Pop-Location
}

# No need to keep the assets repo around, so clean it up.
Write-Host -ForegroundColor Cyan "Cleaning up..."
Remove-Item $AssetsDir -Recurse -Force | Out-Null

Write-Host -ForegroundColor Cyan "Preparing client..."
if ($Destiny) {
    Copy-Item -Path "$PSScriptRoot/server_destiny.ini" -Destination "$ClientDir/server.ini"
}
if (!(Test-Path -PathType Leaf -Path $ClientShortcutPath)) {
    New-Shortcut -Path $ClientShortcutPath -Target "$ClientDir/plClient.exe" -Arguments "/LocalData"
}
