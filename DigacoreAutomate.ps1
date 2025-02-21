# Define paths
$logFile = "C:\Digacore\script-log.txt"
$tempFolder = [System.IO.Path]::GetTempPath()
$extractPath = "C:\Digacore"
$bgInfoSource = "C:\Digacore\BGInfo"
$bgInfoDest = "C:\Program Files\BGInfo"
$shortcutSource = "C:\Digacore\BGInfo\config - Shortcut.lnk"
$startupFolder = "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp"
$backgroundImage = "$bgInfoDest\DG_Custombackground.jpg"
$zipUrl = "https://raw.githubusercontent.com/jtrunnell-DTC/Test-Files/main/Files.zip"
$zipPath = "$tempFolder\files.zip"

# List of apps to install
$apps = @(
    "Google.Chrome",
    "Mozilla.Firefox",
    "Microsoft.PowerShell",
    "Microsoft.OneDrive"

)

# List of apps to remove (decrapify Windows)
$removeApps = @(
    "Microsoft.Office.Desktop",
    "Microsoft.OfficeHub",
    "Microsoft.MicrosoftOfficeHub",
    "Microsoft.GetHelp",
    "Microsoft.Getstarted",
    "Microsoft.3DBuilder",
    "Microsoft.3DViewer",
    "Microsoft.BingWeather",
    "Microsoft.MicrosoftSolitaireCollection",
    "Microsoft.XboxApp",
    "Microsoft.XboxGameOverlay",
    "Microsoft.XboxGamingOverlay",
    "Microsoft.XboxIdentityProvider",
    "Microsoft.XboxSpeechToTextOverlay",
    "Microsoft.BingNews",
    "Microsoft.Messaging",
    "Microsoft.MicrosoftStickyNotes",
    "Microsoft.MixedReality.Portal",
    "Microsoft.OneConnect",
    "Microsoft.People",
    "Microsoft.Print3D",
    "Microsoft.SkypeApp",
    "Microsoft.StorePurchaseApp",
    "Microsoft.Wallet",
    "Microsoft.WindowsAlarms",
    "Microsoft.WindowsCamera",
    "Microsoft.WindowsFeedbackHub",
    "Microsoft.WindowsMaps",
    "Microsoft.WindowsSoundRecorder",
    "Microsoft.YourPhone",
    "Microsoft.ZuneMusic",
    "Microsoft.ZuneVideo"
)

# Ensure the log directory exists
if (-not (Test-Path -Path $logFile)) {
    New-Item -ItemType File -Path $logFile -Force | Out-Null
}

# Logging function
Function Write-Log {
    param ([string]$message)
    Add-Content -Path $logFile -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $message"
}

Write-Log "Starting Intune Customization Script"

# Function to install applications
Function Install-App {
    param ([string]$appId)
    try {
        winget install -e --id $appId --silent --accept-package-agreements --accept-source-agreements
        Write-Log "Installed ${appId} successfully."
    } catch {
        Write-Log "Failed to install ${appId}: $_"
    }
}

foreach ($app in $apps) {
    Install-App -appId $app
}

Write-Log "Application installations complete."

# Remove Bloatware
Function Remove-Bloatware {
    foreach ($app in $bloatware) {
        try {
            Get-AppxPackage -Name $app | Remove-AppxPackage
            Write-Log "Removed $app successfully."
        } catch {
            Write-Log "Failed to remove $app: $_"
        }
    }
}

Remove-Bloatware
Write-Log "Bloatware removal complete."

# Create directories
New-Item -ItemType Directory -Path $extractPath -Force | Out-Null
Write-Log "Created directory: $extractPath"

# Download and extract files
try {
    Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath -ErrorAction Stop
    Write-Log "Downloaded zip file successfully."
    Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force
    Write-Log "Extracted zip file contents successfully."
    Remove-Item -Path $zipPath -Force
} catch {
    Write-Log "File download/extraction failed: $_"
    exit 1
}

# Copy BGInfo to Program Files
try {
    Copy-Item -Path $bgInfoSource -Destination $bgInfoDest -Recurse -Force
    Write-Log "Copied BGInfo folder successfully."
} catch {
    Write-Log "Failed to copy BGInfo folder: $_"
    exit 1
}

# Move shortcut to startup folder
try {
    Move-Item -Path $shortcutSource -Destination "$startupFolder\config - Shortcut.lnk" -Force
    Write-Log "Moved shortcut successfully."
} catch {
    Write-Log "Failed to move shortcut: $_"
    exit 1
}

# Refresh BGInfo
Function Refresh-BGInfo {
    try {
        $bgInfoExecutable = "C:\Program Files\BGInfo\BGInfo.exe"
        $bgInfoConfig = "C:\Digacore\BGInfo\BGInfoConfig.bgi"
        Start-Process -FilePath $bgInfoExecutable -ArgumentList "$bgInfoConfig /timer:0"
        Write-Log "BGInfo refreshed successfully."
    } catch {
        Write-Log "Failed to refresh BGInfo: $_"
    }
}

Refresh-BGInfo

# Set wallpaper for the current user
Function Refresh-Wallpaper {
    $regPath = "HKCU:\Control Panel\Desktop"

    if (Test-Path $backgroundImage) {
        Set-ItemProperty -Path $regPath -Name Wallpaper -Value $backgroundImage
        Set-ItemProperty -Path $regPath -Name WallpaperStyle -Value 2 # Stretch mode
        Set-ItemProperty -Path $regPath -Name TileWallpaper -Value 0
        rundll32.exe user32.dll, UpdatePerUserSystemParameters
        Write-Log "Wallpaper refreshed successfully."
    } else {
        Write-Log "Wallpaper file not found: $backgroundImage"
    }
}

Refresh-Wallpaper

# Rename PC Script
Function Rename-PC {
    param ([string]$siteCode)

    $SerialNumber = (Get-WmiObject -Class Win32_BIOS).SerialNumber
    $SystemInfo = Get-WmiObject -Class Win32_ComputerSystem
    $Model = $SystemInfo.PCSystemType
    $IsVM = $SystemInfo.Model -match "Virtual|VMware|Hyper-V"

    if ($IsVM) {
        $pcType = "VM"
    } elseif ($Model -eq 2) {
        $pcType = "LT"
    } elseif ($Model -eq 3) {
        $pcType = "WS"
    } elseif ($Model -eq 4) {
        $pcType = "KS"
    } else {
        $pcType = "PC"
    }

    $NewPCName = "$siteCode-$pcType-$SerialNumber"

    if ($env:COMPUTERNAME -ne $NewPCName) {
        Write-Host "Renaming computer to $NewPCName..."
        Rename-Computer -NewName $NewPCName -Force
        Restart-Computer -Force
    } else {
        Write-Host "Computer name is already compliant. No changes needed."
    }
}

# Get site code from user
$siteCode = Read-Host -Prompt "Enter the 4-letter Site Code (ALL CAPS)"
Rename-PC -siteCode $siteCode

Write-Log "Customization script completed."
Start-Sleep -Seconds 15
Write-Log "Rebooting the computer..."
Restart-Computer -Force
