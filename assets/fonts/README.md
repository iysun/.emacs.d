# assets/fonts/ —— vendor 进本仓库的字体

配置依赖的字体不能只靠"机器上恰好装了"来保证：`lisp/init-ui.el` 里图标码位用的
Nerd Font 补丁字体 Windows 不自带，新机器上会导致 mode-line/tab-line 图标渲染成
豆腐块 □。这里把能合法重新分发的那部分字体文件直接收进仓库，配 `scripts/install-fonts.ps1`
一键装进当前用户（不需要管理员），换新机器不用再手动找字体装。

详细说明（为什么选这几个字体、版权调研过程、如何重新 vendor）见
[docs/notes/vendored-fonts.md](../../docs/notes/vendored-fonts.md)。这里只列文件清单。

## 文件清单

| 文件 | 字体 | 许可证 | 上游出处 |
|---|---|---|---|
| `JetBrainsMonoNerdFontMono-Regular.ttf`<br>`JetBrainsMonoNerdFontMono-Bold.ttf` | JetBrainsMono Nerd Font Mono（NoLigatures，打过 Nerd Font 图标补丁） | OFL-1.1（`OFL-JetBrainsMono.txt`） | [ryanoasis/nerd-fonts](https://github.com/ryanoasis/nerd-fonts/tree/master/patched-fonts/JetBrainsMono/NoLigatures)，master 分支 |
| `SarasaTermSCNerd-Regular.ttf` | Sarasa Term SC Nerd（更纱黑体终端版，打过 Nerd 补丁，中英 2:1 等宽对齐） | OFL-1.1（`OFL-SarasaGothic.txt`） | [laishulu/Sarasa-Term-SC-Nerd](https://github.com/laishulu/Sarasa-Term-SC-Nerd) v2.3.1，从 `SarasaTermSCNerd-Unhinted.ttf.7z` 里只取 Regular 一个文件 |
| `SourceHanSansSC-Regular.otf` | Source Han Sans SC（思源黑体，简体中文） | OFL-1.1（`OFL-SourceHanSans.txt`） | [adobe-fonts/source-han-sans](https://github.com/adobe-fonts/source-han-sans) 2.005R，从 `09_SourceHanSansSC.zip` 里只取 `OTF/SimplifiedChinese/SourceHanSansSC-Regular.otf` |
| `NotoColorEmoji-WindowsCompatible.ttf` | Noto Color Emoji（Windows 兼容变体） | OFL-1.1（`OFL-NotoEmoji.txt`） | [googlefonts/noto-emoji](https://github.com/googlefonts/noto-emoji) main 分支 `fonts/NotoColorEmoji_WindowsCompatible.ttf` |
| `Symbola.ttf` | Symbola（George Douros，符号/古文字符集） | 作者自由分发授权（"Unicode Fonts for Ancient Scripts" 系列一贯声明可自由使用/编辑/再分发） | [na4zagin3/g1951d-fonts](https://github.com/na4zagin3/g1951d-fonts) 镜像的 `Symbola (v.8.00 2015-10-01).zip`，只取 `Symbola.ttf` |

总计约 50MB，纯 git 提交，未用 Git LFS。

## 明确没有 vendor 的字体（版权原因）

微软雅黑 / DengXian / Segoe UI Symbol / Segoe UI Emoji（Windows 专有授权字体）、
阿里巴巴普惠体、HarmonyOS Sans / Mi Sans ——这些字体的授权协议都明确禁止把字体文件
本身单独重新分发到像本仓库这样的公开渠道。它们仍然是 `lisp/init-ui.el` 候选表里的
选项（本机装了就用），只是不进 `assets/`。原因和调研过程见
[docs/notes/vendored-fonts.md](../../docs/notes/vendored-fonts.md)。

## 装到本机

```powershell
powershell -ExecutionPolicy Bypass -File scripts\install-fonts.ps1
```

装完重启 Emacs 生效。细节见脚本头部注释和 `docs/notes/vendored-fonts.md`。
