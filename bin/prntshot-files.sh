#!/bin/bash
# prntshot-files — the body of the "prnt.li Upload Selection" Quick Action.
#
# Uploads whatever is passed in (Finder hands Quick Actions the current
# selection) and copies the links to the clipboard.
#
# File safety: this script only ever READS the files it is given. It never
# modifies, moves, renames or deletes them.

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

# Locate the uploader. Automator runs this body from its own sandbox with no
# meaningful BASH_SOURCE, so check the explicit install location first and fall
# back to whatever directory this script happens to live in.
UPLOADER="$HOME/.local/bin/prntshot-upload"
if [ ! -x "$UPLOADER" ]; then
    UPLOADER="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)/prntshot-upload"
fi

notify() {
    local title="$1" msg="$2"
    if command -v terminal-notifier >/dev/null 2>&1; then
        terminal-notifier -title "$title" -message "$msg" -sender com.apple.Photos 2>/dev/null || \
            osascript -e "display notification \"${msg//\"/}\" with title \"${title//\"/}\""
    else
        osascript -e "display notification \"${msg//\"/}\" with title \"${title//\"/}\""
    fi
}

if [ ! -x "$UPLOADER" ]; then
    notify "prnt.li" "Upload helper not found at ${UPLOADER}"
    exit 1
fi

# Collect real files. Automator normally passes one path per argument, but be
# defensive: a path list can also arrive newline-separated inside a single
# argument depending on how the service is invoked. Folders are dropped, since
# prnt.li takes files.
files=()
for arg in "$@"; do
    while IFS= read -r f; do
        if [ -n "$f" ] && [ -f "$f" ]; then
            files+=("$f")
        fi
    done <<< "$arg"
done

if [ ${#files[@]} -eq 0 ]; then
    notify "prnt.li" "No files selected"
    exit 1
fi

# prnt.li accepts up to 10 files per multipart request; upload one at a time so
# a single failure does not cost the rest, and so a huge selection still works.
links=""
failures=0
for f in "${files[@]}"; do
    if link="$("$UPLOADER" "$f" 2>/dev/null)" && [ -n "$link" ]; then
        links="${links}${link}"$'\n'
    else
        failures=$((failures + 1))
        echo "prntshot: failed to upload $(basename "$f")" >&2
    fi
done

if [ -n "$links" ]; then
    # Strip the trailing newline: the clipboard should hold just the links.
    printf '%s' "${links%$'\n'}" | pbcopy
fi

count=$(printf '%s' "$links" | grep -c . 2>/dev/null || echo 0)
if [ "$failures" -gt 0 ]; then
    notify "prnt.li" "Uploaded ${count} file(s), ${failures} failed"
    exit 1
fi

notify "prnt.li" "Uploaded ${count} file(s) — links copied"