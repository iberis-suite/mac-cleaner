# mac-cleaner

[![tests](https://github.com/chaibialaa/mac-cleaner/actions/workflows/tests.yml/badge.svg)](https://github.com/chaibialaa/mac-cleaner/actions/workflows/tests.yml)

A tiny, dependency-free macOS cleaner for the terminal. One zsh script, no daemon, no telemetry.

```
     ┌┬┐┌─┐┌─┐   ┌─┐┬  ┌─┐┌─┐┌┐┌┌─┐┬─┐
     │││├─┤│  ───│  │  ├┤ ├─┤│││├┤ ├┬┘
     ┴ ┴┴ ┴└─┘   └─┘┴─┘└─┘┴ ┴┘└┘└─┘┴└─
```

## Install

```sh
brew install chaibialaa/tap/mac-cleaner
```

## Usage

```sh
mac-cleaner              # interactive menu
mac-cleaner ram          # free inactive memory (sudo purge)
mac-cleaner trash        # empty the Trash
mac-cleaner uninstall    # remove an app and its leftovers in ~/Library
mac-cleaner large        # find large files in your home folder
mac-cleaner caches       # app caches, logs, Xcode, npm, Composer, Gradle, Homebrew, Docker, idle node_modules
mac-cleaner downloads    # old files in ~/Downloads
mac-cleaner startup      # login items, launch agents and daemons, and disable them
mac-cleaner duplicates   # identical files (same content), keeps the oldest copy
mac-cleaner temp         # old files in /private/tmp and $TMPDIR, app copies left by updates (*.code_sign_clone)
mac-cleaner dev          # merged or idle git worktrees, Library/ of idle Unity projects
mac-cleaner system       # swap, local Time Machine snapshots, APFS volumes, purgeable space
mac-cleaner auto         # everything safe in one pass: caches, logs, dev caches, Homebrew, old temp files, Trash
mac-cleaner history      # what was freed, and when
```

Options, for any command:

```sh
--dry-run, -n   # preview what would be done, delete nothing
--yes, -y       # do not ask for confirmation (e.g. `mac-cleaner auto --yes` in a weekly job)
```

- Uninstalled apps, large files, old downloads, duplicates and startup items go to the **Trash**, so you can put them back.
- Only emptying the Trash and cleaning caches delete files for good, and both ask first.
- Docker and `node_modules` are listed in `caches` but left out of `auto`. Docker volumes are never touched.
- `caches` skips the cache of every running app (matched by bundle id, app or process name) and lists what it skipped. `~/.cache` (uv, Hugging Face…) is never touched.
- `temp` removes entries of `/private/tmp` and `$TMPDIR` older than 3 days (`MAC_CLEANER_TEMP_DAYS`) that you own and that no process has open (checked with `lsof`), plus `*.code_sign_clone` copies of apps that are not running. APFS clones can share blocks, so the real gain is measured with `df` before and after.
- `dev` scans `MAC_CLEANER_PROJECTS` (default: home folder) for git repositories. A worktree is offered for removal only if it is clean, no process uses it, it has not been touched in the last day, and its branch is merged into the main branch or it has been idle for 14 days (`MAC_CLEANER_DEV_DAYS`). It is removed with `git worktree remove` (never `rm`), branches are kept, and orphaned worktrees are pruned. Separately, it can empty the `Library/` folder of Unity projects that no Unity instance has open and that did not change in 14 days: Unity rebuilds it next time, which takes a while.
- `system` only reports, without sudo: swap, local snapshots, APFS volumes, purgeable space. Swap is only really freed by a restart. If you accept, it runs `sudo tmutil thinlocalsnapshots / 999999999999 4` and `sudo purge`.
- `auto` includes `temp` (never clones of running apps), but never `dev` nor Unity `Library/`: those are always on demand.
- `node_modules` folders (and git repositories for `dev`) are scanned in your home folder. Point to other folders with `MAC_CLEANER_PROJECTS="$HOME:/path/to/projects"`. A project counts as idle when none of its files changed in 90 days.
- Skip some cache entries with `MAC_CLEANER_SKIP="brew docker"`.
- Apple system apps are never uninstalled.
- The interface follows your system language (English or French). Force it with `MAC_CLEANER_LANG=en` or `fr`.
- `NO_COLOR=1` disables colors and animations.

History is kept in `~/.local/state/mac-cleaner/history.tsv`.

Grant **Full Disk Access** to your terminal (System Settings › Privacy & Security) for accurate Trash sizes and leftover detection.

---

## Français

Un petit nettoyeur macOS pour le terminal : libérer la RAM, vider la corbeille, désinstaller une app avec ses fichiers, trouver les gros fichiers, les vieux téléchargements et les doublons, nettoyer les caches (y compris Xcode, Gradle, Homebrew, Docker, node_modules) sans toucher à ceux des apps ouvertes, gérer ce qui se lance au démarrage, tout nettoyer d'un coup avec `mac-cleaner auto`, et voir l'historique.

Pour un Mac de développement plein :

- `mac-cleaner temp` : fichiers de `/private/tmp` et `$TMPDIR` de plus de 3 jours qu'aucun processus n'a ouverts, et copies d'apps laissées par les mises à jour (`*.code_sign_clone`, par exemple Chrome) quand l'app ne tourne pas. L'espace réellement regagné est mesuré avec `df`, car les clones APFS partagent des blocs.
- `mac-cleaner dev` : worktrees git propres, sans processus, fusionnés ou inactifs depuis 14 jours, supprimés avec `git worktree remove` (les branches restent), puis `git worktree prune`. À part, vider le `Library/` des projets Unity inactifs : Unity le recréera à la prochaine ouverture, ce qui prend du temps.
- `mac-cleaner system` : swap, instantanés Time Machine, volumes APFS, purgeable, sans sudo. Le swap ne se libère vraiment qu'au redémarrage. Avec ton accord : `tmutil thinlocalsnapshots` et `purge` en sudo.
- `auto` inclut `temp`, jamais `dev` ni `Library/` Unity. `--dry-run` montre ce qui serait fait sans rien supprimer. Installation : `brew install chaibialaa/tap/mac-cleaner`, puis `mac-cleaner`.

## Tests

```sh
zsh tests/run.zsh
```

Each test runs in a throwaway home folder with its own Trash, so nothing on your Mac is touched.

## License

MIT
