;; init-format.el 	-*- lexical-binding: t -*-
;;
;; apheleia：非 LSP 场景的格式化能力，手动触发。两者引擎不同——eglot-format
;; 靠 LSP 协议向 server 要格式化结果，apheleia 靠跑外部 CLI formatter 再 diff
;; 打 patch 回 buffer，apheleia 的 formatter 只能是外部命令规格，接不了 eglot
;; 协议调用，故两个引擎没法合并成一个；`SPC f`（见 init-keymaps.el 的
;; my/format-buffer）改为统一入口，按 buffer 是否有 eglot 托管自动分流。
;; 不开 apheleia-mode/apheleia-global-mode，不在存盘时自动跑——
;; apheleia-format-buffer 是独立命令，不依赖该 mode 也能按 apheleia-mode-alist /
;; apheleia-formatters 找到 formatter 并执行。
;;
;; 例外：emacs-lisp-mode。apheleia 自带的默认 apheleia-mode-alist 里已经映射了
;; (emacs-lisp-mode . lisp-indent)。它的格式化流程不管 formatter 是不是纯 Lisp
;; 函数，最后都要靠外部 diff/gdiff 生成 RCS patch 应用回 buffer；GUI 启动的
;; Emacs（runemacs.exe）继承的 PATH 往往比开发用的 shell 窄，找不到 diff 时直接
;; 报 "Failed to run diff: Searching for program: No such file or directory,
;; diff"。本仓库不需要 elisp 格式化，显式摘掉这个默认映射。
(with-eval-after-load 'apheleia
  (setf (alist-get 'emacs-lisp-mode apheleia-mode-alist nil 'remove) nil)
  (when (executable-find "shfmt")
    (setf (alist-get 'sh-mode apheleia-mode-alist) 'shfmt)))

(defun my/format-buffer ()
  "格式化统一入口：eglot 托管的 buffer 用 eglot-format，否则用 apheleia-format-buffer。"
  (interactive)
  (if (and (fboundp 'eglot-managed-p) (eglot-managed-p))
      (call-interactively #'eglot-format)
    (call-interactively #'apheleia-format-buffer)))

(provide 'init-format)
