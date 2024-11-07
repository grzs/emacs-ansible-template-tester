;; defaults
(defvar ansible-template-tester-dir
  (file-name-concat user-emacs-directory "ansible-template-tester")
  "path to modul directory")
(defvar ansible-template-tester-cmd "ansible"
  "path to ansible cli")
(defvar ansible-template-tester-module "ansible.builtin.template"
  "ansible fully qualified module name")
(defvar ansible-template-tester--editing-in-progress nil
  "boolean value to hold editor window state")

;; inventory
(defconst ansible-template-tester--inventory-file
  (file-name-concat ansible-template-tester-dir "hosts")
  "ansible inventory hosts file path, relative to package dir")
(defconst ansible-template-tester--inventory-content "emacs ansible_connection=local\r\n"
  "hosts file content")

(defconst ansible-template-tester--inventory-hostvars-dir
  (file-name-concat ansible-template-tester-dir "host_vars")
  "ansible inventory host_vars directory")
(defconst ansible-template-tester--inventory-hostvars-file
  (file-name-concat ansible-template-tester--inventory-hostvars-dir "emacs.yml")
  "ansible inventory host_vars file host_vars/emacs.yml")

;; temporary files
(defconst ansible-template-tester--template-file
  (file-name-concat ansible-template-tester-dir "template.j2")
  "temporary jinja2 template file, relative to package dir")
(defconst ansible-template-tester--result-file
  (file-name-concat ansible-template-tester-dir "result.txt")
  "temporary result file, relative to package dir")

;; contents
(defconst ansible-template-tester--window-header
  "Ansible Template Tester
=======================

v: edit vars                     n: next block                        r: reset
t: edit temlate                  p: previous block                    q: close
e: evaluate and display result   TAB: toggle block folding at point   k: kill
"
  "main windows header")
(defconst ansible-template-tester--vars-initial-content "foo: bar"
  "Initial content of vars file")
(defconst ansible-template-tester--template-initial-content "value of foo: {{ foo }}"
  "Initial content of vars file")

(defconst ansible-template-tester--main-buffer-name "*Ansible-template-tester*")
(defconst ansible-template-tester--editing-buffer-name "*Ansible-template-tester-edit*")
(defconst ansible-template-tester--stdout-buffer-name "*Ansible-template-tester-output*")
(defconst ansible-template-tester--stderr-buffer-name "*Ansible-template-tester-error*")
(defconst ansible-template-tester--vars-block-name "vars")
(defconst ansible-template-tester--template-block-name "template")
(defconst ansible-template-tester--result-block-name "result")
(defconst ansible-template-tester--tmp-files-alist
  (list (cons 'vars (list ansible-template-tester--vars-block-name
                          ansible-template-tester--inventory-hostvars-file))
        (cons 'template (list ansible-template-tester--template-block-name
                              ansible-template-tester--template-file))))

(defvar-keymap ansible-template-tester-map
  :doc "Keymap for ansible-template-tester"
  "v" #'ansible-template-tester-edit-vars
  "t" #'ansible-template-tester-edit-template
  "e" #'ansible-template-tester-eval
  "r" #'ansible-template-tester-reset
  "q" #'ansible-template-tester-quit
  "k" #'ansible-template-tester-kill
  "n" #'ansible-template-tester-next-block
  "p" #'ansible-template-tester-previous-block
  "TAB" #'org-hide-block-toggle)


;; dependencies
(require 'gnus-util)
(require 'f)
(require 'org)

;; misc
(defun ansible-template-tester--ensure-at-empty-line ()
  "checks whether end-of-line equals to beginning of line, add newline if not"
  (end-of-line)
  (unless (eq (point) (save-excursion (beginning-of-line) (point)))
    (newline)))

(defun ansible-template-tester--switch-to-buffer ()
  (switch-to-buffer ansible-template-tester--main-buffer-name)
  (unless (eq major-mode 'org-mode) (org-mode)))

;; startup
(defun ansible-template-tester--init ()
  "function to ensure that dir structure exists"
  (mkdir ansible-template-tester--inventory-hostvars-dir t)
  (f-write-text ansible-template-tester--inventory-content 'utf-8
                ansible-template-tester--inventory-file)
  (f-write-text ansible-template-tester--vars-initial-content 'utf-8
                ansible-template-tester--inventory-hostvars-file)
  (f-write-text ansible-template-tester--template-initial-content 'utf-8
                ansible-template-tester--template-file))

(add-hook 'emacs-startup-hook 'ansible-template-tester-init)

;; business logic
(defun ansible-template-tester--insert-code-block (name content lang)
  (end-of-buffer)
  (ansible-template-tester--ensure-at-empty-line)
  (newline)
  (insert (format "#+NAME: %s" name)) (newline)
  (insert (format "#+BEGIN_SRC %s" lang)) (newline)
  (newline)
  (insert content) (newline)
  (newline)
  (insert "#+END_SRC") (newline))

(defun ansible-template-tester--init-buffer ()
  (ansible-template-tester--switch-to-buffer)
  (use-local-map ansible-template-tester-map)
  (setq buffer-read-only nil)
  (erase-buffer)
  (insert ansible-template-tester--window-header)
  (newline)
  (ansible-template-tester--insert-code-block
   ansible-template-tester--vars-block-name
   ansible-template-tester--vars-initial-content "yaml")
  (ansible-template-tester--insert-code-block
   ansible-template-tester--template-block-name
   ansible-template-tester--template-initial-content "jinja2")
  (ansible-template-tester--insert-code-block
   ansible-template-tester--result-block-name
   "" "txt")
  (setq buffer-read-only t)
  (beginning-of-buffer))

(defun ansible-template-tester--display-result (result)
  (ansible-template-tester--switch-to-buffer)
  (unless (eq major-mode 'org-mode) (org-mode))
  (setq buffer-read-only nil)
  ;; try to find result block, delete if found
  (when-let ((block-start (org-babel-find-named-block
                           ansible-template-tester--result-block-name)))
    (goto-char block-start)
    (search-backward-regexp "^#\\+END_SRC")
    (next-line)
    (delete-region (point) (buffer-end 1)))

  ;; create block
  (ansible-template-tester--insert-code-block
   ansible-template-tester--result-block-name
   result "txt")
  (setq buffer-read-only t)
  (beginning-of-buffer))

(defun ansible-template-tester--edit-code-block (name)
  (ansible-template-tester--switch-to-buffer)
  (setq buffer-read-only nil)
  (goto-char (org-babel-find-named-block name))
  (org-edit-src-code nil ansible-template-tester--editing-buffer-name)
  (setq ansible-template-tester--editing-in-progress t))

(defun ansible-template-tester--save-code-block (block file)
  (ansible-template-tester--switch-to-buffer)
  (setq buffer-read-only t)
  (goto-char (org-babel-find-named-block block))
  (let ((content (org-element-property :value (org-element-at-point))))
    (f-write-text content 'utf-8 file)))

(defun ansible-template-tester--save-code-blocks ()
  (dolist (block-file (mapcar 'cdr ansible-template-tester--tmp-files-alist))
    (apply 'ansible-template-tester--save-code-block block-file))
  (beginning-of-buffer))

(defun ansible-template-tester--on-window-buffer-change (frame)
  (if-let ((buffer (get-buffer ansible-template-tester--editing-buffer-name)))
      (setq ansible-template-tester--editing-in-progress t)
    (when ansible-template-tester--editing-in-progress
      (setq ansible-template-tester--editing-in-progress nil)
      (ansible-template-tester--switch-to-buffer)
      (setq buffer-read-only t)
      (ansible-template-tester--save-code-blocks))))

(add-hook 'window-buffer-change-functions
          'ansible-template-tester--on-window-buffer-change)

;; public functions
(defun ansible-template-tester-edit-vars ()
  (interactive)
  (ansible-template-tester--edit-code-block
   ansible-template-tester--vars-block-name))

(defun ansible-template-tester-edit-template ()
  (interactive)
  (ansible-template-tester--edit-code-block
   ansible-template-tester--template-block-name))

(defun ansible-template-tester-eval ()
  (interactive)
  (when (eq 1 (shell-command (format "which %s" ansible-template-tester-cmd)))
    (error "Couldn't find ansible binary"))
  (let ((module-args (format "'src=%s dest=%s'"
                             ansible-template-tester--template-file
                             ansible-template-tester--result-file)))
    (let ((result nil)
          (rc (shell-command (format "%s -i %s -m %s -a %s emacs"
                                     ansible-template-tester-cmd
                                     ansible-template-tester--inventory-file
                                     ansible-template-tester-module
                                     module-args)
                             ansible-template-tester--stdout-buffer-name
                             ansible-template-tester--stderr-buffer-name)))
      (if (eq 0 rc) 
        (setq result (f-read-text ansible-template-tester--result-file))
        (setq result (format "ansible exited with code %d" rc)))
      (ansible-template-tester--display-result result))))

(defun ansible-template-tester-reset ()
  (interactive)
  (with-current-buffer ansible-template-tester--stderr-buffer-name
    (kill-buffer))
  (ansible-template-tester--init-buffer)
  (ansible-template-tester--save-code-blocks))

(defun ansible-template-tester-quit ()
  (interactive)
  (ansible-template-tester--switch-to-buffer)
  (delete-window))

(defun ansible-template-tester-kill ()
  (interactive)
  (with-current-buffer ansible-template-tester--stderr-buffer-name
    (kill-buffer))
  (with-current-buffer ansible-template-tester--stdout-buffer-name
    (kill-buffer))
  (ansible-template-tester--switch-to-buffer)
  (kill-buffer))

;; navigation
(defun ansible-template-tester-next-block ()
  (interactive)
  (org-next-block 1))

(defun ansible-template-tester-previous-block ()
  (interactive)
  (org-next-block 1 t))

;; main entrypoint
(defun ansible-template-tester ()
  (interactive)
  (if-let ((buffer (gnus-buffer-live-p ansible-template-tester--main-buffer-name)))
      (switch-to-buffer buffer)
    (ansible-template-tester--init-buffer)))

(provide 'ansible-template-tester)
