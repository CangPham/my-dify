# Script để kiểm tra và undo các file chỉ thay đổi line ending
param(
    [switch]$DryRun = $false
)

Write-Host "Đang kiểm tra các file có thay đổi line ending..." -ForegroundColor Yellow

# Lấy danh sách tất cả file đã thay đổi
$modifiedFiles = git status --porcelain | Where-Object { $_ -match "^ M " } | ForEach-Object { $_.Substring(3) }

$lineEndingOnlyFiles = @()
$realChangedFiles = @()

foreach ($file in $modifiedFiles) {
    Write-Host "Kiểm tra: $file" -ForegroundColor Cyan
    
    # Kiểm tra diff của file
    $diffOutput = git diff --no-index --ignore-space-at-eol --ignore-blank-lines --ignore-all-space $file 2>$null
    
    if ($LASTEXITCODE -eq 0 -or [string]::IsNullOrWhiteSpace($diffOutput)) {
        # Nếu không có diff hoặc diff rỗng, có thể chỉ là line ending
        $lineEndingOnlyFiles += $file
        Write-Host "  -> Chỉ thay đổi line ending" -ForegroundColor Green
    } else {
        $realChangedFiles += $file
        Write-Host "  -> Có thay đổi nội dung thực" -ForegroundColor Red
    }
}

Write-Host "`n=== KẾT QUẢ ===" -ForegroundColor Yellow
Write-Host "Files chỉ thay đổi line ending: $($lineEndingOnlyFiles.Count)" -ForegroundColor Green
Write-Host "Files có thay đổi nội dung: $($realChangedFiles.Count)" -ForegroundColor Red

if ($lineEndingOnlyFiles.Count -gt 0) {
    Write-Host "`nFiles chỉ thay đổi line ending:" -ForegroundColor Green
    $lineEndingOnlyFiles | ForEach-Object { Write-Host "  $_" }
    
    if (-not $DryRun) {
        $confirm = Read-Host "`nBạn có muốn undo các file chỉ thay đổi line ending? (y/N)"
        if ($confirm -eq 'y' -or $confirm -eq 'Y') {
            Write-Host "Đang undo các file chỉ thay đổi line ending..." -ForegroundColor Yellow
            
            foreach ($file in $lineEndingOnlyFiles) {
                git checkout -- $file
                Write-Host "  Đã undo: $file" -ForegroundColor Green
            }
            
            Write-Host "`nHoàn thành! Đã undo $($lineEndingOnlyFiles.Count) files." -ForegroundColor Green
        }
    } else {
        Write-Host "`n[DRY RUN] Sẽ undo $($lineEndingOnlyFiles.Count) files" -ForegroundColor Yellow
    }
}

if ($realChangedFiles.Count -gt 0) {
    Write-Host "`nFiles có thay đổi nội dung thực (sẽ giữ lại):" -ForegroundColor Red
    $realChangedFiles | ForEach-Object { Write-Host "  $_" }
}
