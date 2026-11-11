;;; init-lsp-symbols.el --- LSP workspace/symbol 搜索（consult 界面）  -*- lexical-binding: t; -*-

;; 由 init-lsp.el require；eglot 与 consult 都是按需加载。

(defun my/lsp--servers ()
  "Return eglot servers supporting workspace/symbol for the current project."
  (when (featurep 'eglot)
    (cl-delete-if-not
     (lambda (server)
       (and server
            (let ((eglot--cached-server server))
              (eglot-server-capable :workspaceSymbolProvider))))
     (if-let* ((project (project-current))
               (servers (gethash project eglot--servers-by-project)))
         servers
       (list (eglot-current-server))))))

(defconst my/lsp-symbol-narrow
  '((?c . "Class") (?f . "Function") (?e . "Enum") (?i . "Interface")
    (?m . "Module") (?n . "Namespace") (?p . "Package") (?s . "Struct")
    (?t . "Type Parameter") (?v . "Variable")
    (?A . "Array") (?B . "Boolean") (?C . "Constant") (?E . "Enum Member")
    (?F . "Field") (?M . "Method") (?N . "Number") (?O . "Object")
    (?P . "Property") (?S . "String") (?o . "Other")))

(defvar my/lsp-symbols--history nil)

(defun my/lsp--candidate (info)
  "Turn an LSP SymbolInformation INFO into a consult candidate."
  (let* ((loc (plist-get info :location))
         (start (plist-get (plist-get loc :range) :start))
         (path (eglot-uri-to-path (plist-get loc :uri)))
         (rel (file-relative-name path))
         (shown (if (string-prefix-p ".." rel) (abbreviate-file-name path) rel))
         (kind (alist-get (plist-get info :kind) eglot--symbol-kind-names)))
    (propertize (format "%s %s:%d" (plist-get info :name) shown
                        (1+ (or (plist-get start :line) 0)))
                'consult--type (or (car (rassoc kind my/lsp-symbol-narrow)) ?o)
                'consult--candidate info)))

(defun my/lsp--marker (info open)
  "Return the marker of INFO, using OPEN to visit files."
  (let* ((loc (plist-get info :location))
         (start (plist-get (plist-get loc :range) :start)))
    (consult--marker-from-line-column
     (funcall (or open #'find-file) (eglot-uri-to-path (plist-get loc :uri)))
     (1+ (or (plist-get start :line) 0))
     (or (plist-get start :character) 0))))

(defun my/lsp--state ()
  "Preview/jump state for `my/lsp-symbols'."
  (let ((open (consult--temporary-files))
        (jump (consult--jump-state)))
    (lambda (action info)
      (when (eq action 'exit) (funcall open))
      (funcall jump action (and info (my/lsp--marker info open))))))

(defun my/lsp--async-source (servers)
  "Return a consult async source querying SERVERS for workspace symbols."
  (lambda (async)
    (lambda (action)
      (if (stringp action)
          (let (responses)
            (dolist (server servers)
              (jsonrpc-async-request
               server :workspace/symbol `(:query ,action)
               :success-fn (lambda (resp)
                             (setq responses (append responses (append resp nil)))
                             (funcall async 'flush)
                             (funcall async responses))
               :error-fn (lambda (&rest _) (message "workspace/symbol 失败"))
               :timeout-fn (lambda () (message "workspace/symbol 超时"))))
            (funcall async action))
        (funcall async action)))))

(defun my/lsp-symbols ()
  "在 LSP 工作区符号里搜索（workspace/symbol），用光标处的符号作初始输入。
没有 eglot 后端时退化为 `xref-find-apropos'。"
  (interactive)
  (require 'consult)
  (let ((servers (my/lsp--servers)))
    (if (not servers)
        (minibuffer-with-setup-hook #'my/search--select-seed
          (call-interactively #'xref-find-apropos))
      (let ((default-directory
             (or (ignore-errors (project-root (eglot--project (car servers))))
                 default-directory)))
        (minibuffer-with-setup-hook #'my/search--select-seed
          (consult--read
           (consult--async-pipeline
            (consult--async-min-input)
            (consult--async-throttle)
            (my/lsp--async-source servers)
            (consult--async-map #'my/lsp--candidate)
            (consult--async-highlight))
           :require-match t
           :prompt "LSP Symbols: "
           :sort t
           :initial (my/search-seed)
           :history '(:input my/lsp-symbols--history)
           :category 'my/lsp-symbols
           :lookup #'consult--lookup-candidate
           :group (consult--type-group my/lsp-symbol-narrow)
           :narrow (consult--type-narrow my/lsp-symbol-narrow)
           :state (my/lsp--state))
          (run-hooks 'consult-after-jump-hook))))))

(provide 'init-lsp-symbols)
;;; init-lsp-symbols.el ends here
