;; init-format.el 	-*- lexical-binding: t -*-
;;
;; apheleia：非 LSP 场景的格式化能力。`SPC f' = eglot-format（见 init-keymaps.el）
;; 只覆盖 LSP 托管的 buffer；shell 脚本等完全没有格式化手段，故引入 apheleia 补上。
;;
;; 保守起步：不把 eglot 托管的 mode 映射进 apheleia-mode-alist，避免存盘时被
;; eglot-format（手动）与 apheleia（自动）两套流程抢同一个 buffer。apheleia
;; 对没配置 formatter 的 major-mode 是空操作，全局开着没有副作用；后续加语言
;; 模块时再按需往 apheleia-mode-alist / apheleia-formatters 里加。
;;
;; 例外：emacs-lisp-mode。apheleia 自带的默认 apheleia-mode-alist 里已经映射了
;; (emacs-lisp-mode . lisp-indent)，不是空白——任何 .el buffer 存盘（含
;; customize-save-variable 写 custom.el，如 switch-emacs-theme / 补全风格切换）
;; 都会触发它。apheleia 的格式化流程不管 formatter 是不是纯 Lisp 函数，最后都要
;; 靠外部 diff/gdiff 生成 RCS patch 应用回 buffer；GUI 启动的 Emacs（runemacs.exe）
;; 继承的 PATH 往往比开发用的 shell 窄，找不到 diff 时直接报
;; "Failed to run diff: Searching for program: No such file or directory, diff"。
;; 本仓库不需要 elisp 自动格式化，显式摘掉这个默认映射。
(add-hook 'after-init-hook 'apheleia-global-mode)

(with-eval-after-load 'apheleia
  (setf (alist-get 'emacs-lisp-mode apheleia-mode-alist nil 'remove) nil)
  (when (executable-find "shfmt")
    (setf (alist-get 'sh-mode apheleia-mode-alist) 'shfmt)))

(provide 'init-format)
