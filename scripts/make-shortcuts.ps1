# make-shortcuts.ps1 — 在 Windows 开始菜单建 Emacs 快捷方式
#
#   powershell -ExecutionPolicy Bypass -File scripts\make-shortcuts.ps1
#
# 建两个入口（当前用户，不需要管理员）：
#   Emacs                   → runemacs.exe --dump-file=<repo>\emacs.pdmp   （日常，走映像）
#   Emacs (不用 dump 映像)  → runemacs.exe                                  （映像过期/损坏时兜底）
#
# 为什么是 runemacs.exe：emacs.exe 是控制台子系统，双击必弹一个多余的终端窗口；
# runemacs.exe 是 GUI 子系统，且会把参数原样转交给 emacs.exe。
# 为什么不指向 emacs-dump.cmd：.cmd 同样会挂一个控制台窗口。代价是快捷方式没有
# 「pdmp 缺失就回退普通启动」的逻辑，所以才需要上面第二个入口做手工兜底。

param(
  # emacs 的 bin 目录；留空则按 scoop 里的 msys2 位置推断
  # （PATH 上的 emacs 是 scoop shim，shim 目录里没有 runemacs.exe，推不出来）
  [string]$Bin,
  [string]$Repo = (Split-Path -Parent $PSScriptRoot)
)

if (-not $Bin) {
  $prefix = & scoop prefix msys2 2>$null
  if ($prefix) { $Bin = Join-Path $prefix "mingw64\bin" }
}

$runemacs = Join-Path $Bin "runemacs.exe"
if (-not (Test-Path $runemacs)) {
  Write-Error "找不到 $runemacs —— 用 -Bin 显式指定 emacs 的 bin 目录，例如 <scoop>\apps\msys2\current\mingw64\bin"
  exit 1
}

$pdmp = Join-Path $Repo "emacs.pdmp"
$sm   = [Environment]::GetFolderPath('Programs')
$ws   = New-Object -ComObject WScript.Shell

function New-Lnk($name, $argline, $desc) {
  $path = Join-Path $sm "$name.lnk"
  $s = $ws.CreateShortcut($path)
  $s.TargetPath       = $runemacs
  $s.Arguments        = $argline
  $s.WorkingDirectory = $env:USERPROFILE
  $s.IconLocation     = "$runemacs,0"
  $s.Description      = $desc
  $s.WindowStyle      = 1
  $s.Save()
  Write-Output $path
}

New-Lnk "Emacs" "--dump-file=`"$pdmp`"" "GNU Emacs (msys2/mingw64)，用 emacs.pdmp 映像加速启动"
New-Lnk "Emacs (不用 dump 映像)" "" "GNU Emacs (msys2/mingw64)，普通启动；emacs.pdmp 过期或损坏时用这个"
