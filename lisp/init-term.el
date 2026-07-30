;; init-term.el 	-*- lexical-binding: t -*-
;; eshell 配置

;; eshell 键绑定
;;(define-key eshell-mode-map (kbd "C-l") 'eshell-clear)
;;(define-key eshell-mode-map (kbd "<M-tab>") 'tab-bar-switch-to-next-tab)
;; eshell 模式键绑定
;;(define-key eshell-mode-map (kbd "C-d") 'eshell-delchar-or-maybe-eof)
;;(define-key eshell-mode-map (kbd "C-r") 'consult-history)

;; eshell 自定义函数
(defun eshell-clear ()
  (interactive)
  (let ((eshell-buffer-maximum-lines 0))
    (eshell-truncate-buffer)
    (previous-line)
    (delete-char 1)))

;; eshell 配置
(add-hook 'completion-at-point-functions 'pcomplete-completations-at-point nil t)

;; eshell 别名文件。no-littering 把 `eshell-directory-name' 指到了 var/eshell/（运行期数据），
;; 但**别名是配置、要入库**，所以单独指到 etc/eshell/alias（etc/ 不在 gitignore 里）。
;; 历史 / lastdir 仍留在 var/eshell/。
(setq eshell-aliases-file
      (expand-file-name "etc/eshell/alias" user-emacs-directory))

;; eshell 自定义变量
(setq eshell-banner-message "")
(setq eshell-visual-commands '("bat" "less" "more" "htop" "man" "vim" "fish"))
(setq eshell-destroy-buffer-when-process-dies t)
(setq eshell-cmpl-autolist t)
(setq eshell-where-to-jump 'begin)
(setq eshell-review-quick-commands nil)
(setq eshell-smart-space-goes-to-end t)
(setq eshell-history-size 10000)


(autoload 'eshell-delchar-or-maybe-eof "em-rebind")

;; ================= 提示符 =================
;; 自写，替代 `eshell-git-prompt' 的 multiline2 主题——外观照抄它，只把两处贵的调用换掉。
;;
;; 为什么不用原包：`eshell-git-prompt-multiline2' 每画一次提示符要**起 4 个 git 进程**
;; （`eshell-git-prompt--branch-name' 在它函数体里被调了三遍，每遍都真的 spawn 一次，
;; 再加一次 `git status --porcelain'）。本机 `benchmark-run' 实测：整条提示符 945ms、
;; 单次 `git symbolic-ref' 225ms、`git status --porcelain' 255ms——Windows 上创建进程
;; 本来就贵，于是每敲一条命令回车后固定卡约 1 秒；连非仓库目录也要 422ms（分支名那两处
;; 仍会调）。这是 eshell「卡」的主因。
;;
;; 两处替代：
;;   - 分支名：直接读 .git/HEAD 这个纯文本文件（一行 "ref: refs/heads/xxx" 或裸 sha），
;;     0 次进程创建，微秒级。
;;   - 工作区脏/净（✗ / ✔）：`git status --porcelain' 没有便宜的文件替代品，改成**异步**
;;     跑，结果按仓库根缓存。画提示符时只读缓存、不阻塞；进程返回后再就地把提示符里那
;;     两个字符替换掉。所以最坏情况是 ✗/✔ 晚几百毫秒出现，而不是让你等它。

(defface my/eshell-prompt-secondary '((t :foreground "#51afef" :weight ultra-bold))
  "提示符的框线与分隔符。" :group 'eshell-prompt)
(defface my/eshell-prompt-user '((t :foreground "magenta" :weight ultra-bold))
  "提示符里的用户名。" :group 'eshell-prompt)
(defface my/eshell-prompt-host '((t :foreground "green" :weight ultra-bold))
  "提示符里的主机名。" :group 'eshell-prompt)
(defface my/eshell-prompt-dir '((t :foreground "white" :weight ultra-bold))
  "提示符里的当前目录名。" :group 'eshell-prompt)
(defface my/eshell-prompt-git '((t :foreground "red" :weight ultra-bold))
  "提示符里的 git 分支名。" :group 'eshell-prompt)
(defface my/eshell-prompt-clean
  '((((class color) (background light)) :foreground "forest green")
    (((class color) (background dark))  :foreground "green"))
  "分支图标与「工作区干净」标记 ✔。" :group 'eshell-prompt)
(defface my/eshell-prompt-dirty
  '((((class color) (background light)) :foreground "dark orange")
    (((class color) (background dark))  :foreground "red"))
  "「工作区有改动」标记 ✗。" :group 'eshell-prompt)
(defface my/eshell-prompt-fail '((t :foreground "red" :weight ultra-bold))
  "上条命令失败时的 >> 提示符。" :group 'eshell-prompt)
(defface my/eshell-prompt-time
  '((((class color) (background light)) :foreground "slate blue" :weight ultra-bold)
    (((class color) (background dark))  :foreground "gold" :weight ultra-bold))
  "提示符里的时间。" :group 'eshell-prompt)

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
  "eshell 提示符：外观同 eshell-git-prompt 的 multiline2，但渲染路径上不起 git 进程。"
  (let* ((sep (propertize ")──(" 'face 'my/eshell-prompt-secondary))
         (repo (my/eshell-prompt--repo))
         (root (car repo))
         (branch (and repo (my/eshell-prompt--branch (cdr repo)))))
    (when root (my/eshell-prompt--refresh-status root))
    (concat
     (propertize "\n┌─(" 'face 'my/eshell-prompt-secondary)
     (propertize (user-login-name) 'face 'my/eshell-prompt-user)
     (propertize "@" 'face 'my/eshell-prompt-secondary)
     (propertize (system-name) 'face 'my/eshell-prompt-host)
     sep
     (propertize (my/eshell-prompt--short-dir) 'face 'my/eshell-prompt-dir)
     (if branch
         (concat sep
                 (propertize "⎇ " 'face 'my/eshell-prompt-clean)
                 (propertize branch 'face 'my/eshell-prompt-git)
                 (propertize (my/eshell-prompt--slot-string
                              (gethash root my/eshell-prompt--dirty-cache))
                             my/eshell-prompt--slot-prop t))
       "")
     sep
     (propertize (format-time-string "%I:%M:%S %p") 'face 'my/eshell-prompt-time)
     (propertize ")\n└─" 'face 'my/eshell-prompt-secondary)
     (propertize ">>" 'face (if (my/eshell-prompt--success-p)
                                'my/eshell-prompt-secondary
                              'my/eshell-prompt-fail))
     (propertize " " 'face 'my/eshell-prompt-time))))

(setq eshell-prompt-function #'my/eshell-prompt)
;; `eshell-prompt-regexp' 在 30.1 起已标记 obsolete（提示符边界改用 field 属性），
;; 但 `eshell-forward-matching-input' 等老函数还在读它，跟原主题保持一致设上。
(setq eshell-prompt-regexp "^[^$\n]*└─>> ")

;; ================= 语法高亮 =================
(add-hook 'eshell-mode-hook 'eshell-syntax-highlighting-global-mode)

;; eshell-syntax-highlighting 挂在 `post-command-hook' 上，每次按键重解析整行输入，
;; 命令名 token 要走一次 `executable-find'：本机实测命中 7.4ms、**未命中 20.9ms**
;; （`exec-path' 44 项 × Windows 还要逐个试 .exe/.bat/.cmd 后缀），而命令名没敲完时
;; 走的全是未命中那条路——敲一个命令名就凭空多出上百毫秒。这里只在 eshell buffer 里
;; 给它套一层缓存（命中与否都缓存），别处的 `executable-find' 行为不变。
(defvar my/eshell--executable-cache (make-hash-table :test #'equal)
  "eshell 里 `executable-find' 的结果缓存：(命令 . remote) → 路径或 nil。")

(defun my/eshell-clear-executable-cache ()
  "清空 eshell 的 `executable-find' 缓存。装了新命令行工具后没被高亮成命令时用。"
  (interactive)
  (clrhash my/eshell--executable-cache)
  (message "eshell executable 缓存已清空"))

(defun my/eshell--executable-find-cached (orig command &optional remote)
  "只在 eshell buffer 里给 `executable-find' 加缓存（见上面的说明）。"
  (if (derived-mode-p 'eshell-mode)
      (let* ((key (cons command remote))
             (hit (gethash key my/eshell--executable-cache 'my/miss)))
        (if (eq hit 'my/miss)
            (puthash key (funcall orig command remote) my/eshell--executable-cache)
          hit))
    (funcall orig command remote)))

(advice-add 'executable-find :around #'my/eshell--executable-find-cached)
;; 内置 completion-preview-mode（Emacs 30+，替代 capf-autosuggest）在 eshell/comint 里
;; 是否启用由 init-completion.el 的补全风格切换（my/completion--set-preview-hooks）统一管理。
;; eshell 模式钩子
(add-hook 'eshell-mode-hook
          (lambda ()
            (setq eshell-prefer-lisp-functions t)
            (setq password-cache t)
            (setq password-cache-expiry 900)
            ;; (setenv "TERM" "xterm-256color")
            (setq-local truncate-lines -1)
            ))

(provide 'init-term)
