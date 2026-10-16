;; ime.el 	-*- lexical-binding: t -*-

;; 须由 early-init 用绝对路径在最早期 load（那时 load-path 还没建立）。
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

(add-hook 'evil-insert-state-exit-hook #'my/switch-to-english-input-method)

(when (and (memq system-type '(gnu/linux darwin))
           (executable-find "fcitx5-remote"))
  (global-set-key (kbd "C-SPC")
                  (lambda () (interactive)
                    (call-process "fcitx5-remote" nil 0 nil "-o"))))

(provide 'ime)
