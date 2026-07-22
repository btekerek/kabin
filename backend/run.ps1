# Starts the backend for local dev: activates the venv, applies any
# pending migrations, then runs daphne bound to 0.0.0.0 so phones on the
# same Wi-Fi (not just this machine) can reach it 

# Usage (from anywhere): powershell -File backend\run.ps1
# Or from inside backend\:                .\run.ps1

$ErrorActionPreference = "Stop"

# Resolve paths relative to this script's own location, so it works
# regardless of what directory you run it from.
Set-Location $PSScriptRoot

Write-Host "Activating virtualenv..." -ForegroundColor Cyan
. .\.venv\Scripts\Activate.ps1

Write-Host "Applying migrations..." -ForegroundColor Cyan
python manage.py migrate
if ($LASTEXITCODE -ne 0) {
    Write-Host "migrate failed (exit code $LASTEXITCODE) - not starting the server." -ForegroundColor Red
    exit $LASTEXITCODE
}

Write-Host "Starting daphne on 0.0.0.0:8000..." -ForegroundColor Cyan
daphne -b 0.0.0.0 -p 8000 config.asgi:application
