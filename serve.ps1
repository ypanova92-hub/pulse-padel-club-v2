# Minimal static preview server: powershell -File serve.ps1
# Supports byte ranges (video). Open index.html?slow=1 to delay the court and player PNGs by 4 s each for fallback testing.
$root = $PSScriptRoot
$port = if ($env:PORT) { [int]$env:PORT } else { 4174 }
$types = @{ '.html'='text/html; charset=utf-8'; '.svg'='image/svg+xml'; '.jpg'='image/jpeg'; '.png'='image/png'; '.webp'='image/webp'; '.mp4'='video/mp4'; '.css'='text/css'; '.js'='text/javascript' }
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$port/")
$listener.Start()
Write-Host "Serving $root at http://localhost:$port"
while ($listener.IsListening) {
  $ctx = $listener.GetContext()
  $req = $ctx.Request
  $res = $ctx.Response
  $path = [Uri]::UnescapeDataString($req.Url.LocalPath).TrimStart('/')
  if (-not $path) { $path = 'index.html' }
  $file = [IO.Path]::GetFullPath((Join-Path $root $path))
  if ($file.StartsWith($root) -and (Test-Path $file -PathType Leaf)) {
    $ext = [IO.Path]::GetExtension($file)
    if ($path -match 'court|player' -and $req.UrlReferrer -and $req.UrlReferrer.Query -match 'slow=1') { Start-Sleep -Milliseconds 4000 }
    $bytes = [IO.File]::ReadAllBytes($file)
    $res.ContentType = $types[$ext]
    $res.AddHeader('Accept-Ranges', 'bytes')
    $start = 0; $end = $bytes.Length - 1
    $range = $req.Headers['Range']
    if ($range -match 'bytes=(\d*)-(\d*)') {
      if ($matches[1]) { $start = [int64]$matches[1] }
      if ($matches[2]) { $end = [Math]::Min([int64]$matches[2], $bytes.Length - 1) }
      $res.StatusCode = 206
      $res.AddHeader('Content-Range', "bytes $start-$end/$($bytes.Length)")
    }
    $len = $end - $start + 1
    $res.ContentLength64 = $len
    if ($req.HttpMethod -ne 'HEAD') {
      try { $res.OutputStream.Write($bytes, $start, $len) } catch { }
    }
  } else { $res.StatusCode = 404 }
  try { $res.Close() } catch { }
}
