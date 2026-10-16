;; init-base.el 	-*- lexical-binding: t -*-

(require 'cl-lib)

(require 'gcmh)
(setq gcmh-high-cons-threshold (* 128 1024 1024))
(gcmh-mode 1)

;; (add-hook 'after-init-hook 'toggle-frame-maximized)
(progn
  (global-auto-revert-mode t)
  (setq make-backup-files nil)
  (setq use-short-answers t)
  (setq select-enable-clipboard nil)

  (setq-default indent-tabs-mode nil)

  (setq project-vc-extra-root-markers '(".project"))

  (global-hl-line-mode t)

  (setq jit-lock-defer-time 0.1)
  )

(setq eldoc-echo-area-prefer-doc-buffer t)

(defun my/doc-at-point ()
  "看光标处符号的文档。第一次按弹出 eldoc 文档窗口，窗口已开时再按一次跳进去（便于翻页/复制）。

弹窗直接调内置的 `eldoc'（= `eldoc-print-current-symbol-info'）：它交互调用时走
`eldoc--invoke-strategy' 的 interactive 分支，**绕过 `eldoc-idle-delay' 立刻请求一次**，
并把 interactive 标志一路透传给 `eldoc-display-in-buffer'，由后者在**异步结果回来之后**
才弹窗——eglot 的 textDocument/hover 是异步的，这一点很关键。
⚠ 别图省事直接绑 `eldoc-doc-buffer'：那个只读「上一次」算出来的结果，刚跳到新符号上按
就会显示上一个符号的陈旧内容，而且从没算过时直接 `user-error'。
另：`eldoc' 不要求 `eldoc-mode' 开着，只要 buffer 里 `eldoc-documentation-functions' 非空。"
  (interactive)
  ;; ⚠ 显示时被改名为 *eldoc for <sym>*，只能靠此内部变量定位
  (let ((win (and (buffer-live-p eldoc--doc-buffer)
                  (get-buffer-window eldoc--doc-buffer))))
    (if (and win (not (eq win (selected-window))))
        (select-window win)
      (call-interactively #'eldoc))))

(add-hook 'after-init-hook 'savehist-mode)
(progn
  (setq enable-recursive-minibuffers t)
  (setq history-length 1000)
  (setq savehist-additional-variables '(kill-ring
                                        register-alist
                                        mark-ring
                                        global-mark-ring
                                        search-ring
                                        regexp-search-ring
                                        extended-command-history))
  (setq savehist-autosave-interval 300)
  )

;; ⚠ 不剥属性会让 savehist 膨胀，不可打印对象则整次保存失败
(defun my/savehist-unpropertize ()
  (setq kill-ring
        (mapcar #'substring-no-properties
                (cl-remove-if-not #'stringp kill-ring))
        register-alist
        (cl-loop for (reg . item) in register-alist
                 if (stringp item)
                 collect (cons reg (substring-no-properties item))
                 else collect (cons reg item))))

(defun my/savehist-drop-unprintable-registers ()
  (setq register-alist (cl-remove-if-not #'savehist-printable register-alist)))

(with-eval-after-load 'savehist
  (add-hook 'savehist-save-hook #'my/savehist-unpropertize)
  (add-hook 'savehist-save-hook #'my/savehist-drop-unprintable-registers))

(add-hook 'after-init-hook 'recentf-mode)
(progn
  (setq recentf-max-saved-items 300)
  (setq recentf-auto-cleanup 'never)
  (setq recentf-filename-handlers '(abbreviate-file-name))
  )

;; ⚠ C-x b 已绑 consult-buffer、不读此 frame 参数，看不到变化属预期
(defvar my/buffer-allow-names '("*compilation*" "*eshell*")
  "即使以 * 开头，也允许出现在 `other-buffer' 候选里的 buffer 名。")

(defun my/buffer-predicate (buf)
  (or (not (string-prefix-p "*" (buffer-name buf)))
      (member (buffer-name buf) my/buffer-allow-names)))

(defun my/set-buffer-predicate (&optional frame)
  (set-frame-parameter frame 'buffer-predicate #'my/buffer-predicate))

(add-hook 'after-init-hook #'my/set-buffer-predicate)
;; ⚠ 新 frame 不继承 frame 参数，须单独再设
(add-hook 'after-make-frame-functions #'my/set-buffer-predicate)

;; ⚠ 两套都要设：环境变量给 git/curl/LSP 子进程，变量给 url 库
(defvar my/proxy-address "127.0.0.1:7897"
  "HTTP(S) 代理地址，格式 host:port。")

(defvar my/proxy-no-proxy "^\\(localhost\\|127\\.0\\.0\\.1\\)"
  "不走代理的主机名正则，对应 `url-proxy-services' 的 no_proxy 项。")

(defun my/proxy-on ()
  "启用网络代理（`my/proxy-address'）。"
  (interactive)
  (setq url-proxy-services
        `(("http"     . ,my/proxy-address)
          ("https"    . ,my/proxy-address)
          ("no_proxy" . ,my/proxy-no-proxy)))
  (let ((url (concat "http://" my/proxy-address)))
    (setenv "http_proxy" url)
    (setenv "https_proxy" url)
    (setenv "HTTP_PROXY" url)
    (setenv "HTTPS_PROXY" url))
  (setenv "no_proxy" "localhost,127.0.0.1")
  (setenv "NO_PROXY" "localhost,127.0.0.1")
  (message "Proxy on: %s" my/proxy-address))

(defun my/proxy-off ()
  "关闭网络代理。"
  (interactive)
  (setq url-proxy-services nil)
  (dolist (var '("http_proxy" "https_proxy" "HTTP_PROXY" "HTTPS_PROXY"
                 "no_proxy" "NO_PROXY"))
    (setenv var nil))
  (message "Proxy off"))

(defun my/proxy-toggle ()
  "切换网络代理开关。"
  (interactive)
  (if url-proxy-services
      (my/proxy-off)
    (my/proxy-on)))

(provide 'init-base)
