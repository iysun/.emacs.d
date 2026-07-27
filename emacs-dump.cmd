@echo off
:: emacs-dump.cmd — 用 portable dump 映像启动 Emacs（加速启动）
:: 用法：双击或在命令行执行，支持传额外参数，如 emacs-dump.cmd somefile.txt
::
:: dump 映像（emacs.pdmp）必须与当前 emacs 二进制匹配。
:: 装/删包或 scoop update emacs 后须先 make dump 重建。
:: 「装/删包后忘了重建」这种静默失效由 init-full.el 的 my/check-pdmp-freshness
:: 在启动时检查并告警（比在本脚本里比时间戳更准，也覆盖手动 --dump-file 启动）。

set "PDMP=%~dp0emacs.pdmp"

if exist "%PDMP%" (
    emacs --dump-file="%PDMP%" %*
) else (
    echo [emacs-dump] emacs.pdmp 不存在，回退到普通启动。先运行 make dump 生成映像。
    emacs %*
)
