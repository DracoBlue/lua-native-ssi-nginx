#!/usr/bin/env bash

test_success=0
test_errors=0

cd `dirname $0`
cd tests

# We cannot use while read line here
# @see http://fvue.nl/wiki/Bash:_Piped_%60while-read'_loop_starts_subshell
# for further information
for file in `ls *.txt`
do
	TEST_NAME=`echo "$file" | cut -f 1 -d '.'`
	if [ -f "$TEST_NAME.sh" ]
	then
		bash "$TEST_NAME.sh" > "${TEST_NAME}.result"
		current_exit_code="${?}"
	else
		curl -sS "localhost:4778/${TEST_NAME}/" > "${TEST_NAME}.result"
		current_exit_code="${?}"
	fi
	if [ "${current_exit_code}" -ne "0" ]
	then
		echo "  [  ] $TEST_NAME"
		echo "   -> broken! (curl did not 2xx, Exit code: $current_exit_code)"
		let test_errors=test_errors+1
	else
		diff "${TEST_NAME}.txt" "${TEST_NAME}.result"
		current_exit_code="${?}"
		if [ "${current_exit_code}" -ne "0" ]
		then
			echo "  [  ] $TEST_NAME"
			echo "   -> broken! (.txt != .result, Exit code: $current_exit_code)"
			let test_errors=test_errors+1
		else
			echo "  [OK] $TEST_NAME"
			let test_success=test_success+1
		fi
	fi
done

if [ ! $test_errors -eq 0 ]
then
	exit 1
fi

exit 0