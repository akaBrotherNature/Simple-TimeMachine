# ---------------------------------------------------------------------------- #
#                              Simple TimeMachine                              #
# ---------------------------------------------------------------------------- #



# --------------------------------- Settings --------------------------------- #

$folderToBackup = "$env:USERPROFILE\Documents\".TrimEnd("\")

$backupDestination = "S:\Backup\Simple TimeMachine\".TrimEnd("\")

$backupInterval = 10 # In minutes 

$retentionTime = 30 # Days to keep files



# ---------------------------- File change watcher --------------------------- #

[System.Collections.Generic.List[string]]$changedFiles = @()

$watcher = New-Object System.IO.FileSystemWatcher

$watcher.IncludeSubdirectories = $true

$watcher.Path = $folderToBackup
$watcher.EnableRaisingEvents = $true

$action =

{
    $path = $event.SourceEventArgs.FullPath
    $changedFiles.Add($path)

}

Register-ObjectEvent $watcher "Changed" -Action $action
Register-ObjectEvent $watcher "Created" -Action $action
Register-ObjectEvent $watcher "Renamed" -Action $action



# --------------------------- Backup on timed loop --------------------------- #

do {

    # Copy the logged changes
    [System.Collections.Generic.List[string]]$changedFilesToProcess = $changedFiles | Select-Object -Unique

    # Reset the changed files log
    [System.Collections.Generic.List[string]]$changedFiles = @()

    # Create contsainer for the list of files to backup
    [System.Collections.Generic.List[string]]$filesToBackup = @()


    foreach ($item in $changedFilesToProcess) {

        # Add item if it still exists and is a file
        if ((Test-Path -Path $item) -And (Test-Path -Path $item -PathType Leaf)) {

            $filesToBackup.Add($item)
        }
    
    }

    # Every x minutes, copy files from backup location with timestamp
    $timestamp = Get-Date -Format "yyyy_MM_dd HH_mm_ss"

    # Write to log
    "[$timestamp] - Starting backup" | Out-File -FilePath (Join-Path $backupDestination "Simple TimeMachine Log.txt") -Encoding utf8 -Append


    foreach ($file in $filesToBackup) {

        # New filename
        $newFilename = "$timestamp " + ($file | Split-Path -Leaf)
    
        # Backup path
        $backupPath = Join-Path $backupDestination (($file | Split-Path -Parent) -replace [regex]::Escape($folderToBackup))
      
        # Backup
        New-Item -Path (Join-Path $backupPath $newFilename) -Force
        Copy-Item -Path $file -Destination (Join-Path $backupPath $newFilename)
        "Copied `"$backupPath$newFilename`"" | Out-File -FilePath (Join-Path $backupDestination "Simple TimeMachine Log.txt") -Encoding utf8 -Append
    
    }
    
    "[$timestamp] - Going to sleep" | Out-File -FilePath (Join-Path $backupDestination "Simple TimeMachine Log.txt") -Encoding utf8 -Append

    Start-Sleep -Seconds ($backupInterval * 60)
    


    # ---------------------------- Backup maintainence --------------------------- #

    # Delete files older than retention time
    Get-ChildItem -Path $backupDestination -File -Recurse | Where-Object { $_.CreationTime -lt ((Get-Date).AddDays(-$retentionTime)) } | ForEach-Object {
        

        if ($_.FullName -ne (Join-Path $backupDestination "Simple TimeMachine Log.txt")) {
            "[$timestamp] - Removing old file $($_.fullname)" | Out-File -FilePath (Join-Path $backupDestination "Simple TimeMachine Log.txt") -Encoding utf8 -Append
            $_ | Remove-Item -Force
        } }

    # Delete temp files
    $backupDestination | Get-ChildItem -Force -Recurse | Where-Object { $_.name -like "* ~$*" } | ForEach-Object {
        "[$timestamp] - Removing temporary file $($_.fullname)" | Out-File -FilePath (Join-Path $backupDestination "Simple TimeMachine Log.txt") -Encoding utf8 -Append
        $_ | Remove-Item -Force
    } 


    # Delete zero byte files
    Get-ChildItem -Path $backupDestination -File -Recurse | Where-Object { $_.Length -eq 0 } | ForEach-Object {
        "[$timestamp] - Removing zero byte file $($_.fullname)" | Out-File -FilePath (Join-Path $backupDestination "Simple TimeMachine Log.txt") -Encoding utf8 -Append
        $_ | Remove-Item -Force
    } 


    # Delete empty folders
    Do {
        $EmptyFolderFound = $false
        Get-ChildItem -Path $backupDestination -Recurse -Directory | ForEach-Object {
            If ($_.GetFiles().Count -eq 0 -and $_.GetDirectories().Count -eq 0) {
                "[$timestamp] - Removing empty folder $($_.fullname)" | Out-File -FilePath (Join-Path $backupDestination "Simple TimeMachine Log.txt") -Encoding utf8 -Append
                $_ | Remove-Item -Force
                $EmptyFolderFound = $true
            }
        }
    } while ($EmptyFolderFound -eq $true)

} while ($true)


