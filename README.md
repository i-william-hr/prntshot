# prntshot

Screenshot a region of your screen — or any Finder selection — straight to
[prnt.li](https://prnt.li), with **only the link** copied to your clipboard and
**nothing left behind on disk**.

Two macOS Quick Actions, a few small shell scripts, no background process, no
menu-bar app, no accessibility hacks.

> **This supersedes [Bash-OSX-Uploadfile](https://github.com/i-william-hr/Bash-OSX-Uploadfile).**
> That project uploaded to a self-hosted server over SSH/HTTP and required you to
> edit server credentials into the script. This one talks to prnt.li's public API,
> needs no server of your own, and is packaged as native Quick Actions. The old
> repository is sunset — use this instead.

## What it does

| Action | What happens |
|---|---|
| **Screenshot and Upload** | macOS' native area picker → upload → link on clipboard |
| **Upload to prnt.li** | Uploads the current Finder selection → links on clipboard |

The picker is macOS' own — the same one behind <kbd>⌘</kbd><kbd>⇧</kbd><kbd>4</kbd> —
so you keep the familiar loupe, crosshair, window snapping and multi-monitor
handling. Both actions also appear in Finder's right-click ▸ Quick Actions.

## Requirements

- macOS 10.15 or later (tested on 15.7)
- `curl` and `python3` (both ship with macOS)
- A free [prnt.li](https://prnt.li) account is *not* required; uploads are anonymous by default

## Install

```bash
git clone https://github.com/i-william-hr/prntshot.git
cd prntshot
./make-workflows.sh      # generate the Quick Actions
./install-workflows.sh   # install scripts + workflows
```

Then bind the shortcuts:

1. Open **System Settings ▸ Keyboard ▸ Keyboard Shortcuts ▸ Services**
2. Under **Quick Actions**, find:
   - **Screenshot and Upload** → bind <kbd>⌘</kbd><kbd>⌥</kbd><kbd>1</kbd>
   - **Upload to prnt.li** → bind <kbd>⌘</kbd><kbd>⌥</kbd><kbd>2</kbd>
3. If macOS asks for **Screen Recording**, allow **Automator**. That is the only
   permission needed.

Suggested bindings shown above deliberately avoid <kbd>⌘</kbd><kbd>⇧</kbd><kbd>3</kbd>/<kbd>4</kbd>/<kbd>5</kbd>,
which macOS and Freeform already use for their own screenshot tools.

## Usage

Press your shortcut and drag a region. The link lands on your clipboard, ready to
paste. Select files in Finder and press the other shortcut to upload those.

## Notifications

Each action posts two notifications — **Upload started** and **Upload
finished — link copied** — so you get confirmation even when the clipboard
isn't visible.

These use the built-in `osascript display notification`, which needs no
dependency. If [terminal-notifier](https://github.com/julienXX/terminal-notifier)
is installed it is used automatically instead, which gives more control over the
banner. Neither is required.

## File safety

Nothing of yours is ever deleted.

- **Success** → the temporary screenshot is removed and the link is on your clipboard.
- **Failure** (offline, rate-limited, server error) → the screenshot is **kept**,
  moved to your Desktop with a timestamp, and a notification tells you where it went.
- **Cancelled picker** (<kbd>Esc</kbd>) → nothing was written, so nothing to clean up.
- **Finder selections are only ever read.** They are never modified, moved or deleted.

A screenshot you couldn't upload is usually a screenshot you still want, so a
failed upload preserves it rather than tidying up after itself. The only `rm` in
the codebase targets a file the script itself created, in its own cache
directory, and only after a confirmed successful upload.

## How it works

```
bin/prntshot-upload       curl wrapper for POST /api/upload; prints the bare link
bin/prntshot-capture.sh   the Screenshot Quick Action body
bin/prntshot-files.sh     the Upload-selection Quick Action body
make-workflows.sh         generates the .workflow bundles from templates/
install-workflows.sh      installs everything and refreshes the Services cache
templates/                known-good .workflow files, used as the generator basis
```

`templates/` holds Automator workflow files carried over from
[Bash-OSX-Uploadfile](https://github.com/i-william-hr/Bash-OSX-Uploadfile), where
they were known to work. This project reuses them as the structural basis for the
generator — see *pitfall 1* below for why the structure can't simply be written
from scratch.

Uploads use the **raw-body** form of `POST /api/upload` — the body *is* the file,
with `X-Filename` for the display name — rather than assembling a multipart form
for what is always a single file. The response is parsed defensively:

- there is **no `ok` key**, and the media-type field is **`kind`**, not `type`
- every field is optional in the spec, including the `urls` array
- a `200` can still carry a partial-failure `errors` array, which is surfaced
  rather than swallowed

The link is taken from the response rather than reconstructed from the token,
because prnt.li serves from more than one URL shape.

## Two pitfalls worth knowing about

Both of these cost real debugging time, and both fail *silently* — which is what
makes them nasty. They're documented here so you don't rediscover them.

### 1. A hand-written `.workflow` is accepted but never runs

An Automator workflow is not a simple plist. To actually execute, the action needs
`ALAccepts`, `AMProvides`, `AMParameterProperties`, `Class Name`, `UUID` and
`nibPath`, and the document needs `AMApplicationVersion` / `AMDocumentVersion`
plus a full `workflowMetaData` block.

A file missing those is still **listed** by macOS: it appears in Services, it
appears in Keyboard Shortcuts, and triggering it flashes the menu bar. It just
never runs. That looks exactly like a permissions problem, and will send you
chasing TCC settings that were never the issue.

So `make-workflows.sh` clones a known-good workflow from `templates/` and replaces
only the shell body and menu title. Keep it that way.

### 2. Service names must be unique

macOS resolves Services by name. If two installed bundles both register a service
called `Upload to prnt.li`, the entry becomes ambiguous and quietly stops being
offered as bindable in System Settings.

`install-workflows.sh` removes any lingering app bundle that might register a
colliding name. If a service ever goes missing from the Keyboard Shortcuts list,
check for a duplicate first:

```bash
/System/Library/CoreServices/pbs -dump_pboard | grep -c '"Upload to prnt.li"'
```

## Notes

- Anonymous uploads are capped at **20/hour per IP**, max **1 GiB per file**, with
  a **7-day default expiry**.
- To raise the rate limit, put an API key in `~/.config/prntshot/apikey`. It is
  sent as `X-API-Key`. (prnt.li currently has no keys configured server-side, so
  this is future-proofing rather than a working feature.)
- No credentials are stored in this repository, and none are needed.

## License

MIT — see `LICENSE`.
