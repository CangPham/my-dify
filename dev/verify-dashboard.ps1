# =============================================================================
# Dashboard Integration Verification Script
# =============================================================================

Write-Host "🔍 Verifying Dashboard Integration..." -ForegroundColor Green

$errors = @()
$warnings = @()

# Check files exist
Write-Host "`n📁 Checking file structure..." -ForegroundColor Blue

$requiredFiles = @(
    "dashboard/main.py",
    "dashboard/config.yaml",
    "dashboard/Dockerfile",
    "api/controllers/dashboard/__init__.py",
    "api/controllers/dashboard/accounts.py",
    "api/models/alies_payments_custom.py",
    "docker/docker-compose.yaml",
    ".env.example"
)

foreach ($file in $requiredFiles) {
    if (Test-Path $file) {
        Write-Host "  ✅ $file" -ForegroundColor Green
    } else {
        Write-Host "  ❌ $file" -ForegroundColor Red
        $errors += "Missing file: $file"
    }
}

# Check blueprint registration
Write-Host "`n🔧 Checking blueprint registration..." -ForegroundColor Blue
$blueprintFile = "api/extensions/ext_blueprints.py"
if (Test-Path $blueprintFile) {
    $content = Get-Content $blueprintFile -Raw
    if ($content -match "dashboard_bp") {
        Write-Host "  ✅ Dashboard blueprint registered" -ForegroundColor Green
    } else {
        Write-Host "  ❌ Dashboard blueprint not registered" -ForegroundColor Red
        $errors += "Dashboard blueprint not registered in ext_blueprints.py"
    }
}

# Check docker-compose configuration
Write-Host "`n🐳 Checking Docker configuration..." -ForegroundColor Blue
$dockerFile = "docker/docker-compose.yaml"
if (Test-Path $dockerFile) {
    $content = Get-Content $dockerFile -Raw
    if ($content -match "dashboard:") {
        Write-Host "  ✅ Dashboard service configured" -ForegroundColor Green
    } else {
        Write-Host "  ❌ Dashboard service not configured" -ForegroundColor Red
        $errors += "Dashboard service not configured in docker-compose.yaml"
    }

    if ($content -match "8501:8501") {
        Write-Host "  ✅ Dashboard port exposed" -ForegroundColor Green
    } else {
        Write-Host "  ⚠️ Dashboard port not exposed" -ForegroundColor Yellow
        $warnings += "Dashboard port 8501 not exposed in docker-compose.yaml"
    }
}

# Check model imports
Write-Host "`n📊 Checking model imports..." -ForegroundColor Blue
$modelsFile = "api/models/__init__.py"
if (Test-Path $modelsFile) {
    $content = Get-Content $modelsFile -Raw
    $customModels = @("AliesPaymentsCustom", "PaymentsHistoryCustom", "SystemCustomInfo")

    foreach ($model in $customModels) {
        if ($content -match $model) {
            Write-Host "  ✅ $model imported" -ForegroundColor Green
        } else {
            Write-Host "  ❌ $model not imported" -ForegroundColor Red
            $errors += "Model $model not imported in models/__init__.py"
        }
    }
}

# Check Account model fields
Write-Host "`n👤 Checking Account model..." -ForegroundColor Blue
$accountFile = "api/models/account.py"
if (Test-Path $accountFile) {
    $content = Get-Content $accountFile -Raw
    $requiredFields = @("id_custom_plan", "plan_expiration", "month_before_banned", "max_of_apps")

    foreach ($field in $requiredFields) {
        if ($content -match $field) {
            Write-Host "  ✅ $field field added" -ForegroundColor Green
        } else {
            Write-Host "  ❌ $field field missing" -ForegroundColor Red
            $errors += "Account model missing field: $field"
        }
    }
}

# Summary
Write-Host "`n📋 Verification Summary:" -ForegroundColor Cyan
if ($errors.Count -eq 0) {
    Write-Host "  ✅ All checks passed!" -ForegroundColor Green
} else {
    Write-Host "  ❌ $($errors.Count) errors found:" -ForegroundColor Red
    foreach ($error in $errors) {
        Write-Host "    - $error" -ForegroundColor Red
    }
}

if ($warnings.Count -gt 0) {
    Write-Host "  ⚠️ $($warnings.Count) warnings:" -ForegroundColor Yellow
    foreach ($warning in $warnings) {
        Write-Host "    - $warning" -ForegroundColor Yellow
    }
}

Write-Host "`n🚀 Next steps:" -ForegroundColor Cyan
Write-Host "  1. Fix any errors above" -ForegroundColor White
Write-Host "  2. Run: .\dev\start-dashboard.ps1" -ForegroundColor White
Write-Host "  3. Test: http://localhost:8501" -ForegroundColor White
Write-Host "  4. Login: admin / DifyAdmin2024" -ForegroundColor White
