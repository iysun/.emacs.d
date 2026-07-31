;; extensions/eshell-prompt/eshell-prompt.el 	-*- lexical-binding: t -*-
;;
;; eshell 提示符实现本体，由 `lisp/init-term.el' `load'。
;;
;; 自写，两行结构：第一行目录+git分支/脏净，第二行 >>。曾经外观照抄
;; `eshell-git-prompt' 的 multiline2 主题（user@host、分段框线、时间都在），
;; 嫌太花后砍掉了这些装饰，只留下当初为了性能换掉的两处底层实现。
;;
;; 为什么不直接用 `eshell-git-prompt-multiline2'：它每画一次提示符要**起 4 个
;; git 进程**（`eshell-git-prompt--branch-name' 在它函数体里被调了三遍，每遍都
;; 真的 spawn 一次，再加一次 `git status --porcelain'）。本机 `benchmark-run'
;; 实测：整条提示符 945ms、单次 `git symbolic-ref' 225ms、`git status
;; --porcelain' 255ms——Windows 上创建进程本来就贵，于是每敲一条命令回车后固定
;; 卡约 1 秒；连非仓库目录也要 422ms（分支名那两处仍会调）。这是 eshell「卡」
;; 的主因。
;;
;; 两处替代：
;;   - 分支名：直接读 .git/HEAD 这个纯文本文件（一行 "ref: refs/heads/xxx" 或裸 sha），
;;     0 次进程创建，微秒级。
;;   - 工作区脏/净（✗ / ✔）：`git status --porcelain' 没有便宜的文件替代品，改成**异步**
;;     跑，结果按仓库根缓存。画提示符时只读缓存、不阻塞；进程返回后再就地把提示符里那
;;     两个字符替换掉。所以最坏情况是 ✗/✔ 晚几百毫秒出现，而不是让你等它。

(defface my/eshell-prompt-secondary '((t :foreground "#51afef" :weight ultra-bold))
  "提示符的 ┌─/└─ 前缀与括号。" :group 'eshell-prompt)
(defface my/eshell-prompt-dir '((t :foreground "white" :weight ultra-bold))
  "提示符里的当前目录名。" :group 'eshell-prompt)
(defface my/eshell-prompt-git '((t :foreground "red" :weight ultra-bold))
  "提示符里的 git 分支名。" :group 'eshell-prompt)
(defface my/eshell-prompt-clean
  '((((class color) (background light)) :foreground "forest green")
    (((class color) (background dark))  :foreground "green"))
  "「工作区干净」标记 ✔。" :group 'eshell-prompt)
(defface my/eshell-prompt-dirty
  '((((class color) (background light)) :foreground "dark orange")
    (((class color) (background dark))  :foreground "red"))
  "「工作区有改动」标记 ✗。" :group 'eshell-prompt)
(defface my/eshell-prompt-fail '((t :foreground "red" :weight ultra-bold))
  "上条命令失败时的 >> 提示符。" :group 'eshell-prompt)

(defvar my/eshell-prompt--dirty-cache (make-hash-table :test #'equal)
  "仓库根目录 → \\='dirty / \\='clean。异步 `git status' 的结果缓存，画提示符时只读它。")

(defvar-local my/eshell-prompt--status-proc nil
  "本 buffer 正在跑的异步 git status 进程；用来避免连按回车时堆一串重复进程。")

(defconst my/eshell-prompt--slot-prop 'my/eshell-prompt-status-slot
  "标记提示符里「脏/净」那两个字符的文本属性，供异步结果回来时定位替换。")

(defun my/eshell-prompt--repo ()
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

(defun my/eshell-prompt--branch (git-dir)
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

(defun my/eshell-prompt--slot-string (state)
  "STATE（\\='dirty / \\='clean / nil=还没算出来）对应的两字符标记。
三种取值宽度都是 2，异步结果回来时才能等长替换、不挪动后面的 marker。"
  (pcase state
    ('dirty (propertize " ✗" 'face 'my/eshell-prompt-dirty))
    ('clean (propertize " ✔" 'face 'my/eshell-prompt-clean))
    (_      (propertize " …" 'face 'my/eshell-prompt-secondary))))

(defun my/eshell-prompt--update-slot (buffer state)
  "把 BUFFER 里最后一个提示符的脏/净标记就地换成 STATE 对应的字符。
提示符已经作为只读文本插进 buffer 了，整条重画既贵又会打乱 field，所以只找带
`my/eshell-prompt--slot-prop' 的那两个字符替换，并把 eshell 加在它身上的
field / read-only / front-sticky 等属性原样搬过去（丢了会破坏 C-a 与提示符间跳转）。"
  (when (buffer-live-p buffer)
    (with-current-buffer buffer
      (require 'text-property-search)
      (save-excursion
        (goto-char (point-max))
        (when-let* ((m (text-property-search-backward my/eshell-prompt--slot-prop t t)))
          (let* ((beg (prop-match-beginning m))
                 (end (prop-match-end m))
                 (new (my/eshell-prompt--slot-string state))
                 (props (plist-put (copy-sequence (text-properties-at beg))
                                   'face (get-text-property 0 'face new)))
                 (inhibit-read-only t))
            (delete-region beg end)
            (goto-char beg)
            (insert (apply #'propertize new props))))))))

(defun my/eshell-prompt--refresh-status (root)
  "异步跑一次 `git status --porcelain' 刷新 ROOT 的脏/净缓存，完成后就地更新提示符。
`--no-optional-locks' 避免这个纯查询顺手去写 index 锁，跟命令行里的 git 抢锁。"
  (unless (process-live-p my/eshell-prompt--status-proc)
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
                          (puthash root state my/eshell-prompt--dirty-cache)
                          (my/eshell-prompt--update-slot buffer state))))))))
      (setq my/eshell-prompt--status-proc proc)
      (unless proc (kill-buffer out)))))   ; 机器上没有 git：静默退化成只显示 …

(defun my/eshell-prompt--short-dir ()
  "只显示当前目录名（跟 multiline2 一致，不显示完整路径）。"
  (let ((dir (directory-file-name (abbreviate-file-name default-directory))))
    (if (string-empty-p (file-name-nondirectory dir))
        dir                             ; 盘符根目录，如 \"d:/\"
      (file-name-nondirectory dir))))

(defun my/eshell-prompt--success-p ()
  "上条命令是否成功。eshell 刚启动时 `eshell-last-command-status' 还没定义，按成功算。"
  (or (not (boundp 'eshell-last-command-status))
      (= eshell-last-command-status 0)))

(defun my/eshell-prompt ()
  "eshell 提示符：两行，第一行目录+git分支/脏净，第二行 >>。不起 git 进程。"
  (let* ((repo (my/eshell-prompt--repo))
         (root (car repo))
         (branch (and repo (my/eshell-prompt--branch (cdr repo)))))
    (when root (my/eshell-prompt--refresh-status root))
    (concat
     (propertize "\n┌─ " 'face 'my/eshell-prompt-secondary)
     (propertize (my/eshell-prompt--short-dir) 'face 'my/eshell-prompt-dir)
     (if branch
         (concat
          (propertize " (" 'face 'my/eshell-prompt-secondary)
          (propertize branch 'face 'my/eshell-prompt-git)
          (propertize (my/eshell-prompt--slot-string
                       (gethash root my/eshell-prompt--dirty-cache))
                      my/eshell-prompt--slot-prop t)
          (propertize ")" 'face 'my/eshell-prompt-secondary))
       "")
     (propertize "\n└─" 'face 'my/eshell-prompt-secondary)
     (propertize ">>" 'face (if (my/eshell-prompt--success-p)
                                'my/eshell-prompt-secondary
                              'my/eshell-prompt-fail))
     (propertize " " 'face 'my/eshell-prompt-secondary))))

(setq eshell-prompt-function #'my/eshell-prompt)
;; `eshell-prompt-regexp' 在 30.1 起已标记 obsolete（提示符边界改用 field 属性），
;; 但 `eshell-forward-matching-input' 等老函数还在读它，跟原主题保持一致设上。
(setq eshell-prompt-regexp "^[^$\n]*└─>> ")

(provide 'init-eshell-prompt)
