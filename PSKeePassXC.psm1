# Define module-scoped variables
$script:KeePassXCConnection = $null

# Dot source all .ps1 files in the Public subfolder
Get-ChildItem -Path "$PSScriptRoot\Public\*.ps1" | ForEach-Object { . $_.FullName }

# Dot source all .ps1 files in the Private subfolder (if any)
if (Test-Path "$PSScriptRoot\Private\*.ps1") {
    Get-ChildItem -Path "$PSScriptRoot\Private\*.ps1" | ForEach-Object { . $_.FullName }
}

# Export only the functions using PowerShell standard verb-noun naming.
Export-ModuleMember -Function *-*