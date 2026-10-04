#!/bin/bash
# Build the two prnt.li Quick Actions from known-working templates.
#
# An Automator .workflow is NOT a simple plist: the action needs ALAccepts /
# AMProvides / Class Name / UUID / nibPath and the document needs AMDocumentVersion
# and a full workflowMetaData block. Hand-rolling that produces a service macOS
# lists but silently fails to run. So we clone a working .workflow and replace
# only the shell body and the menu title.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
TPL="$ROOT/templates"
STAGE="$ROOT/build/workflows"

rm -rf "$STAGE"
mkdir -p "$STAGE"

build_one() {
    local template="$1" out_name="$2" menu_title="$3" script="$4"
    local dest="$STAGE/${out_name}.workflow"

    if [ ! -d "$TPL/$template" ]; then
        echo "missing template: $TPL/$template" >&2
        exit 1
    fi

    cp -R "$TPL/$template" "$dest"

    # Patch only the two things that differ from the template.
    /usr/bin/python3 - "$dest" "$menu_title" "$script" <<'PY'
import plistlib, sys

dest, menu_title, script_path = sys.argv[1:4]
with open(script_path, 'r', encoding='utf-8') as f:
    body = f.read()

# 1. Replace the shell body, leaving every structural key untouched.
wflow = dest + '/Contents/document.wflow'
doc = plistlib.load(open(wflow, 'rb'))
params = doc['actions'][0]['action']['ActionParameters']
params['COMMAND_STRING'] = body
params['ShellPath'] = '/bin/bash'
plistlib.dump(doc, open(wflow, 'wb'))

# 2. Set the menu title shown in Services / Keyboard Shortcuts.
info_path = dest + '/Contents/Info.plist'
info = plistlib.load(open(info_path, 'rb'))
for svc in info.get('NSServices', []):
    svc.setdefault('NSMenuItem', {})['default'] = menu_title
plistlib.dump(info, open(info_path, 'wb'))

print("built", dest)
PY
}

# The Screenshot action takes no input (it launches the picker itself).
build_one "Screenshot.template.workflow" "prnt.li Screenshot" \
    "Screenshot and Upload" "$ROOT/bin/prntshot-capture.sh"

# The Upload action receives the Finder selection as file objects.
build_one "Upload.template.workflow" "prnt.li Upload" \
    "Upload to prnt.li" "$ROOT/bin/prntshot-files.sh"

echo
echo "Staged in $STAGE"