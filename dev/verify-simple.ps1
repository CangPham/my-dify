Write-Host "Verifying Dashboard Integration..." -ForegroundColor Green

$errors = @()

# Check key files
$files = @(
    "dashboard/main.py",
    "dashboard/config.yaml", 
    "api/controllers/dashboard/__init__.py",
    "api/controllers/dashboard/accounts.py"
)

Write-Host "`nChecking files..." -ForegroundColor Blue
foreach ($file in $files) {
    if (Test-Path $file) {
        Write-Host "  OK: $file" -ForegroundColor Green
    } else {
        Write-Host "  MISSING: $file" -ForegroundColor Red
        $errors += $file
    }
}

# Check blueprint registration
Write-Host "`nChecking blueprint..." -ForegroundColor Blue
$content = Get-Content "api/extensions/ext_blueprints.py" -Raw
if ($content -match "dashboard_bp") {
    Write-Host "  OK: Blueprint registered" -ForegroundColor Green
} else {
    Write-Host "  ERROR: Blueprint not registered" -ForegroundColor Red
    $errors += "blueprint"
}

# Summary
Write-Host "`nSummary:" -ForegroundColor Cyan
if ($errors.Count -eq 0) {
    Write-Host "  All checks passed!" -ForegroundColor Green
    Write-Host "`nNext steps:" -ForegroundColor Yellow
    Write-Host "  1. Start database: docker-compose up -d db redis" -ForegroundColor White
    Write-Host "  2. Run migrations: cd api; uv run flask db upgrade" -ForegroundColor White
    Write-Host "  3. Start services: .\dev\start-dashboard.ps1" -ForegroundColor White
} else {
    Write-Host "  $($errors.Count) errors found" -ForegroundColor Red
}
