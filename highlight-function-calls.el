;;; highlight-function-calls.el --- Highlight function/macro calls  -*- lexical-binding: t; -*-

;; Author: Adam Porter <adam@alphapapa.net>
;; Url: http://github.com/alphapapa/highlight-function-calls
;; Version: 0.1-pre
;; Package-Requires: ((emacs "24.4"))
;; Keywords: highlighting

;;; Commentary:

;; This package highlights function symbols in function calls.  This
;; makes them stand out from other symbols, which makes it easy to see
;; where calls to other functions are.  Optionally, macros and special
;; forms can be highlighted as well.  Also, a list of symbols can be
;; excluded from highlighting; by default, ones like +/-, </>, error,
;; require, etc. are excluded.  Finally, the `not' function can be
;; highlighted specially.

;;; Code:

(defgroup highlight-function-calls nil
  "Options for highlighting function/macro calls and special forms.")

(defface highlight-function-calls--face
  '((t (:underline t)))
  "Face for highlighting function calls."
  :group 'highlight-function-calls)

(defface highlight-function-calls--not-face
  '((t (:weight bold :foreground "red")))
  "Face for highlighting `not'."
  :group 'highlight-function-calls)

(defcustom highlight-function-calls-exclude-symbols
  '(
    =
    +
    -
    /
    *
    <
    >
    <=
    >=
    error
    require
    throw
    user-error
    )
  "List of symbols to not highlight."
  :type '(repeat symbol))

(defcustom highlight-function-calls-macro-calls nil
  "Whether to highlight macro calls.")

(defcustom highlight-function-calls-special-forms nil
  "Whether to highlight special-forms calls.")

(defcustom highlight-function-calls-not t
  "Whether to highlight `not'.")

(defconst highlight-function-calls--keywords
  '((
     ;; First we match an opening paren, which prevents matching
     ;; function names as arguments.  We also avoid matching opening
     ;; parens immediately after quotes.

     ;; FIXME: This does not avoid matching opening parens in quoted
     ;; lists. I don't know if we can fix this, because `syntax-ppss'
     ;; doesn't give any information about this.  It might require
     ;; using semantic, which we probably don't want to mess with.
     "\\(?:^\\|[[:space:]]+\\)("  ; (rx (or bol (1+ space)) "(")

     ;; NOTE: The (0 nil) is required, although I don't understand
     ;; exactly why.  This was confusing enough, following the
     ;; docstring for `font-lock-add-keywords'.
     (0 nil)

     ;; Now we use a HIGHLIGHT MATCH-ANCHORED form to match the symbol
     ;; after the paren.  We call the `highlight-function-calls--matcher'
     ;; function to test whether the face should be applied.  We use a
     ;; PRE-MATCH-FORM to return a position at the end of the symbol,
     ;; which prevents matching function name symbols later on the
     ;; line, but we must not move the point in the process.  We do
     ;; not use a POST-MATCH-FORM.  Then we use the MATCH-HIGHLIGHT
     ;; form to highlight group 0, which is the whole symbol, we apply
     ;; the `highlight-function-calls--face' face, and we `prepend' it so
     ;; that it overrides existing faces; this way we even work with,
     ;; e.g. `rainbow-identifiers-mode', but only if we're activated
     ;; last.
     (highlight-function-calls--matcher
      (save-excursion
        (forward-symbol 1)
        (point))
      nil
      (0 highlight-function-calls--face-name prepend))))
  "Keywords argument for `font-lock-add-keywords'.")

(defvar highlight-function-calls--face-name nil)

(defun highlight-function-calls--matcher (end)
  "The matcher function to be used by font lock mode."
  (setq end (save-excursion (forward-symbol 1) (point)))
  (catch 'highlight-function-calls--matcher
    (when (not (nth 5 (syntax-ppss)))
      (while (re-search-forward (rx symbol-start (*? any) symbol-end) end t)
        (let ((match (intern-soft (match-string 0))))
          (when (and (or (functionp match)
                         (when highlight-function-calls-macro-calls
                           (macrop match))
                         (when highlight-function-calls-special-forms
                           (special-form-p match)))
                     (not (member match highlight-function-calls-exclude-symbols)))
            (goto-char (match-end 0))
            (setq highlight-function-calls--face-name
                  (pcase match
                    ((and 'not (guard highlight-function-calls-not))  'highlight-function-calls--not-face)
                    (otherwise 'highlight-function-calls--face)))
            (throw 'highlight-function-calls--matcher t)))))
    nil))

;;;###autoload
(define-minor-mode highlight-function-calls-mode
  "Highlight function calls.

Toggle highlighting of function calls on or off.

With a prefix argument ARG, enable if ARG is positive, and
disable it otherwise. If called from Lisp, enable the mode if ARG
is omitted or nil, and toggle it if ARG is `toggle'."
  :init-value nil :lighter nil :keymap nil
  (let ((keywords highlight-function-calls--keywords))
    (font-lock-remove-keywords nil keywords)
    (when highlight-function-calls-mode
      (font-lock-add-keywords nil keywords 'append)))
  ;; Refresh font locking.
  (when font-lock-mode
    (if (fboundp 'font-lock-flush)
        (font-lock-flush)
      (with-no-warnings (font-lock-fontify-buffer)))))

(provide 'highlight-function-calls)

;;; highlight-function-calls.el ends here
