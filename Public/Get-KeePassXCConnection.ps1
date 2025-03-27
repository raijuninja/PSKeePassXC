function Get-KeePassXCConnection {
    <#
    .SYNOPSIS
        Returns the current KeePassXC connection.
    
    .DESCRIPTION
        Gets the current KeePassXC connection object if one exists.
    
    .EXAMPLE
        $connection = Get-KeePassXCConnection
        
        Returns the current KeePassXC connection object.
    
    .NOTES
        Returns $null if no connection has been established.
    #>
    [CmdletBinding()]
    param()
    
    if ($script:KeePassXCConnection -and $script:KeePassXCConnection.Connected) {
        return $script:KeePassXCConnection
    }
    else {
        Write-Verbose "No active KeePassXC connection found."
        return $null
    }
}