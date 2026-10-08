<#
.SYNOPSIS
    Forwards a Claude Code hook event to a running ukagaka ghost as an SSTP NOTIFY.

.DESCRIPTION
    Claude Code runs this script as an async command hook and writes the hook input (JSON) to stdin.
    The script sends one request to SSP on 127.0.0.1:

        NOTIFY SSTP/1.1
        Charset: UTF-8
        Sender: Claude Code
        ReceiverGhostName: Claudia
        Event: OnClaudeCodeHook
        Reference0: <hook_event_name>
        Reference1: <session_id>
        Reference2: <cwd>
        Reference3: <the hook input as one line of JSON; long strings are cut>

    When SSP is not running, the connection is refused at once and the script ends quietly.
    It never writes to stdout, so Claude Code receives no decision from it.

    Environment variables (all optional):
        UKAGAKA_NOTIFY_GHOST  \0 name of the receiving ghost. Default: Claudia. "*" sends without a receiver
                              (SSP then picks the active ghost).
        UKAGAKA_NOTIFY_PORT   SSTP port. Default: 9801.

    Written in ASCII only so that Windows PowerShell 5.1 reads it correctly without a BOM.
#>
param(
    [string]$Ghost = $env:UKAGAKA_NOTIFY_GHOST,
    [int]$Port = 0
)

$ErrorActionPreference = 'Stop'
$utf8 = New-Object System.Text.UTF8Encoding($false)

if (-not $Ghost) { $Ghost = 'Claudia' }
if ($Port -le 0) {
    $Port = 9801
    if ($env:UKAGAKA_NOTIFY_PORT -match '^\d+$') { $Port = [int]$env:UKAGAKA_NOTIFY_PORT }
}

# Longest string kept in Reference3. Hook inputs can carry whole files (Write) or long messages.
$MaxString = 400

function Limit-Strings($value) {
    if ($null -eq $value) { return $null }
    if ($value -is [string]) {
        if ($value.Length -gt $MaxString) { return $value.Substring(0, $MaxString) + '...' }
        return $value
    }
    if ($value -is [System.Management.Automation.PSCustomObject]) {
        foreach ($p in @($value.PSObject.Properties)) { $p.Value = Limit-Strings $p.Value }
        return $value
    }
    if ($value -is [System.Array]) {
        return ,@($value | ForEach-Object { Limit-Strings $_ })
    }
    return $value
}

# SSTP header values are single lines.
function Format-HeaderValue([string]$text) {
    if ($null -eq $text) { return '' }
    return ($text -replace "[\r\n\x00]+", ' ')
}

try {
    $reader = New-Object System.IO.StreamReader([Console]::OpenStandardInput(), $utf8)
    $raw = $reader.ReadToEnd()
} catch {
    exit 0
}

$hookEvent = ''
$session = ''
$cwd = ''
$detail = ''
try {
    $data = $raw | ConvertFrom-Json
    $hookEvent = [string]$data.hook_event_name
    $session = [string]$data.session_id
    $cwd = [string]$data.cwd
    # The last reply of the assistant is long and not needed by the ghost.
    if ($data.PSObject.Properties['last_assistant_message']) { $data.PSObject.Properties.Remove('last_assistant_message') }
    $data = Limit-Strings $data
    $detail = $data | ConvertTo-Json -Compress -Depth 20
} catch {
    exit 0
}
if (-not $hookEvent) { exit 0 }

$lines = @(
    'NOTIFY SSTP/1.1',
    'Charset: UTF-8',
    'Sender: Claude Code'
)
if ($Ghost -ne '*') { $lines += 'ReceiverGhostName: ' + (Format-HeaderValue $Ghost) }
$lines += @(
    'Event: OnClaudeCodeHook',
    ('Reference0: ' + (Format-HeaderValue $hookEvent)),
    ('Reference1: ' + (Format-HeaderValue $session)),
    ('Reference2: ' + (Format-HeaderValue $cwd)),
    ('Reference3: ' + (Format-HeaderValue $detail))
)

$client = New-Object System.Net.Sockets.TcpClient
try {
    # SSP not running: localhost refuses at once. The wait only guards against a stuck listener.
    $connect = $client.BeginConnect('127.0.0.1', $Port, $null, $null)
    if (-not $connect.AsyncWaitHandle.WaitOne(1000)) { exit 0 }
    try { $client.EndConnect($connect) } catch { exit 0 }

    $client.ReceiveTimeout = 5000
    $stream = $client.GetStream()
    $bytes = $utf8.GetBytes(($lines -join "`r`n") + "`r`n`r`n")
    $stream.Write($bytes, 0, $bytes.Length)
    # Read the status line so that SSP finishes the request before the socket closes.
    $response = New-Object System.IO.StreamReader($stream, $utf8)
    try { [void]$response.ReadLine() } catch { }
} catch {
} finally {
    $client.Close()
}
exit 0
