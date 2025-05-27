# Foobar Playlist File Search & Replace Tool - Refactored PowerShell Script

# region: ASCII Banner
Write-Host @"
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

"@
# endregion

# region: Function Definitions

function Replace-Variables {
    param ([string]$inputString)
    $pattern = '\$env:([a-zA-Z_][a-zA-Z0-9_]*)'
    return [regex]::Replace($inputString, $pattern, {
        param($match)
        $envVarName = $match.Groups[1].Value
        return [System.Environment]::GetEnvironmentVariable($envVarName) ?? $match.Value
    })
}

function Prompt-FileDialog {
    param (
        [string]$title,
        [string]$initialDir
    )
    Add-Type -AssemblyName System.Windows.Forms
    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    $dialog.InitialDirectory = $initialDir
    $dialog.Filter = "M3U Unicode playlist (*.m3u8)|*.m3u8"
    $dialog.Title = $title
    $dialog.ShowDialog() | Out-Null
    return $dialog.FileName
}

function Read-PlaylistLines {
    param ([string]$path)
    return Get-Content -Encoding UTF8 -LiteralPath $path -ReadCount 0
}

function Create-NewPlaylistsDir {
    param ([string]$basePath)
    $newDir = Join-Path $basePath "_new-playlists"
    if (-not (Test-Path $newDir)) {
        New-Item -ItemType Directory -Path $newDir | Out-Null
    }
    return $newDir
}

function Show-ErrorDialog {
    param ([string]$message)
    [System.Windows.Forms.MessageBox]::Show($message, "Error", 'OK', 'Error') | Out-Null
}

# endregion

# region: Load Config & Setup
$config = Get-Content -Path "./config.json" | ConvertFrom-Json
foreach ($key in $config.PSObject.Properties.Name) {
    if ($config.$key -is [string]) {
        $config.$key = Replace-Variables -inputString $config.$key
    }
}

$ListsDir = $config.ListsDir
$ListsExt = $config.ListsExt
$logReportLoc = $config.LogReportLoc
$logMissingLoc = $config.LogMissingLoc
$unwantedSet = [System.Collections.Generic.HashSet[string]]::new()
$config.UnwantedLists | ForEach-Object { $unwantedSet.Add($_) | Out-Null }

Remove-Item -LiteralPath $logReportLoc, $logMissingLoc -ErrorAction SilentlyContinue
# endregion

# region: Prompt for Mode
Write-Host "Enter mode: 'Search' or 'Replace'"
Write-Host "1. Search`n2. Replace`n"
$mode = Read-Host
if ($mode -notin @('1', '2')) { Write-Error "Invalid mode."; exit }
Write-Host `n
$mode = if ($mode -eq '2') { 'replace' } else { 'search' }

# endregion

# region: File Selection
$SourceListLoc = Prompt-FileDialog -title "Select source list" -initialDir $ListsDir
if (-not $SourceListLoc -or $unwantedSet.Contains((Get-Item $SourceListLoc).Name)) {
    Show-ErrorDialog "Invalid or unwanted source list selected."
    exit
}
$sourceLines = Read-PlaylistLines -path $SourceListLoc

if ($mode -eq 'replace') {
    $ReplacementListLoc = Prompt-FileDialog -title "Select replacement list" -initialDir $ListsDir
    if (-not $ReplacementListLoc -or $unwantedSet.Contains((Get-Item $ReplacementListLoc).Name)) {
        Show-ErrorDialog "Invalid or unwanted replacement list selected."
        exit
    }
    $replacementLines = Read-PlaylistLines -path $ReplacementListLoc
    if ($replacementLines.Count -ne $sourceLines.Count) {
        Write-Error "Source and replacement lists must have the same number of lines."
        exit
    }
}
# endregion

# region: Index Playlists
$lists = Get-ChildItem -LiteralPath $ListsDir -Filter "*.$ListsExt" | Where-Object {
    -not $unwantedSet.Contains($_.Name)
}

$listsData = @()
$contentIndex = @{}
$SourceListNumber = -1

for ($i = 0; $i -lt $lists.Count; $i++) {
    $file = $lists[$i]
    $lines = Get-Content -Encoding UTF8 -LiteralPath $file.FullName
    $contentSet = [System.Collections.Generic.HashSet[string]]::new()
    foreach ($line in $lines) {
        $contentSet.Add($line) | Out-Null
        if (-not $contentIndex.ContainsKey($line)) {
            $contentIndex[$line] = [System.Collections.Generic.List[string]]::new()
        }
        $contentIndex[$line].Add($file.Name)
    }
    $listsData += [PSCustomObject]@{
        Index = $i; Name = $file.Name; Path = $file.FullName; Content = $contentSet
    }
    if ($file.FullName -eq $SourceListLoc) { $SourceListNumber = $i }
    Write-Progress -Activity "Indexing playlists" -Status "$($i + 1)/$($lists.Count)" -PercentComplete (($i + 1) / $lists.Count * 100)
}
Write-Progress -Activity "Indexing playlists" -Completed
if ($SourceListNumber -eq -1) { Write-Error "Source list not indexed."; exit }
# endregion

# region: Search & Replace
$results = @()
if ($mode -eq 'replace') {
    $sourceLineToIndex = @{}
    for ($i = 0; $i -lt $sourceLines.Count; $i++) {
        $sourceLineToIndex[$sourceLines[$i]] = $i
    }
    $newPlaylistsDir = Create-NewPlaylistsDir -basePath $ListsDir
}

for ($i = 0; $i -lt $sourceLines.Count; $i++) {
    $line = $sourceLines[$i]
    if ($contentIndex.ContainsKey($line)) {
        $hits = $contentIndex[$line] | Where-Object {
            $_ -ne $listsData[$SourceListNumber].Name -and ($mode -ne 'replace' -or $_ -ne (Get-Item $ReplacementListLoc).Name)
        }
        if ($hits.Count -gt 0) {
            $results += "\n$line"
            $results += ($hits | ForEach-Object { " $_" })

            if ($mode -eq 'replace') {
                foreach ($hit in $hits) {
                    $playlist = $listsData | Where-Object { $_.Name -eq $hit }
                    if ($playlist) {
                        $newPath = Join-Path $newPlaylistsDir $playlist.Name
                        $lines = Get-Content -Encoding UTF8 -LiteralPath $playlist.Path
                        $updated = $lines | ForEach-Object {
                            if ($sourceLineToIndex.ContainsKey($_)) {
                                $replacementLines[$sourceLineToIndex[$_]]
                            } else {
                                $_
                            }
                        }
                        $updated | Set-Content -Encoding UTF8 -LiteralPath $newPath
                    }
                }
            }
        }
    }
    Write-Progress -Activity "Searching playlists" -Status "$($i + 1)/$($sourceLines.Count)" -PercentComplete (($i + 1) / $sourceLines.Count * 100)
}
Write-Progress -Activity "Searching playlists" -Completed
# endregion

# region: Report Output
if ($results.Count -gt 0) {
    $results | Out-File -Encoding UTF8 -LiteralPath $logReportLoc
}

if ((Test-Path $logReportLoc) -and ((Get-Item $logReportLoc).Length -gt 10)) {
    Invoke-Item -LiteralPath $logReportLoc
}
if ((Test-Path $logMissingLoc) -and ((Get-Item $logMissingLoc).Length -gt 10)) {
    Invoke-Item -LiteralPath $logMissingLoc
}
# endregion