# til.ps1 — Create TIL + open in VS Code + auto git add/commit/push (+Regenerate option)

param(
    [switch]$Regenerate  # force regenerate today's file
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
Set-Location -Path $PSScriptRoot

# Date parts
$today = Get-Date
$date  = $today.ToString("yyyy-MM-dd")
$year  = $today.ToString("yyyy")
$month = $today.ToString("MM")

# Paths
$dir      = Join-Path $PSScriptRoot "$year\$month"
$new      = Join-Path $dir "$date.md"
$template = Join-Path $PSScriptRoot "template.md"

# Ensure directory
New-Item -ItemType Directory -Force -Path $dir | Out-Null

# Build content
function New-TilContent {
    param([string]$TemplatePath, [string]$Date)

    if (Test-Path $TemplatePath) {
        Write-Host "info: using template.md" -ForegroundColor Cyan
        $content = Get-Content $TemplatePath -Raw -Encoding UTF8
        $content = $content.Replace("{{DATE}}", $Date).Replace("{{date}}", $Date)
        return $content
    }
    else {
        Write-Host "info: using fallback template" -ForegroundColor Yellow
        $fallback = @"
# 🗓️ $Date TIL

---

# ✅ 오늘 한 일
- 

---

# 📚 배운 점
> 오늘 학습한 핵심 개념과 예시를 기록

# 📌 핵심 개념
- 

# 💡 예시 코드
```python
# 예시 코드

# 🛠️ 이슈 & 해결
| 🐞 문제 상황 | 🔍 원인 | 💡 해결 방법 |
|--------------|--------|--------------|
|  |  |  |

## 🎯 내일 할 일
- 📚 
- 💻 
"@
        return $fallback
    }
}

# Decide creation
$shouldCreate = $true
if (Test-Path $new) {
    if ($Regenerate) {
        Write-Host "info: -Regenerate specified -> overwriting today's file" -ForegroundColor Green
    }
    else {
        if (Test-Path $template) {
            $tmplTime = (Get-Item $template).LastWriteTimeUtc
            $fileTime = (Get-Item $new).LastWriteTimeUtc
            if ($tmplTime -gt $fileTime) {
                Write-Host "info: template.md is newer -> regenerate" -ForegroundColor Green
                $Regenerate = $true
            }
            else {
                $shouldCreate = $false
            }
        }
        else {
            $shouldCreate = $false
        }
    }
}

# Create/Update file
if ($shouldCreate -or $Regenerate) {
    $text = New-TilContent -TemplatePath $template -Date $date
    Set-Content -Path $new -Value $text -Encoding UTF8
}
else {
    Write-Host "hint: today's file exists and template is not newer -> skip" -ForegroundColor DarkGray
}

# Open in VS Code (fallback to default app)
if (Get-Command code -ErrorAction SilentlyContinue) {
    code $new
}
else {
    Start-Process $new
}

# Git automation (stage all changes, commit if any, then push)
if (Test-Path (Join-Path $PSScriptRoot ".git")) {
    try {
        $branch = (git rev-parse --abbrev-ref HEAD 2>$null)
        if (-not $branch -or $branch -eq "HEAD") {
            $branch = "main"
            git branch -M $branch 2>$null
        }

        $hasOrigin = (git remote 2>$null) -contains "origin"
        if (-not $hasOrigin) {
            Write-Host "hint: no remote 'origin'. Run: git remote add origin <URL>"
            return
        }

        # 1) 스테이징: 변경/삭제/추가 모두 포함
        git add -A

        # 2) 커밋할 내용이 있는지 확인
        $changes = git status --porcelain
        if ($changes) {
            git commit -m "TIL: $date"
        }
        else {
            Write-Host "hint: no changes to commit."
        }

        # 3) 푸시
        git push -u origin $branch
    }
    catch {
        Write-Host ("git error: " + $_.Exception.Message)
    }
}
else {
    Write-Host "hint: not a Git repo. Run 'git init' first."
}
