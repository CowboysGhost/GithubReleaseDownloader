<#
GithubReleaseInstaller.ps1
- Downloads and installs the most recent release file from a GitHub repository
- Supports executable formats: EXE, JAR, PS1, BAT, ZIP, MSIX, APPX
- Auto-detects the latest release from GitHub API
- Version: 26.0.5

================================================================================
VERIFIED SECONDARY LINKS
================================================================================

### Official Documentation
# GitHub API documentation for releases
$VerifyGitHubAPI = "https://docs.github.com/en/rest/releases/releases"

# Official GitHub homepage
$VerifyHomepage = "https://github.com"

================================================================================
END VERIFIED LINKS SECTION
================================================================================
#>

#Requires -Version 5.1

# ==== VERSION ====
$ScriptVersion = "26.0.6"


[void][System.Reflection.Assembly]::LoadWithPartialName('System.Drawing')
[void][System.Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms')

# ==== Configuration ====
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$SupportedExtensions = @('.exe', '.jar', '.ps1', '.bat', '.zip', '.msix', '.appx', '.msi')

# ==== UI Form ====
$form = New-Object System.Windows.Forms.Form
$form.Text = "GitHub Release Installer v$ScriptVersion"
$form.Size = New-Object System.Drawing.Size(550, 420)
$form.StartPosition = "CenterScreen"
$form.BackColor = [System.Drawing.Color]::FromArgb(20,20,20)
$form.ForeColor = [System.Drawing.Color]::White
$form.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false

# Title label
$lblTitle = New-Object System.Windows.Forms.Label
$lblTitle.Text = "GitHub Release Installer -- v$ScriptVersion"
$lblTitle.Location = New-Object System.Drawing.Point(20, 15)
$lblTitle.Size = New-Object System.Drawing.Size(500, 30)
$lblTitle.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
$lblTitle.ForeColor = [System.Drawing.Color]::FromArgb(220, 40, 40)
$form.Controls.Add($lblTitle)

# GitHub URL input
$lblRepo = New-Object System.Windows.Forms.Label
$lblRepo.Text = "GitHub Repository URL:"
$lblRepo.Location = New-Object System.Drawing.Point(20, 55)
$lblRepo.Size = New-Object System.Drawing.Size(500, 20)
$lblRepo.ForeColor = [System.Drawing.Color]::White
$form.Controls.Add($lblRepo)

$tbRepo = New-Object System.Windows.Forms.TextBox
$tbRepo.Location = New-Object System.Drawing.Point(20, 75)
$tbRepo.Size = New-Object System.Drawing.Size(500, 25)
$tbRepo.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$tbRepo.Text = "https://github.com/USERNAME/REPOSITORY"
$tbRepo.BackColor = [System.Drawing.Color]::FromArgb(20,20,20)  # Match form background
$tbRepo.ForeColor = [System.Drawing.Color]::Gray
$tbRepo.Add_Enter({ $tbRepo.ForeColor = [System.Drawing.Color]::White; if ($tbRepo.Text -eq "https://github.com/USERNAME/REPOSITORY") { $tbRepo.Text = "" } })
$tbRepo.Add_Leave({ if ($tbRepo.Text -eq "") { $tbRepo.Text = "https://github.com/USERNAME/REPOSITORY"; $tbRepo.ForeColor = [System.Drawing.Color]::Gray } })
$form.Controls.Add($tbRepo)

# Download folder input
$lblFolder = New-Object System.Windows.Forms.Label
$lblFolder.Text = "Install Folder (Optional, leave empty for script directory):"
$lblFolder.Location = New-Object System.Drawing.Point(20, 110)
$lblFolder.Size = New-Object System.Drawing.Size(500, 20)
$form.Controls.Add($lblFolder)

$tbFolder = New-Object System.Windows.Forms.TextBox
$tbFolder.Location = New-Object System.Drawing.Point(20, 130)
$tbFolder.Size = New-Object System.Drawing.Size(440, 25)
$tbFolder.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$tbFolder.Text = $ScriptDir
$tbFolder.BackColor = [System.Drawing.Color]::FromArgb(20,20,20)  # Match form background
$tbFolder.ForeColor = [System.Drawing.Color]::White
$form.Controls.Add($tbFolder)

$btnBrowse = New-Object System.Windows.Forms.Button
$btnBrowse.Text = "Browse"
$btnBrowse.Location = New-Object System.Drawing.Point(465, 130)
$btnBrowse.Size = New-Object System.Drawing.Size(55, 25)
$btnBrowse.BackColor = [System.Drawing.Color]::FromArgb(160, 20, 20)
$btnBrowse.ForeColor = [System.Drawing.Color]::White
$btnBrowse.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$btnBrowse.FlatAppearance.BorderSize = 0
$btnBrowse.Add_Click({
    $folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
    $folderBrowser.Description = "Select install folder"
    $folderBrowser.SelectedPath = $tbFolder.Text
    if ($folderBrowser.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $tbFolder.Text = $folderBrowser.SelectedPath
    }
})
$form.Controls.Add($btnBrowse)

# Status label
$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Location = New-Object System.Drawing.Point(20, 170)
$statusLabel.Size = New-Object System.Drawing.Size(500, 50)
$statusLabel.Text = "Status: Ready. Enter a GitHub repository URL and click 'Download and Install Latest Release'."
$form.Controls.Add($statusLabel)

# Progress bar
$progressBar = New-Object System.Windows.Forms.ProgressBar
$progressBar.Location = New-Object System.Drawing.Point(20, 225)
$progressBar.Size = New-Object System.Drawing.Size(500, 20)
$progressBar.Style = "Marquee"
$progressBar.Visible = $false
$form.Controls.Add($progressBar)

# Buttons panel
$btnPanel = New-Object System.Windows.Forms.Panel
$btnPanel.Location = New-Object System.Drawing.Point(20, 255)
$btnPanel.Size = New-Object System.Drawing.Size(500, 150)
$btnPanel.BackColor = [System.Drawing.Color]::Transparent
$form.Controls.Add($btnPanel)

function New-RedButton($text, $x, $y, $width, $height, $scriptBlock) {
    $btn = New-Object System.Windows.Forms.Button
    $btn.Text = $text
    $btn.Location = New-Object System.Drawing.Point($x, $y)
    $btn.Size = New-Object System.Drawing.Size($width, $height)
    $btn.BackColor = [System.Drawing.Color]::FromArgb(160, 20, 20)
    $btn.ForeColor = [System.Drawing.Color]::White
    $btn.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Regular)
    $btn.FlatAppearance.BorderSize = 0
    $btn.Add_Click($scriptBlock)
    return $btn
}

# Helper function to parse GitHub URL
function Parse-GitHubUrl {
    param([string]$Url)
    
    # Remove trailing slash
    $Url = $Url.TrimEnd('/')
    
    # Match GitHub URL pattern
    if ($Url -match 'https?://github\.com/([^/]+)/([^/]+)(?:\.git)?') {
        $owner = $matches[1]
        $repo = $matches[2] -replace '\.git$', ''
        return @{ Owner = $owner; Repo = $repo }
    }
    return $null
}

# 1) Download & Install
$btnInstall = New-RedButton "Download and Install Latest Release" 0 0 500 40 {
    # Parse GitHub URL
    $repoUrl = $tbRepo.Text.Trim()
    
    if ($repoUrl -eq "https://github.com/USERNAME/REPOSITORY") {
        $statusLabel.Text = "Status: ERROR - Please enter a valid GitHub repository URL."
        return
    }
    
    $githubInfo = Parse-GitHubUrl -Url $repoUrl
    
    if (-not $githubInfo) {
        $statusLabel.Text = "Status: ERROR - Invalid GitHub URL. Format: https://github.com/OWNER/REPO"
        return
    }
    
    $owner = $githubInfo.Owner
    $repo = $githubInfo.Repo
    $installFolder = $tbFolder.Text.Trim()
    
    if ([string]::IsNullOrWhiteSpace($installFolder)) {
        $installFolder = $ScriptDir
    }
    
    $statusLabel.Text = "Status: Fetching latest release from $owner/$repo..."
    $progressBar.Visible = $true
    $progressBar.Refresh()
    
    try {
        # Get latest release from GitHub API
        $apiUrl = "https://api.github.com/repos/$owner/$repo/releases/latest"
        $headers = @{
            'Accept' = 'application/vnd.github.v3+json'
            'User-Agent' = 'PowerShell-GitHubReleaseInstaller'
        }
        
        # Get GitHub API token (optional, for rate limiting)
        $githubToken = $env:GITHUB_TOKEN
        if ($githubToken) {
            $headers['Authorization'] = "token $githubToken"
        }
        
        $release = Invoke-RestMethod -Uri $apiUrl -Headers $headers -Method Get -UseBasicParsing
        
        $releaseName = $release.name
        $releaseTag = $release.tag_name
        $assets = $release.assets
        
        if (-not $assets -or $assets.Count -eq 0) {
            $statusLabel.Text = "Status: ERROR - No downloadable assets found in latest release ($releaseTag)."
            $progressBar.Visible = $false
            [System.Windows.Forms.MessageBox]::Show(
                "No downloadable files found in the latest release ($releaseTag).`n`nThe repository does not have a release with executable files (EXE, JAR, PS1, BAT, ZIP, etc.).",
                "No Release Assets Found",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Warning
            )
            return
        }
        
        # Find the first executable file
        $downloadableAsset = $null
        foreach ($asset in $assets) {
            $extension = [IO.Path]::GetExtension($asset.name).ToLower()
            if ($SupportedExtensions -contains $extension) {
                $downloadableAsset = $asset
                break
            }
        }
        
        if (-not $downloadableAsset) {
            $availableExtensions = ($assets | ForEach-Object { [IO.Path]::GetExtension($_.name) }) -join ", "
            $statusLabel.Text = "Status: ERROR - No executable format found."
            $progressBar.Visible = $false
            [System.Windows.Forms.MessageBox]::Show(
                "No executable files found in the latest release ($releaseTag).`n`nSupported formats: EXE, JAR, PS1, BAT, ZIP, MSIX, APPX, MSI`n`nAvailable file types: $availableExtensions",
                "No Executable Format Found",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Warning
            )
            return
        }
        
        $downloadUrl = $downloadableAsset.browser_download_url
        $assetName = $downloadableAsset.name
        $fileSize = [math]::Round($downloadableAsset.size / 1MB, 2)
        
        $statusLabel.Text = "Status: Found $assetName ($fileSize MB). Downloading..."
        $progressBar.Refresh()
        
        # Create install folder if it doesn't exist
        if (-not (Test-Path $installFolder)) {
            New-Item -ItemType Directory -Path $installFolder -Force | Out-Null
        }
        
        # Download the file
        $localPath = Join-Path $installFolder $assetName
        Invoke-WebRequest -Uri $downloadUrl -OutFile $localPath -UseBasicParsing
        
        $statusLabel.Text = "Status: Download complete! File saved to: $localPath"
        $progressBar.Visible = $false
        
        [System.Windows.Forms.MessageBox]::Show(
            "Download complete!`n`nRelease: $releaseName`nFile: $assetName`nSize: $fileSize MB`nLocation: $localPath",
            "Download Successful",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        )
    }
    catch {
        $errorMessage = $_.Exception.Message
        
        # Check for 404 error (repo not found)
        if ($_ -match "404") {
            $statusLabel.Text = "Status: ERROR - Repository not found or private."
        }
        else {
            $statusLabel.Text = "Status: Error - $errorMessage"
        }
        $progressBar.Visible = $false
    }
}
$btnPanel.Controls.Add($btnInstall)

# 2) Check Connection
$btnCheck = New-RedButton "Test GitHub Connection" 0 50 500 40 {
    $statusLabel.Text = "Status: Testing GitHub connection..."
    
    try {
        $testUrl = "https://api.github.com"
        $result = Invoke-RestMethod -Uri $testUrl -TimeoutSec 10 -UseBasicParsing
        $statusLabel.Text = "Status: GitHub connection OK. Rate limit: $($result.rate.remaining) requests remaining."
    }
    catch {
        $statusLabel.Text = "Status: ERROR - Cannot connect to GitHub. Check your internet connection."
    }
}
$btnPanel.Controls.Add($btnCheck)

# Run form
[void]$form.ShowDialog()