---
name: run
description: 批处理加载验证全量 + 精简两套 profile，确认配置能无错加载，按错修复
---

验证本 Emacs 配置能否正常加载。两套 profile 都用 `--batch` 加载，捕捉加载期错误。

## A. 全量 profile

```powershell
emacs --batch `
  --eval "(setq user-emacs-directory (file-name-as-directory (expand-file-name `".`")))" `
  --eval "(setq debug-on-error t)" `
  --load early-init.el --load init.el `
  --eval "(message `"== FULL PROFILE LOADED OK ==`")" 2>&1 | Select-Object -Last 8
Write-Output "EXIT=$LASTEXITCODE"
```

## B. 精简 profile

```powershell
$env:EMACS_MINIMAL = "1"
emacs --batch `
  --eval "(setq user-emacs-directory (file-name-as-directory (expand-file-name `".`")))" `
  --eval "(setq debug-on-error t)" `
  --load init.el `
  --eval "(message `"== MINIMAL PROFILE LOADED OK ==`")" 2>&1 | Select-Object -Last 6
Write-Output "EXIT=$LASTEXITCODE"
Remove-Item Env:\EMACS_MINIMAL
```

看到对应的 `== … LOADED OK ==` 且 `EXIT=0`、无回溯 → 该 profile 通过。

## 判断与修复

- **真 bug（要修）**：`Cannot open load file`（缺包/缺 require）、`void-function`、`void-variable`、
  `Symbol's value as variable is void`、`wrong-type-argument`、模块加载顺序错。
  按回溯定位 `文件:行` 修，回到对应步骤重验。
- **可忽略**：evil-collection 关于 issue #60 的提示等信息性输出（非错误）。

## 注意

- 批处理无 GUI，只验证「能否无错加载」。**视觉外观**（字体/主题/modeline/tab）仍需启动真实 Emacs 肉眼确认：
  `emacs`（全量）/ `emacs --minimal`（精简），看 `*Messages*` 与 `*Warnings*`。
- 包要已装在 `elpa/`；报缺包多半是首次安装没跑完——让用户在交互 Emacs 里触发安装。
- 别修改 `elpa/`、`custom.el`；别在工作区留 `.elc`（交互会话 `load-prefer-newer` 为 nil，旧 `.elc` 会盖过新 `.el`）。
