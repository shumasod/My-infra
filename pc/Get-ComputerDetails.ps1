function Get-ComputerDetails {
    <#
    .SYNOPSIS
    This script is used to get useful information from a computer.

    .DESCRIPTION
    This script is used to get useful information from a computer. Currently, the script gets the following information:
    - Explicit Credential Logons (Event ID 4648)
    - Logon events (Event ID 4624)
    - AppLocker logs to find what processes are created
    - PowerShell logs to find PowerShell scripts which have been executed
    - RDP Client Saved Servers, which indicates what servers the user typically RDP's in to

    .PARAMETER ToString
    Switch: Outputs the data as text instead of objects, good if you are using this script through a backdoor.

    .EXAMPLE
    Get-ComputerDetails
    Gets information about the computer and outputs it as PowerShell objects.

    Get-ComputerDetails -ToString
    Gets information about the computer and outputs it as raw text.

    .NOTES
    This script is useful for fingerprinting a server to see who connects to this server (from where), and where users on this server connect to.
    You can also use it to find Powershell scripts and executables which are typically run, and then use this to backdoor those files.
    #>

    [CmdletBinding()]
    Param (
        [Parameter(Position = 0)]
        [Switch]
        $ToString
    )

    Set-StrictMode -Version 2

    $SecurityLog = Get-EventLog -LogName Security
    $Filtered4624 = Find-4624Logons $SecurityLog
    $Filtered4648 = Find-4648Logons $SecurityLog
    $AppLockerLogs = Find-AppLockerLogs
    $PSLogs = Find-PSScriptsInPSAppLog
    $RdpClientData = Find-RDPClientConnections

    if ($ToString) {
        Write-Output "Event ID 4624 (Logon):"
        Write-Output ($Filtered4624.Values | Format-List)
        Write-Output "Event ID 4648 (Explicit Credential Logon):"
        Write-Output ($Filtered4648.Values | Format-List)
        Write-Output "AppLocker Process Starts:"
        Write-Output ($AppLockerLogs.Values | Format-List)
        Write-Output "PowerShell Script Executions:"
        Write-Output ($PSLogs.Values | Format-List)
        Write-Output "RDP Client Data:"
        Write-Output ($RdpClientData.Values | Format-List)
    }
    else {
        $Properties = @{
            LogonEvent4624        = $Filtered4624.Values
            LogonEvent4648        = $Filtered4648.Values
            AppLockerProcessStart = $AppLockerLogs.Values
            PowerShellScriptStart = $PSLogs.Values
            RdpClientData         = $RdpClientData.Values
        }

        $ReturnObj = New-Object -TypeName PSObject -Property $Properties
        return $ReturnObj
    }
}

function Find-4648Logons {
    <#
    .SYNOPSIS
    Retrieve the unique 4648 logon events. This will often find cases where a user is using remote desktop to connect to another computer. It will give the
    the account that RDP was launched with and the account name of the account being used to connect to the remote computer. This is useful
    for identifying normal authentication patterns. Other actions that will trigger this include any runas action.

    .DESCRIPTION
    Retrieve the unique 4648 logon events. This will often find cases where a user is using remote desktop to connect to another computer. It will give the
    the account that RDP was launched with and the account name of the account being used to connect to the remote computer. This is useful
    for identifying normal authentication patterns. Other actions that will trigger this include any runas action.

    .PARAMETER SecurityLog
    The Security event log to search.

    .EXAMPLE
    Find-4648Logons $SecurityLog
    Gets the unique 4648 logon events.

    .NOTES
    Author: Joe Bialek, Twitter: @JosephBialek
    Version: 1.1

    .LINK
    Blog: http://clymb3r.wordpress.com/
    Github repo: https://github.com/clymb3r/PowerShell
    #>

    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true)]
        $SecurityLog
    )

    $ExplicitLogons = $SecurityLog | Where-Object { $_.InstanceID -eq 4648 }
    $ResultInfo = @{}

    foreach ($ExplicitLogon in $ExplicitLogons) {
        $Subject = $false
        $AccountWhosCredsUsed = $false
        $TargetServer = $false
        $SourceAccountName = ""
        $SourceAccountDomain = ""
        $TargetAccountName = ""
        $TargetAccountDomain = ""
        $TargetServer = ""

        foreach ($line in $ExplicitLogon.Message -split "\r\n") {
            if ($line -match "^Subject:$") {
                $Subject = $true
            }
            elseif ($line -match "^Account\sWhose\sCredentials\sWere\sUsed:$") {
                $Subject = $false
                $AccountWhosCredsUsed = $true
            }
            elseif ($line -match "^Target\sServer:") {
                $AccountWhosCredsUsed = $false
                $TargetServer = $true
            }
            elseif ($Subject) {
                if ($line -match "\s+Account\sName:\s+(\S.*)") {
                    $SourceAccountName = $Matches[1]
                }
                elseif ($line -match "\s+Account\sDomain:\s+(\S.*)") {
                    $SourceAccountDomain = $Matches[1]
                }
            }
            elseif ($AccountWhosCredsUsed) {
                if ($line -match "\s+Account\sName:\s+(\S.*)") {
                    $TargetAccountName = $Matches[1]
                }
                elseif ($line -match "\s+Account\sDomain:\s+(\S.*)") {
                    $TargetAccountDomain = $Matches[1]
                }
            }
            elseif ($TargetServer) {
                if ($line -match "\s+Target\sServer\sName:\s+(\S.*)") {
                    $TargetServer = $Matches[1]
                }
            }
        }

        # Filter out logins that don't matter
        if (-not ($TargetAccountName -match "^DWM-.*" -and $TargetAccountDomain -match "^Window\sManager$")) {
            $Key = "$SourceAccountName$SourceAccountDomain$TargetAccountName$TargetAccountDomain$TargetServer"
            if (-not $ResultInfo.ContainsKey($Key)) {
                $Properties = @{
                    LogType            = 4648
                    LogSource          = "Security"
                    SourceAccountName  = $SourceAccountName
                    SourceDomainName   = $SourceAccountDomain
                    TargetAccountName  = $TargetAccountName
                    TargetDomainName   = $TargetAccountDomain
                    TargetServer       = $TargetServer
                    Count              = 1
                    Times              = @($ExplicitLogon.TimeGenerated)
                }

                $ResultObj = New-Object -TypeName PSObject -Property