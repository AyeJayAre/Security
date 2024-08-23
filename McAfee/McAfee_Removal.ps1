### McAfee Removal
# Requires: Windows, PowerShell 3.0+
# This script executes the following steps to remove all McAfee applicaitons and files from a 
# Windows host, checks for common reasons the removal will fail, attempts to remediate common 
# problems, and inform the user if steps fail for manual intervention.
#   Confirms the script is running in the Administrator context
#   Checks for available disk space, clears temp files if > 90%
#   Terminates all McAfee processes running 
#   Configures the McAfeeFramework service to restart on failure in order to accept uninstall commands
#   Checks the status of the Windows Installer service and restarts it if it isn't running
#   Checks for McAfee Directories on the host 
#   Checks the registry for installed McAfee products
#   If McAfee products are detected run the command to disable removal protection
#   If McAfee products are detected attempt to uninstall them via msiexec
#   Attempt to uninstall all remaining McAfee products with WMIC
#   Attempt to remove all orhpaned McAfee directories
#   Check host for remaining McAfee components and output to console

# Check if the script is running with admin privileges
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
if (-not $isAdmin) {
    Write-Output "This script must be run as an Administrator. Please re-run this script as an Administrator."
    return
} else {
    Write-Output "This script is running with administrative privileges."
}

# Get disk space info for the C: drive
$drive = Get-PSDrive C

# Calculate disk space consumed
$freeSpaceGB = $drive.Free / 1GB
$totalSpaceGB = $drive.Used + $freeSpaceGB
$usedSpaceGB = $totalSpaceGB - $freeSpaceGB
$usedSpacePercent = ($usedSpaceGB / $totalSpaceGB) * 100

# Output disk space consumed
Write-Output "Disk space consumed on $($drive.Name):"
Write-Output "Total: ${totalSpaceGB}GB"
Write-Output "Used: ${usedSpaceGB}GB (${usedSpacePercent}%)"

# Check if drive usage is above 90%
if ($usedSpacePercent -gt 90) {
    Write-Output "Drive usage is above 90%. Deleting temp files..."

    # System temp files
    Remove-Item -Path 'C:\Windows\Temp\*.*' -Recurse -Force -ErrorAction SilentlyContinue

    # User temp files
    Remove-Item -Path "$env:TEMP\*.*" -Recurse -Force -ErrorAction SilentlyContinue

    # Get total drive usage after deleting temp files
    $drive = Get-WmiObject -Class Win32_LogicalDisk -Filter "DeviceID='C:'"
    $totalSpace = [math]::Round($drive.Size / 1GB, 2)
    $freeSpace = [math]::Round($drive.FreeSpace / 1GB, 2)
    $usedSpace = $totalSpace - $freeSpace
    $usedSpacePercent = $usedSpace / $totalSpace * 100

    if ($usedSpacePercent -gt 95) {
        Write-Output "Temp files deletion completed. Drive usage is now at $usedSpacePercent%. WARNING: Disk space is still above 95%."
    } else {
        Write-Output "Temp files deletion completed. Drive usage is now at $usedSpacePercent%."
    }
} else {
    Write-Output "Drive usage is under 90%. Temp files will not be deleted. Drive usage is currently at $usedSpacePercent%."
}

# End all McAfee processes running in the background
Write-Output "Ending all McAfee processes running in the background..."
Get-Process | Where-Object { $_.Name -like "*McAfee*" } | ForEach-Object {
    $processName = $_.Name
    Write-Output "Ending $processName..."
    try {
        Stop-Process -Name $processName -Force -ErrorAction Stop
        Write-Output "Successfully ended $processName."
    } catch {
        Write-Output "FAILED to end $processName."
    }
}

# Configuring McAfee Framework service to restart on failure
Write-Output "Configuring McAfee Framework service to restart on failure..."

$service = Get-Service -Name 'McAfeeFramework' -ErrorAction SilentlyContinue  
  
if ($service) {  
    sc.exe failure $service.Name reset= 0 actions= restart/60000/restart/60000/restart/60000
    Write-Output "McAfee Framework service configured to restart on failure."
} else {  
    Write-Output "Cannot find any service with service name 'McAfeeFramework'. Skipping configuration."
}

# Check if the installer service is running, skip restarting it if so
Write-Output "Checking the installer service..."
$serviceStatus = Get-Service -Name msiserver -ErrorAction SilentlyContinue

if ($serviceStatus.Status -eq 'Running') {
    Write-Output "The installer service is already running, skipping the restart step."
} else {
    # Restart the installer service
    Write-Output "Instaler is not running, restarting the installer service."
    try {
        Restart-Service -Name msiserver -ErrorAction Stop
    } catch {
        Write-Output "FAILED to restart the installer service, but script will continue."
    }
}

# Define directories to search
$directoriesToSearch = @(
    "C:\Program Files",
    "C:\Program Files (x86)",
    "C:\ProgramData"
)  

# Search for McAfee directories
Write-Output "Searching for McAfee directories..."
$mcafeeDirectories = @()
foreach ($directory in $directoriesToSearch) {
    if (Test-Path $directory) {
        Get-ChildItem -Path $directory -Directory -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like "*McAfee*" } |
        ForEach-Object { $mcafeeDirectories += $_.FullName }
    }
}
if ($mcafeeDirectories) {
    Write-Output "McAfee directories found BEFORE attempting uninstall:"
    $mcafeeDirectories | ForEach-Object { Write-Output $_ }
} else {
    Write-Output "No McAfee directories found."
}

# Check the registry for McAfee products
Write-Output "Checking the registry for McAfee products..."
$registryPaths = @(
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall",
    "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
)

$mcafeeRegistryEntries = @()
foreach ($path in $registryPaths) {
    Get-ChildItem -Path $path |
    ForEach-Object { Get-ItemProperty -Path $_.PsPath } |
    Where-Object { $_.DisplayName -like "*McAfee*" } |
    ForEach-Object { $mcafeeRegistryEntries += $_.DisplayName }
}
if ($mcafeeRegistryEntries) {
    Write-Output "McAfee products found in registry BEFORE attempting uninstall:"
    $mcafeeRegistryEntries | ForEach-Object { Write-Output $_ }
} else {
    Write-Output "No McAfee products found in the registry."
}

# If McAfee products are detected run the command to disable removal protection
if ($mcafeeProducts) {  
    Write-Output "Attempting Agent removal command"    
      
    # Check if frminst.exe in Agent folder exists    
    $agentPaths = @(  
        'C:\Program Files\McAfee\Agent\frminst.exe',  
        'C:\Program Files (x86)\McAfee\Agent\frminst.exe'  
    )  
    $commonFrameworkPaths = @(  
        'C:\Program Files\McAfee\Common Framework\frminst.exe',  
        'C:\Program Files (x86)\McAfee\Common Framework\frminst.exe'  
    )  
  
    $frminstPath = $null  
  
    foreach ($path in $agentPaths) {  
        if (Test-Path -Path $path) {  
            $frminstPath = $path  
            break  
        }  
    }  
  
    if ($frminstPath) {  
        Write-Host "Found $frminstPath. Running it..."  
        Start-Process -FilePath $frminstPath -ArgumentList '/remove=agent' -Wait -NoNewWindow  
        Start-Process -FilePath $frminstPath -ArgumentList '/forceuninstall' -Wait -NoNewWindow  
    } else {  
        Write-Host "frminst.exe not found in Agent folder."  
    }  
  
    $frminstPath = $null  
  
    foreach ($path in $commonFrameworkPaths) {  
        if (Test-Path -Path $path) {  
            $frminstPath = $path  
            break  
        }  
    }  
  
    if ($frminstPath) {  
        Write-Host "Found $frminstPath. Running it..."  
        Start-Process -FilePath $frminstPath -ArgumentList '/remove=agent' -Wait -NoNewWindow  
        Start-Process -FilePath $frminstPath -ArgumentList '/forceuninstall' -Wait -NoNewWindow  
    } else {  
        Write-Host "frminst.exe not found in Common Framework folder."  
    }  
} else {  
    Write-Output "McAfee Agent removal command not run, frminst.exe not found."  
}  


# Define the uninstall commands for each McAfee product
$uninstallCommands = @{
    "McAfee Endpoint Security Adaptive Threat Protection" = @("msiexec /x {377DA1C7-79DE-4102-8DB7-5C2296A3E960} /q")
    "McAfee Endpoint Security Web Control" = @("msiexec /x {5974413A-8D95-4D64-B9EE-40DF28186445} /q")
    "McAfee Endpoint Security Threat Prevention" = @("msiexec /x {CE15D1B6-19B6-4D4D-8F43-CF5D2C3356FF} /q",
                                                    "msiexec /x {820D7600-089E-486B-860F-279B8119A893} /q")
    "McAfee Data Exchange Layer for MA" = @("msiexec /x {4DCFB3A9-FFFB-4A84-A113-B02356070CA4} /q",
                                            "msiexec /x {434973D4-3060-4824-B054-4FF850B0E80E} /q",
                                            "msiexec /x {A5C434EE-8FA2-4446-BB99-97A72AA6BA90} /q")
    "McAfee Endpoint Security Platform" = @("msiexec /x {B16DE18D-4D5D-45F8-92BD-8DC17225AFD8} /q")
    "McAfee VirusScan Enterprise" = @("msiexec /x {CE15D1B6-19B6-4D4D-8F43-CF5D2C3356FF} /q")
    "McAfee Solidifier" = @("msiexec /x {432DB9E4-6388-432F-9ADB-61E8782F4593} /q")
    "McAfee Agent 5.7" = @("c:\Program Files\McAfee\Agent\x86\frminst.exe /forceuninstall")
    "McAfee Agent 5.3" = @("cc:\Program Files\McAfee\Common Framework\x86\frminst.exe /forceuninstall")
    "McAfee Agent MSI" = @("msiexec /x {F80C7274-F75D-4754-BD1C-E8204A6EB4BE} /q",
                            "msiexec /x {434973D4-3060-4824-B054-4FF850B0E80E} /q",
                            "msiexec /x {4C3A8CA3-B83A-477C-AAB3-AABE42E62DD2} /q")
}
  
# If McAfee products are detected attempt to uninstall them via msiexec
if ($mcafeeProducts) {
    Write-Output "Uninstalling McAfee products..."
    $mcafeeProducts | ForEach-Object {
        $productName = $_.Name
        if ($uninstallCommands.ContainsKey($productName)) {
            $uninstallCommandsForProduct = $uninstallCommands[$productName]
            foreach ($uninstallCommand in $uninstallCommandsForProduct) {
                Write-Output "Uninstalling $productName with command $uninstallCommand..."
                try {
                    $process = Start-Process -FilePath 'cmd.exe' -ArgumentList "/c $uninstallCommand" -Wait -PassThru -NoNewWindow -RedirectStandardOutput stdout.txt -RedirectStandardError stderr.txt
                    if ($process.ExitCode -ne 0) {
                        Write-Output "Error uninstalling $productName. Exit code: $($process.ExitCode)."
                        Write-Output "StdOut: $(Get-Content stdout.txt)"
                        Write-Output "StdErr: $(Get-Content stderr.txt)"
                    } else {
                        Write-Output "Successfully uninstalled $productName."
                    }
                } catch {
                    Write-Output "Error uninstalling $productName : $_"
                }
            }
        } else {
            Write-Output "No uninstall command found for $productName"
        }
    }
} else {
    Write-Output "No McAfee products found."
}

# Attempt to uninstall all remaining McAfee products with WMIC
Write-Output "Running WMIC to catch any remaining McAfee products..."

$wmicCommand = "wmic /node:$env:COMPUTERNAME product WHERE Vendor='McAfee, Inc.' call uninstall /nointeractive"

try {
    cmd /c "$wmicCommand 2>McAfeeWMICError.log"

    if (Test-Path "McAfeeWMICError.log") {
        Write-Output "Error running WMIC command. See McAfeeWMICError.log for details."
        Remove-Item "McAfeeWMICError.log"
    } else {
        Write-Output "Remaining McAfee products uninstalled." 
    }
} catch {
    Write-Output "Error running WMIC command: $_"
}

# After all uninstall attempts, attempt to remove McAfee directories
Write-Output "Removing McAfee directories..."
foreach ($directory in $mcafeeDirectories) {
    Write-Output "Removing $directory..."
    try {
        Remove-Item -Path $directory -Recurse -Force -ErrorAction Stop
        Write-Output "Successfully removed $directory."
    } catch {
        Write-Output "FAILED to remove $directory."
    }
}

Write-Output "Running post uninstall attempt checks..."

# Get a list of all installed programs
$installedPrograms = Get-WmiObject -Class Win32_Product

# Filter for McAfee products
$mcafeeProducts = $installedPrograms | Where-Object { $_.Name -like "*McAfee*" }

# Search for McAfee products remaining in Programs/Features after removal attemps
if ($mcafeeProducts) {
    Write-Output "McAfee products found in Programs and features AFTER attempting uninstall:"
    $mcafeeProducts | ForEach-Object { Write-Output $_.Name }
} else {
    Write-Output "No McAfee products found in Programs and features."
}

# Search for McAfee directories for files remaining after removal attemps
Write-Output "Searching for McAfee directories..."
$mcafeeDirectories = @()
foreach ($directory in $directoriesToSearch) {
    if (Test-Path $directory) {
        Get-ChildItem -Path $directory -Directory -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like "*McAfee*" } |
        ForEach-Object { $mcafeeDirectories += $_.FullName }
    }
}
if ($mcafeeDirectories) {
    Write-Output "McAfee directories found AFTER attempting uninstall:"
    $mcafeeDirectories | ForEach-Object { Write-Output $_ }
} else {
    Write-Output "No McAfee directories found."
}

# Check the registry for McAfee products remaining after removal attemps
Write-Output "Checking the registry for McAfee products..."
$registryPaths = @(
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall",
    "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
)
$mcafeeRegistryEntries = @()
foreach ($path in $registryPaths) {
    Get-ChildItem -Path $path |
    ForEach-Object { Get-ItemProperty -Path $_.PsPath } |
    Where-Object { $_.DisplayName -like "*McAfee*" } |
    ForEach-Object { $mcafeeRegistryEntries += $_.DisplayName }
}  
if ($mcafeeRegistryEntries) {
    Write-Output "McAfee products found in registry AFTER attempting uninstall:"
    $mcafeeRegistryEntries | ForEach-Object { Write-Output $_ }
} else {
    Write-Output "No McAfee products found in the registry."
}
Write-Output "Script complete, review output to see what McAfee products remain."
