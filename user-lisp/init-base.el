;; init-base.el 	-*- lexical-binding: t -*-

(require 'cl-lib)

(require 'gcmh)
(setq gcmh-high-cons-threshold (* 128 1024 1024))
(gcmh-mode 1)

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
  )

;; ⚠ 不剥属性会让 savehist 膨胀，不可打印对象则整次保存失败
;; ⚠ yank-handler 是行级/块级粘贴的唯一依据，剥掉后 p/P 会退化成字符级
(defun iys--savehist-strip-string (string)
  (let ((handler (and (> (length string) 0)
                      (get-text-property 0 'yank-handler string)))
        (copy (substring-no-properties string)))
    (when handler
      (put-text-property 0 (length copy) 'yank-handler handler copy))
    copy))

(defun iys--savehist-unpropertize ()
  (setq kill-ring
        (mapcar #'iys--savehist-strip-string
                (cl-remove-if-not #'stringp kill-ring))
        register-alist
        (cl-loop for (reg . item) in register-alist
                 if (stringp item)
                 collect (cons reg (iys--savehist-strip-string item))
                 else collect (cons reg item))))

(defun iys--savehist-drop-unprintable-registers ()
  (setq register-alist (cl-remove-if-not #'savehist-printable register-alist)))

;; ⚠ savehist-save-hook 会 setq 在线变量；在副本上跑，否则自动存盘后立即丢 yank-handler
(defun iys--savehist-save-on-copies (orig &rest args)
  (let ((kill-ring (copy-sequence kill-ring))
        (register-alist (copy-sequence register-alist)))
    (apply orig args)))

(with-eval-after-load 'savehist
  (add-hook 'savehist-save-hook #'iys--savehist-unpropertize)
  (add-hook 'savehist-save-hook #'iys--savehist-drop-unprintable-registers)
  (advice-add 'savehist-save :around #'iys--savehist-save-on-copies))

(add-hook 'after-init-hook 'recentf-mode)
(progn
  (setq recentf-max-saved-items 300)
  (setq recentf-auto-cleanup 'never)
  )

;; ⚠ C-x b 已绑 consult-buffer、不读此 frame 参数，看不到变化属预期
(defvar iys/buffer-allow-names '("*compilation*" "*eshell*")
  "即使以 * 开头，也允许出现在 `other-buffer' 候选里的 buffer 名。")

(defun iys--buffer-predicate (buf)
  (or (not (string-prefix-p "*" (buffer-name buf)))
      (member (buffer-name buf) iys/buffer-allow-names)))

(defun iys--set-buffer-predicate (&optional frame)
  (set-frame-parameter frame 'buffer-predicate #'iys--buffer-predicate))

(add-hook 'after-init-hook #'iys--set-buffer-predicate)
;; ⚠ 新 frame 不继承 frame 参数，须单独再设
(add-hook 'after-make-frame-functions #'iys--set-buffer-predicate)

;; ⚠ 两套都要设：环境变量给 git/curl/LSP 子进程，变量给 url 库
;; ⚠ 只通过 M-x 调用，配置里没有引用；不要当成死代码删掉
(defvar iys/proxy-address "127.0.0.1:7897"
  "HTTP(S) 代理地址，格式 host:port。")

(defvar iys/proxy-no-proxy "^\\(localhost\\|127\\.0\\.0\\.1\\)"
  "不走代理的主机名正则，对应 `url-proxy-services' 的 no_proxy 项。")

(defun iys/proxy-on ()
  "启用网络代理（`iys/proxy-address'）。"
  (interactive)
  (setq url-proxy-services
        `(("http"     . ,iys/proxy-address)
          ("https"    . ,iys/proxy-address)
          ("no_proxy" . ,iys/proxy-no-proxy)))
  (let ((url (concat "http://" iys/proxy-address)))
    (setenv "http_proxy" url)
    (setenv "https_proxy" url)
    (setenv "HTTP_PROXY" url)
    (setenv "HTTPS_PROXY" url))
  (setenv "no_proxy" "localhost,127.0.0.1")
  (setenv "NO_PROXY" "localhost,127.0.0.1")
  (message "Proxy on: %s" iys/proxy-address))

(defun iys/proxy-off ()
  "关闭网络代理。"
  (interactive)
  (setq url-proxy-services nil)
  (dolist (var '("http_proxy" "https_proxy" "HTTP_PROXY" "HTTPS_PROXY"
                 "no_proxy" "NO_PROXY"))
    (setenv var nil))
  (message "Proxy off"))

(defun iys/proxy-toggle ()
  "切换网络代理开关。"
  (interactive)
  (if url-proxy-services
      (iys/proxy-off)
    (iys/proxy-on)))

(provide 'init-base)
