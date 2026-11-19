$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$firebaseWorkDir = Join-Path $projectRoot '.firebase'
$env:TEMP = Join-Path $firebaseWorkDir 'temp'
$env:TMP = $env:TEMP
$env:npm_config_cache = Join-Path $firebaseWorkDir 'npm-cache'

New-Item -ItemType Directory -Force -Path $env:TEMP, $env:npm_config_cache | Out-Null

Push-Location $projectRoot
try {
  npm.cmd --prefix admin-dashboard ci
  if ($LASTEXITCODE -ne 0) { throw "npm ci failed with exit code $LASTEXITCODE." }

  npm.cmd --prefix admin-dashboard run build
  if ($LASTEXITCODE -ne 0) { throw "Dashboard build failed with exit code $LASTEXITCODE." }

  firebase deploy --only firestore:rules,hosting --project shopaflow
  if ($LASTEXITCODE -ne 0) { throw "Firebase deployment failed with exit code $LASTEXITCODE." }
} finally {
  Pop-Location
}
