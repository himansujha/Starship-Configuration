<#
  term-config-win.ps1 — Terminal environment setup for Windows
  PowerShell 7 · PSReadLine · Terminal-Icons · Starship · Nerd Font · Windows Terminal

  Run from PowerShell (no admin needed):
      powershell -ExecutionPolicy Bypass -File .\term-config-win.ps1
#>

$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

if ($PSVersionTable.PSVersion.Major -ge 6 -and -not $IsWindows) {
    Write-Host "This script is for Windows. Use term-config-mac.sh on macOS, term-config-linux.sh on Linux."
    exit 1
}

# ─── Colors & Styles ──────────────────────────────────────────────────────────
$E = [char]27
$RED="$E[0;31m";  $BRED="$E[1;31m"
$GREEN="$E[0;32m";$BGREEN="$E[1;32m"
$YELLOW="$E[1;33m"
$BCYAN="$E[1;36m"; $MAGENTA="$E[0;35m"
$WHITE="$E[1;37m"; $BOLD="$E[1m"; $DIM="$E[2m"; $ITALIC="$E[3m"; $NC="$E[0m"

# ─── Helpers ──────────────────────────────────────────────────────────────────
function Say($s)     { [Console]::Out.Write("$s`n") }
function Info($m)    { Say "  ${BCYAN}◆${NC} ${WHITE}$m${NC}" }
function Success($m) { Say "  ${BGREEN}✔${NC} ${GREEN}$m${NC}" }
function Warn($m)    { Say "  ${YELLOW}⚡${NC} ${YELLOW}$m${NC}" }
function Dim($m)     { Say "  ${DIM}$m${NC}" }
function Fail($m)    { Say "  ${BRED}✘${NC} ${RED}$m${NC}"; [Console]::CursorVisible = $true; exit 1 }

function Typewrite($text, $delay = 25) {
    [Console]::Out.Write("  ")
    foreach ($ch in $text.ToCharArray()) { [Console]::Out.Write($ch); Start-Sleep -Milliseconds $delay }
    Say ""
}

function Draw-Progress($current, $total, $label) {
    $width = 40
    $filled = [int][math]::Floor($current * $width / $total)
    $pct = [int][math]::Floor($current * 100 / $total)
    $bar = "${BGREEN}" + ("█" * $filled) + "${DIM}" + ("░" * ($width - $filled)) + "${NC}"
    [Console]::Out.Write("`r  $bar  ${BOLD}$("{0,3}" -f $pct)%${NC}  ${DIM}$label${NC}   ")
}

function Get-Msgs($key) {
    switch ($key) {
        'pwsh'     { 'Summoning PowerShell 7|Negotiating with conhost|Preparing a better shell|Installing your new home' }
        'module'   { 'Talking to the Gallery|Teaching the shell to predict|Making your shell smarter|Fish features incoming' }
        'starship' { 'Reaching for the stars|Downloading rocket fuel|Warping to prompt paradise|Starship launching soon' }
        'preset'   { 'Mixing Gruvbox colors|Painting your prompt|Loading the rainbow|Tuning your terminal style' }
        'font'     { 'Forging glyphs|Pouring icons into fonts|Polishing ligatures|Nerding out' }
        'wt'       { 'Opening Windows Terminal settings|Swapping fonts|Choosing a default profile|Making it official' }
        default    { 'Working on it|Hang tight|Almost there|Stay with me' }
    }
}

function Section-Box($num, $total, $name) {
    Say ""
    Say "  ${BCYAN}┌──────────────────────────────────────────────────────┐${NC}"
    Say ("  ${BCYAN}│${NC}  ${BOLD}Task {0}/{1}${NC}  ${BCYAN}·${NC}  {2,-41}${BCYAN}│${NC}" -f $num, $total, $name)
    Say "  ${BCYAN}└──────────────────────────────────────────────────────┘${NC}"
    Say ""
}

# Re-read PATH from the registry so freshly installed tools are found
function Refresh-Path {
    $machine = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $user    = [Environment]::GetEnvironmentVariable('Path', 'User')
    $env:Path = "$machine;$user"
}

# ─── Animated spinner: runs a scriptblock in a background job ────────────────
function Run-Silent($label, $msgKey, [scriptblock]$block, $argList = @()) {
    $msgs = (Get-Msgs $msgKey) -split '\|'
    $frames = '⠋','⠙','⠹','⠸','⠼','⠴','⠦','⠧','⠇','⠏'
    $dots   = '·  ','·· ','···',' ··','  ·'
    $i = 0; $d = 0; $m = 0
    $sw = [Diagnostics.Stopwatch]::StartNew()

    # Run the block in a job with errors made terminating, so failures mark the job Failed
    $job = Start-Job -ArgumentList $block.ToString(), $argList -ScriptBlock {
        param($code, $jobArgs)
        $ErrorActionPreference = 'Stop'
        $ProgressPreference = 'SilentlyContinue'
        & ([scriptblock]::Create($code)) @jobArgs
    }
    while ($job.State -eq 'Running' -or $job.State -eq 'NotStarted') {
        $el = [int]$sw.Elapsed.TotalSeconds
        $elStr = if ($el -lt 60) { "${el}s" } else { "$([int][math]::Floor($el/60))m$($el%60)s" }
        [Console]::Out.Write("`r  ${BCYAN}$($frames[$i])${NC}  ${DIM}$($msgs[$m])${NC}${MAGENTA}$($dots[$d])${NC}  ${DIM}[$elStr]${NC}   ")
        $i = ($i + 1) % $frames.Count
        $d = ($d + 1) % $dots.Count
        if ($i % 20 -eq 0) { $m = ($m + 1) % $msgs.Count }
        Start-Sleep -Milliseconds 100
    }
    $output = Receive-Job $job -ErrorVariable jobErr -ErrorAction SilentlyContinue 2>&1 | Out-String
    $failed = $job.State -eq 'Failed'
    Remove-Job $job -Force
    $total = [int]$sw.Elapsed.TotalSeconds
    [Console]::Out.Write("`r" + (' ' * 80) + "`r")

    if ($failed) {
        Say "  ${BRED}✘${NC}  ${RED}$label${NC} ${DIM}failed after ${total}s${NC}"
        Say "`n  ${DIM}┌─ Error Output ──────────────────────────────${NC}"
        foreach ($line in (($output + ($jobErr | Out-String)) -split "`r?`n")) { if ($line) { Say "  ${DIM}│${NC} $line" } }
        Say "  ${DIM}└─────────────────────────────────────────────${NC}`n"
        [Console]::CursorVisible = $true
        exit 1
    }
    Success "$label ${DIM}(${total}s)${NC}"
}

# ─── Banner ───────────────────────────────────────────────────────────────────
$BANNER = @'
  ████████╗███████╗██████╗ ███╗   ███╗ ██████╗ ██████╗ ███╗   ██╗███████╗██╗ ██████╗
     ██╔══╝██╔════╝██╔══██╗████╗ ████║██╔════╝██╔═══██╗████╗  ██║██╔════╝██║██╔════╝
     ██║   █████╗  ██████╔╝██╔████╔██║██║     ██║   ██║██╔██╗ ██║█████╗  ██║██║  ███╗
     ██║   ██╔══╝  ██╔══██╗██║╚██╔╝██║██║     ██║   ██║██║╚██╗██║██╔══╝  ██║██║   ██║
     ██║   ███████╗██║  ██║██║ ╚═╝ ██║╚██████╗╚██████╔╝██║ ╚████║██║     ██║╚██████╔╝
     ╚═╝   ╚══════╝╚═╝  ╚═╝╚═╝     ╚═╝ ╚═════╝ ╚═════╝ ╚═╝  ╚═══╝╚═╝     ╚═╝ ╚═════╝
'@
function Print-Banner {
    Say ""
    Say "${BOLD}${BCYAN}$BANNER${NC}"
    Say "  ${DIM}     Terminal environment setup — PowerShell 7 · PSReadLine · Starship${NC}"
    Say "  ${DIM}     ──────────────────────────────────────────────────────────────${NC}"
    Say ""
}

# ─── Interactive Checkbox Menu ────────────────────────────────────────────────
function Checkbox-Menu($title, [string[]]$items) {
    $count = $items.Count
    $checked = @(1) * $count
    $cursor = 0

    [Console]::Out.Write("$E[?1049h")   # alternate screen
    [Console]::CursorVisible = $false
    Clear-Host
    Print-Banner
    $top = [Console]::CursorTop

    try {
        while ($true) {
            [Console]::SetCursorPosition(0, $top)
            $sel = ($checked | Measure-Object -Sum).Sum
            Say "  ${BOLD}${WHITE}$title${NC}  ${DIM}($sel/$count selected)${NC}   "
            Say "  ${DIM}↑↓ navigate  ·  Space toggle  ·  A toggle all  ·  Enter confirm${NC}"
            Say ""
            for ($i = 0; $i -lt $count; $i++) {
                $box = if ($checked[$i]) { "${BGREEN}[✔]${NC}" } else { "${DIM}[  ]${NC}" }
                if ($i -eq $cursor) { Say "  ${BCYAN}▶${NC} $box  ${BOLD}${WHITE}$($items[$i])${NC}   " }
                else                { Say "    $box  ${DIM}$($items[$i])${NC}   " }
            }
            Say ""
            $barW = 30; $filled = [int][math]::Floor($sel * $barW / $count)
            Say ("  ${BGREEN}" + ("▪" * $filled) + "${DIM}" + ("▫" * ($barW - $filled)) + "${NC}  ${BCYAN}$sel${NC}${DIM}/$count ready to install${NC}   ")

            $key = [Console]::ReadKey($true)
            switch ($key.Key) {
                'UpArrow'   { if ($cursor -gt 0) { $cursor-- } }
                'DownArrow' { if ($cursor -lt $count - 1) { $cursor++ } }
                'Spacebar'  { $checked[$cursor] = 1 - $checked[$cursor] }
                'A'         { $allOn = -not ($checked -contains 0); for ($i = 0; $i -lt $count; $i++) { $checked[$i] = if ($allOn) { 0 } else { 1 } } }
                'Enter'     { return @(for ($i = 0; $i -lt $count; $i++) { if ($checked[$i]) { $i } }) }
                'Escape'    { return @() }
            }
        }
    } finally {
        [Console]::Out.Write("$E[?1049l")
        [Console]::CursorVisible = $true
    }
}

# ══════════════════════════════════════════════════════════════════════════════
$MENU_ITEMS = @(
    'PowerShell 7            — modern cross-platform shell (required base)',
    'PSReadLine              — Fish-like suggestions & syntax colors',
    'Terminal-Icons          — file & folder icons in directory listings',
    'Starship                — Cross-shell prompt (gruvbox-rainbow)',
    'JetBrainsMono Nerd Font — icons for the Starship prompt',
    'Windows Terminal        — PowerShell 7 as default + Nerd Font'
)

$selected = @(Checkbox-Menu 'Select components to install:' $MENU_ITEMS)
if ($selected.Count -eq 0) { Say "`n  ${YELLOW}⚡${NC} Nothing selected. Exiting.`n"; exit 0 }

$INSTALL_PWSH     = $selected -contains 0
$INSTALL_PSRL     = $selected -contains 1
$INSTALL_ICONS    = $selected -contains 2
$INSTALL_STARSHIP = $selected -contains 3
$INSTALL_FONT     = $selected -contains 4
$CONFIG_WT        = $selected -contains 5

$TOTAL = 1 + [int]$INSTALL_PWSH + [int]$INSTALL_PSRL + [int]$INSTALL_ICONS + (2 * [int]$INSTALL_STARSHIP) + [int]$INSTALL_FONT + [int]$CONFIG_WT
$CURRENT = 0
$INSTALLED = New-Object System.Collections.Generic.List[string]

function Next-Task($name) {
    $script:CURRENT++
    Section-Box $script:CURRENT $TOTAL $name
    Draw-Progress $script:CURRENT $TOTAL 'Overall progress'; Say ""
}

Clear-Host
Print-Banner
Say "  ${BCYAN}▸${NC} ${BOLD}$TOTAL tasks${NC} queued  ${DIM}·  let's gooo${NC}"

# Profile files for both PowerShell 7 and Windows PowerShell 5.1 (handles OneDrive-redirected Documents)
$DOCS = [Environment]::GetFolderPath('MyDocuments')
$PROFILE_PATHS = @(
    (Join-Path $DOCS 'PowerShell\Microsoft.PowerShell_profile.ps1'),
    (Join-Path $DOCS 'WindowsPowerShell\Microsoft.PowerShell_profile.ps1')
)

function Winget-Install($id, $label, $msgKey) {
    Run-Silent $label $msgKey {
        param($id)
        $out = & winget install --id $id -e --source winget --accept-package-agreements --accept-source-agreements --disable-interactivity 2>&1 | Out-String
        # 0 = installed, -1978335189 (0x8A15002B) = already installed / no upgrade available
        if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne -1978335189) { throw "winget exited with $LASTEXITCODE`n$out" }
        $out
    } @($id)
}

# ─── Task: Detect Environment ─────────────────────────────────────────────────
Next-Task 'Detecting Environment'
$os = [Environment]::OSVersion.Version
Info "Windows $($os.Major).$($os.Minor) build $($os.Build) · PowerShell $($PSVersionTable.PSVersion)"

$needWinget = $INSTALL_PWSH -or $INSTALL_STARSHIP
if ($needWinget) {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Fail "winget not found. Install 'App Installer' from the Microsoft Store, then re-run."
    }
    Info "Package manager: ${BOLD}winget${NC}"
}

$execPolicy = Get-ExecutionPolicy -Scope CurrentUser
if ($execPolicy -in @('Undefined', 'Restricted', 'AllSigned')) {
    Info "Allowing your PowerShell profile to load (ExecutionPolicy RemoteSigned, current user only)"
    Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force
    Success "ExecutionPolicy → RemoteSigned (CurrentUser)"
}

# ─── Task: PowerShell 7 ───────────────────────────────────────────────────────
if ($INSTALL_PWSH) {
    Next-Task 'Installing PowerShell 7'
    Typewrite 'Faster, cross-platform, and actively developed.'
    if (Get-Command pwsh -ErrorAction SilentlyContinue) {
        Warn 'PowerShell 7 is already installed — skipping'
        $INSTALLED.Add("PowerShell 7 ${DIM}(already present)${NC}")
    } else {
        Winget-Install 'Microsoft.PowerShell' 'Installing PowerShell 7' 'pwsh'
        Refresh-Path
        $INSTALLED.Add("PowerShell 7 ${GREEN}✔${NC}")
    }
}

# ─── Task: PSReadLine ─────────────────────────────────────────────────────────
if ($INSTALL_PSRL) {
    Next-Task 'Installing PSReadLine'
    Typewrite 'Fish-style superpowers, coming right up...'
    Run-Silent 'Installing PSReadLine (latest)' 'module' {
        if (-not (Get-PackageProvider -ListAvailable -Name NuGet -ErrorAction SilentlyContinue)) {
            Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Scope CurrentUser -Force | Out-Null
        }
        Install-Module PSReadLine -Scope CurrentUser -Force -AllowClobber -SkipPublisherCheck
    }
    $INSTALLED.Add("PSReadLine ${GREEN}✔${NC}")
}

# ─── Task: Terminal-Icons ─────────────────────────────────────────────────────
if ($INSTALL_ICONS) {
    Next-Task 'Installing Terminal-Icons'
    Typewrite 'Every file gets a face.'
    if (Get-Module -ListAvailable -Name Terminal-Icons) {
        Warn 'Terminal-Icons is already installed — skipping'
        $INSTALLED.Add("Terminal-Icons ${DIM}(already present)${NC}")
    } else {
        Run-Silent 'Installing Terminal-Icons' 'module' {
            if (-not (Get-PackageProvider -ListAvailable -Name NuGet -ErrorAction SilentlyContinue)) {
                Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Scope CurrentUser -Force | Out-Null
            }
            Install-Module Terminal-Icons -Scope CurrentUser -Force -Repository PSGallery
        }
        $INSTALLED.Add("Terminal-Icons ${GREEN}✔${NC}")
    }
}

# ─── Task: Starship ───────────────────────────────────────────────────────────
if ($INSTALL_STARSHIP) {
    Next-Task 'Installing Starship Prompt'
    Typewrite 'Blazing-fast. Infinitely configurable. Zero compromise.'
    if (Get-Command starship -ErrorAction SilentlyContinue) {
        Warn 'Starship is already installed — skipping'
        $INSTALLED.Add("Starship ${DIM}(already present)${NC}")
    } else {
        Winget-Install 'Starship.Starship' 'Installing Starship' 'starship'
        Refresh-Path
        if (-not (Get-Command starship -ErrorAction SilentlyContinue)) { Fail 'Starship installation failed (not on PATH)' }
        $INSTALLED.Add("Starship ${GREEN}✔${NC}")
    }

    Next-Task 'Applying gruvbox-rainbow Preset'
    Typewrite 'Warm earth tones meet electric neon. Your prompt will glow.'
    $cfgDir = Join-Path $HOME '.config'
    New-Item -ItemType Directory -Force -Path $cfgDir | Out-Null
    $starshipExe = (Get-Command starship).Source
    Run-Silent 'Applying gruvbox-rainbow preset' 'preset' {
        param($exe, $out)
        & $exe preset gruvbox-rainbow -o $out
        if ($LASTEXITCODE -ne 0) { throw "starship preset exited with $LASTEXITCODE" }
    } @($starshipExe, (Join-Path $cfgDir 'starship.toml'))
    $INSTALLED.Add("gruvbox-rainbow preset ${GREEN}✔${NC}")
}

# ─── Write the PowerShell profile block ───────────────────────────────────────
if ($INSTALL_PSRL -or $INSTALL_ICONS -or $INSTALL_STARSHIP) {
    $block = @'
# >>> term-config >>>
if (Get-Module -ListAvailable PSReadLine) {
    Import-Module PSReadLine
    # Grey inline suggestions from history (→ to accept) need PSReadLine 2.1+
    if ((Get-Module PSReadLine).Version -ge [version]'2.1.0') { Set-PSReadLineOption -PredictionSource History }
    Set-PSReadLineOption -EditMode Windows
    Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
    Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
    Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
}
if (Get-Module -ListAvailable Terminal-Icons) { Import-Module Terminal-Icons }
if (Get-Command starship -ErrorAction SilentlyContinue) { Invoke-Expression (& starship init powershell) }
# <<< term-config <<<
'@
    foreach ($p in $PROFILE_PATHS) {
        New-Item -ItemType Directory -Force -Path (Split-Path $p) | Out-Null
        $existing = if (Test-Path $p) { Get-Content $p -Raw } else { '' }
        if ($existing -and $existing.Contains('# >>> term-config >>>')) {
            Warn "Profile already configured: ${DIM}$p${NC}"
            continue
        }
        if ($existing) {
            $bak = "$p.bak.$(Get-Date -Format yyyyMMdd_HHmmss)"
            Copy-Item $p $bak
            Info "Backed up profile → ${DIM}$bak${NC}"
        }
        Add-Content -Path $p -Value "`r`n$block" -Encoding UTF8
        Success "Profile updated: ${DIM}$p${NC}"
    }
}

# ─── Task: Nerd Font (per-user install, no admin) ─────────────────────────────
if ($INSTALL_FONT) {
    Next-Task 'Installing JetBrainsMono Nerd Font'
    Typewrite "Starship's icons need a Nerd Font to render properly."
    $fontDir = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'
    if (Get-ChildItem $fontDir -Filter 'JetBrainsMonoNerdFont-*.ttf' -ErrorAction SilentlyContinue) {
        Warn 'JetBrainsMono Nerd Font is already installed — skipping'
        $INSTALLED.Add("JetBrainsMono Nerd Font ${DIM}(already present)${NC}")
    } else {
        Run-Silent 'Downloading & installing JetBrainsMono Nerd Font' 'font' {
            param($fontDir)
            $ProgressPreference = 'SilentlyContinue'
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            $tmp = Join-Path $env:TEMP "jbm-nerd-$([guid]::NewGuid())"
            New-Item -ItemType Directory -Force -Path $tmp, $fontDir | Out-Null
            $zip = Join-Path $tmp 'JetBrainsMono.zip'
            Invoke-WebRequest -UseBasicParsing -Uri 'https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip' -OutFile $zip
            Expand-Archive -Path $zip -DestinationPath $tmp -Force
            $reg = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'
            if (-not (Test-Path $reg)) { New-Item -Path $reg -Force | Out-Null }
            Get-ChildItem $tmp -Filter 'JetBrainsMonoNerdFont-*.ttf' | ForEach-Object {
                $dest = Join-Path $fontDir $_.Name
                Copy-Item $_.FullName $dest -Force
                New-ItemProperty -Path $reg -Name "$($_.BaseName) (TrueType)" -Value $dest -PropertyType String -Force | Out-Null
            }
            Remove-Item $tmp -Recurse -Force
        } @($fontDir)
        $INSTALLED.Add("JetBrainsMono Nerd Font ${GREEN}✔${NC}")
    }
}

# ─── Task: Windows Terminal settings ──────────────────────────────────────────
if ($CONFIG_WT) {
    Next-Task 'Configuring Windows Terminal'
    Typewrite 'Making PowerShell 7 your one and only...'
    $wtPaths = @(
        (Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json'),
        (Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json'),
        (Join-Path $env:LOCALAPPDATA 'Microsoft\Windows Terminal\settings.json')
    )
    $wt = $wtPaths | Where-Object { Test-Path $_ } | Select-Object -First 1
    if (-not $wt) {
        Warn 'Windows Terminal settings not found — open Windows Terminal once, then re-run this step'
    } else {
        $bak = "$wt.bak.$(Get-Date -Format yyyyMMdd_HHmmss)"
        Copy-Item $wt $bak
        Info "Backed up settings → ${DIM}$bak${NC}"
        try {
            # Strip whole-line // comments so Windows PowerShell 5.1 can parse the JSON
            $raw = (Get-Content $wt -Raw -Encoding UTF8) -replace '(?m)^\s*//.*$', ''
            $json = $raw | ConvertFrom-Json

            if (-not $json.profiles.PSObject.Properties['defaults']) {
                $json.profiles | Add-Member -NotePropertyName defaults -NotePropertyValue ([pscustomobject]@{})
            }
            $defaults = $json.profiles.defaults
            if (-not $defaults.PSObject.Properties['font']) {
                $defaults | Add-Member -NotePropertyName font -NotePropertyValue ([pscustomobject]@{})
            }
            $defaults.font | Add-Member -NotePropertyName face -NotePropertyValue 'JetBrainsMono Nerd Font' -Force
            Success 'Default font → JetBrainsMono Nerd Font'

            # PowerShell 7's auto-generated profile GUID
            $pwshGuid = '{574e775e-4f2a-5b96-ac1e-a2962a402336}'
            $hasPwsh = @($json.profiles.list | Where-Object { $_.guid -eq $pwshGuid }).Count -gt 0
            if ($hasPwsh -or (Get-Command pwsh -ErrorAction SilentlyContinue)) {
                $json | Add-Member -NotePropertyName defaultProfile -NotePropertyValue $pwshGuid -Force
                Success 'Default profile → PowerShell 7'
            } else {
                Warn 'PowerShell 7 profile not found in Windows Terminal — default profile unchanged'
            }

            $out = $json | ConvertTo-Json -Depth 64
            [IO.File]::WriteAllText($wt, $out, (New-Object System.Text.UTF8Encoding($false)))
            $INSTALLED.Add("Windows Terminal settings ${GREEN}✔${NC}")
        } catch {
            Copy-Item $bak $wt -Force
            Warn "Could not update settings automatically ($($_.Exception.Message)). Restored the backup."
            Dim  'Set it by hand: Windows Terminal → Settings → Defaults → Appearance → Font face'
        }
    }
}

# ─── Summary ──────────────────────────────────────────────────────────────────
Draw-Progress $TOTAL $TOTAL 'All tasks complete'
Say "`n"
Say "  ${BGREEN}╔══════════════════════════════════════════════════════╗${NC}"
Say "  ${BGREEN}║${NC}   ${BOLD}${WHITE}  ✔  Setup Complete!${NC}                                ${BGREEN}║${NC}"
Say "  ${BGREEN}╠══════════════════════════════════════════════════════╣${NC}"
Say "  ${BGREEN}║${NC}  ${BOLD}Installed / Verified:${NC}                                ${BGREEN}║${NC}"
foreach ($item in $INSTALLED) { Say "  ${BGREEN}║${NC}    ${BCYAN}▸${NC}  $item" }
Say "  ${BGREEN}╠══════════════════════════════════════════════════════╣${NC}"
Say "  ${BGREEN}║${NC}  ${BOLD}Next step:${NC}  ${ITALIC}Restart Windows Terminal, or run:${NC}       ${BGREEN}║${NC}"
Say "  ${BGREEN}║${NC}  ${BCYAN}  >  ${NC}${BOLD}. `$PROFILE${NC}                                       ${BGREEN}║${NC}"
Say "  ${BGREEN}╚══════════════════════════════════════════════════════╝${NC}"
Say ""
Say "  ${DIM}Enjoy your new terminal. You earned it. 🚀${NC}"
Say ""
