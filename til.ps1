# til.ps1 — TIL 파일 생성 + VS Code 열기 + 자동 add/commit/push

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
Set-Location -Path $PSScriptRoot

# 날짜·경로
$today = Get-Date
$date  = $today.ToString("yyyy-MM-dd")
$year  = $today.ToString("yyyy")
$month = $today.ToString("MM")

$dir      = Join-Path $PSScriptRoot "$year\$month"
$new      = Join-Path $dir "$date.md"
$template = Join-Path $PSScriptRoot "template.md"

# 디렉터리 생성
New-Item -ItemType Directory -Force -Path $dir | Out-Null

# 파일 생성(템플릿 우선)
if (-not (Test-Path $new)) {
    if (Test-Path $template) {
        $content = Get-Content $template -Raw -Encoding UTF8
        $content = $content.Replace("{{DATE}}", $date)
        Set-Content -Path $new -Value $content -Encoding UTF8
    } else {
        $fallback = @"
# $date TIL

## 오늘 한 일
- 

## 배운 점
- 

## 이슈/에러와 해결
- 

## 내일 할 일
- 
"@
        Set-Content -Path $new -Value $fallback -Encoding UTF8
    }
}

# VS Code로 열기(미설치면 기본 앱)
if (Get-Command code -ErrorAction SilentlyContinue) { code $new } else { Start-Process $new }

# Git 자동 처리(.git 있을 때만)
if (Test-Path (Join-Path $PSScriptRoot ".git")) {
    try {
        # 브랜치 결정
        $branch = (git rev-parse --abbrev-ref HEAD 2>$null)
        if (-not $branch -or $branch -eq "HEAD") {
            $branch = "main"
            git branch -M $branch 2>$null
        }

        # 원격 확인(없으면 안내만)
        $hasOrigin = (git remote 2>$null) -contains "origin"
        if (-not $hasOrigin) {
            Write-Host "hint: 원격 미설정. 먼저 'git remote add origin <URL>' 실행."
            return
        }

        # 스테이징 → 변경 있을 때만 커밋
        git add -- $new
        $changes = git status --porcelain
        if ($changes) {
            git commit -m "TIL: $date"
        } else {
            Write-Host "hint: 커밋할 변경 없음."
        }

        # 푸시
        git push -u origin $branch
    } catch {
        Write-Host "git 오류: $($_.Exception.Message)"
    }
} else {
    Write-Host "hint: Git repo 아님. 'git init' 후 사용."
}
