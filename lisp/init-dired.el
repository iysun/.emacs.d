;; init-dired.el 	-*- lexical-binding: t -*-
;;(setq dired-omit-files-p t) ; 自动隐藏某些文件
;;(setq dired-omit-regexp "\\(^\\.[^.]\\|\\(~$\\|\\ .orig$\\|.rej$\\)")

;; Always delete and copy recursively
(setq dired-recursive-deletes 'always
      dired-recursive-copies 'always)

;; dired 四件套延迟到首次打开 dired 才加载（省 ~1.6s 启动）。
;; 这些 define-key 需 dired-mode-map，本就只在 dired 下用，延迟无损功能。
(with-eval-after-load 'dired
  (require 'dired-quick-sort)
  (define-key dired-mode-map "S" 'hydra-dired-quick-sort/body)   ; 快速排序

  (require 'dired-git-info)
  (define-key dired-mode-map "I" 'dired-git-info-mode)           ; 显示 git 信息

  (require 'dired-rsync)
  (define-key dired-mode-map (kbd "C-c C-r") 'dired-rsync)       ; rsync

  ;; (require 'diredfl) ; Colorful dired（按需启用）
  (require 'dired-subtree)
  (define-key dired-mode-map (kbd "TAB") 'dired-subtree-toggle)) ; 折叠子目录（类似 ranger）

(provide 'init-dired)
