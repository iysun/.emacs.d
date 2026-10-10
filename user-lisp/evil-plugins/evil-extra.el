;; evil-extra.el 	-*- lexical-binding: t -*-
;;
;; 自 evil-collection 提取的常用 special mode 的 evil 键位。
;; （VC 见 evil-vc.el；dired 见 evil-dired.el；ibuffer 见 evil-ibuffer.el。）
;; 来源（evil-collection 20260623.308，GPLv3）：
;;   modes/compile      -> evil-collection-compile.el
;;   modes/embark       -> evil-collection-embark.el
;;   modes/help         -> evil-collection-help.el
;;   modes/xref         -> evil-collection-xref.el
;;   modes/package-menu -> evil-collection-package-menu.el
;;   modes/grep         -> evil-collection-grep.el
;;   modes/wgrep        -> evil-collection-wgrep.el
;;   modes/proced       -> evil-collection-proced.el
;;
;; 另：occur-mode 只做了最小绑定（本地补充，非 evil-collection）。
;;
;; `evil-define-key' 是宏，编译期需 evil；运行时整体包在 `with-eval-after-load 'evil'；
;; 目标 map 未建好时由 `evil-define-key' 自动推迟。
;;
;; evil-collection 的语义名（`evil-collection-bind'）已按
;; `evil-collection-binding-defaults' 展开成真实按键：
;;   mark=m  unmark=u  unmark-all=U  mark-toggle-all=~  mark-delete=d  execute-marks=x
;;   next-item=gj  prev-item=gk  next-section=]]  prev-section=[[
;;   next-section-2=C-j  prev-section-2=C-k
;;   action=RET/<return>  action-other=S-<return>/S-RET/go  action-stay=M-<return>/M-RET/gO
;;   find-file=gf  refresh=gr  quit=q  quit-save=ZZ  quit-cancel=ZQ
;;   scroll-down=SPC  scroll-up=S-SPC/S-<space>  describe-mode=g?  browse-url=gx

(eval-when-compile (require 'evil))

;; 只读收尾用（对应 evil-collection-inhibit-insert-state）。
;; `eval-and-compile'：下面 `evil-extra--readonly-bindings' 宏在**编译期**展开、
;; 需要读到这个列表，故必须让它编译期也有值。
(eval-and-compile
  (defconst evil-extra--readonly-commands
    '(evil-append evil-append-line evil-insert evil-insert-line
      evil-change evil-change-line evil-substitute evil-change-whole-line
      evil-delete evil-delete-line evil-delete-char evil-delete-backward-char
      evil-replace evil-replace-state evil-open-below evil-open-above
      evil-paste-after evil-paste-before evil-join evil-indent
      evil-shift-left evil-shift-right evil-invert-char)))

;; 只读类 mode 的公共收尾：q/ZZ/ZQ + 禁用插入/修改类命令。
;; 必须是宏、且传入**字面量** keymap 符号，`evil-define-key' 才能对尚未建立的
;; keymap 自动推迟（传变量符号会退化成检查名为 `map' 的变量，永远不触发）。
;; remap 项在**编译期**全部拼进同一次 `evil-define-key' 调用，这样每个 mode 只
;; 注册 1 个 after-load 延迟项（若运行期循环调用 evil-define-key，会注册 23 个）。
(defmacro evil-extra--readonly-bindings (map)
  "Apply evil-collection's read-only bindings to literal keymap MAP."
  `(evil-define-key 'normal ,map
     (kbd "q")  'my/quit-window
     (kbd "ZZ") 'quit-window
     (kbd "ZQ") 'evil-quit
     ,@(apply #'append
              (mapcar (lambda (c) `((vector 'remap ',c) #'ignore))
                      evil-extra--readonly-commands))))

;; 编译相关两个 keymap 共用同一套绑定（用宏传入字面量 map 符号，
;; 这样 `evil-define-key' 才能对尚未建立的 keymap 自动推迟）。
(defmacro evil-extra--compile-map (map)
  "Bind evil keys for compilation keymap MAP."
  `(progn
     ;; 把 g 前缀让给 evil（编译 map 里若有 g 前缀会挡住 evil 的 g）。
     (evil-define-key nil ,map (kbd "g") nil)
     (evil-define-key 'normal ,map
       (kbd "TAB")        'compilation-next-error
       (kbd "S-TAB")      'compilation-previous-error
       (kbd "RET")        'compile-goto-error
       (kbd "<return>")   'compile-goto-error
       (kbd "S-<return>") 'compilation-display-error
       (kbd "S-RET")      'compilation-display-error
       (kbd "go")         'compilation-display-error
       (kbd "M-<return>") 'compilation-display-error
       (kbd "M-RET")      'compilation-display-error
       (kbd "gO")         'compilation-display-error
       (kbd "gj")         'compilation-next-error
       (kbd "gk")         'compilation-previous-error
       (kbd "]]")         'compilation-next-file
       (kbd "[[")         'compilation-previous-file
       (kbd "C-j")        'compilation-next-error
       (kbd "C-k")        'compilation-previous-error
       (kbd "gr")         'recompile)))

(with-eval-after-load 'evil

  ;; ---------------------------------------------------------------- compile
  (evil-set-initial-state 'compilation-mode 'normal)
  (evil-extra--readonly-bindings compilation-mode-map)
  (evil-extra--compile-map compilation-mode-map)
  (evil-extra--compile-map compilation-minor-mode-map)

  ;; ----------------------------------------------------------------- embark
  (evil-set-initial-state 'embark-collect-mode 'normal)
  (evil-define-key 'normal embark-collect-mode-map
    "a"        'embark-act
    "A"        'embark-act-all
    "E"        'embark-export
    (kbd "M-a") 'embark-collect-direct-action-minor-mode
    "m"        'embark-select
    "gr"       'revert-buffer)

  ;; ------------------------------------------------------------------- help
  (evil-set-initial-state 'help-mode 'normal)
  (evil-extra--readonly-bindings help-mode-map)
  (evil-define-key 'normal help-mode-map
    (kbd "C-f")      'scroll-up-command
    (kbd "C-b")      'scroll-down-command
    (kbd "<tab>")    'forward-button
    (kbd "<backtab>") 'backward-button
    (kbd "g TAB")    'forward-button
    "g]"             'forward-button
    "g["             'backward-button
    (kbd "C-o")      'help-go-back
    (kbd "C-i")      'help-go-forward
    "<"              'help-go-back
    ">"              'help-go-forward
    "r"              'help-follow
    ;; 语义名展开
    (kbd "SPC")      'scroll-up-command
    (kbd "S-SPC")    'scroll-down-command
    (kbd "S-<space>") 'scroll-down-command
    (kbd "S-<return>") 'push-button
    (kbd "S-RET")    'push-button
    (kbd "go")       'push-button
    (kbd "M-<return>") 'push-button
    (kbd "M-RET")    'push-button
    (kbd "gO")       'push-button
    (kbd "g?")       'describe-mode
    (kbd "gr")       'revert-buffer
    ;; Emacs 28+
    "s"              'help-view-source
    "i"              'help-goto-info
    "c"              'help-customize)

  ;; ------------------------------------------------------------------- xref
  (evil-set-initial-state 'xref--xref-buffer-mode 'normal)
  (evil-extra--readonly-bindings xref--xref-buffer-mode-map)
  (evil-define-key 'normal xref--xref-buffer-mode-map
    (kbd "C-n") 'xref-next-line
    (kbd "C-p") 'xref-prev-line
    "r"         'xref-query-replace-in-results
    "Q"         'xref-query-replace-in-results
    "o"         'xref-show-location-at-point
    ;; 语义名展开
    (kbd "RET")       'xref-goto-xref
    (kbd "<return>")  'xref-goto-xref
    (kbd "S-<return>") 'xref-quit-and-goto-xref
    (kbd "S-RET")     'xref-quit-and-goto-xref
    (kbd "go")        'xref-quit-and-goto-xref
    (kbd "M-<return>") 'xref-show-location-at-point
    (kbd "M-RET")     'xref-show-location-at-point
    (kbd "gO")        'xref-show-location-at-point
    (kbd "gj")        'xref-next-line
    (kbd "gk")        'xref-prev-line
    (kbd "C-j")       'xref-next-line
    (kbd "C-k")       'xref-prev-line
    (kbd "]]")        'xref-next-group
    (kbd "[[")        'xref-prev-group
    (kbd "gr")        'xref-revert-buffer)
  (evil-set-initial-state 'xref--transient-buffer-mode 'normal)
  (evil-define-key 'normal xref--transient-buffer-mode-map
    (kbd "RET")      'xref-quit-and-goto-xref
    (kbd "<return>") 'xref-quit-and-goto-xref)

  ;; ----------------------------------------------------------- package-menu
  (evil-set-initial-state 'package-menu-mode 'normal)
  (evil-extra--readonly-bindings package-menu-mode-map)
  (evil-define-key 'normal package-menu-mode-map
    "i"   'package-menu-mark-install
    "U"   'package-menu-mark-upgrades
    ;; 语义名展开
    "u"   'package-menu-mark-unmark
    "d"   'package-menu-mark-delete
    "x"   'package-menu-execute
    "g?"  'package-menu-describe-package
    "gr"  'revert-buffer)
  (when (fboundp 'package-browse-url)
    (evil-define-key 'normal package-menu-mode-map "gx" 'package-browse-url))

  ;; ------------------------------------------------------------------ grep
  (evil-set-initial-state 'grep-mode 'normal)
  (evil-define-key 'normal grep-mode-map
    "n"        'evil-search-next
    (kbd "C-j") 'next-error-no-select
    (kbd "C-k") 'previous-error-no-select
    (kbd "q")   #'my/quit-window)
  (with-eval-after-load 'wgrep
    (evil-define-key 'normal grep-mode-map "i" 'wgrep-change-to-wgrep-mode))

  ;; ------------------------------------------------------------------ occur
  ;; occur 不在 evil-collection 里，这里补一个最小绑定：q 走 my/quit-window。
  (evil-set-initial-state 'occur-mode 'normal)
  (evil-define-key 'normal occur-mode-map (kbd "q") #'my/quit-window)

  ;; ----------------------------------------------------------------- wgrep
  (evil-define-key nil wgrep-mode-map
    [remap evil-write] 'wgrep-finish-edit)
  (evil-define-key 'normal wgrep-mode-map
    (kbd "<escape>") 'wgrep-exit
    "ZZ"             'wgrep-finish-edit
    "ZQ"             'wgrep-abort-changes)

  ;; ----------------------------------------------------------------- proced
  (evil-set-initial-state 'proced-mode 'normal)
  (evil-extra--readonly-bindings proced-mode-map)
  (evil-define-key 'normal proced-mode-map
    "*"            'proced-mark-all
    "M"            'proced-mark-all
    "c"            'proced-mark-children
    "C"            'proced-mark-children
    "p"            'proced-mark-parents
    "P"            'proced-mark-parents
    (kbd "<delete>") 'proced-unmark-backward
    "zt"           'proced-toggle-tree
    "u"            'proced-undo
    "O"            'proced-omit-processes
    "x"            'proced-send-signal
    "s"            'proced-filter-interactive
    "S"            'proced-format-interactive
    "oo"           'proced-sort-start
    "oO"           'proced-sort-interactive
    "oc"           'proced-sort-pcpu
    "om"           'proced-sort-pmem
    "op"           'proced-sort-pid
    "ot"           'proced-sort-time
    "ou"           'proced-sort-user
    "r"            'proced-renice
    ;; 语义名展开
    (kbd "SPC")    'evil-scroll-down
    (kbd "S-SPC")  'evil-scroll-up
    (kbd "S-<space>") 'evil-scroll-up
    "m"            'proced-mark
    "~"            'proced-toggle-marks
    "U"            'proced-unmark-all
    (kbd "RET")      'proced-refine
    (kbd "<return>") 'proced-refine
    "gr"           'revert-buffer))

(provide 'evil-extra)
;;; evil-extra.el ends here
