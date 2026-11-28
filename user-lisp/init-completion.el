;; init-completion.el   -*- lexical-binding: t -*-

;; ⚠ evil-define-key 是宏，须编译期 require evil，否则 .elc 报 Invalid function
(eval-when-compile (require 'evil))
(declare-function lspmux-async-next "lspmux-async")
(declare-function lspmux-async-prev "lspmux-async")

(progn
  (setq completion-styles '(orderless basic))
  (setq completion-category-defaults nil)
  (setq completion-category-overrides '((file (styles basic partial-completion))))
  )

;; 拼音首字母：z→[z中张…]，故 zw 命中「中文」；要求首字母连续
(defun iys/orderless-pinyin (component)
  "把纯 ASCII 字母组件按拼音首字母匹配中文候选。"
  (when (and (>= (length component) 2)
             (string-match-p "\\`[a-zA-Z]+\\'" component))
    (require 'pinyinlib)
    (orderless-regexp (pinyinlib-build-regexp-string component t))))

(with-eval-after-load 'orderless
  (add-to-list 'orderless-matching-styles #'iys/orderless-pinyin))

(add-hook 'after-init-hook 'marginalia-mode)

(with-eval-after-load 'vertico
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

;; ---- 搜索种子：单行选区优先，否则取光标处内容 ----
(defun iys/search-seed (&optional thing)
  "单行选区 → 选区文本；否则 → 光标处的 THING（默认 symbol）。"
  (cond
   ((use-region-p)
    (let ((beg (region-beginning)) (end (region-end)))
      (when (= (line-number-at-pos beg) (line-number-at-pos end))
        (string-trim (buffer-substring-no-properties beg end)))))
   (t (thing-at-point (or thing 'symbol) t))))

(defun iys/search--delete-seed ()
  "种子仍整段选中时，DEL/Delete 删掉整段而不是一个字符。"
  (when (and (use-region-p)
             (memq this-command '(delete-backward-char delete-char
                                  backward-delete-char-untabify))
             (= (region-beginning) (minibuffer-prompt-end))
             (= (region-end) (point-max)))
    (delete-region (region-beginning) (region-end))
    (deactivate-mark)
    (setq this-command 'ignore)))

(defun iys/search--select-seed ()
  "选中 minibuffer 里的初始输入，并让 DEL/Delete 能一次清空。"
  (when (and (minibufferp) (> (point-max) (minibuffer-prompt-end)))
    (push-mark (minibuffer-prompt-end) nil t)
    (goto-char (point-max))
    (add-hook 'pre-command-hook #'iys/search--delete-seed nil t)))

;; 下面每个 wrapper 都让 M-s 开头的搜索带上光标处内容，并在 minibuffer 里全选
(defun iys/consult-line (&optional arg)
  "`consult-line'，带光标处内容作为初始输入。"
  (interactive "P")
  (minibuffer-with-setup-hook #'iys/search--select-seed
    (consult-line (iys/search-seed) (and arg t))))

(defun iys/consult-line-multi (&optional query)
  "`consult-line-multi'，带光标处内容作为初始输入。"
  (interactive "P")
  (minibuffer-with-setup-hook #'iys/search--select-seed
    (consult-line-multi query (iys/search-seed))))

(defun iys/consult-ripgrep (&optional dir)
  "`consult-ripgrep'，带光标处内容作为初始输入。"
  (interactive "P")
  (minibuffer-with-setup-hook #'iys/search--select-seed
    (consult-ripgrep dir (iys/search-seed))))

(defun iys/consult-grep (&optional dir)
  "`consult-grep'，带光标处内容作为初始输入。"
  (interactive "P")
  (minibuffer-with-setup-hook #'iys/search--select-seed
    (consult-grep dir (iys/search-seed))))

(defun iys/consult-git-grep (&optional dir)
  "`consult-git-grep'，带光标处内容作为初始输入。"
  (interactive "P")
  (minibuffer-with-setup-hook #'iys/search--select-seed
    (consult-git-grep dir (iys/search-seed))))

(defun iys/consult-fd (&optional dir)
  "`consult-fd'，优先用光标处的文件名作为初始输入。"
  (interactive "P")
  (minibuffer-with-setup-hook #'iys/search--select-seed
    (consult-fd dir (or (iys/search-seed 'filename) (iys/search-seed)))))

(defun iys/consult-locate (&optional initial)
  "`consult-locate'，优先用光标处的文件名作为初始输入。"
  (interactive)
  (minibuffer-with-setup-hook #'iys/search--select-seed
    (consult-locate (or initial (iys/search-seed 'filename) (iys/search-seed)))))

(defun iys/consult-keep-lines ()
  "`consult-keep-lines'，带光标处内容作为初始输入。"
  (interactive)
  (minibuffer-with-setup-hook #'iys/search--select-seed
    (consult-keep-lines
     (lambda (pattern cands)
       (consult--completion-filter-dispatch pattern cands 'consult-location 'highlight))
     (iys/search-seed))))

(defun iys/consult-focus-lines ()
  "`consult-focus-lines'，带光标处内容作为初始输入。"
  (interactive)
  (minibuffer-with-setup-hook #'iys/search--select-seed
    (consult-focus-lines
     (lambda (pattern cands)
       (consult--completion-filter-dispatch pattern cands 'consult-location 'highlight))
     nil
     (iys/search-seed))))

(progn
  ;; ⚠ "." 走同步路径，会当场阻塞一次 LSP 往返
  (setq corfu-auto-trigger ".")
  (setq corfu-preview-current nil)
  ;; popupinfo 是第二个子 frame，还会同步做 completionItem/resolve。
  ;; 后续延迟太短时，每换一个候选就改一次尺寸；PGTK 上要等合成器。
  ;; 停够一秒才更新，快速翻候选不会跟着弹。
  (setq corfu-popupinfo-delay '(1.0 . 1.0))
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
                   (cond
                    ((bound-and-true-p lspmux-async-menu-mode) #'lspmux-async-next)
                    ((and corfu-mode completion-in-region-mode) #'corfu-next)
                    (t cmd)))))
  (evil-define-key 'insert 'global (kbd "C-p")
    `(menu-item "" evil-complete-previous :filter
                ,(lambda (cmd)
                   (cond
                    ((bound-and-true-p lspmux-async-menu-mode) #'lspmux-async-prev)
                    ((and corfu-mode completion-in-region-mode) #'corfu-previous)
                    (t cmd)))))
  )

(setq text-mode-ispell-word-completion nil)

(setq read-extended-command-predicate #'command-completion-default-include-p)

(setq cape-dabbrev-check-other-buffers nil)
(add-to-list 'completion-at-point-functions #'cape-dabbrev)
(add-to-list 'completion-at-point-functions #'cape-file)
(add-to-list 'completion-at-point-functions #'cape-elisp-block)
(add-to-list 'completion-at-point-functions #'cape-keyword)
(add-to-list 'completion-at-point-functions #'cape-abbrev)

;; 不直接用全局 completion-at-point-functions：里面还有 elisp/abbrev，顺序也不是预览要的。
;; LSP 候选走 lspmux 仓库里的 `lspmux-async' 菜单，不进这条同步 capf。
(defvar iys/completion-preview-capfs
  (list #'cape-dabbrev #'cape-keyword #'cape-file)
  "行内预览用的本地 capf。")

;; ⚠ eshell 只有参数位能给 pcomplete（命令位会枚举 exec-path，很慢）；换掉它则文件名无候选
(defun iys/completion-preview--eshell-in-args-p ()
  "point 是否已经离开命令名那一段（命令名与 point 之间出现过空白）。
起点用 `field-beginning'：提示符文本带 `field' = \\='prompt（`eshell-emit-prompt' 加的），
输入区是另一个 field，所以这里取到的就是本次输入的开头，不会把提示符里的空格算进去。"
  (let ((beg (field-beginning (point) t)))
    (string-match-p "[ \t]" (buffer-substring-no-properties beg (point)))))

(defun iys/completion-preview--eshell-pcomplete ()
  "只在参数位生效的 pcomplete capf，供行内预览用（理由见上面的注释）。
⚠ 必须补上 `:exclusive no'：`completion-preview--capf-wrapper' 在一个 capf 给不出
候选时会返回 \\='(nil) 来**阻断**后面的 capf（只有声明了 `:exclusive no' 的才放行），
而 pcomplete 没声明。不补的话，参数位上但 pcomplete 无候选的输入（如 `echo hel'）
会被它挡住，落不到 cape-dabbrev，历史提示就没了。plist 里先出现的键优先，所以万一
pcomplete 以后自己带了 `:exclusive'，这里追加的这份会被自动忽略，不会改变它的意图。"
  (when (and (fboundp 'pcomplete-completions-at-point)
             (iys/completion-preview--eshell-in-args-p))
    (when-let* ((res (pcomplete-completions-at-point)))
      (append res '(:exclusive no)))))

(defun iys/completion-preview--capfs ()
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
入口，留待真需要时再单独处理。

其它 buffer 只用本地词。LSP 候选在 `lspmux-async' 的菜单里，不走这条同步 capf。"
  (cond
   ((derived-mode-p 'eshell-mode)
    (append (list #'cape-history #'iys/completion-preview--eshell-pcomplete)
            iys/completion-preview-capfs))
   ((derived-mode-p 'comint-mode)
    (cons #'cape-history iys/completion-preview-capfs))
   (t iys/completion-preview-capfs)))

(defun iys/completion-preview--local-capfs (orig &rest args)
  "让 `completion-preview--update' 只看 `iys/completion-preview--capfs' 给出的列表。"
  (let ((completion-at-point-functions (iys/completion-preview--capfs)))
    (apply orig args)))

(with-eval-after-load 'completion-preview
  (advice-add 'completion-preview--update :around
              #'iys/completion-preview--local-capfs)
  (setq completion-preview-minimum-symbol-length 2)
  ;; ⚠ 默认 nil = 每键同步跑一遍 capf，零防抖
  (setq completion-preview-idle-delay 0.05)
  (dolist (cmd '(evil-delete-backward-char
                 evil-delete-backward-char-and-join
                 evil-delete-char))
    (push cmd completion-preview-commands))
  )

(defconst iys/completion-styles '(auto manual preview-only)
  "可选补全风格：
auto         corfu 自动弹出（打字即弹），关闭行内预览；
manual       corfu 仅手动触发（C-M-i / iys/lsp-complete），开启行内预览；
preview-only 完全关闭 corfu 弹窗，只保留行内预览。")

(defcustom iys/completion-style nil
  "启动时应用的补全风格；nil 表示 manual。"
  :type '(choice (const auto) (const manual) (const preview-only))
  :group 'completion)

(defun iys/completion--preview-hook-list ()
  '(prog-mode-hook text-mode-hook eshell-mode-hook comint-mode-hook))

(defun iys/completion--set-preview-hooks (enable)
  "把 completion-preview-mode 挂/摘到 prog/text/eshell/comint 四个 hook 上。"
  (dolist (hook (iys/completion--preview-hook-list))
    (if enable
        (add-hook hook #'completion-preview-mode)
      (remove-hook hook #'completion-preview-mode))))

(defun iys/completion--sync-preview-buffers (enable)
  "把已打开、属于上述四类 major-mode 的 buffer 里的 completion-preview-mode 同步到 ENABLE。"
  (dolist (buf (buffer-list))
    (with-current-buffer buf
      (when (derived-mode-p 'prog-mode 'text-mode 'eshell-mode 'comint-mode)
        (completion-preview-mode (if enable 1 -1))))))

(defun iys/completion--set-corfu (enable)
  "联动 global-corfu-mode 与 corfu-popupinfo-mode。两者都是 :global t，
用显式 1/-1 而非 hook 里的隐式 toggle，避免反复切换风格后状态漂移。"
  (global-corfu-mode (if enable 1 -1))
  (corfu-popupinfo-mode (if enable 1 -1)))

(defun iys--apply-completion-style (style)
  "按 STYLE（auto/manual/preview-only）应用补全行为，对已打开的 buffer 立即生效。"
  (pcase style
    ('auto
     (setq corfu-auto t)
     (iys/completion--set-corfu t)
     (iys/completion--set-preview-hooks nil)
     (iys/completion--sync-preview-buffers nil))
    ('manual
     (setq corfu-auto nil)
     (iys/completion--set-corfu t)
     (iys/completion--set-preview-hooks t)
     (iys/completion--sync-preview-buffers t))
    ('preview-only
     (iys/completion--set-corfu nil)
     (iys/completion--set-preview-hooks t)
     (iys/completion--sync-preview-buffers t))
    (_ (error "未知补全风格: %s" style))))

(defun iys/switch-completion-style (style)
  "交互切换补全风格并持久化到 custom.el（仿 iys/switch-emacs-theme）。"
  (interactive
   (list
    (intern (completing-read
             "select completion style: "
             (mapcar #'symbol-name iys/completion-styles)
             nil t))))
  (iys--apply-completion-style style)
  (customize-save-variable 'iys/completion-style style))

(defun iys/use-completion-style ()
  (iys--apply-completion-style
   (if (and (boundp 'iys/completion-style)
            (memq iys/completion-style iys/completion-styles))
       iys/completion-style
     'manual)))
(add-hook 'after-init-hook 'iys/use-completion-style)

(provide 'init-completion)
