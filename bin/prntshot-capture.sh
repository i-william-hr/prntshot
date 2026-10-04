#!/bin/bash
# prntshot-capture — the body of the "prnt.li Screenshot" Quick Action.
#
# Shows macOS' native area picker (the same one behind cmd+shift+4), uploads
# the result to prnt.li, copies the link, and deletes the temp file ONLY when
# the upload succeeded. On failure the screenshot is kept on the Desktop.

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

# Locate the uploader. Automator runs this body from its own sandbox with no
# meaningful BASH_SOURCE, so check the explicit install location first and fall
# back to whatever directory this script happens to live in.
UPLOADER="$HOME/.local/bin/prntshot-upload"
if [ ! -x "$UPLOADER" ]; then
    UPLOADER="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)/prntshot-upload"
fi

# Prefer terminal-notifier (brew install terminal-notifier) and fall back to
# the built-in osascript, which needs no dependency at all.
#
# Both paths need a single-line message: a newline inside an AppleScript string
# literal is a syntax error, so collapse whitespace and strip quotes first.
notify() {
    local title="$1" msg="$2"
    title="$(printf '%s' "${title//\"/}" | tr '\n\r\t' '   ')"
    msg="$(printf '%s' "${msg//\"/}" | tr '\n\r\t' '   ')"

    if command -v terminal-notifier >/dev/null 2>&1; then
        terminal-notifier -title "$title" -message "$msg" 2>/dev/null && return 0
    fi
    osascript -e "display notification \"${msg}\" with title \"${title}\"" 2>/dev/null || true
}

if [ ! -x "$UPLOADER" ]; then
    notify "prnt.li" "Upload helper not found at ${UPLOADER}"
    exit 1
fi

# Private capture directory. Only files this script creates ever live here.
capture_dir="$HOME/Library/Caches/com.prntshot.uploader"
mkdir -p "$capture_dir"

# Unique name so a collision is impossible.
tmpname="prntshot-$(uuidgen).png"
tmppath="${capture_dir}/${tmpname}"

# -i interactive picker, -x no sound, -r no dpi metadata (smaller file).
# NOTE: -T is a DELAY before capture ("take the picture after a delay of
# <seconds>, default is 5"), NOT a thumbnail toggle. Passing -T 0 makes the
# picker fire the capture immediately, before the user can drag a selection —
# which is exactly why uploads were failing. Do not add -T here.
# Keep stderr: if Screen Recording is denied, screencapture fails here and we
# need to say so rather than appearing to do nothing.
screencapture -i -x -r "$tmppath" 2>/tmp/prntshot-scrot-err.$$
scrot_exit=$?
scrot_err="$(cat "/tmp/prntshot-scrot-err.$$" 2>/dev/null)"
rm -f "/tmp/prntshot-scrot-err.$$"

# Nothing written: either the user cancelled (ESC / right-click), which is
# normal and silent, or screencapture was denied.
if [ $scrot_exit -ne 0 ] || [ ! -f "$tmppath" ]; then
    [ -f "$tmppath" ] && rm -f "$tmppath"

    # Distinguish "cancelled" from "denied". A cancel produces no file and no
    # error text; a permission failure reports itself.
    if [ -n "$scrot_err" ]; then
        notify "prnt.li — cannot capture" \
            "Screen Recording is not allowed for Automator.

Open System Settings > Privacy & Security > Screen & System Audio
Recording and enable Automator, then try again."
    fi
    exit 0
fi

notify "prnt.li" "Upload started"

link="$("$UPLOADER" "$tmppath" 2>/tmp/prntshot-capture-err.$$)"
rc=$?
err="$(cat "/tmp/prntshot-capture-err.$$" 2>/dev/null)"
rm -f "/tmp/prntshot-capture-err.$$"

if [ $rc -eq 0 ] && [ -n "$link" ]; then
    printf '%s' "$link" | pbcopy
    # Success: delete the temp file we created, and nothing else.
    rm -f "$tmppath"
    notify "prnt.li" "Upload finished — link copied"
else
    # Failure: never delete the screenshot. Move it somewhere findable,
    # without ever overwriting an existing Desktop file.
    stamp="$(date '+%Y-%m-%d-%H%M%S')"
    dest="$HOME/Desktop/prntshot-${stamp}.png"
    n=1
    while [ -e "$dest" ]; do
        dest="$HOME/Desktop/prntshot-${stamp}-${n}.png"
        n=$((n + 1))
    done
    mv "$tmppath" "$dest" 2>/dev/null || dest="$tmppath"
    notify "prnt.li — upload failed" "Screenshot kept at ${dest}"
    [ -n "$err" ] && echo "prntshot: ${err}" >&2
fi