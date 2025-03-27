function Get-KeePassXCEntry {
    <#
    .SYNOPSIS
        Retrieves entries from a KeePassXC database.
    
    .DESCRIPTION
        Gets entries from a KeePassXC database using the KeePassXC CLI.
        Can retrieve a single entry by name or list all entries.
    
    .PARAMETER Connection
        Connection object created by Connect-KeePassXC. If not provided, a new connection will be established.
    
    .PARAMETER EntryName
        Name of the entry to retrieve.
    
    .PARAMETER ListAll
        Switch to list all entries in the database.
    
    .PARAMETER DatabasePath
        Path to the KeePassXC database file (.kdbx). Only used if Connection is not provided.
    
    .PARAMETER KeyFilePath
        Path to the KeePassXC key file (.keyx). Only used if Connection is not provided.
    
    .EXAMPLE
        Get-KeePassXCEntry -EntryName "MyWebsite"
        
        Retrieves the entry named "MyWebsite" from the KeePassXC database.
    
    .EXAMPLE
        $connection = Connect-KeePassXC
        Get-KeePassXCEntry -Connection $connection -ListAll
        
        Lists all entries in the KeePassXC database using an existing connection.
    
    .EXAMPLE
        Get-KeePassXCEntry -ListAll | Where-Object { $_.Title -like "*gmail*" }
        
        Lists all entries and filters for those with "gmail" in the title.
    
    .NOTES
        Requires KeePassXC to be installed with the CLI tool available.
    #>
    [CmdletBinding(DefaultParameterSetName = 'SingleEntry')]
    param (
        [Parameter(ValueFromPipeline = $true)]
        [PSCustomObject]$Connection,
        
        [Parameter(Mandatory = $true, ParameterSetName = 'SingleEntry')]
        [string]$EntryName,
        
        [Parameter(Mandatory = $true, ParameterSetName = 'AllEntries')]
        [switch]$ListAll,
        
        [Parameter(ParameterSetName = 'SingleEntry')]
        [Parameter(ParameterSetName = 'AllEntries')]
        [string]$DatabasePath,
        
        [Parameter(ParameterSetName = 'SingleEntry')]
        [Parameter(ParameterSetName = 'AllEntries')]
        [string]$KeyFilePath
    )
    
    begin {
		# If no connection provided, tell user to connect first
        if (-not $Connection) {
            $Connection = Get-KeePassXCConnection
            if (-not $Connection) {
                throw "No KeePassXC connection available. Please run Connect-KeePassXC first."
            }
        }
        
        # Extract connection details
        $KeePassXC = $Connection.KeePassXC
        $DatabasePath = $Connection.DatabasePath
        $KeyFilePath = $Connection.KeyFilePath
        $Password = $Connection.Credential.GetNetworkCredential().Password
    }
    
    process {
        try {
            if ($ListAll) {
                Write-Verbose "Listing all entries in the database"
                
                # Run KeePassXC CLI to list all entries
                $output = $Password | & $KeePassXC ls --key-file "$KeyFilePath" "$DatabasePath" --recursive --flatten 2>&1
                
                # Filter out the password prompt line
                $output = $output | Where-Object { $_ -notmatch "^Enter password to unlock" }
                
                # Check if the command was successful
                if ($LASTEXITCODE -ne 0) {
                    throw "KeePassXC CLI failed with exit code $LASTEXITCODE. Output: $output"
                }
                
                # Process the output as a list of entries
                $entries = @()
                
                foreach ($item in $output) {
                    # Convert to string to safely work with it
                    $line = "$item"
                    
                    # Skip empty lines, heading lines and divider lines
                    if (-not [string]::IsNullOrWhiteSpace($line) -and 
                        $line -notmatch "^UUID|^----" -and 
                        $line -notmatch "^$") {
                        
                        # Try different regex patterns based on KeePassXC CLI output format
                        if ($line -match "^([a-zA-Z0-9-]+)\s+(.+?)/([^/]+)$") {
                            $entries += [PSCustomObject]@{
                                UUID  = $matches[1]
                                Group = $matches[2]
                                Title = $matches[3]
                            }
                        }
                        elseif ($line -match "^([a-zA-Z0-9-]+)\s+(.+?)\s{2,}(.+)$") {
                            $entries += [PSCustomObject]@{
                                UUID  = $matches[1]
                                Group = $matches[2] 
                                Title = $matches[3]
                            }
                        }
                        elseif ($line -match "^(.+?)/$") {
                            $entries += [PSCustomObject]@{
                                UUID  = ""
                                Group = $matches[1]
                                Title = "[Directory]"
                            }
                        }
                        else {
                            $lineTrimmed = $line.Trim()
                            if ($lineTrimmed -ne "") {
                                $entries += [PSCustomObject]@{
                                    Title = $lineTrimmed
                                    UUID  = ""
                                    Group = ""
                                }
                            }
                        }
                    }
                }
                
                # Return entries if found, otherwise return raw output
                if ($entries.Count -gt 0) {
                    return $entries
                }
                else {
                    Write-Warning "Could not parse entries properly. Returning raw output."
                    return @($output | ForEach-Object { "$_" })
                }
            }
            else {
                Write-Verbose "Retrieving entry: $EntryName"
                
                # Run KeePassXC CLI to get the specific entry
                $output = $Password | & $KeePassXC show --key-file "$KeyFilePath" "$DatabasePath" $EntryName --quiet --show-protected 2>&1
                
                # Check if the command was successful
                if ($LASTEXITCODE -ne 0) {
                    throw "KeePassXC CLI failed with exit code $LASTEXITCODE. Output: $output"
                }
                
                # Check if we got valid output
                if (-not $output -or $output -match "Error:" -or $output -match "Invalid") {
                    throw "Failed to retrieve KeePass entry: $output"
                }
                
                # Return entry as a custom object
                return [PSCustomObject]@{
                    Title    = ($output | Select-String "^Title: (.*)").Matches.Groups[1].Value
                    UserName = ($output | Select-String "^UserName: (.*)").Matches.Groups[1].Value
                    Password = ($output | Select-String "^Password: (.*)").Matches.Groups[1].Value
                    URL      = ($output | Select-String "^URL: (.*)").Matches.Groups[1].Value
                    Notes    = ($output | Select-String "^Notes: (.*)").Matches.Groups[1].Value
                    UUID     = ($output | Select-String "^Uuid: (.*)").Matches.Groups[1].Value
                    Tags     = ($output | Select-String "^Tags: (.*)").Matches.Groups[1].Value
                }
            }
        }
        catch {
            throw "Error retrieving KeePass data: $($_.Exception.Message)"
        }
    }
    
    end {
        # Clean up sensitive data
        Remove-Variable Password -ErrorAction SilentlyContinue
    }
}