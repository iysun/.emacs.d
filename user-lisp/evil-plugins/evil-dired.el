;; evil-dired.el 	-*- lexical-binding: t -*-
;;
;; 自 evil-collection 提取的 dired evil 键位。
;; 来源（evil-collection 20260623.308，GPLv3）：modes/dired -> evil-collection-dired.el
;;
;; 说明：`evil-want-keybinding t` 已给 dired 一套基础键（j/k 等），本文件在其上
;; 叠加 evil-collection 的完整绑定（同名键以本文件为准）。dired 本身可编辑，
;; 故不做只读收尾。
;;
;; `evil-define-key' 是宏，编译期需 evil；运行时整体包在 `with-eval-after-load 'evil'；
;; 目标 map 未建好时由 `evil-define-key' 自动推迟。
;;
;; evil-collection 语义名（`evil-collection-bind'）已按
;; `evil-collection-binding-defaults' 展开成真实按键：
;;   mark=m  unmark=u  unmark-all=U  mark-toggle-all=~  mark-delete=d  execute-marks=x
;;   next-item=gj  prev-item=gk  next-section=]]  prev-section=[[
;;   action=RET/<return>  action-other=S-<return>/S-RET/go  action-stay=M-<return>/M-RET/gO
;;   find-file=gf  refresh=gr  quit=q  describe-mode=g?  jump=J  browse-url=gx

(eval-when-compile (require 'evil))

(with-eval-after-load 'evil

  ;; ------------------------------------------------------------------ dired
  (evil-define-key 'normal dired-mode-map
    "j" 'dired-next-line
    "k" 'dired-previous-line
    "q" 'quit-window
    [mouse-2] 'dired-mouse-find-file-other-window
    [follow-link] 'mouse-face
    ;; 标记 / flag 各类文件
    "#" 'dired-flag-auto-save-files
    "." 'dired-clean-directory
    "~" 'dired-flag-backup-files
    ;; 大写键：对标记文件操作
    "A" 'dired-do-find-regexp
    "C" 'dired-do-copy
    "B" 'dired-do-byte-compile
    "D" 'dired-do-delete
    (kbd "gG") 'dired-do-chgrp
    "H" 'dired-do-hardlink
    "L" 'dired-do-load
    "M" 'dired-do-chmod
    "O" 'dired-do-chown
    "P" 'dired-do-print
    "Q" 'dired-do-find-regexp-and-replace
    "S" 'dired-do-symlink
    "T" 'dired-do-touch
    "X" 'dired-do-shell-command
    "Z" 'dired-do-compress
    "c" 'dired-do-compress-to
    "!" 'dired-do-shell-command
    "&" 'dired-do-async-shell-command
    "=" 'dired-diff
    ;; tree dired
    (kbd "M-C-?") 'dired-unmark-all-files
    (kbd "M-C-d") 'dired-tree-down
    (kbd "M-C-u") 'dired-tree-up
    (kbd "M-C-n") 'dired-next-subdir
    (kbd "M-C-p") 'dired-prev-subdir
    (kbd "M-{") 'dired-prev-marked-file
    (kbd "M-}") 'dired-next-marked-file
    ;; % 前缀：正则类命令
    "%" nil
    "%u" 'dired-upcase
    "%l" 'dired-downcase
    "%d" 'dired-flag-files-regexp
    "%g" 'dired-mark-files-containing-regexp
    "%m" 'dired-mark-files-regexp
    "%r" 'dired-do-rename-regexp
    "%C" 'dired-do-copy-regexp
    "%H" 'dired-do-hardlink-regexp
    "%R" 'dired-do-rename-regexp
    "%S" 'dired-do-symlink-regexp
    "%&" 'dired-flag-garbage-files
    ;; * 前缀：标记类命令
    "*" nil
    "**" 'dired-mark-executables
    "*/" 'dired-mark-directories
    "*@" 'dired-mark-symlinks
    "*%" 'dired-mark-files-regexp
    "*c" 'dired-change-marks
    "*s" 'dired-mark-subdir-files
    "*m" 'dired-mark
    "*u" 'dired-unmark
    "*?" 'dired-unmark-all-files
    "*!" 'dired-unmark-all-marks
    (kbd "* <delete>") 'dired-unmark-backward
    (kbd "* C-n") 'dired-next-marked-file
    (kbd "* C-p") 'dired-prev-marked-file
    "*t" 'dired-toggle-marks
    ;; 小写键：非「全部标记文件」类
    "a" 'dired-find-alternate-file
    "i" 'dired-toggle-read-only
    "I" 'dired-maybe-insert-subdir
    "K" 'dired-do-kill-lines
    "r" 'dired-do-redisplay
    "t" 'dired-toggle-marks
    (kbd "gy") 'dired-show-file-type
    "Y" 'dired-copy-filename-as-kill
    "+" 'dired-create-directory
    "o" 'dired-sort-toggle-or-edit
    "<" 'dired-prev-dirline
    ">" 'dired-next-dirline
    "^" 'dired-up-directory
    "-" 'dired-up-directory
    " " 'dired-next-line
    [?\S-\ ] 'dired-previous-line
    [remap next-line] 'dired-next-line
    [remap previous-line] 'dired-previous-line
    (kbd "g$") 'dired-hide-subdir
    (kbd "M-$") 'dired-hide-all
    "(" 'dired-hide-details-mode
    (kbd "M-s a C-s")   'dired-do-isearch
    (kbd "M-s a M-C-s") 'dired-do-isearch-regexp
    (kbd "M-s f C-s")   'dired-isearch-filenames
    (kbd "M-s f M-C-s") 'dired-isearch-filenames-regexp
    [remap read-only-mode] 'dired-toggle-read-only
    [remap toggle-read-only] 'dired-toggle-read-only
    (kbd "<delete>") 'dired-unmark-backward
    ;; 语义名展开
    "m"   'dired-mark
    "u"   'dired-unmark
    "U"   'dired-unmark-all-marks
    "~"   'dired-toggle-marks
    "d"   'dired-flag-file-deletion
    "x"   'dired-do-flagged-delete
    "gj"  'dired-next-dirline
    "gk"  'dired-prev-dirline
    "]]"  'dired-next-dirline
    "[["  'dired-prev-dirline
    (kbd "RET")      'dired-find-file
    (kbd "<return>") 'dired-find-file
    (kbd "S-<return>") 'dired-find-file-other-window
    (kbd "S-RET")    'dired-find-file-other-window
    (kbd "go")       'dired-find-file-other-window
    (kbd "M-<return>") 'dired-view-file
    (kbd "M-RET")    'dired-view-file
    (kbd "gO")       'dired-view-file
    (kbd "gf")       'dired-find-file
    (kbd "g?")       'dired-summary
    (kbd "gr")       'revert-buffer
    "J"   'dired-goto-file
    (kbd "gx")       'browse-url-of-dired-file
    [remap undo] 'dired-undo
    [remap advertised-undo] 'dired-undo
    ;; image-dired
    (kbd "C-t d") 'image-dired-display-thumbs
    (kbd "C-t t") 'image-dired-tag-files
    (kbd "C-t r") 'image-dired-delete-tag
    (kbd "C-t j") 'image-dired-jump-thumbnail-buffer
    (kbd "C-t i") 'image-dired-dired-display-image
    (kbd "C-t x") 'image-dired-dired-display-external
    (kbd "C-t a") 'image-dired-display-thumbs-append
    (kbd "C-t .") 'image-dired-display-thumb
    (kbd "C-t c") 'image-dired-dired-comment-files
    (kbd "C-t f") 'image-dired-mark-tagged-files
    (kbd "C-t C-t") 'image-dired-dired-toggle-marked-thumbs
    (kbd "C-t e") 'image-dired-dired-edit-comment-and-tags
    ;; epa-dired
    ";d" 'epa-dired-do-decrypt
    ";v" 'epa-dired-do-verify
    ";s" 'epa-dired-do-sign
    ";e" 'epa-dired-do-encrypt
    ;; Emacs 30+
    "E"   'dired-do-open)
  ;; 可选扩展包（未装则永不触发）
  (with-eval-after-load 'dired-x
    (evil-define-key 'normal dired-mode-map
      "*(" 'dired-mark-sexp
      "*." 'dired-mark-extension
      "*O" 'dired-mark-omitted))
  (with-eval-after-load 'dired-narrow
    (evil-define-key 'normal dired-mode-map
      "s" 'dired-narrow-regexp))
  (with-eval-after-load 'dired-subtree
    (evil-define-key 'normal dired-mode-map
      (kbd "TAB") 'dired-subtree-toggle
      "gh" 'dired-subtree-up
      "gl" 'dired-subtree-down
      (kbd "M-j") 'dired-subtree-next-sibling
      (kbd "M-k") 'dired-subtree-previous-sibling)))

(provide 'evil-dired)
;;; evil-dired.el ends here
