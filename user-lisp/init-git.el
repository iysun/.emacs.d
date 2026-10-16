;;; -*- lexical-binding: t; -*-

(with-eval-after-load 'log-edit
  (setq log-edit-hook (remove 'log-edit-show-files log-edit-hook)))

;; ⚠ 别引入 diff-hl/flydiff：全局 idle timer 给每个改过的 buffer 起 git diff（Windows 贵），CRLF 警告还会误报 hunk
(setq vc-dir-auto-hide-up-to-date 'revert)

(defun my/auto-smerge-mode ()
  (save-excursion
    (goto-char (point-min))
    (when (re-search-forward "^<<<<<<< " nil t)
      (smerge-mode 1))))
(add-hook 'find-file-hook #'my/auto-smerge-mode)

(require 'hydra)

(defhydra hydra-smerge (:color red)
  "处理冲突"
  ("n" smerge-next "下一处冲突")
  ("p" smerge-prev "上一处冲突")
  ("m" smerge-keep-upper "保留我方")
  ("o" smerge-keep-lower "保留对方")
  ("b" smerge-keep-base "保留基线")
  ("a" smerge-keep-all "全部保留")
  ("R" smerge-refine "高亮差异")
  ("q" nil "退出"))

(provide 'init-git)
