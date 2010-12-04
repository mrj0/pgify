diff="diff -uw"
input=test/input
output=test/pgout
expected=test/expected
error=test/error

trap "rm -f \"$input\" \"$output\" \"$expected\" \"$error\"" EXIT

function pgify() {
    ./pgify $* -d -f "$input" > "$output" 2>"$error" || exit $?
    $diff "$expected" "$output"
    ret=$?
    if test "$ret" != "0"; then
        echo "---------------------------------------- output:"
        cat "$output"
        echo "---------------------------------------- error:"
        cat "$error"
    fi
    exit $ret
}