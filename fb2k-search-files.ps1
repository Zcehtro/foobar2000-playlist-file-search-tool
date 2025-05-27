# Foobar Playlist File Search - PowerShell Version

Write-Host "
___________          ___.                _______________  _______  _______    
\_   _____/___   ____\_ |__ _____ _______\_____  \   _  \ \   _  \ \   _  \   
 |    __)/  _ \ /  _ \| __ \\__  \\_  __ \/  ____/  /_\  \/  /_\  \/  /_\  \  
 |     \(  <_> |  <_> ) \_\ \/ __ \|  | \/       \  \_/   \  \_/   \  \_/   \ 
 \___  / \____/ \____/|___  (____  /__|  \_______ \_____  /\_____  /\_____  / 
     \/                   \/     \/              \/     \/       \/       \/  
__________.__                .__  .__          __                             
\______   \  | _____  ___.__.|  | |__| _______/  |_                           
 |     ___/  | \__  \<   |  ||  | |  |/  ___/\   __\                          
 |    |   |  |__/ __ \\___  ||  |_|  |\___ \  |  |                            
 |____|   |____(____  / ____||____/__/____  > |__|                            
                    \/\/                  \/                                  
___________.__.__             _________                           .__         
\_   _____/|__|  |   ____    /   _____/ ____ _____ _______   ____ |  |__      
 |    __)  |  |  | _/ __ \   \_____  \_/ __ \\__  \\_  __ \_/ ___\|  |  \     
 |     \   |  |  |_\  ___/   /        \  ___/ / __ \|  | \/\  \___|   Y  \    
 \___  /   |__|____/\___  > /_______  /\___  >____  /__|    \___  >___|  /    
     \/                 \/          \/     \/     \/            \/     \/     
___________           .__                                                     
\__    ___/___   ____ |  |                                                    
  |    | /  _ \ /  _ \|  |                                                    
  |    |(  <_> |  <_> )  |__                                                  
  |____| \____/ \____/|____/                                                  
                                                                              
"

# Function to replace environment variables in strings using PowerShell $env: template
function Replace-Variables {
    param (
        [string]$inputString
    )
    $pattern = '\$env:([a-zA-Z_][a-zA-Z0-9_]*)'
    return [regex]::Replace($inputString, $pattern, {
            param($match)
            $envVarName = $match.Groups[1].Value
            $envValue = [System.Environment]::GetEnvironmentVariable($envVarName)
            if ($envValue) {
                return $envValue
            }
            else {
                return $match.Value
            }
        })
}


# Load configuration from JSON file
$configPath = ".\config.json"
$config = Get-Content -Path $configPath | ConvertFrom-Json

# Preprocess environment variables in the configuration
foreach ($key in $config.PSObject.Properties.Name) {
    if ($config.$key -is [string]) {
        $config.$key = Replace-Variables -inputString $config.$key
    }
}

# Access configuration variables
$ListsDir = $config.ListsDir
$ListsExt = $config.ListsExt
$logReportLoc = $config.LogReportLoc
$logMissingLoc = $config.LogMissingLoc
$unwantedLists = $config.UnwantedLists

# Helper: Clear logs
Remove-Item -LiteralPath $logReportLoc, $logMissingLoc -ErrorAction SilentlyContinue

# Prompt user for mode
Write-Host "Enter mode: 'Search' or 'Replace'

- Search mode will search for files in the source list and report their locations in all the other 
playlists in the current folder.
- Replace mode will replace the files in the source list with the files in the replacement list.

Note: The source and replacement lists must have the same number of lines.
1. Search
2. Replace"
$mode = Read-Host 
if ($mode -notin @('1', '2')) {
    Write-Error "Invalid mode selected. Exiting."
    exit
}

# Set mode value explicitly for search and replace
if ($mode -eq '2') {
    Write-Host "Replace mode selected."
    $mode = 'replace'
}
else {
    Write-Host "Search mode selected."
    $mode = 'search'
}

# Build a set of unwanted lists for quick lookup
$unwantedSet = [System.Collections.Generic.HashSet[string]]::new()
foreach ($file in $unwantedLists) {
    $unwantedSet.Add($file) | Out-Null
}

# Prompt user to select a source list
Add-Type -AssemblyName System.Windows.Forms
$OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
$OpenFileDialog.InitialDirectory = $ListsDir
$OpenFileDialog.Filter = "M3U Unicode playlist (*.m3u8)|*.m3u8"
$OpenFileDialog.Title = "Select source list containing files to search for"
$OpenFileDialog.ShowDialog() | Out-Null
$SourceListLoc = $OpenFileDialog.FileName

# Verify if the selected source list is in the unwanted lists
if ($unwantedSet.Contains((Get-Item -LiteralPath $SourceListLoc).Name)) {
    [System.Windows.Forms.MessageBox]::Show("The selected source list is in the unwanted lists. Exiting.", "Error", 'OK', 'Error')
    exit
}

if (-not $SourceListLoc) {
    [System.Windows.Forms.MessageBox]::Show("No file selected.", "Error", 'OK', 'Error')
    exit
}

# Parse lines in source list
$sourceLines = Get-Content -Encoding UTF8 -LiteralPath $SourceListLoc -ReadCount 0

# If in replace mode, prompt for replacement list
if ($mode -eq 'replace') {
    $OpenFileDialog.Title = "Select replacement list containing replacement file paths"
    $OpenFileDialog.ShowDialog() | Out-Null
    $ReplacementListLoc = $OpenFileDialog.FileName

    # Verify if the selected replacement list is in the unwanted lists
    if ($unwantedSet.Contains((Get-Item -LiteralPath $ReplacementListLoc).Name)) {
        [System.Windows.Forms.MessageBox]::Show("The selected replacement list is in the unwanted lists. Exiting.", "Error", 'OK', 'Error')
        exit
    }

    if (-not $ReplacementListLoc) {
        [System.Windows.Forms.MessageBox]::Show("No replacement file selected.", "Error", 'OK', 'Error')
        exit
    }

    $replacementLines = Get-Content -Encoding UTF8 -LiteralPath $ReplacementListLoc -ReadCount 0
    if ($replacementLines.Count -ne $sourceLines.Count) {
        Write-Error "Source and replacement lists must have the same number of lines."
        exit
    }
}

# Filter out unwanted lists from the directory listing
$lists = Get-ChildItem -LiteralPath $ListsDir -Filter "*.$ListsExt" | Where-Object {
    -not $unwantedSet.Contains($_.Name)
}
$listsTotal = $lists.Count
$SourceListNumber = -1

# Read content of all lists into a hashtable for faster lookup
$listsData = @()
$contentIndex = @{}

for ($i = 0; $i -lt $listsTotal; $i++) {
    $filePath = $lists[$i].FullName
    $fileName = $lists[$i].Name
    $lines = Get-Content -Encoding UTF8 -LiteralPath $filePath
    $contentSet = [System.Collections.Generic.HashSet[string]]::new()
    foreach ($line in $lines) {
        $contentSet.Add($line) | Out-Null
        if (-not $contentIndex.ContainsKey($line)) {
            $contentIndex[$line] = [System.Collections.Generic.List[string]]::new()
        }
        $contentIndex[$line].Add($fileName)
    }
    $listsData += [PSCustomObject]@{
        Index   = $i
        Name    = $fileName
        Path    = $filePath
        Content = $contentSet
    }
    if ($filePath -eq $SourceListLoc) {
        $SourceListNumber = $i
    }
    Write-Progress -Activity "Building index" -Status "$($i + 1) of $listsTotal" -PercentComplete ((($i + 1) / $listsTotal) * 100)
}
Write-Progress -Activity "Building index" -Completed

if ($SourceListNumber -eq -1) {
    Write-Error "Source list not found in directory listing."
    exit
}

$results = @()

# Search using the reverse content index
for ($i = 0; $i -lt $sourceLines.Count; $i++) {
    $line = $sourceLines[$i]
    if ($contentIndex.ContainsKey($line)) {
        $lineResults = @()
        foreach ($match in $contentIndex[$line]) {
            # Exclude the source and replacement lists from being compared
            if ($match -ne $listsData[$SourceListNumber].Name -and ($mode -ne 'replace' -or $match -ne (Get-Item -LiteralPath $ReplacementListLoc).Name)) {
                $lineResults += " $match"

                # If in replace mode, create output directory for new playlists
                $newPlaylistsDir = Join-Path $ListsDir "_new-playlists"
                if (-not (Test-Path -LiteralPath $newPlaylistsDir)) {
                    New-Item -ItemType Directory -Path $newPlaylistsDir | Out-Null
                }
                
                # If in replace mode, create a new playlist with replaced lines
                if ($mode -eq 'replace') {
                    $playlist = $listsData | Where-Object { $_.Name -eq $match }
                    if ($playlist) {
                        $newPlaylistPath = Join-Path $newPlaylistsDir $playlist.Name
                        $newContent = @()
                        foreach ($playlistLine in $playlist.Content) {
                            if ($playlistLine -eq $line) {
                                $newContent += $replacementLines[$i]
                            }
                            else {
                                $newContent += $playlistLine
                            }
                        }
                        $newContent | Set-Content -Encoding UTF8 -LiteralPath $newPlaylistPath
                    }
                }
            }
        }
        if ($lineResults.Count -gt 0) {
            $results += "`n$line"
            $results += $lineResults
        }
    }
    Write-Progress -Activity "Searching playlists" -Status "$($i + 1) of $($sourceLines.Count)" -PercentComplete (($i + 1) / $sourceLines.Count * 100)
}
Write-Progress -Activity "Searching playlists" -Completed

# Write report
if ($results.Count -gt 0) {
    $results | Out-File -Encoding UTF8 -LiteralPath $logReportLoc
}

# Show logs if they have content
if ((Test-Path -LiteralPath $logReportLoc) -and ((Get-Item -LiteralPath $logReportLoc).Length -gt 10)) {
    Invoke-Item -LiteralPath $logReportLoc
}
if ((Test-Path -LiteralPath $logMissingLoc) -and ((Get-Item -LiteralPath $logMissingLoc).Length -gt 10)) {
    Invoke-Item -LiteralPath $logMissingLoc
}

