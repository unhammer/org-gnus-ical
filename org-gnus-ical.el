;;; org-gnus-ical.el --- Capture iCalendar invitations from Gnus to Org -*- lexical-binding: t; -*-

;; Copyright (C) 2021 Kevin Brubeck Unhammer

;; Author: Kevin Brubeck Unhammer <unhammer@fsfe.org>
;; Version: 0.1.0
;; URL: https://github.com/unhammer/org-gnus-ical
;; Package-Requires: ((emacs "25.3.2"))
;; Keywords: outlines, mail, calendar
;;
;; This file is not part of GNU Emacs.
;;
;; GNU Emacs is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 2 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs.  If not, see <https://www.gnu.org/licenses/>.

;;
;;; Commentary:

;; Lets you `org-capture' links to iCalendar invitations from
;; Gnus.  Put the bundled ical2org script in PATH, then use
;; `org-gnus-ical-capture-template' as a capture template function –
;; see help for that function for usage examples.
;;
;; Loading this code will also add a hook that reminds you to capture
;; invites on opening such articles.

;;; Code:

(require 'gnus-art)

(defun org-gnus-ical--part-is-icalendar (part)
  "Non-nil if PART is a text/calendar invite."
  (and (>= (length part) 3)
       (listp (caddr part))
       (or (equal "application/ics" (caaddr part))
           (equal "text/calendar" (caaddr part)))))

(defun org-gnus-ical--article-has-icalendar ()
  "Non-nil if current article has an icalendar invite."
  (with-current-buffer gnus-article-buffer
    (save-excursion
      (cl-some #'org-gnus-ical--part-is-icalendar
               gnus-article-mime-handle-alist))))

(defun org-gnus-ical-message-if-icalendar ()
  "Note if the article has text/calendar invites."
  (when (org-gnus-ical--article-has-icalendar)
    (message (substitute-command-keys
              "\\[org-capture] to capture iCalendar invite"))))

(add-hook 'gnus-article-prepare-hook #'org-gnus-ical-message-if-icalendar)

(defun org-gnus-ical--ical2org ()
  "Run `ical2org' on this buffer, return as stringk.
FUN is run with no arguments in this buffer.
Put current buffer back as-was afterwards."
  (shell-command-on-region (point-min) (point-max)
                           "ical2org"
                           nil
                           'replace
                           "*ical2org errors*"
                           'display-errors)
  (buffer-string))

(defun org-gnus-ical--parsed-icalendar ()
  "Return any text/calendar invites as an `org-mode' entry.
Used by `org-gnus-ical--capture-template'."
  (with-current-buffer gnus-article-buffer
    (save-excursion
      (cl-loop for part in gnus-article-mime-handle-alist
               ;; TODO: Are there ever several invites in one message?
               when (org-gnus-ical--part-is-icalendar part)
               return (save-window-excursion
                        ;; for some reason, with-current-buffer isn't enough to satisfy gnus-article-check-buffer:
                        (pop-to-buffer gnus-article-buffer)
                        (gnus-mime-copy-part (cdr part))
                        (org-gnus-ical--ical2org))))))

(defun org-gnus-ical--org-capture-escape (str)
  "Escape any % in STR as a call to `my-org-capture-pct'."
  (replace-regexp-in-string "%" "%(my-org-capture-pct)" str))

(defun org-gnus-ical-capture-template ()
  "Template function for `org-capture'.
When looking at an ical invitation, run `ical2org'.

Example usage:

  (add-to-list 'org-capture-templates
               '(\"c\" \"iCalendar invite\" entry
                 (file+olp \"~/org/work.org\"
                           \"Meetings\")
                 (function org-gnus-ical-capture-template)))

Tip: You can also make a wrapper around this that falls back to
a different template if there is no iCalendar invite, or removes
stuff you don't want from it, e.g.

   (defun my-email-capture ()
      (replace-regexp-in-string             ; strip some boilerplate
       \".*Join on your computer.*\"
       \"\"
       (or (org-gnus-ical-capture-template)
           \"* TODO %?\\n  %t\\n%i\\n  %a\"))"
  (when (memq major-mode '(gnus-summary-mode gnus-article-mode))
    (when-let ((parsed (org-gnus-ical--parsed-icalendar)))
      (concat (org-gnus-ical--org-capture-escape parsed) "\n"
              "  %a\n"
              "  %i%?\n"))))

(provide 'org-gnus-ical)

;;; org-gnus-ical.el ends here
