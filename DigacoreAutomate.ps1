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
$pcName = "XXXX"
$LocalUsername = "DTC"
$LocalPassword = "Tuv1a=F@ll3n"  # Change this as needed

# Add or remove apps https://winstall.app/ to see proper names
$apps = @(
    "Google.Chrome",
    "Mozilla.Firefox",
    "Microsoft.PowerShell"
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
    param (
        [string]$appId
    )
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

# Create directories if they don't exist
New-Item -ItemType Directory -Path $extractPath -Force | Out-Null
Write-Log "Created directory: $extractPath"

# Download the zip file using Invoke-WebRequest
try {
    Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath -ErrorAction Stop
    Write-Log "Downloaded zip file successfully."
} catch {
    Write-Log "Failed to download the zip file: $_"
    exit 1
}

# Extract zip contents directly to the desired folder (C:\Digacore)
try {
    Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force
    Write-Log "Extracted zip file contents successfully."
} catch {
    Write-Log "Failed to extract the zip file: $_"
    exit 1
}

# Cleanup: Remove the zip file after extraction
try {
    Remove-Item -Path $zipPath -Force
    Write-Log "Removed the downloaded zip file: $zipPath"
} catch {
    Write-Log "Failed to remove the zip file: $_"
}

# Copy BGInfo folder to Program Files
try {
    Copy-Item -Path $bgInfoSource -Destination $bgInfoDest -Recurse -Force
    Write-Log "Copied BGInfo folder successfully."
} catch {
    Write-Log "Failed to copy BGInfo folder: $_"
    exit 1
}

# Move shortcut to startup folder with error handling
try {
    Move-Item -Path $shortcutSource -Destination "$startupFolder\config - Shortcut.lnk" -Force
    Write-Log "Moved shortcut successfully."
} catch {
    Write-Log "Failed to move shortcut: $_"
    exit 1
}

# Set wallpaper for the current user
Function Refresh-Wallpaper {
    $regPath = "HKCU:\Control Panel\Desktop"

    # Ensure the wallpaper file exists
    if (Test-Path $backgroundImage) {
        # Set wallpaper in user registry
        Set-ItemProperty -Path $regPath -Name Wallpaper -Value $backgroundImage
        Set-ItemProperty -Path $regPath -Name WallpaperStyle -Value 2 # Stretch mode
        Set-ItemProperty -Path $regPath -Name TileWallpaper -Value 0

        # Force Windows to refresh wallpaper
        rundll32.exe user32.dll, UpdatePerUserSystemParameters

        Write-Log "Wallpaper refreshed successfully."
    } else {
        Write-Log "Wallpaper file not found: $backgroundImage"
    }
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

# Call the functions to refresh the wallpaper and BGInfo
Refresh-Wallpaper
Refresh-BGInfo

# Function to create a local user
Function Create-LocalUser {
    param (
        [string]$username,
        [string]$password
    )
    
    try {
        # Convert password to SecureString
        $securePassword = ConvertTo-SecureString -String $password -AsPlainText -Force

        # Check if the user already exists
        if (Get-LocalUser -Name $username -ErrorAction SilentlyContinue) {
            Write-Host "User '$username' already exists. Skipping creation."
        } else {
            # Create the local user
            New-LocalUser -Name $username -Password $securePassword -FullName "$username User" -Description "Local user created by script"
            Write-Host "Created local user: $username successfully."

            # Add user to Administrators group
            Add-LocalGroupMember -Group "Administrators" -Member $username
            Write-Host "Added $username to Administrators group successfully."
        }
    } catch {
        Write-Host "Failed to create local user '$username': $_"
    }
}

# Call function with variables
Create-LocalUser -username $LocalUsername -password $LocalPassword

# Rename PC Script
powershell -noexit -ExecutionPolicy Bypass -File RenamePC.ps1

# Function to check if the computer name follows the required pattern
function IsNameCompliant($computerName) {
    $pattern = "^" + [regex]::Escape($pcName.Substring(0, 4)) + "-[A-Z]{2}-[A-Za-z0-9]+$"
    return ($computerName -match $pattern)
}

# Get system details
$SerialNumber = (Get-WmiObject -Class Win32_BIOS).SerialNumber
$SystemInfo = Get-WmiObject -Class Win32_ComputerSystem
$Model = $SystemInfo.PCSystemType
$Manufacturer = $SystemInfo.Manufacturer
$IsVM = $SystemInfo.Model -match "Virtual|VMware|Hyper-V"

# Prompt the user for the Site Code
$pcName = Read-Host -Prompt "Please enter the Site Code (4 Letters All Caps)"

# Determine system type
if ($IsVM) {
    $pcType = "VM"
} elseif ($Model -eq 2) {
    $pcType = "LT"  # Laptop
} elseif ($Model -eq 3) {
    $pcType = "WS"  # Workstation/Desktop
} elseif ($Model -eq 4) {
    $pcType = "KS" # All-in-One
} else {
    $pcType = "PC"  # Default to PC if unknown
}

# Generate new PC name
$NewPCName = "$pcName-$pcType-$SerialNumber"

# Check if renaming is necessary
if (-not (IsNameCompliant($env:COMPUTERNAME))) {
    Write-Host "Renaming computer to $NewPCName..."
    Rename-Computer -NewName $NewPCName -Force
    Restart-Computer -Force
} else {
    Write-Host "Computer name is already compliant. No changes needed."
    exit
}

Write-Log "Customization and decrapification script completed."
Start-Sleep -Seconds 15
Write-Log "Rebooting the computer..."
Restart-Computer -Force