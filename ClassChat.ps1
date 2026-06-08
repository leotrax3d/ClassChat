Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# --- DESIGN-THEME (Mocha) ---
$colors = @{
    bg      = [System.Drawing.ColorTranslator]::FromHtml("#1e1e2e")
    surface = [System.Drawing.ColorTranslator]::FromHtml("#313244")
    surface2= [System.Drawing.ColorTranslator]::FromHtml("#45475a")
    text    = [System.Drawing.ColorTranslator]::FromHtml("#cdd6f4")
    subtext = [System.Drawing.ColorTranslator]::FromHtml("#a6adc8")
    green   = [System.Drawing.ColorTranslator]::FromHtml("#a6e3a1")
    mauve   = [System.Drawing.ColorTranslator]::FromHtml("#cba6f7")
    red     = [System.Drawing.ColorTranslator]::FromHtml("#f38ba8")
    blue    = [System.Drawing.ColorTranslator]::FromHtml("#89b4fa")
    yellow  = [System.Drawing.ColorTranslator]::FromHtml("#f9e2af")
}

# Farbpalette fuer Benutzer
$userColors = @(
    [System.Drawing.ColorTranslator]::FromHtml("#f38ba8") # red
    [System.Drawing.ColorTranslator]::FromHtml("#fab387") # peach
    [System.Drawing.ColorTranslator]::FromHtml("#f9e2af") # yellow
    [System.Drawing.ColorTranslator]::FromHtml("#a6e3a1") # green
    [System.Drawing.ColorTranslator]::FromHtml("#94e2d5") # teal
    [System.Drawing.ColorTranslator]::FromHtml("#89dceb") # sky
    [System.Drawing.ColorTranslator]::FromHtml("#89b4fa") # blue
    [System.Drawing.ColorTranslator]::FromHtml("#cba6f7") # mauve
    [System.Drawing.ColorTranslator]::FromHtml("#f5c2e7") # pink
)

# --- SETUP (Ordnerstruktur) ---
$folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
$folderBrowser.Description = "WAEHLE DEN GETEILTEN CHAT-ORDNER"
if ($folderBrowser.ShowDialog() -ne 'OK') { exit }

$chatDir   = $folderBrowser.SelectedPath
$onlineDir = Join-Path $chatDir "online"
$typingDir = Join-Path $chatDir "typing"
$attachDir = Join-Path $chatDir "attachments"
$afkDir    = Join-Path $chatDir "afk"

# NEU: Kanaele definieren
$script:channels = @("allgemein", "hausaufgaben", "gaming", "offtopic")
$script:currentChannel = "allgemein"
$script:chatFile = Join-Path $chatDir "chat_$($script:currentChannel).log"

foreach ($dir in ($onlineDir, $typingDir, $attachDir, $afkDir)) { 
    if (!(Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null } 
}
foreach ($ch in $script:channels) {
    $cf = Join-Path $chatDir "chat_$ch.log"
    if (!(Test-Path $cf)) { New-Item -Path $cf -ItemType File | Out-Null }
}

# --- VARIABLEN ---
$script:encryptionActive = $false
$script:lastLineCount = -1 # Start mit -1 fuer sofortigen Load
$script:myUserName = $env:USERNAME
$script:soundEnabled = $true
$script:searchTerm = "" # NEU: Suchbegriff

# Variablen fuer Join/Leave und Einmal-Aktionen
$script:knownUsers = @()
$script:isFirstLoad = $true
$script:playedRickrolls = @()

# --- GUI (Benutzeroberflaeche) ---
$form = New-Object System.Windows.Forms.Form
$form.Text = "Klassen-Chat ULTIMATE"
$form.Size = "1000, 660" # VERBREITERT FUER CHANNELS & SUCHE
$form.BackColor = $colors.bg
$form.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false

$lblTitle = New-Object System.Windows.Forms.Label
$lblTitle.Text = "KLASSEN-CHAT"
$lblTitle.ForeColor = $colors.mauve
$lblTitle.Font = New-Object System.Drawing.Font("Segoe UI", 20, [System.Drawing.FontStyle]::Bold)
$lblTitle.Location = "20, 15"
$lblTitle.AutoSize = $true
$form.Controls.Add($lblTitle)

$nameBox = New-Object System.Windows.Forms.TextBox
$nameBox.Text = $script:myUserName
$nameBox.Location = "770, 25"
$nameBox.Size = "200, 25"
$nameBox.BackColor = $colors.surface
$nameBox.ForeColor = $colors.text
$nameBox.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$nameBox.BorderStyle = "FixedSingle"
$form.Controls.Add($nameBox)

# NEU: Kanaele-Liste (Links)
$lblChannels = New-Object System.Windows.Forms.Label
$lblChannels.Text = "KANAELE"
$lblChannels.ForeColor = $colors.subtext
$lblChannels.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$lblChannels.Location = "20, 70"
$lblChannels.AutoSize = $true
$form.Controls.Add($lblChannels)

$channelList = New-Object System.Windows.Forms.ListBox
$channelList.Location = "20, 95"
$channelList.Size = "130, 405"
$channelList.BackColor = $colors.surface
$channelList.ForeColor = $colors.text
$channelList.BorderStyle = "None"
$channelList.Font = New-Object System.Drawing.Font("Segoe UI", 11)
foreach ($ch in $script:channels) { [void]$channelList.Items.Add("#$ch") }
$channelList.SelectedIndex = 0
$form.Controls.Add($channelList)

$chatBox = New-Object System.Windows.Forms.RichTextBox
$chatBox.Location = "170, 70"
$chatBox.Size = "580, 430"
$chatBox.BackColor = $colors.surface
$chatBox.ForeColor = $colors.text
$chatBox.BorderStyle = "None"
$chatBox.ReadOnly = $true
$chatBox.DetectUrls = $true
$chatBox.Font = New-Object System.Drawing.Font("Segoe UI", 11)
$form.Controls.Add($chatBox)

# NEU: Suchfeld (Rechts)
$searchBox = New-Object System.Windows.Forms.TextBox
$searchBox.Location = "770, 70"
$searchBox.Size = "165, 25"
$searchBox.BackColor = $colors.surface
$searchBox.ForeColor = $colors.text
$searchBox.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$searchBox.BorderStyle = "FixedSingle"
$form.Controls.Add($searchBox)

$searchClearBtn = New-Object System.Windows.Forms.Button
$searchClearBtn.Text = "X"
$searchClearBtn.Location = "945, 70"
$searchClearBtn.Size = "25, 25"
$searchClearBtn.BackColor = $colors.surface2
$searchClearBtn.ForeColor = $colors.text
$searchClearBtn.FlatStyle = "Flat"
$searchClearBtn.FlatAppearance.BorderSize = 0
$searchClearBtn.Cursor = [System.Windows.Forms.Cursors]::Hand
$form.Controls.Add($searchClearBtn)

$lblOnline = New-Object System.Windows.Forms.Label
$lblOnline.Text = "ONLINE"
$lblOnline.ForeColor = $colors.subtext
$lblOnline.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$lblOnline.Location = "770, 110"
$lblOnline.AutoSize = $true
$form.Controls.Add($lblOnline)

$onlineList = New-Object System.Windows.Forms.ListBox
$onlineList.Location = "770, 135"
$onlineList.Size = "200, 365"
$onlineList.BackColor = $colors.surface
$onlineList.ForeColor = $colors.blue
$onlineList.BorderStyle = "None"
$onlineList.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$form.Controls.Add($onlineList)

$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Text = ""
$statusLabel.ForeColor = $colors.subtext
$statusLabel.Location = "170, 505"
$statusLabel.Size = "580, 20"
$statusLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Italic)
$form.Controls.Add($statusLabel)

# Panel fuer Input
$inputPanel = New-Object System.Windows.Forms.Panel
$inputPanel.Location = "170, 530"
$inputPanel.Size = "340, 45" 
$inputPanel.BackColor = $colors.surface
$form.Controls.Add($inputPanel)

$inputBox = New-Object System.Windows.Forms.TextBox
$inputBox.Location = "10, 10"
$inputBox.Size = "320, 25"
$inputBox.BackColor = $colors.surface
$inputBox.ForeColor = $colors.text
$inputBox.Font = New-Object System.Drawing.Font("Segoe UI", 12)
$inputBox.BorderStyle = "None"
$inputPanel.Controls.Add($inputBox)

$muteBtn = New-Object System.Windows.Forms.Button
$muteBtn.Text = "AN" 
$muteBtn.Location = "520, 530"
$muteBtn.Size = "40, 45"
$muteBtn.BackColor = $colors.surface2
$muteBtn.ForeColor = $colors.text
$muteBtn.FlatStyle = "Flat"
$muteBtn.FlatAppearance.BorderSize = 0
$muteBtn.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$muteBtn.Cursor = [System.Windows.Forms.Cursors]::Hand
$form.Controls.Add($muteBtn)

$attachBtn = New-Object System.Windows.Forms.Button
$attachBtn.Text = "+" 
$attachBtn.Location = "570, 530"
$attachBtn.Size = "40, 45"
$attachBtn.BackColor = $colors.surface2
$attachBtn.ForeColor = $colors.text
$attachBtn.FlatStyle = "Flat"
$attachBtn.FlatAppearance.BorderSize = 0
$attachBtn.Font = New-Object System.Drawing.Font("Segoe UI", 16, [System.Drawing.FontStyle]::Bold)
$attachBtn.Cursor = [System.Windows.Forms.Cursors]::Hand
$form.Controls.Add($attachBtn)

$sendBtn = New-Object System.Windows.Forms.Button
$sendBtn.Text = "SENDEN"
$sendBtn.Location = "620, 530"
$sendBtn.Size = "130, 45"
$sendBtn.BackColor = $colors.green
$sendBtn.ForeColor = $colors.bg
$sendBtn.FlatStyle = "Flat"
$sendBtn.FlatAppearance.BorderSize = 0
$sendBtn.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$sendBtn.Cursor = [System.Windows.Forms.Cursors]::Hand
$form.Controls.Add($sendBtn)

# Hover-Effekte
$sendBtn.Add_MouseEnter({ $sendBtn.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#b4f9af") })
$sendBtn.Add_MouseLeave({ $sendBtn.BackColor = $colors.green })
$attachBtn.Add_MouseEnter({ $attachBtn.BackColor = $colors.blue; $attachBtn.ForeColor = $colors.bg })
$attachBtn.Add_MouseLeave({ $attachBtn.BackColor = $colors.surface2; $attachBtn.ForeColor = $colors.text })
$muteBtn.Add_MouseEnter({ $muteBtn.BackColor = $colors.blue; $muteBtn.ForeColor = $colors.bg })
$muteBtn.Add_MouseLeave({ $muteBtn.BackColor = $colors.surface2; $muteBtn.ForeColor = $colors.text })
$searchClearBtn.Add_MouseEnter({ $searchClearBtn.BackColor = $colors.red; $searchClearBtn.ForeColor = $colors.bg })
$searchClearBtn.Add_MouseLeave({ $searchClearBtn.BackColor = $colors.surface2; $searchClearBtn.ForeColor = $colors.text })

# Mute-Button Logik
$muteBtn.Add_Click({
    $script:soundEnabled = -not $script:soundEnabled
    $muteBtn.Text = if ($script:soundEnabled) { "AN" } else { "AUS" }
})

# --- FUNKTIONEN ---

function Get-UserColor($userName) {
    if ([string]::IsNullOrWhiteSpace($userName)) { return $colors.text }
    $hash = 0
    foreach ($char in $userName.ToCharArray()) { $hash += [int]$char }
    return $userColors[$hash % $userColors.Count]
}

function Append-UserMessage {
    param($time, $user, $msg, $type)
    
    $chatBox.SelectionStart = $chatBox.TextLength
    $chatBox.SelectionColor = $colors.subtext
    $chatBox.AppendText("[$time] ")

    $chatBox.SelectionStart = $chatBox.TextLength
    $chatBox.SelectionColor = Get-UserColor $user
    
    if ($type -eq "Action") {
        $chatBox.AppendText("* $user ")
        $chatBox.SelectionStart = $chatBox.TextLength
        $chatBox.SelectionColor = $colors.mauve
        $chatBox.AppendText("$msg`n")
    } else {
        $chatBox.AppendText($user)
        
        $chatBox.SelectionStart = $chatBox.TextLength
        $chatBox.SelectionColor = $colors.subtext
        $chatBox.AppendText(": ")

        $chatBox.SelectionStart = $chatBox.TextLength
        if ($type -eq "Whisper") {
            $chatBox.SelectionColor = $colors.mauve
            $chatBox.AppendText("[PRIVAT] $msg`n")
        } else {
            if ($msg -match "@$($nameBox.Text)") {
                $chatBox.SelectionColor = $colors.red
                $chatBox.SelectionFont = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
                if ($script:soundEnabled) { [System.Media.SystemSounds]::Asterisk.Play() }
            } else {
                $chatBox.SelectionColor = $colors.text
                $chatBox.SelectionFont = New-Object System.Drawing.Font("Segoe UI", 11)
            }
            $chatBox.AppendText("$msg`n")
            $chatBox.SelectionFont = New-Object System.Drawing.Font("Segoe UI", 11)
        }
    }
    $chatBox.ScrollToCaret()
}

function Append-StyledText {
    param($text, $color)
    $chatBox.SelectionStart = $chatBox.TextLength
    $chatBox.SelectionColor = $color
    $chatBox.AppendText($text + "`n")
    $chatBox.ScrollToCaret()
}

function Invoke-Crypt {
    param($text, [switch]$decrypt)
    if (-not $script:encryptionActive) { return $text }
    try {
        if ($decrypt) { 
            $bytes = [System.Convert]::FromBase64String($text)
            return [System.Text.Encoding]::UTF8.GetString($bytes)
        } else {
            $bytes = [System.Text.Encoding]::UTF8.GetBytes($text)
            return [System.Convert]::ToBase64String($bytes)
        }
    } catch { return $text }
}

function Send-Message {
    param($msg)
    
    $time = (Get-Date).ToString("HH:mm")
    $user = $nameBox.Text.Trim()
    $line = "[$time] ${user}: $msg"
    
    try {
        $utf8NoBom = New-Object System.Text.UTF8Encoding $false
        [System.IO.File]::AppendAllText($script:chatFile, (Invoke-Crypt $line) + "`r`n", $utf8NoBom)
    } catch {
        Append-StyledText "SYSTEM: Fehler beim Senden. Datei kurz blockiert? Bitte erneut versuchen." $colors.red
    }
    $inputBox.Clear()
}

function Clear-AFK {
    $afkFile = Join-Path $afkDir "$($nameBox.Text).afk"
    if (Test-Path $afkFile) {
        Remove-Item $afkFile -ErrorAction SilentlyContinue
        Send-Message "ist wieder da."
    }
}

function Handle-Command {
    param($inputStr)
    $parts = $inputStr.Split(" ", 3)
    $cmd = $parts[0].ToLower()
    
    switch ($cmd) {
        "/help" {
            Append-StyledText "--- HILFE (Lokal) ---" $colors.yellow
            Append-StyledText "/w [Name] [Text] - Privat fluestern" $colors.text
            Append-StyledText "/me [Aktion] - Zeigt eine Aktion an" $colors.mauve
            Append-StyledText "/poll Frage|Opt1|Opt2 - Umfrage starten" $colors.blue
            Append-StyledText "/roll - Wuerfelt eine Zahl von 1-100" $colors.green
            Append-StyledText "/coin - Wirft eine Muenze" $colors.green
            Append-StyledText "/rps [schere|stein|papier] - Minispiel" $colors.green
            Append-StyledText "/rickroll [Name] - Jemanden rickrollen" $colors.red
            Append-StyledText "/afk - Abwesenheits-Status umschalten" $colors.text
            Append-StyledText "/nick [Name] - Name aendern" $colors.text
            Append-StyledText "/clear - Chat-Fenster leeren" $colors.text
            Append-StyledText "/clearfile - Gesamte Chat-Historie loeschen" $colors.red
            return $true
        }
        "/w" {
            if ($parts.Count -ge 3) { Send-Message "[WHISPER:$($parts[1])] $($parts[2])" }
            return $true
        }
        "/me" {
            if ($parts.Count -ge 2) { 
                $action = $inputStr.Substring(3).Trim()
                Send-Message "[ACTION] $action" 
            }
            return $true
        }
        "/roll" {
            $rand = Get-Random -Minimum 1 -Maximum 101
            Send-Message "[ACTION] wuerfelt eine $rand (1-100)"
            return $true
        }
        "/coin" {
            $result = if ((Get-Random -Minimum 0 -Maximum 2) -eq 0) { "Kopf" } else { "Zahl" }
            Send-Message "[ACTION] wirft eine Muenze: $result"
            return $true
        }
        "/rps" {
            if ($parts.Count -ge 2) {
                $userWahl = $parts[1].ToLower()
                $optionen = @("schere", "stein", "papier")
                
                if ($userWahl -in $optionen) {
                    $botWahl = $optionen | Get-Random
                    $ergebnis = ""
                    
                    if ($userWahl -eq $botWahl) { $ergebnis = "Unentschieden!" }
                    elseif (($userWahl -eq "schere" -and $botWahl -eq "papier") -or
                            ($userWahl -eq "stein" -and $botWahl -eq "schere") -or
                            ($userWahl -eq "papier" -and $botWahl -eq "stein")) {
                        $ergebnis = "Du gewinnst!"
                    } else {
                        $ergebnis = "Bot gewinnt!"
                    }
                    Send-Message "[ACTION] spielt Schere, Stein, Papier. Wahl: $userWahl. Bot waehlt: $botWahl. -> $ergebnis"
                } else {
                    Append-StyledText "SYSTEM: Ungueltig! Nutze /rps schere, /rps stein oder /rps papier." $colors.red
                }
            } else {
                Append-StyledText "SYSTEM: Nutze /rps [schere|stein|papier]" $colors.red
            }
            return $true
        }
        "/poll" {
            $pollData = $inputStr.Substring(6).Trim()
            if ($pollData -match "\|") {
                $pollId = [guid]::NewGuid().ToString().Substring(0,8)
                Send-Message "[POLL:$pollId|$pollData]"
            } else {
                Append-StyledText "SYSTEM: Fehlerhaftes Umfrage-Format. Nutze: /poll Frage|Option1|Option2" $colors.red
            }
            return $true
        }
        "/rickroll" {
            if ($parts.Count -ge 2) {
                $target = $parts[1]
                $uuid = [guid]::NewGuid().ToString()
                Send-Message "[RICKROLL:$target|$uuid]"
            } else {
                Append-StyledText "SYSTEM: Fehlerhaftes Format. Nutze: /rickroll [Name]" $colors.red
            }
            return $true
        }
        "/afk" {
            $afkFile = Join-Path $afkDir "$($nameBox.Text).afk"
            if (Test-Path $afkFile) {
                Clear-AFK
            } else {
                "1" | Out-File $afkFile -ErrorAction SilentlyContinue
                Send-Message "ist jetzt AFK"
            }
            return $true
        }
        "/clearfile" {
            Clear-Content $script:chatFile
            Send-Message "--- Chat wurde von $($nameBox.Text) geleert ---"
            return $true
        }
        "/clear" { $chatBox.Clear(); return $true }
        "/nick"  { $nameBox.Text = $parts[1]; return $true }
        "/crypt" { 
            $script:encryptionActive = -not $script:encryptionActive
            Append-StyledText "Krypt-Modus jetzt: $script:encryptionActive" $colors.mauve
            return $true
        }
    }
    return $false
}

# --- TIMER LOGIK ---
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 1500
$timer.Add_Tick({
    try {
        $utf8NoBom = New-Object System.Text.UTF8Encoding $false
        if (Test-Path $script:chatFile) {
            $lines = [System.IO.File]::ReadAllLines($script:chatFile, $utf8NoBom)
            
            if ($lines.Count -ne $script:lastLineCount) {
                
                $pollDatabase = @{}
                foreach ($l in $lines) {
                    $dec = Invoke-Crypt $l -decrypt
                    if ($dec -match "^\[.*?\] .*?: \[POLL:(?<id>[^\|]+)\|(?<data>.*)\]") {
                        $id = $Matches.id
                        $pData = $Matches.data -split '\|'
                        $pollDatabase[$id] = @{ Question = $pData[0]; Options = $pData[1..($pData.Count-1)]; Votes = @{} }
                    }
                    elseif ($dec -match "^\[.*?\] (?<user>.*?): \[VOTE:(?<id>[^\|]+)\|(?<opt>.*)\]") {
                        $id = $Matches.id
                        if ($pollDatabase.ContainsKey($id)) {
                            $pollDatabase[$id].Votes[$Matches.user] = $Matches.opt
                        }
                    }
                }

                $chatBox.Clear()
                foreach ($l in $lines) {
                    $dec = Invoke-Crypt $l -decrypt
                    
                    if ($dec -match "\[VOTE:.*\]") { continue }

                    # Suchfilter anwenden
                    if ($script:searchTerm -ne "" -and $dec.IndexOf($script:searchTerm, [System.StringComparison]::OrdinalIgnoreCase) -lt 0) {
                        continue
                    }

                    if ($dec -match "\[FILE:(?<file>.*?)\]") {
                        $fileName = $Matches['file']
                        $fullPath = Join-Path $attachDir $fileName
                        $uri = ([uri]$fullPath).AbsoluteUri
                        $dec = $dec.Replace("[FILE:$fileName]", "[DATEI] $uri")
                    }

                    if ($dec -match "^\[(?<time>.*?)\] (?<user>.*?): (?<content>.*)") {
                        $time = $Matches.time
                        $user = $Matches.user
                        $content = $Matches.content

                        if ($content -match "^\[RICKROLL:(?<target>[^\|]+)\|(?<id>.*)\]") {
                            $target = $Matches.target
                            $id = $Matches.id
                            Append-StyledText "[$time] * $user hat $target gerickrollt!" $colors.mauve
                            if ($target -eq $nameBox.Text -and $id -notin $script:playedRickrolls) {
                                $script:playedRickrolls += $id
                                if (-not $script:isFirstLoad) { try { Start-Process "https://www.youtube.com/watch?v=xvFZjo5PgG0" } catch {} }
                            }
                        }
                        elseif ($content -match "^\[POLL:(?<id>[^\|]+)\|(?<data>.*)\]") {
                            $id = $Matches.id
                            $poll = $pollDatabase[$id]
                            
                            $chatBox.SelectionStart = $chatBox.TextLength
                            $chatBox.SelectionColor = $colors.subtext
                            $chatBox.AppendText("[$time] ")
                            $chatBox.SelectionStart = $chatBox.TextLength
                            $chatBox.SelectionColor = Get-UserColor $user
                            $chatBox.AppendText("$user ")
                            $chatBox.SelectionColor = $colors.blue
                            $chatBox.AppendText("startete eine Umfrage:`n")
                            
                            Append-StyledText "  [?] $($poll.Question)" $colors.yellow
                            
                            $tally = @{}
                            foreach ($opt in $poll.Options) { $tally[$opt] = 0 }
                            foreach ($v in $poll.Votes.Values) { if ($null -ne $tally[$v]) { $tally[$v]++ } }
                            
                            foreach ($opt in $poll.Options) {
                                $count = $tally[$opt]
                                $safeOpt = [uri]::EscapeDataString($opt)
                                $link = "http://poll.local/$id/$safeOpt"
                                Append-StyledText "   -> $opt ($count Stimmen) -> Abstimm-Link: $link" $colors.text
                            }
                            Append-StyledText "--------------------------------------" $colors.surface2
                        }
                        elseif ($content -match "^\[WHISPER:(?<target>.*?)\] (?<msg>.*)") {
                            $target = $Matches.target
                            $msg = $Matches.msg
                            if ($target -eq $nameBox.Text -or $user -eq $nameBox.Text) {
                                Append-UserMessage -time $time -user $user -msg $msg -type "Whisper"
                            }
                        }
                        elseif ($content -match "^\[ACTION\] (?<msg>.*)") {
                            Append-UserMessage -time $time -user $user -msg $Matches.msg -type "Action"
                        }
                        else {
                            Append-UserMessage -time $time -user $user -msg $content -type "Normal"
                        }
                    }
                    else {
                        Append-StyledText $dec $colors.text
                    }
                }
                
                $script:lastLineCount = $lines.Count
            }
        }

        # --- ONLINE & AFK UPDATES ---
        $now = Get-Date
        Get-ChildItem $onlineDir | ForEach-Object {
            if (($now - $_.LastWriteTime).TotalSeconds -gt 10) { Remove-Item $_.FullName -ErrorAction SilentlyContinue }
        }
        
        $onlineUsers = Get-ChildItem $onlineDir | Select-Object -ExpandProperty BaseName
        $afkUsers = Get-ChildItem $afkDir | Select-Object -ExpandProperty BaseName
        
        $currentOnline = @()
        
        $onlineList.Items.Clear()
        foreach ($u in $onlineUsers) {
            $currentOnline += $u
            if ($u -in $afkUsers) { [void]$onlineList.Items.Add("$u (AFK)") }
            else { [void]$onlineList.Items.Add($u) }
        }

        if (-not $script:isFirstLoad) {
            foreach ($u in $currentOnline) {
                if ($u -notin $script:knownUsers -and $u -ne $nameBox.Text) {
                    Append-StyledText "SYSTEM: $u hat den Chat betreten." $colors.green
                }
            }
            foreach ($k in $script:knownUsers) {
                if ($k -notin $currentOnline -and $k -ne $nameBox.Text) {
                    Append-StyledText "SYSTEM: $k hat den Chat verlassen." $colors.subtext
                }
            }
        }

        $script:knownUsers = $currentOnline
        $script:isFirstLoad = $false

        Get-ChildItem $typingDir | ForEach-Object {
            if (($now - $_.LastWriteTime).TotalSeconds -gt 3) { Remove-Item $_.FullName -ErrorAction SilentlyContinue }
        }
        
        $typers = Get-ChildItem $typingDir -Filter "*_$($script:currentChannel).typing" | Where-Object { $_.Name -notmatch "^$($nameBox.Text)_" } | ForEach-Object { $_.BaseName.Replace("_$($script:currentChannel)", "") }
        $statusLabel.Text = if ($typers) { ($typers -join ", ") + " schreibt gerade..." } else { "" }

        $myOnlineFile = Join-Path $onlineDir "$($nameBox.Text).txt"
        "1" | Out-File $myOnlineFile -ErrorAction SilentlyContinue
        
    } catch {}
})

# --- EVENT HANDLER ---

$channelList.Add_SelectedIndexChanged({
    $selected = $channelList.SelectedItem.ToString().Replace("#", "")
    if ($script:currentChannel -ne $selected) {
        $script:currentChannel = $selected
        $script:chatFile = Join-Path $chatDir "chat_$($script:currentChannel).log"
        $script:lastLineCount = -1
        $chatBox.Clear()
        Append-StyledText "SYSTEM: Du bist nun im Kanal #$selected" $colors.subtext
    }
})

$searchBox.Add_TextChanged({
    $script:searchTerm = $searchBox.Text.Trim()
    $script:lastLineCount = -1 
})

$searchClearBtn.Add_Click({
    $searchBox.Clear()
})

$attachBtn.Add_Click({
    $ofd = New-Object System.Windows.Forms.OpenFileDialog
    $ofd.Title = "Datei oder Bild auswaehlen"
    $ofd.Filter = "Alle Dateien (*.*)|*.*|Bilder (*.jpg;*.png;*.gif)|*.jpg;*.png;*.gif"
    
    if ($ofd.ShowDialog() -eq 'OK') {
        $sourceFile = $ofd.FileName
        $fileInfo = Get-Item $sourceFile
        if ($fileInfo.Length -gt 52428800) {
            [System.Windows.Forms.MessageBox]::Show("Datei ist zu gross! Maximal 50 MB.", "Fehler", 0, 48)
            return
        }
        $originalName = [System.IO.Path]::GetFileName($sourceFile)
        $safeName = "$(Get-Date -Format 'yyyyMMdd_HHmmss')_$originalName"
        $destPath = Join-Path $attachDir $safeName
        
        try {
            Copy-Item -Path $sourceFile -Destination $destPath -ErrorAction Stop
            Clear-AFK
            Send-Message "[FILE:$safeName]"
        } catch {
            [System.Windows.Forms.MessageBox]::Show("Fehler beim Kopieren.", "Fehler", 0, 16)
        }
    }
})

$chatBox.Add_LinkClicked({
    param($sender, $e)
    $link = $e.LinkText
    
    if ($link -match "^http://poll\.local/(?<id>[^/]+)/(?<opt>.*)") {
        $id = $Matches.id
        $opt = [uri]::UnescapeDataString($Matches.opt)
        Send-Message "[VOTE:$id|$opt]"
    }
    elseif ($link -match "^file:///") {
        try {
            $uri = New-Object System.Uri($link)
            Invoke-Item $uri.LocalPath
        } catch {
            Append-StyledText "SYSTEM: Datei konnte nicht geoffnet werden." $colors.red
        }
    }
})

$sendBtn.Add_Click({
    $val = $inputBox.Text.Trim()
    if ($val.StartsWith("/")) {
        if (Handle-Command $val) { $inputBox.Clear(); return }
    }
    if ($val) { 
        Clear-AFK
        Send-Message $val 
    }
})

$inputBox.Add_KeyDown({
    if ($_.KeyCode -eq 'Enter') { $sendBtn.PerformClick(); $_.SuppressKeyPress = $true }
})

$inputBox.Add_TextChanged({
    $tFile = Join-Path $typingDir "$($nameBox.Text)_$($script:currentChannel).typing"
    try { "1" | Out-File $tFile -ErrorAction SilentlyContinue } catch {}
})

# --- START ---
$timer.Start()
Append-StyledText "SYSTEM: Willkommen. Tippe /help fuer Befehle." $colors.subtext

$form.Add_Closing({ 
    $timer.Stop()
    Remove-Item (Join-Path $onlineDir "$($nameBox.Text).txt") -ErrorAction SilentlyContinue
    Remove-Item (Join-Path $typingDir "$($nameBox.Text)_*.typing") -ErrorAction SilentlyContinue
    Remove-Item (Join-Path $afkDir "$($nameBox.Text).afk") -ErrorAction SilentlyContinue
})

$form.ShowDialog()
