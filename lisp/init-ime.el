;; init-ime.el 	-*- lexical-binding: t -*-
;;
;; 输入法切换：退出 evil 插入态时切回英文，本质是 evil 集成的一部分，只是
;; 实现因平台而异（Windows 用 im-select.exe，Linux/macOS 用 fcitx5-remote），
;; 用 `cond' 在一个函数里把所有平台分支放在一起，不按 OS 拆文件。
;;
;; 之所以单独开一个文件而不是直接写进 lisp/init-evil.el：全量 profile 的
;; `lisp/init-evil.el' 和精简 profile 的 `init-minimal.el' 是两条不相交的
;; 加载路径，精简 profile 根本不 require `lisp/' 下任何全量模块，两边过去
;; 各自重复定义过一份。这里复用 `early-init.el' 已经在用的「绝对路径 `load'，
;; 两套 profile 都吃到」这条引导路径，只定义一份。
;;
;; 由 `early-init.el' 在最早期用绝对路径 `load'（那时 `lisp/' 还没被 init.el
;; 加进 load-path，`require' 用不了）。

;; Windows 用 im-select.exe；Linux/macOS 用 fcitx5-remote。找不到对应程序时
;; 静默跳过，不在没装该程序的平台上报错。
(defvar my/im-select-path "d:/im-select.exe"
  "Windows 上 im-select.exe 的路径，可按需修改。")

(defun my/switch-to-english-input-method ()
  "退出插入态时把输入法切到英文。"
  (cond
   ((eq system-type 'windows-nt)
    (when (file-exists-p my/im-select-path)
      (call-process my/im-select-path nil 0 nil "1033")))
   ((memq system-type '(gnu/linux darwin))
    (when (executable-find "fcitx5-remote")
      (call-process "fcitx5-remote" nil 0 nil "-c")))))

;; 两套 profile 都用 evil，这里注册一次即可；`add-hook' 对尚未定义的 hook
;; 变量（evil 这时还没加载）也是安全的，evil 加载后自然生效。
(add-hook 'evil-insert-state-exit-hook #'my/switch-to-english-input-method)

;; C-SPC 激活输入法：仅在 Linux/macOS（有 fcitx5-remote）保留此行为；
;; Windows 上不劫持 C-SPC，保留默认 set-mark-command。
(when (and (memq system-type '(gnu/linux darwin))
           (executable-find "fcitx5-remote"))
  (global-set-key (kbd "C-SPC")
                  (lambda () (interactive)
                    (call-process "fcitx5-remote" nil 0 nil "-o"))))

(provide 'init-ime)
