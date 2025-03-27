# PSKeePassXC Module

PSKeePassXC is a PowerShell module designed to interact with KeePassXC's CLI, a popular password manager. This module allows users to automate and manage their KeePassXC database entries directly from PowerShell.

## Features

- Connect to KeePassXC databases with support for key files
- Securely manage and store database credentials
- Retrieve individual or all entries from KeePassXC databases
- Cross-platform support (Windows, macOS, Linux)

## Installation

1. Clone the repository or download the module files.
2. Place the `PSKeePassXC` folder in one of your PowerShell module directories:
   - For the current user: `C:\Users\<YourUsername>\Documents\PowerShell\Modules\`
   - For all users: `C:\Program Files\PowerShell\Modules\`
3. Import the module in your PowerShell session:
   ```powershell
   Import-Module PSKeePassXC
   ```

## Usage

### Connect to a KeePassXC Database
```powershell
# Connect with database path and key file
Connect-KeePassXC -DatabasePath "C:\path\to\database.kdbx" -KeyFilePath "C:\path\to\key.keyx"

# Force new credentials
Connect-KeePassXC -DatabasePath "C:\path\to\database.kdbx" -ForceNewCredential
```

### Get the Current Connection
```powershell
$connection = Get-KeePassXCConnection
```

### Retrieve Entries
```powershell
# Get a specific entry by name
Get-KeePassXCEntry -EntryName "MyWebsite"

# List all entries in the database
Get-KeePassXCEntry -ListAll

# Filter entries
Get-KeePassXCEntry -ListAll | Where-Object { $_.Title -like "*gmail*" }

# Using an existing connection
$connection = Connect-KeePassXC -DatabasePath "path\to\database.kdbx" -KeyFilePath "path\to\key.keyx"
Get-KeePassXCEntry -Connection $connection -EntryName "MyEntry"
```

## Prerequisites

- KeePassXC must be installed on your system with the CLI available
- The module will look for the KeePassXC CLI in standard installation locations or in your PATH

## Credential Management

The module securely stores database credentials using PowerShell's Export-Clixml, which leverages Windows DPAPI on Windows systems. Credentials are stored in:
- Windows: `%APPDATA%\PSKeePassXC\KeePassCredentials.xml`
- macOS: `~/Library/Application Support/PSKeePassXC/KeePassCredentials.xml`
- Linux: `~/.config/PSKeePassXC/KeePassCredentials.xml`

## Contributing

Contributions are welcome! Feel free to submit issues or pull requests to improve the module.

## License

This project is licensed under the MIT License.