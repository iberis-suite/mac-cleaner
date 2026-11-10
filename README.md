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
mac-cleaner uninstall "/Applications/Name.app" --dry-run   # no search, no question: preview (or --yes) for this app
mac-cleaner large        # find large files in your home folder
mac-cleaner caches       # app caches, logs, Xcode, npm, Composer, Gradle, Homebrew, Docker, idle node_modules
mac-cleaner caches --yes # no question: everything except Docker and node_modules (same safe set as auto)
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
- The menu bar app (`menubar/`) can schedule `mac-cleaner auto --yes` every Monday at 10:00 (a LaunchAgent, log in `~/Library/Logs/mac-cleaner-weekly.log`).

## Scripting

For `large`, `downloads`, `duplicates`, `startup`, `dev`, `caches`, `temp`, `trash` and `auto`, no keyboard is needed:

```sh
mac-cleaner large --list --min 500          # do nothing, one TSV line per item: index, KB, label, path, type
mac-cleaner large --dry-run --min 500 --select "1 3"   # preview with the same indexes
mac-cleaner large --yes --min 500 --select "1 3"       # act on them (or --select all)
mac-cleaner downloads --list --days 90
mac-cleaner duplicates --list --dir ~/Documents --min 1   # index = group, type = keep or copy
mac-cleaner startup --list                  # type = login, agent, sysagent, daemon, plus a 6th column on/off
mac-cleaner dev --yes --select "2" --select-unity "1"     # worktrees, then Unity Library/ (never with --yes alone)
mac-cleaner caches --list                   # type = cache key (apps, logs, npm, brew, docker, nodemod…), 6th column safe or excluded
mac-cleaner caches --yes --select "1 4"
mac-cleaner temp --list                     # type = tmp or clone; kept = clone of a running app
mac-cleaner temp --yes --select "2 5"
mac-cleaner trash --list                    # one line per top-level item of the Trash, type = file or dir
mac-cleaner auto --list                     # one line per section auto would run, in order: index, KB, label, -, section
```

Lines with index `0` are not selectable: `skipped` (cache of a running app, in `caches` and `auto`) and `kept` (app copy of a running app, in `temp` and `auto`).

Titles and colors are not printed with `--list`, so stdout only holds the TSV lines. Indexes are the same as the list as long as the disk did not change. If `SUDO_ASKPASS` is set, every `sudo` call becomes `sudo -A` (`ram`, `system`, system startup items), so no terminal is needed.

History is kept in `~/.local/state/mac-cleaner/history.tsv`.

Grant **Full Disk Access** to your terminal (System Settings › Privacy & Security) for accurate Trash sizes and leftover detection.

---

## Français

Un petit nettoyeur macOS pour le terminal : libérer la RAM, vider la corbeille, désinstaller une app avec ses fichiers, trouver les gros fichiers, les vieux téléchargements et les doublons, nettoyer les caches (y compris Xcode, Gradle, Homebrew, Docker, node_modules) sans toucher à ceux des apps ouvertes, gérer ce qui se lance au démarrage, tout nettoyer d'un coup avec `mac-cleaner auto`, et voir l'historique.

Pour un Mac de développement plein :

- `mac-cleaner temp` : fichiers de `/private/tmp` et `$TMPDIR` de plus de 3 jours qu'aucun processus n'a ouverts, et copies d'apps laissées par les mises à jour (`*.code_sign_clone`, par exemple Chrome) quand l'app ne tourne pas. L'espace réellement regagné est mesuré avec `df`, car les clones APFS partagent des blocs.
- `mac-cleaner dev` : worktrees git propres, sans processus, fusionnés ou inactifs depuis 14 jours, supprimés avec `git worktree remove` (les branches restent), puis `git worktree prune`. À part, vider le `Library/` des projets Unity inactifs : Unity le recréera à la prochaine ouverture, ce qui prend du temps.
- `mac-cleaner system` : swap, instantanés Time Machine, volumes APFS, purgeable, sans sudo. Le swap ne se libère vraiment qu'au redémarrage. Avec ton accord : `tmutil thinlocalsnapshots` et `purge` en sudo.
- `mac-cleaner caches --dry-run` ou `--yes` : plus de choix au clavier, tout sauf Docker et `node_modules` (la sélection de `auto`).
- `mac-cleaner uninstall "/Applications/Nom.app" --dry-run` (ou `--yes`) : traite directement cette app, sans recherche ni question ; les apps Apple restent refusées.
- `auto` inclut `temp`, jamais `dev` ni `Library/` Unity. `--dry-run` montre ce qui serait fait sans rien supprimer. Installation : `brew install chaibialaa/tap/mac-cleaner`, puis `mac-cleaner`.
- Scripts et app : `--list` pour `large`, `downloads`, `duplicates`, `startup`, `dev`, `caches` (6e colonne `safe` ou `excluded`), `temp` (type `tmp` ou `clone`), `trash` (un élément de premier niveau par ligne) et `auto` (une ligne par section, dans l'ordre d'exécution) ; aucune action, une ligne TSV par élément : index, Ko, libellé, chemin, type ; index `0` = non sélectionnable, `skipped` (cache d'une app ouverte) ou `kept` (copie d'une app ouverte) ; `--select "1 3"` ou `all` (répond au choix avec les mêmes index, avec `--dry-run` ou `--yes`), `--select-unity` pour `dev`, et `--min`, `--days`, `--dir` pour les paramètres de `large`, `downloads`, `duplicates`. Avec `SUDO_ASKPASS`, le CLI appelle `sudo -A` : plus besoin de terminal.
- L'app de barre des menus (`menubar/`) peut programmer `mac-cleaner auto --yes` chaque lundi à 10 h (LaunchAgent, journal dans `~/Library/Logs/mac-cleaner-weekly.log`).

## Tests

```sh
zsh tests/run.zsh
```

Each test runs in a throwaway home folder with its own Trash, so nothing on your Mac is touched.

## License

MIT
