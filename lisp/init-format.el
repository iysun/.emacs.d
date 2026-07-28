;; init-format.el 	-*- lexical-binding: t -*-
;;
;; apheleia：非 LSP 场景的格式化能力。`SPC f' = eglot-format（见 init-keymaps.el）
;; 只覆盖 LSP 托管的 buffer；shell 脚本等完全没有格式化手段，故引入 apheleia 补上。
;;
;; 保守起步：不把 eglot 托管的 mode 映射进 apheleia-mode-alist，避免存盘时被
;; eglot-format（手动）与 apheleia（自动）两套流程抢同一个 buffer。apheleia
;; 对没配置 formatter 的 major-mode 是空操作，全局开着没有副作用；后续加语言
;; 模块时再按需往 apheleia-mode-alist / apheleia-formatters 里加。

(add-hook 'after-init-hook 'apheleia-global-mode)

(with-eval-after-load 'apheleia
  (when (executable-find "shfmt")
    (setf (alist-get 'sh-mode apheleia-mode-alist) 'shfmt)))

(provide 'init-format)
