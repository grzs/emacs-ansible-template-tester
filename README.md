# Ansible Template Tester for Emacs #

This package is inspired by the template tester made by @sivel
(<https://ansible.sivel.net/test>), which is a great tool, but I thought that it
would be much more convenient to have something similar in Emacs. So here it is.

## Dependencies ##

 - ansible binary
   (configurable via `ansible-template-tester-cmd`)
   
## Installation ##

In your init file:
```elisp
(unless (package-installed-p 'ansible-template-tester)
  (package-vc-install "https://github.com/grzs/emacs-ansible-template-tester"
                      nil nil 'ansible-template-tester))
```

## Usage ##

The UI is basically a read-only org-mode window with three source code blocks
and a dedicated keymap. When you launch ansible-template-tester, you will see
these lines:

```org

Ansible Template Tester
=======================

v: edit vars                     n: next block                        r: reset
t: edit temlate                  p: previous block                    q: close
e: evaluate and display result   TAB: toggle block folding at point   k: kill


#+NAME: vars
#+BEGIN_SRC yaml

foo: bar

#+END_SRC

#+NAME: template
#+BEGIN_SRC jinja2

value of foo: {{ foo }}

#+END_SRC

#+NAME: result
#+BEGIN_SRC txt



#+END_SRC
```
