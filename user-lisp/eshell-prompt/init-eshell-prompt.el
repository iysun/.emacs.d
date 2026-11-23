;; user-lisp/eshell-prompt/init-eshell-prompt.el 	-*- lexical-binding: t -*-

(defface iys/eshell-prompt-secondary '((t :foreground "#51afef" :weight ultra-bold))
  "提示符的 ┌─/└─ 前缀与括号。" :group 'eshell-prompt)
(defface iys/eshell-prompt-dir '((t :foreground "white" :weight ultra-bold))
  "提示符里的当前目录名。" :group 'eshell-prompt)
(defface iys/eshell-prompt-git '((t :foreground "red" :weight ultra-bold))
  "提示符里的 git 分支名。" :group 'eshell-prompt)
(defface iys/eshell-prompt-clean
  '((((class color) (background light)) :foreground "forest green")
    (((class color) (background dark))  :foreground "green"))
  "「工作区干净」标记 ✔。" :group 'eshell-prompt)
(defface iys/eshell-prompt-dirty
  '((((class color) (background light)) :foreground "dark orange")
    (((class color) (background dark))  :foreground "red"))
  "「工作区有改动」标记 ✗。" :group 'eshell-prompt)
(defface iys/eshell-prompt-fail '((t :foreground "red" :weight ultra-bold))
  "上条命令失败时的 >> 提示符。" :group 'eshell-prompt)

(defvar iys/eshell-prompt--dirty-cache (make-hash-table :test #'equal)
  "仓库根目录 → \\='dirty / \\='clean。异步 `git status' 的结果缓存，画提示符时只读它。")

(defvar-local iys/eshell-prompt--status-proc nil
  "本 buffer 正在跑的异步 git status 进程；用来避免连按回车时堆一串重复进程。")

(defconst iys/eshell-prompt--slot-prop 'iys/eshell-prompt-status-slot
  "标记提示符里「脏/净」那两个字符的文本属性，供异步结果回来时定位替换。")

(defun iys/eshell-prompt--repo ()
  "返回 (仓库根 . .git 目录)，不在 git 仓库里则返回 nil。全程只 stat 文件，不起进程。
worktree / submodule 里 .git 是个文本文件，内容形如 \"gitdir: ../.git/worktrees/x\"，
这里跟着解析一层。"
  (when-let* ((root (locate-dominating-file default-directory ".git")))
    (let ((dot-git (expand-file-name ".git" root)))
      (cond
       ((file-directory-p dot-git) (cons root (file-name-as-directory dot-git)))
       ((file-regular-p dot-git)
        (with-temp-buffer
          (insert-file-contents dot-git nil 0 512)
          (goto-char (point-min))
          (when (looking-at "gitdir:[ \t]*\\(.+\\)")
            (cons root (file-name-as-directory
                        (expand-file-name (string-trim (match-string 1)) root))))))))))

(defun iys/eshell-prompt--branch (git-dir)
  "从 GIT-DIR/HEAD 读出分支名；游离 HEAD 时退回短 sha。读文件，不 spawn git。"
  (let ((head (expand-file-name "HEAD" git-dir)))
    (when (file-readable-p head)
      (with-temp-buffer
        (insert-file-contents head nil 0 256)
        (goto-char (point-min))
        (cond
         ((looking-at "ref:[ \t]*refs/heads/\\(.+\\)") (string-trim (match-string 1)))
         ((looking-at "ref:[ \t]*\\(.+\\)")            (string-trim (match-string 1)))
         ((looking-at "\\([0-9a-fA-F]\\{7\\}\\)")      (match-string 1)))))))

(defun iys/eshell-prompt--slot-string (state)
  "STATE（\\='dirty / \\='clean / nil=还没算出来）对应的两字符标记。
三种取值宽度都是 2，异步结果回来时才能等长替换、不挪动后面的 marker。"
  (pcase state
    ('dirty (propertize " ✗" 'face 'iys/eshell-prompt-dirty))
    ('clean (propertize " ✔" 'face 'iys/eshell-prompt-clean))
    (_      (propertize " …" 'face 'iys/eshell-prompt-secondary))))

(defun iys/eshell-prompt--update-slot (buffer state)
  "把 BUFFER 里最后一个提示符的脏/净标记就地换成 STATE 对应的字符。
提示符已经作为只读文本插进 buffer 了，整条重画既贵又会打乱 field，所以只找带
`iys/eshell-prompt--slot-prop' 的那两个字符替换，并把 eshell 加在它身上的
field / read-only / front-sticky 等属性原样搬过去（丢了会破坏 C-a 与提示符间跳转）。"
  (when (buffer-live-p buffer)
    (with-current-buffer buffer
      (require 'text-property-search)
      (save-excursion
        (goto-char (point-max))
        (when-let* ((m (text-property-search-backward iys/eshell-prompt--slot-prop t t)))
          (let* ((beg (prop-match-beginning m))
                 (end (prop-match-end m))
                 (new (iys/eshell-prompt--slot-string state))
                 (props (plist-put (copy-sequence (text-properties-at beg))
                                   'face (get-text-property 0 'face new)))
                 (inhibit-read-only t))
            (delete-region beg end)
            (goto-char beg)
            (insert (apply #'propertize new props))))))))

(defun iys/eshell-prompt--refresh-status (root)
  "异步跑一次 `git status --porcelain' 刷新 ROOT 的脏/净缓存，完成后就地更新提示符。
`--no-optional-locks' 避免这个纯查询顺手去写 index 锁，跟命令行里的 git 抢锁。"
  (unless (process-live-p iys/eshell-prompt--status-proc)
    (let* ((buffer (current-buffer))
           (default-directory root)
           (out (generate-new-buffer " *eshell-prompt-git-status*"))
           (proc (ignore-errors
                   (make-process
                    :name "eshell-prompt-git-status"
                    :buffer out
                    :noquery t
                    :connection-type 'pipe
                    :command '("git" "--no-optional-locks" "status" "--porcelain")
                    :sentinel
                    (lambda (proc _event)
                      (unless (process-live-p proc)
                        (let ((state (if (> (buffer-size (process-buffer proc)) 0)
                                         'dirty 'clean)))
                          (kill-buffer (process-buffer proc))
                          (puthash root state iys/eshell-prompt--dirty-cache)
                          (iys/eshell-prompt--update-slot buffer state))))))))
      (setq iys/eshell-prompt--status-proc proc)
      (unless proc (kill-buffer out)))))

(defun iys/eshell-prompt--short-dir ()
  "只显示当前目录名（跟 multiline2 一致，不显示完整路径）。"
  (let ((dir (directory-file-name (abbreviate-file-name default-directory))))
    (if (string-empty-p (file-name-nondirectory dir))
        dir
      (file-name-nondirectory dir))))

(defun iys/eshell-prompt--success-p ()
  "上条命令是否成功。eshell 刚启动时 `eshell-last-command-status' 还没定义，按成功算。"
  (or (not (boundp 'eshell-last-command-status))
      (= eshell-last-command-status 0)))

(defun iys/eshell-prompt ()
  "eshell 提示符：两行，第一行目录+git分支/脏净，第二行 >>。不起 git 进程。"
  (let* ((repo (iys/eshell-prompt--repo))
         (root (car repo))
         (branch (and repo (iys/eshell-prompt--branch (cdr repo)))))
    (when root (iys/eshell-prompt--refresh-status root))
    (concat
     (propertize "\n┌─ " 'face 'iys/eshell-prompt-secondary)
     (propertize (iys/eshell-prompt--short-dir) 'face 'iys/eshell-prompt-dir)
     (if branch
         (concat
          (propertize " (" 'face 'iys/eshell-prompt-secondary)
          (propertize branch 'face 'iys/eshell-prompt-git)
          (propertize (iys/eshell-prompt--slot-string
                       (gethash root iys/eshell-prompt--dirty-cache))
                      iys/eshell-prompt--slot-prop t)
          (propertize ")" 'face 'iys/eshell-prompt-secondary))
       "")
     (propertize "\n└─" 'face 'iys/eshell-prompt-secondary)
     (propertize ">>" 'face (if (iys/eshell-prompt--success-p)
                                'iys/eshell-prompt-secondary
                              'iys/eshell-prompt-fail))
     (propertize " " 'face 'iys/eshell-prompt-secondary))))

(setq eshell-prompt-function #'iys/eshell-prompt)
;; ⚠ obsolete 但仍被 eshell-forward-matching-input 等读，不能删
(setq eshell-prompt-regexp "^[^$\n]*└─>> ")

(provide 'init-eshell-prompt)
