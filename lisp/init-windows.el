;; init-windows.el 	-*- lexical-binding: t -*-
;;
;; Windows 专项、无其它调用方的设置统一收在这里（原分散在 early-init.el 与
;; lisp/init-git.el）：文件属性/管道调优、控制台代码页、剪贴板编码、git 环境变量。
;; 全部一次性 fire-and-forget，没有别的模块会 require/调用这个文件里的东西。
;; 非 Windows 平台整个文件是空操作。
;;
;; 跨平台功能（哪怕其中一个分支主要是给 Windows 写的，比如输入法切换）不属于
;; 这里，应放在功能所属的模块、或按能力命名的共享文件——见 lisp/init-ime.el
;; 及 AGENTS.md「多平台代码怎么归位」一节。
;;
;; 由 `early-init.el' 在最早期用绝对路径 `load'（那时 `lisp/' 还没被 init.el
;; 加进 load-path，`require' 用不了）；全量/精简两套 profile 都会加载到。

(when (eq system-type 'windows-nt)
  ;; 文件属性与子进程管道。对 LSP / magit 这种高频起子进程、高频 stat 文件的
  ;; 场景影响最明显。
  (when (boundp 'w32-get-true-file-attributes)
    (setq w32-get-true-file-attributes nil     ; 不去解析真实 uid/gid/链接数，这步很贵
          w32-pipe-read-delay 0                ; 子进程管道读取不再等 50ms → LSP/git 响应更跟手
          w32-pipe-buffer-size (* 64 1024)))   ; 管道缓冲区调大，减少大响应的分批次数

  ;; 控制台代码页 + 剪贴板编码：不设的话中文在 --batch 控制台输出、
  ;; 或跨程序剪贴板粘贴时容易乱码。
  (set-selection-coding-system 'utf-16le-dos)
  (w32-set-console-codepage 65001)
  (w32-set-console-output-codepage 65001)

  ;; 给 git 子进程定几个环境变量（原在 lisp/init-git.el）：magit 一次刷新会起
  ;; 很多次 git，这几项能避免"卡在等输入"和无谓的锁竞争。
  (setenv "GIT_TERMINAL_PROMPT" "0")   ; 需要凭据时直接失败，不在无终端处挂起
  (setenv "GIT_ASK_YESNO" "false")     ; 同上，不弹交互确认
  (setenv "GIT_PAGER" "cat")           ; 不起分页器
  (setenv "GIT_OPTIONAL_LOCKS" "0"))   ; 只读操作不抢 index.lock，减少与后台 git 的竞争

(provide 'init-windows)
