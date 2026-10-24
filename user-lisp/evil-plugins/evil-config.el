;; evil-config.el 	-*- lexical-binding: t -*-

;; ⚠ evil-want-* 必须在 evil 加载前设好；evil-want-keybinding 用默认 t（evil-collection 已移除）
(progn
  (setq evil-want-integration t)                ; 与 Emacs minor modes 集成
  (setq evil-want-keybinding t)
  (setq evil-shift-width 2)
  (setq evil-search-module 'evil-search)        ; 必须！支持 gn / cgn
  (setq evil-respect-visual-line-mode t)        ; 在 visual-line-mode 中按行移动
  (setq evil-cross-lines t)                     ; j/k 可跨软换行行（类似 Vim）
  (setq evil-undo-system 'undo-redo)            ; 使用 Emacs 的 undo-tree 或简易 undo-redo
  )

;; ⚠ 编译期必须 require evil：下面用了 evil-define-text-object 宏
(require 'evil)

(evil-mode 1)
(with-eval-after-load 'evil
  (require 'evil-surround)
  (global-evil-surround-mode 1)
  (require 'evil-visualstar)
  (global-evil-visualstar-mode)
  (require 'evil-commentary)
  (evil-commentary-mode)
  )


(defgroup evil-textobj-between nil
  "Text object between for Evil"
  :prefix "evil-textobj-between-"
  :group 'evil)

(defcustom evil-textobj-between-i-key "f"
  "Keys for evil-inner-between"
  :type 'string
  :group 'evil-textobj-between)
(defcustom evil-textobj-between-a-key "f"
  "Keys for evil-a-between"
  :type 'string
  :group 'evil-textobj-between)

(defun evil-between-range (count beg end type &optional inclusive)
  (ignore-errors
    (let ((count (abs (or count 1)))
          (beg (and beg end (min beg end)))
          (end (and beg end (max beg end)))
          (ch (evil-read-key))
          beg-inc end-inc)
      (save-excursion
        (when beg (goto-char beg))
        (evil-find-char (- count) ch)
        (setq beg-inc (point)))
      (save-excursion
        (when end (goto-char end))
        (backward-char)
        (evil-find-char count ch)
        (setq end-inc (1+ (point))))
      (if inclusive
          (evil-range beg-inc end-inc)
        (if (and beg end (= (1+ beg-inc) beg) (= (1- end-inc) end))
            (evil-range beg-inc end-inc)
          (evil-range (1+ beg-inc) (1- end-inc)))))))

(evil-define-text-object evil-a-between (count &optional beg end type)
  "Select range between a character by which the command is followed."
  (evil-between-range count beg end type t))
(evil-define-text-object evil-inner-between (count &optional beg end type)
  "Select inner range between a character by which the command is followed."
  (evil-between-range count beg end type))

(define-key evil-outer-text-objects-map evil-textobj-between-a-key
            'evil-a-between)
(define-key evil-inner-text-objects-map evil-textobj-between-i-key
            'evil-inner-between)

;; ---- 词运动 / 分词（word motion & subwords）----
;; w/b/e、iw/aw：Vim 词（`_' 算词内，不切 camelCase，标点串自成一段）
;; 再并入两侧都是词字符的 `-'（foo-bar）；前导/末尾/连续的 `-' 仍是标点。
;; M-f/M-b 与 i SPC w 仍是 subword。evil 不用 `forward-word'：那会被 subword-mode 改写。
(require 'subword)
(global-subword-mode t)

(defun my/with-vim-word-syntax (fn)
  "临时把 `_' 当成词字符后调用 FN。不改 `-'，也不动 `subword-mode'。"
  (let ((table (make-syntax-table (syntax-table)))
        (word-separating-categories evil-cjk-word-separating-categories)
        (word-combining-categories evil-cjk-word-combining-categories))
    (modify-syntax-entry ?_ "w" table)
    (with-syntax-table table (funcall fn))))

(defun my/vim-word-char-p (char)
  (and char (eq (char-syntax char) ?w)))

(defun my/at-middle-hyphen-p ()
  "当前字符是 `-'，且左右都是词字符（`foo-bar' 的那个横线）。"
  (and (eq (char-after) ?-)
       (my/vim-word-char-p (char-before))
       (my/vim-word-char-p (char-after (1+ (point))))))

(defun my/vim-punct-char-p ()
  "Vim 标点：非词、非空白。两侧夹着词的 `-' 不算。"
  (let ((char (char-after)))
    (and char
         (not (memq char '(?\s ?\t ?\n ?\r ?\f)))
         (not (my/vim-word-char-p char))
         (not (my/at-middle-hyphen-p)))))

(defun my/skip-pred-forward (pred)
  (while (and (not (eobp)) (funcall pred))
    (forward-char)))

(defun my/skip-pred-backward (pred)
  (while (and (not (bobp))
              (save-excursion (backward-char) (funcall pred)))
    (backward-char)))

(defun my/forward-whole-word (count)
  "前进一个 Vim 词，并吃掉后面的 `-<词>'。COUNT 为负则退到词首。"
  (my/with-vim-word-syntax
   (lambda ()
     (let (stuck)
       (if (and count (< count 0))
           (progn
             (forward-word-strictly -1)
             (while (and (not stuck)
                         (eq (char-before) ?-)
                         (my/vim-word-char-p (char-before (1- (point)))))
               (let ((origin (point)))
                 (backward-char 1)
                 (forward-word-strictly -1)
                 (unless (< (point) origin)
                   (goto-char origin)
                   (setq stuck t)))))
         (forward-word-strictly 1)
         (while (and (not stuck) (my/at-middle-hyphen-p))
           (let ((origin (point)))
             (forward-char 1)
             (forward-word-strictly 1)
             (unless (> (point) origin)
               (goto-char origin)
               (setq stuck t)))))))))

(defun my/forward-vim-punct (count)
  "前进一段 Vim 标点。中间短横线视作词的一部分，不在这里停。"
  (my/with-vim-word-syntax
   (lambda ()
     (let ((start (point)))
       (if (and count (< count 0))
           (progn
             (my/skip-pred-backward (lambda () (not (my/vim-punct-char-p))))
             (my/skip-pred-backward #'my/vim-punct-char-p))
         (my/skip-pred-forward (lambda () (not (my/vim-punct-char-p))))
         (my/skip-pred-forward #'my/vim-punct-char-p))
       (if (= (point) start) count 0)))))

(defun forward-evil-whole-word (&optional count)
  "Vim 词运动，外加中间短横线。
`fooBar' / `foo_bar' / `foo-bar' 各算一个词；`foo.bar'、`-foo'、`--flag' 按标点切开。
`Node {' 上 `dw' 只删到 `{' 之前。

返回**未能移动的次数**（0 = 成功）——evil `forward-op' 的约定：
`evil-forward-nearest' 用 `(zerop ...)' 判断成功。返回 nil 会让 aw/b 报
wrong-type-argument。"
  (evil-forward-nearest
   count
   (lambda (&optional cnt)
     (let ((pnt (point)))
       (my/forward-whole-word cnt)
       (if (= pnt (point)) cnt 0)))
   #'my/forward-vim-punct
   #'forward-evil-empty-line))

;; forward-thing 'evil-word' 解析到 (intern-soft "forward-evil-word")，defalias 这一个函数就够
(defalias #'forward-evil-word #'forward-evil-whole-word)

;; ---- 搜索光标下的整词：`*' / `#' ----
;; ⚠ evil-search 会把 `*' 改绑到取词用 Emacs `word' 的版本，故自建：取词走 evil-word、搜索仍走 evil-ex
(defun my/evil-ex-search-word-regex (string)
  "整词 STRING 的搜索正则。词边界处理见上方说明。"
  (let ((w (replace-regexp-in-string "\\`-+\\|-+\\'" "" string)))
    (if (string-empty-p w)
        (regexp-quote string)           ; 整词全是 `-'，无从加边界
      (format "\\<%s\\>" (regexp-quote w)))))

(defun my/evil-ex-start-word-search (direction count)
  "取词用 `evil-word'（整词），搜索仍走 evil-ex；见上方说明。"
  (let* ((string (or (evil-find-thing (eq direction 'forward) 'evil-word)
                     (user-error "No word under point")))
         (regex (my/evil-ex-search-word-regex string)))
    (setq evil-ex-search-count count
          evil-ex-search-direction direction
          evil-ex-search-pattern
          (let (evil-ex-search-vim-style-regexp)
            (evil-ex-make-search-pattern regex))
          evil-ex-search-offset nil
          evil-ex-last-was-search t)
    (unless (equal regex (car evil-ex-search-history))
      (push regex evil-ex-search-history))
    (evil-push-search-history regex (eq direction 'forward)))
  (evil-ex-delete-hl 'evil-ex-search)
  (evil-ex-search-next count))

(evil-define-motion my/evil-ex-search-word-forward (count &optional _symbol)
  "搜索光标下的整词（前向）；走 evil-ex，故 `gn' / `cgn' 可用。"
  :jump t :type exclusive
  (interactive (list (prefix-numeric-value current-prefix-arg)))
  (my/evil-ex-start-word-search 'forward count))
(evil-define-motion my/evil-ex-search-word-backward (count &optional _symbol)
  "搜索光标下的整词（后向）；走 evil-ex，故 `gn' / `cgn' 可用。"
  :jump t :type exclusive
  (interactive (list (prefix-numeric-value current-prefix-arg)))
  (my/evil-ex-start-word-search 'backward count))

(define-key evil-motion-state-map "*" #'my/evil-ex-search-word-forward)
(define-key evil-motion-state-map "#" #'my/evil-ex-search-word-backward)
;; `g*'/`g#' 无边界版用不上，显式解绑
(define-key evil-motion-state-map "g*" nil)
(define-key evil-motion-state-map "g#" nil)

(defun forward-evil-subword (&optional count)
  "Move forward COUNT subwords；返回未能移动的个数（0 = 成功），同 evil forward-op 约定。"
  (let* ((count (or count 1))
         (n (abs count))
         (dir (if (> count 0) 1 -1)))
    (while (and (> n 0)
                (let ((start (point)))
                  (subword-forward dir)
                  (/= start (point))))
      (setq n (1- n)))
    n))

(put 'evil-subword 'forward-op #'forward-evil-subword)

(evil-define-text-object evil-inner-subword (count &optional beg end type)
  "Select inner subword."
  (evil-select-inner-object 'evil-subword beg end type count))

(evil-define-text-object evil-a-subword (count &optional beg end type)
  "Select a subword plus adjacent whitespace.
不用 `evil-select-an-object'：它对「两对象之间无空白」的 subword 会多吞一个后继对象
（实测在 fooBarBaz 上会选成 fooBar），改为在 inner 范围上补相邻空白。"
  (let* ((range (evil-select-inner-object 'evil-subword beg end type count))
         (b (evil-range-beginning range))
         (e (evil-range-end range)))
    (if (and b e (< b e))
        (save-excursion
          (goto-char e)
          (let ((ws (skip-chars-forward " \t")))
            (if (> ws 0)
                (evil-range b (+ e ws) type :expanded t)
              (goto-char b)
              (let ((ws2 (skip-chars-backward " \t")))
                (evil-range (+ b ws2) e type :expanded t)))))
      range)))

(define-key evil-outer-text-objects-map (kbd "SPC w") 'evil-a-subword)
(define-key evil-inner-text-objects-map (kbd "SPC w") 'evil-inner-subword)

(provide 'evil-config)
