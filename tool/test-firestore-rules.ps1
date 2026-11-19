$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$firebaseWorkDir = Join-Path $projectRoot '.firebase'
$env:FIREBASE_EMULATORS_PATH = Join-Path $firebaseWorkDir 'emulators'
$env:TEMP = Join-Path $firebaseWorkDir 'temp'
$env:TMP = $env:TEMP

New-Item -ItemType Directory -Force -Path $env:FIREBASE_EMULATORS_PATH, $env:TEMP | Out-Null

Push-Location $projectRoot
try {
  firebase emulators:exec --only firestore "npm.cmd --prefix admin-dashboard run test:rules"
  if ($LASTEXITCODE -ne 0) {
    throw "Firestore rules tests failed with exit code $LASTEXITCODE."
  }
} finally {
  Pop-Location
}
