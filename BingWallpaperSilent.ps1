$ErrorActionPreference = 'Stop'

$logDir = Join-Path $env:LOCALAPPDATA 'BingWallpaperSilent'
New-Item -ItemType Directory -Path $logDir -Force | Out-Null
$logFile = Join-Path $logDir 'run.log'

function Write-Log {
    param([string]$Message)
    $time = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    Add-Content -Path $logFile -Value "[$time] $Message"
}

try {
    Write-Log 'Start task.'

    Add-Type @"
using System.Runtime.InteropServices;
public class Wallpaper {
    [DllImport("user32.dll", CharSet=CharSet.Auto)]
    public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
}
"@

    $pictures = [Environment]::GetFolderPath('MyPictures')
    $downloadDir = Join-Path $pictures 'BingWallpapers'
    New-Item -ItemType Directory -Path $downloadDir -Force | Out-Null

    function Get-SafeFileName {
        param([string]$Name)
        $invalidChars = [System.IO.Path]::GetInvalidFileNameChars()
        foreach ($ch in $invalidChars) {
            $Name = $Name.Replace($ch, '_')
        }
        return ($Name -replace '\s+', ' ').Trim()
    }

    $baseUrl = 'https://www.bing.com'
    $jsonUrl = 'https://www.bing.com/HPImageArchive.aspx?format=js&idx=0&n=1&mkt=zh-CN&uhd=1&uhdwidth=3840&uhdheight=2160'

    Write-Log "Pictures path: $pictures"
    Write-Log "Download dir: $downloadDir"
    Write-Log 'Requesting Bing metadata...'

    $response = Invoke-RestMethod -Uri $jsonUrl -TimeoutSec 30
    if (-not $response.images -or $response.images.Count -eq 0) {
        throw 'No image info returned from Bing.'
    }

    $img = $response.images[0]
    $title = if ($img.title) { $img.title } else { 'BingWallpaper' }
    $safeTitle = Get-SafeFileName $title
    $fileName = "{0}_{1}.jpg" -f $img.enddate, $safeTitle
    $imageUrl = if ($img.url -match '^https?://') { $img.url } else { "$baseUrl$($img.url)" }
    $imagePath = Join-Path $downloadDir $fileName

    Write-Log "Image URL: $imageUrl"
    Write-Log "Target file: $imagePath"

    if (-not (Test-Path $imagePath)) {
        Write-Log "Downloading: $fileName"
        Invoke-WebRequest -Uri $imageUrl -OutFile $imagePath -TimeoutSec 60
    } else {
        Write-Log "Already exists: $fileName"
    }

    if (-not (Test-Path $imagePath)) {
        throw "Image download failed: $imagePath"
    }

    [void][Wallpaper]::SystemParametersInfo(20, 0, $imagePath, 3)
    Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name Wallpaper -Value $imagePath -ErrorAction SilentlyContinue
    Write-Log "Wallpaper updated: $imagePath"

    Get-ChildItem -Path $downloadDir -Filter '*.jpg' -File |
        Sort-Object LastWriteTime -Descending |
        Select-Object -Skip 30 |
        Remove-Item -Force -ErrorAction SilentlyContinue

    Write-Log 'Task completed successfully.'
}
catch {
    Write-Log "ERROR: $($_.Exception.Message)"
    exit 1
}
