;; init-completion.el   -*- lexical-binding: t -*-

;; ⚠ evil-define-key 是宏，须编译期 require evil，否则 .elc 报 Invalid function
(eval-when-compile (require 'evil))

(progn
  (setq completion-styles '(orderless basic))
  (setq completion-category-defaults nil)
  (setq completion-category-overrides '((file (styles basic partial-completion))))
  )

;; ⚠ marginalia 调 compat--seconds-to-string，Emacs 31 的 compat 已删 → 保留 shim
(unless (fboundp 'compat--seconds-to-string)
  (defalias 'compat--seconds-to-string #'seconds-to-string))

(add-hook 'after-init-hook 'marginalia-mode)

(with-eval-after-load 'vertico
  (setq vertico-count 10)
  (setq vertico-cycle t)
  )
(add-hook 'after-init-hook  'vertico-mode)
(add-hook 'vertico-mode-hook  'vertico-reverse-mode)
(add-hook 'vertico-mode-hook  'vertico-multiform-mode)

(add-hook 'after-init-hook 'which-key-mode)

(setq prefix-help-command 'embark-prefix-help-command)
(progn 
  (defun posframe-display-buffer (buffer)
    (let ((default-bgc (face-attribute 'default :background))
          (hl (face-attribute 'highlight :background)))
      (when buffer (posframe-show
                    buffer
                    :poshandler 'posframe-poshandler-frame-center
                    :font-height 1.0
                    :font-width 1.0
                    :border-width 5
                    :left-fringe 20
                    :right-fringe 20
                    :border-color hl
                    :background-color default-bgc))))
  (defun embark-get-buffer-pos-display (orig-fun)
    (interactive)
    (let* ((orig-result (funcall orig-fun)))
      (lambda (&optional keymap targets prefix)
        (let ((result (funcall orig-result keymap targets prefix)))
          (when (and result (windowp result))
            (posframe-display-buffer (window-buffer result))
            (delete-window result))))))
  (advice-add #'embark-verbose-indicator :around #'embark-get-buffer-pos-display)
  )

(progn
  (advice-add #'register-preview :override #'consult-register-window)
  (setq register-preview-delay 0.5)
  (setq xref-show-xrefs-function #'consult-xref
        xref-show-definitions-function #'consult-xref)
  (setq consult-narrow-key ",")
  )

(add-hook 'completion-list-mode-hook 'consult-preview-at-point-mode)

(add-hook 'embark-collect-mode-hook 'consult-preview-at-point-mode)

(progn
  ;; ⚠ 必须 3：2 会让 gopls 扫全 module 返回上千条
  (setq corfu-auto-prefix 3)
  ;; ⚠ "." 走同步路径，会当场阻塞一次 LSP 往返
  (setq corfu-auto-trigger ".")
  (setq corfu-preview-current nil)
  (setq corfu-auto-delay 0.2)
  (setq corfu-popupinfo-delay '(0.4 . 0.2))
  (custom-set-faces
   '(corfu-border ((t (:inherit region :background unspecified)))))
  )

(with-eval-after-load 'corfu
  (keymap-set corfu-map "RET"
              `(menu-item "" nil :filter
                          ,(lambda (&optional _)
                             (unless (or (derived-mode-p 'eshell-mode 'comint-mode)
                                         (minibufferp))
                               #'corfu-send))))

  ;; ⚠ evil insert 的 C-n/C-p 优先级高于 corfu-map，只能在 evil-insert-state-map 里 filter 分流
  (evil-define-key 'insert 'global (kbd "C-n")
    `(menu-item "" evil-complete-next :filter
                ,(lambda (cmd)
                   (if (and corfu-mode completion-in-region-mode)
                       #'corfu-next
                     cmd))))
  (evil-define-key 'insert 'global (kbd "C-p")
    `(menu-item "" evil-complete-previous :filter
                ,(lambda (cmd)
                   (if (and corfu-mode completion-in-region-mode)
                       #'corfu-previous
                     cmd))))
  )

(setq text-mode-ispell-word-completion nil)

(setq read-extended-command-predicate #'command-completion-default-include-p)

(setq cape-dabbrev-check-other-buffers nil)
(add-to-list 'completion-at-point-functions #'cape-dabbrev)
(add-to-list 'completion-at-point-functions #'cape-file)
(add-to-list 'completion-at-point-functions #'cape-elisp-block)
(add-to-list 'completion-at-point-functions #'cape-keyword)
(add-to-list 'completion-at-point-functions #'cape-abbrev)

;; ⚠ 行内预览会跑全局 capf（含 eglot 的完整 LSP 请求），须用下面的 advice 换成纯本地 capf 表
(defvar my/completion-preview-capfs
  (list #'citre-completion-at-point #'cape-dabbrev #'cape-keyword #'cape-file)
  "行内预览专用的 capf 列表：只用本地廉价源，绝不含 LSP（eglot）。
citre 放最前面——它靠查 tags 文件，比 dabbrev 精确（带 kind/signature 标注），
但 `citre-completion-at-point' 的 collection 没声明 `:exclusive'，一旦有
匹配就会独占，必须排在 dabbrev/keyword/file 前面，否则永远轮不到它：
dabbrev 几乎对任何已在 buffer 里出现过的前缀都能凑出候选，排前面会先把
后面的 capf 全部挡住。citre-mode 没开、或当前 buffer 没有 tags 数据库时
它直接返回 nil，自动落到下面几个源。LSP 候选仍然走手动触发
（C-M-i / `my/lsp-complete'）或 auto 档的 corfu。")

;; ⚠ eshell 只有参数位能给 pcomplete（命令位会枚举 exec-path，很慢）；换掉它则文件名无候选
(defun my/completion-preview--eshell-in-args-p ()
  "point 是否已经离开命令名那一段（命令名与 point 之间出现过空白）。
起点用 `field-beginning'：提示符文本带 `field' = \\='prompt（`eshell-emit-prompt' 加的），
输入区是另一个 field，所以这里取到的就是本次输入的开头，不会把提示符里的空格算进去。"
  (let ((beg (field-beginning (point) t)))
    (string-match-p "[ \t]" (buffer-substring-no-properties beg (point)))))

(defun my/completion-preview--eshell-pcomplete ()
  "只在参数位生效的 pcomplete capf，供行内预览用（理由见上面的注释）。
⚠ 必须补上 `:exclusive no'：`completion-preview--capf-wrapper' 在一个 capf 给不出
候选时会返回 \\='(nil) 来**阻断**后面的 capf（只有声明了 `:exclusive no' 的才放行），
而 pcomplete 没声明。不补的话，参数位上但 pcomplete 无候选的输入（如 `echo hel'）
会被它挡住，落不到 cape-dabbrev，历史提示就没了。plist 里先出现的键优先，所以万一
pcomplete 以后自己带了 `:exclusive'，这里追加的这份会被自动忽略，不会改变它的意图。"
  (when (and (fboundp 'pcomplete-completions-at-point)
             (my/completion-preview--eshell-in-args-p))
    (when-let* ((res (pcomplete-completions-at-point)))
      (append res '(:exclusive no)))))

(defun my/completion-preview--capfs ()
  "预览该用的 capf 列表。
eshell/comint 里最前面放 `cape-history'——补的是 shell 历史（eshell 走
`eshell-history-ring'，即 var/eshell/history 那份持久化历史；comint 走
`comint-input-ring'），从输入行开头整行匹配，这才是 fish 那种\"敲前几个字母就把上次
的整条命令灰着显示出来\"的行为，也正是当年 capf-autosuggest 干的事。
`cape-dabbrev' 顶替不了它：dabbrev 扫的是**当前 buffer 的文本**，只能补到本次会话里
还留在屏幕上的词，重开一个 eshell 就什么都没有。

`cape-history' 自带 `:exclusive no'（没候选时放行后面的 capf）和
`:display-sort-function' / `:cycle-sort-function' = `identity'，
`completion-preview--try-table' 会读这两个 metadata，所以候选保持**最近优先**而不是
被默认的\"按长度+字母序\"重排——历史补全必须最近优先才对。

eshell 里第二条是「只在参数位生效的 pcomplete」：历史没命中时才轮到它补文件名。
comint 不加 pcomplete：那边的命令补全同样要扫 PATH，坑一样，且没有 eshell 这种统一
入口，留待真需要时再单独处理。"
  (cond
   ((derived-mode-p 'eshell-mode)
    (append (list #'cape-history #'my/completion-preview--eshell-pcomplete)
            my/completion-preview-capfs))
   ((derived-mode-p 'comint-mode)
    (cons #'cape-history my/completion-preview-capfs))
   (t my/completion-preview-capfs)))

(defun my/completion-preview--local-capfs (orig &rest args)
  "让 `completion-preview--update' 只看 `my/completion-preview--capfs' 给出的列表。"
  (let ((completion-at-point-functions (my/completion-preview--capfs)))
    (apply orig args)))

(with-eval-after-load 'completion-preview
  (advice-add 'completion-preview--update :around
              #'my/completion-preview--local-capfs)
  (setq completion-preview-minimum-symbol-length 2)
  ;; ⚠ 默认 nil = 每键同步跑一遍 capf，零防抖
  (setq completion-preview-idle-delay 0.05)
  (dolist (cmd '(evil-delete-backward-char
                 evil-delete-backward-char-and-join
                 evil-delete-char))
    (push cmd completion-preview-commands))
  )

(defconst my/completion-styles '(auto manual preview-only)
  "可选补全风格：
auto         corfu 自动弹出（打字即弹），关闭行内预览；
manual       corfu 仅手动触发（C-M-i / my/lsp-complete），开启行内预览；
preview-only 完全关闭 corfu 弹窗，只保留行内预览。")

(defun my/completion--preview-hook-list ()
  '(prog-mode-hook text-mode-hook eshell-mode-hook comint-mode-hook))

(defun my/completion--set-preview-hooks (enable)
  "把 completion-preview-mode 挂/摘到 prog/text/eshell/comint 四个 hook 上。"
  (dolist (hook (my/completion--preview-hook-list))
    (if enable
        (add-hook hook #'completion-preview-mode)
      (remove-hook hook #'completion-preview-mode))))

(defun my/completion--sync-preview-buffers (enable)
  "把已打开、属于上述四类 major-mode 的 buffer 里的 completion-preview-mode 同步到 ENABLE。"
  (dolist (buf (buffer-list))
    (with-current-buffer buf
      (when (derived-mode-p 'prog-mode 'text-mode 'eshell-mode 'comint-mode)
        (completion-preview-mode (if enable 1 -1))))))

(defun my/completion--set-corfu (enable)
  "联动 global-corfu-mode 及其 popupinfo/terminal 全局子模式。三者都是 :global t，
用显式 1/-1 而非 hook 里的隐式 toggle，避免反复切换风格后状态漂移。"
  (global-corfu-mode (if enable 1 -1))
  (corfu-popupinfo-mode (if enable 1 -1))
  (unless (display-graphic-p)
    (corfu-terminal-mode (if enable 1 -1))))

(defun my/apply-completion-style (style)
  "按 STYLE（auto/manual/preview-only）应用补全行为，对已打开的 buffer 立即生效。"
  (pcase style
    ('auto
     (setq corfu-auto t)
     (my/completion--set-corfu t)
     (my/completion--set-preview-hooks nil)
     (my/completion--sync-preview-buffers nil))
    ('manual
     (setq corfu-auto nil)
     (my/completion--set-corfu t)
     (my/completion--set-preview-hooks t)
     (my/completion--sync-preview-buffers t))
    ('preview-only
     (my/completion--set-corfu nil)
     (my/completion--set-preview-hooks t)
     (my/completion--sync-preview-buffers t))
    (_ (error "未知补全风格: %s" style))))

(defun switch-completion-style (style)
  "交互切换补全风格并持久化到 custom.el（仿 switch-emacs-theme）。"
  (interactive
   (list
    (intern (completing-read
             "select completion style: "
             (mapcar #'symbol-name my/completion-styles)
             nil t))))
  (my/apply-completion-style style)
  (customize-save-variable 'custom-completion-style style))

(defun use-completion-style ()
  (my/apply-completion-style
   (if (and (boundp 'custom-completion-style)
            (memq custom-completion-style my/completion-styles))
       custom-completion-style
     'manual)))
(add-hook 'after-init-hook 'use-completion-style)

(provide 'init-completion)
