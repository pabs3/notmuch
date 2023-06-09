#!/usr/bin/env bash

test_description="emacs unthreaded interface"
. $(dirname "$0")/test-lib.sh || exit 1
. $NOTMUCH_SRCDIR/test/test-lib-emacs.sh || exit 1

test_require_emacs

EXPECTED=$NOTMUCH_SRCDIR/test/emacs-unthreaded.expected-output

generate_message "[id]=large-thread-1" '[subject]="large thread"'
printf "  2001-01-05  Notmuch Test Suite   large thread%43s(inbox unread)\n" >> EXPECTED.unthreaded

for num in $(seq 2 64); do
    prev=$((num - 1))
    generate_message '[subject]="large thread"' "[id]=large-thread-$num" "[in-reply-to]=\<large-thread-$prev\>"
    printf "  2001-01-05  Notmuch Test Suite   large thread%43s(inbox unread)\n" >> EXPECTED.unthreaded
done
printf "End of search results.\n" >> EXPECTED.unthreaded

notmuch new > new.output 2>&1

test_begin_subtest "large thread"
test_emacs '(let ((max-lisp-eval-depth 10))
	      (notmuch-unthreaded "subject:large-thread")
	      (notmuch-test-wait)
	      (test-output))'
test_expect_equal_file EXPECTED.unthreaded OUTPUT

test_begin_subtest "message from large thread (status)"
output=$(test_emacs '(let ((max-lisp-eval-depth 10))
		       (notmuch-unthreaded "subject:large-thread")
		       (notmuch-test-wait)
		       (notmuch-tree-show-message nil)
		       (notmuch-test-wait)
		       "SUCCESS")' )
test_expect_equal "$output" '"SUCCESS"'

add_email_corpus
test_begin_subtest "Functions in unthreaded-result-format"
test_emacs '
(let
    ((notmuch-unthreaded-result-format
     (quote (("date" . "%12s  ")
	     ("authors" . "%-20s")
	     ("subject" . "%-54s")
	     (notmuch-test-result-flags . "(%s)")))))
  (notmuch-unthreaded "tag:inbox")
  (notmuch-test-wait)
  (test-output))
'
test_expect_equal_file $EXPECTED/result-format-function OUTPUT

test_begin_subtest "notmuch-unthreaded with nonexistent CWD"
test_emacs '(test-log-error
	      (let ((default-directory "/nonexistent"))
	        (notmuch-unthreaded "*")))'
test_expect_equal "$(cat MESSAGES)" "COMPLETE"

add_email_corpus duplicate

ID3=87r2ecrr6x.fsf@zephyr.silentflame.com
test_begin_subtest "duplicate=3, subject"
test_emacs "(let ((notmuch-tree-show-out t))
	      (notmuch-unthreaded \"id:${ID3}\")
	      (notmuch-test-wait)
	      (notmuch-tree-show-message nil)
	      (notmuch-show-choose-duplicate 3)
	      (test-visible-output \"OUTPUT\"))"
output=$(grep "Subject:" OUTPUT)
file=$(notmuch search --output=files id:${ID3} | head -n 3 | tail -n 1)
subject=$(grep '^Subject:' $file)
test_expect_equal "$output" "$subject"

test_begin_subtest "duplicate=4"
test_emacs "(let ((notmuch-tree-show-out t))
	      (notmuch-unthreaded \"id:${ID3}\")
	      (notmuch-test-wait)
	      (notmuch-tree-show-message nil)
	      (notmuch-show-choose-duplicate 4)
	      (test-visible-output \"OUTPUT\"))"
test_expect_equal_file_nonempty $NOTMUCH_SRCDIR/test/emacs-show.expected-output/notmuch-show-duplicate-4 OUTPUT


test_done
