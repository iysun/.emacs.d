;; evil-ibuffer.el 	-*- lexical-binding: t -*-
;;
;; 自 evil-collection 提取的 ibuffer evil 键位。
;; 来源（evil-collection 20260623.308，GPLv3）：modes/ibuffer -> evil-collection-ibuffer.el
;;
;; ibuffer 默认是 emacs 态，这里改为 normal 态并套上完整键位。
;;
;; `evil-define-key' 是宏，编译期需 evil；运行时整体包在 `with-eval-after-load 'evil'；
;; 目标 map 未建好时由 `evil-define-key' 自动推迟。
;;
;; evil-collection 语义名（`evil-collection-bind'）已按
;; `evil-collection-binding-defaults' 展开成真实按键：
;;   mark=m  unmark=u  unmark-all=U  mark-toggle-all=~  mark-delete=d  execute-marks=x
;;   next-item=gj  prev-item=gk  next-section=]]  prev-section=[[
;;   action=RET/<return>  action-other=S-<return>/S-RET/go  action-stay=M-<return>/M-RET/gO
;;   rename=r/R  jump=J  refresh=gr  quit=q/ZZ/ZQ

(eval-when-compile (require 'evil))

(with-eval-after-load 'evil

  ;; ---------------------------------------------------------------- ibuffer
  (evil-set-initial-state 'ibuffer-mode 'normal)
  (evil-define-key 'normal ibuffer-mode-map
    "R"                'ibuffer-do-rename-uniquely
    "J"                'ibuffer-jump-to-buffer
    (kbd "C-d")        (if evil-want-C-d-scroll
                           'evil-scroll-down
                         'ibuffer-mark-for-delete-backwards)
    (kbd "=")          'ibuffer-diff-with-file
    (kbd "M-g")        'ibuffer-jump-to-buffer
    (kbd "t")          'ibuffer-toggle-marks
    (kbd "M-s a C-s")   'ibuffer-do-isearch
    (kbd "M-s a M-C-s") 'ibuffer-do-isearch-regexp
    (kbd "M-s a C-o")   'ibuffer-do-occur
    ;; mark
    (kbd "DEL")        'ibuffer-unmark-backward
    (kbd "M-DEL")      'ibuffer-unmark-all
    (kbd "* *")        'ibuffer-mark-special-buffers
    (kbd "* c")        'ibuffer-change-marks
    (kbd "* M")        'ibuffer-mark-by-mode
    (kbd "* m")        'ibuffer-mark-modified-buffers
    (kbd "* u")        'ibuffer-mark-unsaved-buffers
    (kbd "* s")        'ibuffer-mark-special-buffers
    (kbd "* r")        'ibuffer-mark-read-only-buffers
    (kbd "* /")        'ibuffer-mark-dired-buffers
    (kbd "* e")        'ibuffer-mark-dissociated-buffers
    (kbd "* h")        'ibuffer-mark-help-buffers
    (kbd "* z")        'ibuffer-mark-compressed-file-buffers
    (kbd ".")          'ibuffer-mark-old-buffers
    ;; immediate operations
    (kbd "}")          'ibuffer-forward-next-marked
    (kbd "{")          'ibuffer-backwards-next-marked
    (kbd "M-}")        'ibuffer-forward-next-marked
    (kbd "M-{")        'ibuffer-backwards-next-marked
    (kbd "gR")         'ibuffer-redisplay
    (kbd "gr")         'ibuffer-update
    "`"                'ibuffer-switch-format
    "-"                'ibuffer-add-to-tmp-hide
    "+"                'ibuffer-add-to-tmp-show
    "X"                'ibuffer-bury-buffer
    (kbd ",")          'ibuffer-toggle-sorting-mode
    (kbd "o i")        'ibuffer-invert-sorting
    (kbd "o a")        'ibuffer-do-sort-by-alphabetic
    (kbd "o v")        'ibuffer-do-sort-by-recency
    (kbd "o s")        'ibuffer-do-sort-by-size
    (kbd "o f")        'ibuffer-do-sort-by-filename/process
    (kbd "o m")        'ibuffer-do-sort-by-major-mode
    ;; filter
    (kbd "s RET")      'ibuffer-filter-by-mode
    (kbd "s m")        'ibuffer-filter-by-used-mode
    (kbd "s M")        'ibuffer-filter-by-derived-mode
    (kbd "s n")        'ibuffer-filter-by-name
    (kbd "s *")        'ibuffer-filter-by-starred-name
    (kbd "s f")        'ibuffer-filter-by-filename
    (kbd "s b")        'ibuffer-filter-by-basename
    (kbd "s .")        'ibuffer-filter-by-file-extension
    (kbd "s <")        'ibuffer-filter-by-size-lt
    (kbd "s >")        'ibuffer-filter-by-size-gt
    (kbd "s i")        'ibuffer-filter-by-modified
    (kbd "s v")        'ibuffer-filter-by-visiting-file
    (kbd "s c")        'ibuffer-filter-by-content
    (kbd "s e")        'ibuffer-filter-by-predicate
    (kbd "s r")        'ibuffer-switch-to-saved-filters
    (kbd "s a")        'ibuffer-add-saved-filters
    (kbd "s x")        'ibuffer-delete-saved-filters
    (kbd "s d")        'ibuffer-decompose-filter
    (kbd "s s")        'ibuffer-save-filters
    (kbd "s p")        'ibuffer-pop-filter
    (kbd "s <up>")     'ibuffer-pop-filter
    (kbd "s !")        'ibuffer-negate-filter
    (kbd "s t")        'ibuffer-exchange-filters
    (kbd "s TAB")      'ibuffer-exchange-filters
    (kbd "s o")        'ibuffer-or-filter
    (kbd "s |")        'ibuffer-or-filter
    (kbd "s &")        'ibuffer-and-filter
    (kbd "s g")        'ibuffer-filters-to-filter-group
    (kbd "s P")        'ibuffer-pop-filter-group
    (kbd "s S-<up>")   'ibuffer-pop-filter-group
    (kbd "s D")        'ibuffer-decompose-filter-group
    (kbd "s /")        'ibuffer-filter-disable
    (kbd "M-n")        'ibuffer-forward-filter-group
    (kbd "\t")         'ibuffer-forward-filter-group
    (kbd "M-p")        'ibuffer-backward-filter-group
    [backtab]          'ibuffer-backward-filter-group
    (kbd "M-j")        'ibuffer-jump-to-filter-group
    (kbd "gx")         'ibuffer-kill-line
    (kbd "C-y")        'ibuffer-yank
    (kbd "s S")        'ibuffer-save-filter-groups
    (kbd "s R")        'ibuffer-switch-to-saved-filter-groups
    (kbd "s X")        'ibuffer-delete-saved-filter-groups
    (kbd "s \\")       'ibuffer-clear-filter-groups
    (kbd "% n")        'ibuffer-mark-by-name-regexp
    (kbd "% m")        'ibuffer-mark-by-mode-regexp
    (kbd "% f")        'ibuffer-mark-by-file-name-regexp
    (kbd "% g")        'ibuffer-mark-by-content-regexp
    (kbd "% L")        'ibuffer-mark-by-locked
    (kbd "C-t")        'ibuffer-visit-tags-table
    (kbd "|")          'ibuffer-do-shell-command-pipe
    (kbd "!")          'ibuffer-do-shell-command-file
    ;; marked operations
    (kbd "A")          'ibuffer-do-view
    (kbd "D")          'ibuffer-do-delete
    (kbd "E")          'ibuffer-do-eval
    (kbd "F")          'ibuffer-do-shell-command-file
    (kbd "I")          'ibuffer-do-query-replace-regexp
    (kbd "H")          'ibuffer-do-view-other-frame
    (kbd "N")          'ibuffer-do-shell-command-pipe-replace
    (kbd "M")          'ibuffer-do-toggle-modified
    (kbd "O")          'ibuffer-do-occur
    (kbd "P")          'ibuffer-do-print
    (kbd "Q")          'ibuffer-do-query-replace
    (kbd "S")          'ibuffer-do-save
    (kbd "T")          'ibuffer-do-toggle-read-only
    (kbd "r")          'ibuffer-do-replace-regexp
    (kbd "V")          'ibuffer-do-revert
    (kbd "W")          'ibuffer-do-view-and-eval
    (kbd "K")          'ibuffer-do-kill-lines
    (kbd "yf")         'ibuffer-copy-filename-as-kill
    (kbd "yb")         'ibuffer-copy-buffername-as-kill
    (kbd "gv")         'ibuffer-do-view
    (kbd "gV")         'ibuffer-do-view-horizontally
    ;; 语义名展开
    "m"                'ibuffer-mark-forward
    "u"                'ibuffer-unmark-forward
    "U"                'ibuffer-unmark-all-marks
    "~"                'ibuffer-toggle-marks
    "d"                'ibuffer-mark-for-delete
    "x"                'ibuffer-do-kill-on-deletion-marks
    (kbd "RET")        'ibuffer-visit-buffer
    (kbd "<return>")   'ibuffer-visit-buffer
    (kbd "S-<return>") 'ibuffer-visit-buffer-other-window
    (kbd "S-RET")      'ibuffer-visit-buffer-other-window
    (kbd "go")         'ibuffer-visit-buffer-other-window
    (kbd "M-<return>") 'ibuffer-visit-buffer-other-window-noselect
    (kbd "M-RET")      'ibuffer-visit-buffer-other-window-noselect
    (kbd "gO")         'ibuffer-visit-buffer-other-window-noselect
    "gj"               'ibuffer-forward-line
    "gk"               'ibuffer-backward-line
    "]]"               'ibuffer-forward-filter-group
    "[["               'ibuffer-backward-filter-group
    "q"                'quit-window
    "ZZ"               'quit-window
    "ZQ"               'quit-window))

(provide 'evil-ibuffer)
;;; evil-ibuffer.el ends here
