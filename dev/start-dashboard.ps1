# =============================================================================
# Dify Dashboard Development Startup Script (Windows)
# =============================================================================

Write-Host "🚀 Starting Dify Dashboard Development Environment..." -ForegroundColor Green

# Check if .env exists
if (-not (Test-Path ".env")) {
    Write-Host "📝 Creating .env file from .env.example..." -ForegroundColor Yellow
    Copy-Item ".env.example" ".env"
    Write-Host "✅ Please edit .env file with your configuration" -ForegroundColor Green
}

# Start database and redis
Write-Host "🗄️ Starting database services..." -ForegroundColor Blue
Set-Location docker
docker-compose up -d db redis

# Wait for database to be ready
Write-Host "⏳ Waiting for database to be ready..." -ForegroundColor Yellow
Start-Sleep -Seconds 10

# Run migrations
Write-Host "🔄 Running database migrations..." -ForegroundColor Blue
Set-Location ..\api
uv run flask db upgrade

# Start API server
Write-Host "🌐 Starting API server..." -ForegroundColor Blue
$apiJob = Start-Job -ScriptBlock {
    Set-Location $using:PWD
    uv run flask run --host 0.0.0.0 --port 5001 --debug
}

# Wait for API to start
Start-Sleep -Seconds 5

# Start Dashboard
Write-Host "📊 Starting Dashboard..." -ForegroundColor Blue
Set-Location ..\dashboard
$env:API_URL = "http://localhost:5001"
$dashboardJob = Start-Job -ScriptBlock {
    Set-Location $using:PWD
    streamlit run main.py --server.port=8501 --server.address=0.0.0.0
}

Write-Host "✅ Dashboard development environment started!" -ForegroundColor Green
Write-Host ""
Write-Host "🔗 Access URLs:" -ForegroundColor Cyan
Write-Host "   Dashboard: http://localhost:8501" -ForegroundColor White
Write-Host "   API:       http://localhost:5001" -ForegroundColor White
Write-Host "   Login:     admin / @DifyAdmin2024" -ForegroundColor White
Write-Host ""
Write-Host "🛑 To stop: Press Ctrl+C" -ForegroundColor Red

# Keep script running and monitor jobs
try {
    while ($true) {
        Start-Sleep -Seconds 1
        if ($apiJob.State -eq "Failed" -or $dashboardJob.State -eq "Failed") {
            Write-Host "❌ One of the services failed!" -ForegroundColor Red
            break
        }
    }
} finally {
    Write-Host "🛑 Stopping services..." -ForegroundColor Yellow
    Stop-Job $apiJob, $dashboardJob -ErrorAction SilentlyContinue
    Remove-Job $apiJob, $dashboardJob -ErrorAction SilentlyContinue
}
