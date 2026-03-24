$outFile = "$env:TEMP\ethy_bot_cmd.txt"
$last = ""
while ($true) {
    Start-Sleep -Seconds 1
    try {
        $clip = Get-Clipboard -ErrorAction SilentlyContinue
        if ($clip -and $clip.StartsWith("!") -and $clip -ne $last) {
            $last = $clip
            Set-Content -Path $outFile -Value $clip -NoNewline
        }
    } catch {}
}
