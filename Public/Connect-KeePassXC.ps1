function Connect-KeePassXC {
    <#
    .SYNOPSIS
        Establishes a connection to a KeePassXC database.
    
    .DESCRIPTION
        Creates a connection to a KeePassXC database using the KeePassXC CLI.
        Handles credential management, CLI discovery, and connection validation.
    
    .PARAMETER DatabasePath
        Path to the KeePassXC database file (.kdbx).
    
    .PARAMETER KeyFilePath
        Path to the KeePassXC key file (.keyx).
    
    .PARAMETER CredentialPath
        Custom path for the saved credential file. If not specified, credentials are stored in the user's AppData folder.
    
    .PARAMETER Credential
        PSCredential object containing the database password. If not provided, the function will try to load saved credentials.
    
    .PARAMETER ForceNewCredential
        Forces creation of new credentials even if saved credentials exist.
    
    .EXAMPLE
        Connect-KeePassXC -DatabasePath "C:\Path\To\Database.kdbx" -KeyFilePath "C:\Path\To\Key.keyx"
        
        Connects to the specified KeePass database using saved or interactively provided credentials.
    
    .EXAMPLE
        $connection = Connect-KeePassXC -DatabasePath "C:\Path\To\Database.kdbx" -ForceNewCredential
        
        Forces creation of new credentials and returns a connection object that can be used with other KeePass functions.
    
    .NOTES
        Requires KeePassXC to be installed with the CLI tool available.
        Credentials are securely stored using Windows DPAPI and are user-specific.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param (
        [Parameter()]
        [string]$DatabasePath,
        
        [Parameter()]
        [string]$KeyFilePath,
        
        [Parameter()]
        [string]$CredentialPath,
        
        [Parameter()]
        [PSCredential]$Credential,
        
        [Parameter()]
        [switch]$ForceNewCredential
    )
    
    # Define default local path for credentials if none provided
    if (-not $CredentialPath) {
        # Determine OS-appropriate path for storing credentials
        if ($IsWindows -or ($null -eq $IsWindows -and [System.Environment]::OSVersion.Platform -eq "Win32NT")) {
            # Windows path
            $appDataPath = Join-Path -Path $env:APPDATA -ChildPath "PSKeePassXC"
        }
        elseif ($IsMacOS -or ($null -eq $IsMacOS -and (Get-Command "uname" -ErrorAction SilentlyContinue) -and (uname) -eq "Darwin")) {
            # macOS path
            $appDataPath = Join-Path -Path $HOME -ChildPath "Library/Application Support/PSKeePassXC"
        }
        else {
            # Linux/Unix path
            $appDataPath = Join-Path -Path $HOME -ChildPath ".config/PSKeePassXC"
        }

        $CredentialPath = Join-Path -Path $appDataPath -ChildPath "KeePassCredentials.xml"
        Write-Verbose "Using credential path: $CredentialPath"
    }

    # Check if credential was provided or if we need to load it
    if (-not $Credential) {
        # Check if the credential file exists and we're not forcing new credentials
        if ((Test-Path -Path $CredentialPath) -and (-not $ForceNewCredential)) {
            try {
                Write-Verbose "Loading credential from $CredentialPath"
                $Credential = Import-Clixml -Path $CredentialPath -ErrorAction Stop
            }
            catch {
                Write-Warning "Failed to load credential file: $($_.Exception.Message)"
                Write-Host "This often happens if the credential file was created on a different computer or with a different user account." -ForegroundColor Yellow

                $recreateChoice = Read-Host "Do you want to create a new credential file? (Y/N)"
                if ($recreateChoice -ne "Y") {
                    throw "Cannot proceed without valid credentials. Error: $($_.Exception.Message)"
                }

                # Delete the problematic credential file if it exists
                if (Test-Path -Path $CredentialPath) {
                    try {
                        Remove-Item -Path $CredentialPath -Force -ErrorAction Stop
                        Write-Host "Removed invalid credential file." -ForegroundColor Cyan
                    }
                    catch {
                        Write-Warning "Could not remove invalid credential file: $($_.Exception.Message)"
                        $CredentialPath = Join-Path -Path (Split-Path -Parent $CredentialPath) -ChildPath "KeePassCredentials_new.xml"
                        Write-Host "Will try to create new credential at: $CredentialPath" -ForegroundColor Cyan
                    }
                }

                # Flag that we need to create new credentials
                $ForceNewCredential = $true
            }
        }

        # Create new credentials if needed
        if ((-not (Test-Path -Path $CredentialPath)) -or $ForceNewCredential) {
            Write-Host "KeePass database credential file not found or needs to be recreated." -ForegroundColor Yellow

            # Create directory if it doesn't exist
            $credDir = Split-Path -Parent $CredentialPath
            if (-not (Test-Path -Path $credDir)) {
                try {
                    New-Item -Path $credDir -ItemType Directory -Force -ErrorAction Stop | Out-Null
                    Write-Host "Created directory: $credDir" -ForegroundColor Cyan
                }
                catch {
                    Write-Warning "Failed to create directory for credentials: $($_.Exception.Message)"
                    $CredentialPath = Join-Path -Path $HOME -ChildPath "KeePassCredentials.xml"
                    Write-Host "Will try to use alternative location: $CredentialPath" -ForegroundColor Yellow
                }
            }

            # Get and save the credential
            try {
                Write-Host "Please enter your KeePassXC database password" -ForegroundColor Cyan
                $Credential = Get-Credential -Message "Enter KeePassXC database credentials" -UserName 'KeePassXC'

                if (-not $Credential) {
                    throw "No credentials were provided."
                }

                $Credential | Export-Clixml -Path $CredentialPath -ErrorAction Stop
                Write-Host "Credentials saved to $CredentialPath" -ForegroundColor Green
            }
            catch {
                throw "Failed to create or save credentials: $($_.Exception.Message)"
            }
        }
    }

    # Find KeePassXC CLI executable
    try {
        # Initialize with potential paths
        $potentialPaths = @(
            "C:\Program Files\KeePassXC\keepassxc-cli.exe",
            "C:\Program Files (x86)\KeePassXC\keepassxc-cli.exe",
            "/Applications/KeePassXC.app/Contents/MacOS/keepassxc-cli",
            "/usr/bin/keepassxc-cli",
            "/usr/local/bin/keepassxc-cli"
        )
        
        $KeePassXC = $null
        
        # Check each potential path
        foreach ($path in $potentialPaths) {
            if (Test-Path -Path $path -ErrorAction SilentlyContinue) {
                $KeePassXC = $path
                Write-Verbose "Found KeePassXC CLI at: $KeePassXC"
                break
            }
        }
        
        # Try to find it in PATH if not found at standard locations
        if (-not $KeePassXC) {
            $cliCommand = Get-Command "keepassxc-cli" -ErrorAction SilentlyContinue
            if ($cliCommand) {
                $KeePassXC = $cliCommand.Source
                Write-Verbose "Found KeePassXC CLI in PATH: $KeePassXC"
            }
        }

        # Verify KeePassXC CLI exists
        if (-not $KeePassXC) {
            throw "KeePassXC CLI not found. Please install KeePassXC or ensure it's in a standard location."
        }

        # Verify database and key file exist
        if (-not (Test-Path -Path $DatabasePath)) {
            throw "KeePass database not found at $DatabasePath"
        }

        if ($KeyFilePath -and (-not (Test-Path -Path $KeyFilePath))) {
            throw "Key file not found at $KeyFilePath"
        }

        # Create connection object
        $passwordText = $Credential.GetNetworkCredential().Password
        
		# Test connection to make sure the password works
		$testCmd = $passwordText | & $KeePassXC ls --key-file "$KeyFilePath" "$DatabasePath" --quiet 2>&1
		if ($LASTEXITCODE -ne 0) {
			throw "Failed to open KeePassXC database. Please check your credentials and try again. Error: $testCmd"
		}
        
		# Store connection in module scope
		$script:KeePassXCConnection = [PSCustomObject]@{
			KeePassXC      = $KeePassXC
			DatabasePath   = $DatabasePath
			KeyFilePath    = $KeyFilePath
			Credential     = $Credential
			CredentialPath = $CredentialPath
			Connected      = $true
		}

		return $script:KeePassXCConnection
    }
    catch {
        throw "Failed to connect to KeePass: $($_.Exception.Message)"
    }
}