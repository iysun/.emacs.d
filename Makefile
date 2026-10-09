EMACS ?= emacs
ROOT := $(CURDIR)

.PHONY: compile clean

# 字节编译作语法检查（非默认）。Emacs 31 的 user-lisp 机制会在启动时按需自动
# 字节编译 user-lisp/；这里提供一条手动全量入口，便于 CI 或排查「某宏在编译期
# 没被加载 → 生成坏 .elc」这类问题（见 docs/notes/byte-compile-broken-elc.md）。
compile:
	@echo "Compiling Emacs Lisp files to .elc..."
	@$(EMACS) --batch -Q \
		--eval "(setq user-emacs-directory (file-name-as-directory \"$(ROOT)\"))" \
		--eval "(setq package-user-dir (expand-file-name \"elpa\" user-emacs-directory))" \
		--eval "(require 'package)" \
		--eval "(package-initialize)" \
		--eval "(dolist (d (list \"user-lisp\" \"user-lisp/mode-line\" \"user-lisp/tab-line\" \"user-lisp/eshell-prompt\")) (add-to-list 'load-path (expand-file-name d user-emacs-directory)))" \
		--eval "(byte-recompile-directory (expand-file-name \"user-lisp\" user-emacs-directory) 0)" \
		--eval "(dolist (f '(\"early-init.el\" \"init.el\")) (byte-recompile-file (expand-file-name f user-emacs-directory) 0 0))" \
		--eval "(message \"Byte compilation finished\")"

# 清掉所有生成的 .elc（含 user-lisp 自动编译产物）与 user-lisp autoload 缓存，
# 下次启动会按需重建。用 Emacs 自己删而不是 find/rm：GNU find 语法在 Windows 会
# 命中 system32\find.exe 而静默失效，走 emacs --batch 三平台行为一致。
clean:
	@echo "Removing generated .elc ..."
	@$(EMACS) --batch --eval "(let ((root (file-name-as-directory \"$(ROOT)\")) (n 0)) (dolist (f (directory-files-recursively root \"[.]elc$$\" nil (lambda (d) (not (member (file-name-nondirectory d) '(\"elpa\" \".git\" \"eln-cache\" \"straight\")))))) (delete-file f) (setq n (1+ n))) (message \"Removed %d .elc file(s)\" n))"
	@$(EMACS) --batch --eval "(let ((af (expand-file-name \"user-lisp/.user-lisp-autoloads.el\" (file-name-as-directory \"$(ROOT)\")))) (when (file-exists-p af) (delete-file af) (message \"Removed user-lisp autoloads cache\")))"
