# install-fonts.ps1 — 把 assets/fonts/ 里 vendor 的字体装进当前用户（不需要管理员）
#
#   powershell -ExecutionPolicy Bypass -File scripts\install-fonts.ps1
#
# 复制到 %LOCALAPPDATA%\Microsoft\Windows\Fonts\，在
# HKCU\Software\Microsoft\Windows NT\CurrentVersion\Fonts 下登记（持久化，下次登录/开机
# 也生效），并当场对本会话调一次 AddFontResourceEx（非 private，全会话可见）+ 广播
# WM_FONTCHANGE——只写注册表不够：GDI 的会话级字体表不会因为注册表多了一条就自动重新
# 扫描，得显式把字体资源加进当前会话，装完马上开新 Emacs 才能看到，不用重新登录。
# 等价于把字体文件拖进"设置 → 个性化 → 字体"，Win10 1809+ 支持，全程不用管理员权限。
#
# 幂等：注册表项已存在且指向的文件确实在目标目录里，就跳过；-Force 强制重装
#（更新 assets/fonts/ 下的字体文件后用）。

param(
  [string]$Repo = (Split-Path -Parent $PSScriptRoot),
  [switch]$Force
)

# 清单：assets/fonts/ 里的文件 -> 装好后 Windows/Emacs 认得的 family 名。
# 这几个 family 名已经用 System.Drawing.Text.PrivateFontCollection 实测确认过
# （字体内部 name table 里到底叫什么，不能只看文件名猜），必须跟
# lisp/init-ui.el 字体候选表里的字符串完全一致，装完才会被 find-font 命中：
#   - JetBrainsMonoNL NFM ——注意不是 "JetBrainsMono NFM"，NoLigatures 变体在
#     name table 里带 "NL" 后缀，是为了跟 Ligatures 变体共存不冲突而故意设计的。
#   - 更纱终端书呆黑体-简 ——Sarasa Term SC Nerd 这个补丁版构建把中文名当成主 family
#     名，不是仓库里原来那个候选表项 "Sarasa Term SC Nerd" 的英文名。
#   - 思源黑体 ——Source Han Sans SC 同理，主 family 名是中文名。
#   - Noto Color Emoji / Symbola ——这两个跟候选表里已有的英文名一致，不用改。
# 文件名特意保留上游原名（含 "NL" 标记），别改短——本机实测踩过坑：改成
# "JetBrainsMonoNerdFontMono-Regular.ttf"（去掉 NL）会跟官方 nerd-fonts 安装器/
# 官网下载包会用的 Ligatures 变体文件同名，装到同一个每用户字体目录时互相覆盖，
# 注册表项目录名对得上、内容却是另一个变体，装完 find-font 认出来的字体驴唇不对马嘴。
$Manifest = @(
  @{ File = 'JetBrainsMonoNLNerdFontMono-Regular.ttf'; Name = 'JetBrainsMonoNL NFM' }
  @{ File = 'JetBrainsMonoNLNerdFontMono-Bold.ttf';     Name = 'JetBrainsMonoNL NFM Bold' }
  @{ File = 'SarasaTermSCNerd-Regular.ttf';             Name = '更纱终端书呆黑体-简' }
  @{ File = 'SourceHanSansSC-Regular.otf';              Name = '思源黑体' }
  @{ File = 'NotoColorEmoji-WindowsCompatible.ttf';     Name = 'Noto Color Emoji' }
  @{ File = 'Symbola.ttf';                              Name = 'Symbola' }
)

$fontsDir = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'
New-Item -ItemType Directory -Force -Path $fontsDir | Out-Null
$regKey = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'

Add-Type -AssemblyName System.Drawing
Add-Type -Namespace Win32Font -Name Native -MemberDefinition @'
  [DllImport("gdi32.dll", SetLastError=true, CharSet=CharSet.Auto)]
  public static extern int AddFontResourceEx(string lpFileName, uint fl, IntPtr pdv);
  [DllImport("user32.dll", SetLastError=true, CharSet=CharSet.Auto)]
  public static extern IntPtr SendMessageTimeout(IntPtr hWnd, uint Msg, UIntPtr wParam, IntPtr lParam, uint fuFlags, uint uTimeout, out IntPtr lpdwResult);
'@

$changed = $false
foreach ($f in $Manifest) {
  $src = Join-Path $Repo "assets\fonts\$($f.File)"
  if (-not (Test-Path $src)) {
    Write-Error "缺文件：$src —— assets/fonts/ 是不是没拉全？"
    continue
  }
  $destName  = Split-Path $src -Leaf
  $dest      = Join-Path $fontsDir $destName
  $ext       = [System.IO.Path]::GetExtension($destName).TrimStart('.').ToUpper()
  $valueName = "$($f.Name) ($ext)"

  $existingVal = (Get-ItemProperty -Path $regKey -Name $valueName -ErrorAction SilentlyContinue).$valueName
  $alreadyOk = (-not $Force) -and (Test-Path $dest) -and ($existingVal -eq $destName)
  if ($alreadyOk) {
    Write-Output "跳过（已装）：$valueName"
    # 已装过的也当场加载一次，保证本次会话里可用（比如上次装完没重启过 Emacs）。
    [Win32Font.Native]::AddFontResourceEx($dest, 0, [IntPtr]::Zero) | Out-Null
    continue
  }

  # 撞名保护：目标位置已经有同名文件、但不是本脚本注册表项指向的那个（既不是我们
  # 自己之前装的），说明是别的什么装过同名字体（比如官方 nerd-fonts 安装器）。
  # 字节比对：内容其实一样（比如那边装的就是同一份官方构建）就直接跳过复制——
  # 反正结果一致，还避开了"文件正被占用"的复制失败（已装好的字体文件会被 GDI
  # 一直开着，覆盖同内容的文件 Windows 也不让写）；内容不一样才是真正的冲突，
  # 报错跳过、不覆盖，不要把人家的字体文件静默换成我们的内容。
  $needCopy = $true
  if ((Test-Path $dest) -and ($existingVal -ne $destName)) {
    $srcHash  = (Get-FileHash -Path $src -Algorithm SHA256).Hash
    $destHash = (Get-FileHash -Path $dest -Algorithm SHA256).Hash
    if ($srcHash -ne $destHash) {
      Write-Error "撞名但内容不同，跳过：$dest 已存在（不是本脚本装的），不覆盖。如果确认可以覆盖，先手动删掉这个文件再重跑。"
      continue
    }
    $needCopy = $false
  }

  if ($needCopy) { Copy-Item -Path $src -Destination $dest -Force }
  New-ItemProperty -Path $regKey -Name $valueName -PropertyType String -Value $destName -Force | Out-Null
  $added = [Win32Font.Native]::AddFontResourceEx($dest, 0, [IntPtr]::Zero)
  if ($added -eq 0) {
    Write-Warning "$valueName 复制/注册表都写了，但 AddFontResourceEx 当场加载失败——重启 Emacs 应该还是能生效（下次登录会从注册表重新扫描），只是这次会话内可能看不到。"
  } else {
    Write-Output "已装：$valueName -> $dest"
  }
  $changed = $true
}

if ($changed) {
  $result = [IntPtr]::Zero
  # HWND_BROADCAST=0xffff, WM_FONTCHANGE=0x001D
  [Win32Font.Native]::SendMessageTimeout([IntPtr]0xffff, 0x001D, [UIntPtr]::Zero, [IntPtr]::Zero, 2, 3000, [ref]$result) | Out-Null
  Write-Output ""
  Write-Output "装完了。重启 Emacs 才能看到新字体（Emacs 自己的字体表是进程启动时读一次的）。"
} else {
  Write-Output "assets/fonts/ 里的字体都已经装好，无需操作。"
}
