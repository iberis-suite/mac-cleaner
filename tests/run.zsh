#!/bin/zsh
setopt null_glob

ROOT=${0:A:h:h}
BIN=$ROOT/mac-cleaner
PTY=$ROOT/tests/terminal.py
pass=0 fail=0

check() {
  local name=$1; shift
  if "$@"; then (( pass++ )); print "ok    $name"
  else (( fail++ )); print "FAIL  $name"; fi
}

setup() {
  SANDBOX=$(mktemp -d)
  export HOME=$SANDBOX/home MAC_CLEANER_TRASH_DIR=$SANDBOX/trash MAC_CLEANER_LANG=fr MAC_CLEANER_TEST=1
  export MAC_CLEANER_SKIP="brew docker" MAC_CLEANER_PROJECTS=$SANDBOX/home/code
  export MAC_CLEANER_TMP_DIRS=$SANDBOX/tmp MAC_CLEANER_CLONE_DIRS=$SANDBOX/X
  unset XDG_STATE_HOME NO_COLOR MAC_CLEANER_TEMP_DAYS MAC_CLEANER_DEV_DAYS
  mkdir -p $HOME $MAC_CLEANER_TRASH_DIR $MAC_CLEANER_TMP_DIRS $MAC_CLEANER_CLONE_DIRS
  HIST=$HOME/.local/state/mac-cleaner/history.tsv
}

BG=()
teardown() { (( ${#BG} )) && kill $BG 2>/dev/null; wait 2>/dev/null; BG=(); rm -rf $SANDBOX }

runapp() {
  mkdir -p "$HOME/Applications/$1.app/Contents/MacOS"
  /usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string $2" "$HOME/Applications/$1.app/Contents/Info.plist" >/dev/null
  ln -s /bin/sleep "$HOME/Applications/$1.app/Contents/MacOS/$1"
  "$HOME/Applications/$1.app/Contents/MacOS/$1" 120 &
  BG+=( $! )
  sleep 0.3
}

old() { touch -t 202001010000 "$@" }

gitc() { GIT_AUTHOR_DATE=2020-01-01T00:00:00 GIT_COMMITTER_DATE=2020-01-01T00:00:00 git -C "$@" }

mkrepo() {
  local r=$HOME/code/repo
  mkdir -p $r && git -C $r init -q -b main && git -C $r config user.email t@t && git -C $r config user.name t
  print a > $r/a; git -C $r add a; gitc $r commit -qm init
  git -C $r worktree add -q -b fusionnee $r/../wt-fusionnee main
  git -C $r worktree add -q -b sale $r/../wt-sale main; print x > $r/../wt-sale/nouveau
  git -C $r worktree add -q -b vieille $r/../wt-vieille main
  print v > $r/../wt-vieille/v; git -C $r/../wt-vieille add v; gitc $r/../wt-vieille commit -qm vieux
  git -C $r worktree add -q -b active $r/../wt-active main
  print n > $r/../wt-active/n; git -C $r/../wt-active add n; git -C $r/../wt-active commit -qm recent
  git -C $r worktree add -q -b occupee $r/../wt-occupee main
  git -C $r worktree add -q -b orpheline $r/../wt-orpheline main
  rm -rf $r/../wt-orpheline
  old $r/.git/worktrees/*/(HEAD|index)(N)
  git -C $r config user.email t@t
  ( cd $r/../wt-occupee && exec sleep 120 ) &
  BG+=( $! )
  sleep 0.3
}

mkunity() {
  local p=$HOME/code/$1
  mkdir -p $p/Assets $p/ProjectSettings $p/Library/ArtifactDB
  print v > $p/ProjectSettings/ProjectVersion.txt; print s > $p/Assets/scene.unity
  head -c 100000 /dev/urandom > $p/Library/ArtifactDB/blob
  [[ $2 == old ]] && old $p/**/*(D) $p
}

mkcaches() {
  mkdir -p $HOME/Library/Caches/com.test.app $HOME/Library/Logs $HOME/.npm/_cacache/x
  head -c 200000 /dev/urandom > $HOME/Library/Caches/com.test.app/blob
  print log > $HOME/Library/Logs/test.log
  print npm > $HOME/.npm/_cacache/x/entry
}

mkproject() {
  mkdir -p $HOME/code/$1/node_modules/dep
  print '{}' > $HOME/code/$1/package.json
  head -c 50000 /dev/urandom > $HOME/code/$1/node_modules/dep/index.js
  [[ $2 == old ]] && touch -t 202001010000 $HOME/code/$1/package.json
}

mkapp() {
  mkdir -p "$HOME/Applications/$1.app/Contents"
  /usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string $2" "$HOME/Applications/$1.app/Contents/Info.plist" >/dev/null
}

empty_dir() { [[ -d $1 && -z $(ls -A $1) ]] }

print "== mac-cleaner tests"

check "syntaxe zsh" zsh -n $BIN

setup
VER=$(awk -F= '/^VERSION=/{print $2}' $BIN)
check "--version" eval '[[ $($BIN --version) == "mac-cleaner $VER" ]]'
check "--help FR" eval '$BIN --help | grep -q "Usage :"'
check "--help EN" eval 'MAC_CLEANER_LANG=en $BIN --help | grep -q "Usage:"'
check "commande inconnue -> code 1" eval '! $BIN nimportequoi >/dev/null'
teardown

setup; mkcaches
out=$(print 't' | $BIN caches --dry-run)
check "caches --dry-run ne supprime rien" eval '[[ -f $HOME/Library/Caches/com.test.app/blob && -f $HOME/.npm/_cacache/x/entry ]]'
check "caches --dry-run affiche l'aperçu" eval '[[ $out == *"[aperçu]"* ]]'
check "caches --dry-run n'écrit pas l'historique" eval '[[ ! -e $HIST ]]'
print 't' | $BIN caches >/dev/null
check "caches vide les dossiers" eval 'empty_dir $HOME/Library/Caches && empty_dir $HOME/Library/Logs && empty_dir $HOME/.npm/_cacache'
check "caches garde les dossiers eux-mêmes" eval '[[ -d $HOME/Library/Caches && -d $HOME/.npm/_cacache ]]'
check "caches écrit l'historique" eval 'grep -q "	m5	" $HIST'
teardown

setup; mkproject ancien old; mkproject actif new
print 't' | $BIN caches >/dev/null
check "node_modules inactif supprimé" eval '[[ ! -e $HOME/code/ancien/node_modules ]]'
check "node_modules actif gardé" eval '[[ -d $HOME/code/actif/node_modules ]]'
check "package.json jamais touché" eval '[[ -f $HOME/code/ancien/package.json ]]'
teardown

setup; mkcaches; print x > $MAC_CLEANER_TRASH_DIR/vieux.txt
$BIN auto --dry-run >/dev/null
check "auto --dry-run ne supprime rien" eval '[[ -f $HOME/Library/Caches/com.test.app/blob && -f $MAC_CLEANER_TRASH_DIR/vieux.txt ]]'
$BIN auto --yes >/dev/null
check "auto --yes vide caches et corbeille" eval 'empty_dir $HOME/Library/Caches && empty_dir $MAC_CLEANER_TRASH_DIR'
check "auto écrit l'historique" eval 'grep -q "	m9	" $HIST'
teardown

setup
mkapp ZzMcTestApp com.test.zzmc
mkdir -p "$HOME/Library/Application Support/ZzMcTestApp" $HOME/Library/Preferences
print x > $HOME/Library/Preferences/com.test.zzmc.plist
print x > $HOME/Library/Preferences/com.test.zzmc.helper.plist
print x > $HOME/Library/Preferences/com.test.zzmcother.plist
printf 'ZzMcTestApp\n1\no\n' | $BIN uninstall >/dev/null
check "désinstallation : app à la corbeille" eval '[[ -d $MAC_CLEANER_TRASH_DIR/ZzMcTestApp.app && ! -e $HOME/Applications/ZzMcTestApp.app ]]'
check "désinstallation : fichiers liés à la corbeille" eval '[[ -f $MAC_CLEANER_TRASH_DIR/com.test.zzmc.plist && -f $MAC_CLEANER_TRASH_DIR/com.test.zzmc.helper.plist && -d "$MAC_CLEANER_TRASH_DIR/ZzMcTestApp" ]]'
check "désinstallation : app voisine épargnée" eval '[[ -f $HOME/Library/Preferences/com.test.zzmcother.plist ]]'
teardown

setup; mkcaches; mkproject ancien old
out=$($BIN caches --dry-run </dev/null)
check "caches --dry-run sans clavier : pas de question" eval '[[ $out != *"Numéros à nettoyer"* && $out == *"tout sauf Docker et node_modules"* ]]'
check "aperçus utilisés par l'app : code 0" eval '$BIN caches --dry-run </dev/null >/dev/null && $BIN temp --dry-run </dev/null >/dev/null && $BIN trash --dry-run </dev/null >/dev/null && $BIN auto --dry-run </dev/null >/dev/null'
check "caches --dry-run sans clavier : rien supprimé" eval '[[ -f $HOME/Library/Caches/com.test.app/blob && -d $HOME/code/ancien/node_modules ]]'
out=$($BIN caches --yes </dev/null)
check "caches --yes sans clavier : caches vidés" eval 'empty_dir $HOME/Library/Caches && empty_dir $HOME/.npm/_cacache'
check "caches --yes sans clavier : node_modules exclu" eval '[[ -d $HOME/code/ancien/node_modules && $out == *"node_modules"*"(exclu)"* ]]'
check "caches --yes écrit l'historique" eval 'grep -q "	m5	" $HIST'
teardown

setup
mkapp ZzArgApp com.test.zzarg
mkdir -p "$HOME/Library/Application Support/ZzArgApp"
out=$($BIN uninstall "$HOME/Applications/ZzArgApp.app" --dry-run </dev/null)
check "uninstall <app> --dry-run : aperçu sans question" eval '[[ $out == *"Total"* && $out == *"ZzArgApp"* && $out != *"Nom (ou partie"* ]]'
check "uninstall <app> --dry-run : rien déplacé" eval '[[ -d $HOME/Applications/ZzArgApp.app && ! -e $HIST ]]'
$BIN uninstall "$HOME/Applications/ZzArgApp.app" --yes </dev/null >/dev/null
check "uninstall <app> --yes : app et fichiers à la corbeille" eval '[[ -d $MAC_CLEANER_TRASH_DIR/ZzArgApp.app && -d "$MAC_CLEANER_TRASH_DIR/ZzArgApp" && ! -e $HOME/Applications/ZzArgApp.app ]]'
check "uninstall <app> --yes écrit l'historique" eval 'grep -q "	m3	.*ZzArgApp" $HIST'
mkapp ZzApple com.apple.zztest
out=$($BIN uninstall "$HOME/Applications/ZzApple.app" --yes </dev/null)
check "uninstall <app> : app Apple refusée" eval '[[ -d $HOME/Applications/ZzApple.app && $out == *"App système Apple"* ]]'
check "uninstall <app> introuvable -> code 1" eval '! $BIN uninstall "$HOME/Applications/Absente.app" --yes </dev/null >/dev/null'
teardown

setup
mkfile -n 3m $HOME/gros.bin; mkfile -n 1m $HOME/petit.bin
printf '2\n1\no\n' | $BIN large >/dev/null
check "gros fichiers : le gros part" eval '[[ -e $MAC_CLEANER_TRASH_DIR/gros.bin && ! -e $HOME/gros.bin ]]'
check "gros fichiers : le petit reste" eval '[[ -e $HOME/petit.bin ]]'
teardown

setup
mkdir -p $HOME/Downloads; print a > $HOME/Downloads/vieux.dmg; print b > $HOME/Downloads/recent.txt
touch -t 202001010000 $HOME/Downloads/vieux.dmg
printf '90\nt\no\n' | $BIN downloads >/dev/null
check "téléchargements : le vieux part" eval '[[ -e $MAC_CLEANER_TRASH_DIR/vieux.dmg ]]'
check "téléchargements : le récent reste" eval '[[ -e $HOME/Downloads/recent.txt ]]'
teardown

setup
mkdir -p $HOME/docs/sub
head -c 2200000 /dev/urandom > $HOME/docs/a.bin
cp $HOME/docs/a.bin $HOME/docs/sub/b.bin; touch $HOME/docs/sub/b.bin
head -c 2200000 /dev/urandom > $HOME/docs/c.bin
printf '\n1\nt\no\n' | $BIN duplicates >/dev/null
check "doublons : la copie part" eval '[[ -e $MAC_CLEANER_TRASH_DIR/b.bin && ! -e $HOME/docs/sub/b.bin ]]'
check "doublons : l'original reste" eval '[[ -e $HOME/docs/a.bin ]]'
check "doublons : le fichier de même taille mais différent reste" eval '[[ -e $HOME/docs/c.bin ]]'
teardown

setup
mkdir -p $HOME/Library/LaunchAgents
/usr/libexec/PlistBuddy -c 'Add :Label string com.test.zzagent' $HOME/Library/LaunchAgents/com.test.zzagent.plist >/dev/null
out=$(printf '1\no\n' | $BIN startup)
check "démarrage : agent listé" eval '[[ $out == *com.test.zzagent* ]]'
check "démarrage : agent désactivé" eval '[[ -e $MAC_CLEANER_TRASH_DIR/com.test.zzagent.plist && ! -e $HOME/Library/LaunchAgents/com.test.zzagent.plist ]]'
teardown

setup; mkcaches; runapp ZzRun com.test.zzrun
mkdir -p $HOME/Library/Caches/com.test.zzrun; print c > $HOME/Library/Caches/com.test.zzrun/cache
out=$(print 't' | $BIN caches)
check "caches : cache d'une app en cours gardé" eval '[[ -f $HOME/Library/Caches/com.test.zzrun/cache ]]'
check "caches : les autres vidés" eval '[[ ! -e $HOME/Library/Caches/com.test.app ]]'
check "caches : app ignorée listée" eval '[[ $out == *"Ignorés, app en cours"*com.test.zzrun* ]]'
teardown

setup; runapp ZzRun com.test.zzrun
T1=$MAC_CLEANER_TMP_DIRS X1=$MAC_CLEANER_CLONE_DIRS
print a > $T1/vieux.log; print b > $T1/recent.log
mkdir -p $T1/vieuxdossier $T1/dossiervivant; print c > $T1/vieuxdossier/f; print d > $T1/dossiervivant/f
print e > $T1/ouvert.log
old $T1/vieux.log $T1/vieuxdossier/f $T1/vieuxdossier $T1/dossiervivant $T1/ouvert.log
sleep 120 < $T1/ouvert.log &
BG+=( $! )
mkdir -p $X1/com.test.zzrun.code_sign_clone $X1/com.test.parti.code_sign_clone
print x > $X1/com.test.zzrun.code_sign_clone/f; print y > $X1/com.test.parti.code_sign_clone/f
sleep 0.3
out=$($BIN temp --dry-run)
check "temp --dry-run ne supprime rien" eval '[[ -f $T1/vieux.log && -d $X1/com.test.parti.code_sign_clone ]]'
check "temp --dry-run parle de df et des clones APFS" eval '[[ $out == *df* && $out == *APFS* ]]'
out=$($BIN temp --yes)
check "temp : vieux fichier et vieux dossier supprimés" eval '[[ ! -e $T1/vieux.log && ! -e $T1/vieuxdossier ]]'
check "temp : fichier récent gardé" eval '[[ -f $T1/recent.log ]]'
check "temp : dossier avec contenu récent gardé" eval '[[ -f $T1/dossiervivant/f ]]'
check "temp : fichier ouvert par un processus gardé" eval '[[ -f $T1/ouvert.log ]]'
check "temp : clone d'app arrêtée supprimé" eval '[[ ! -e $X1/com.test.parti.code_sign_clone ]]'
check "temp : clone d'app en cours gardé et signalé" eval '[[ -d $X1/com.test.zzrun.code_sign_clone && $out == *"app en cours"*com.test.zzrun* ]]'
check "temp : espace réel df affiché" eval '[[ $out == *"réellement regagné (df)"* ]]'
check "temp écrit l'historique" eval 'grep -q "	mt	" $HIST'
teardown

setup; print a > $MAC_CLEANER_TMP_DIRS/vieux.log; old $MAC_CLEANER_TMP_DIRS/vieux.log
$BIN auto --yes >/dev/null
check "auto inclut temp" eval '[[ ! -e $MAC_CLEANER_TMP_DIRS/vieux.log ]]'
teardown

setup; mkrepo; mkunity vieux-unity old; mkunity unity-actif new
W=$HOME/code
out=$($BIN dev --dry-run)
check "dev --dry-run ne supprime rien" eval '[[ -d $W/wt-fusionnee && -f $W/vieux-unity/Library/ArtifactDB/blob ]]'
check "dev --dry-run propose git worktree remove" eval '[[ $out == *"worktree remove"*wt-fusionnee* ]]'
check "dev prévient que Unity recréera Library" eval '[[ $out == *"Unity le recréera"* ]]'
out=$($BIN dev --yes)
check "dev : worktree fusionné supprimé" eval '[[ ! -e $W/wt-fusionnee ]]'
check "dev : worktree inactif depuis 14 j supprimé" eval '[[ ! -e $W/wt-vieille ]]'
check "dev : les branches restent" eval 'git -C $W/repo show-ref -q --verify refs/heads/fusionnee && git -C $W/repo show-ref -q --verify refs/heads/vieille'
check "dev : worktree pas propre gardé" eval '[[ -f $W/wt-sale/nouveau ]]'
check "dev : worktree récent non fusionné gardé" eval '[[ -d $W/wt-active ]]'
check "dev : worktree avec un processus gardé" eval '[[ -d $W/wt-occupee ]]'
check "dev : worktree orphelin nettoyé (prune)" eval '! git -C $W/repo worktree list | grep -q wt-orpheline'
check "dev --yes ne vide jamais Library Unity" eval '[[ -f $W/vieux-unity/Library/ArtifactDB/blob && -f $W/vieux-unity/Assets/scene.unity ]]'
check "dev --yes dit pourquoi Library est gardé" eval '[[ $out == *"--yes ne vide jamais Library"* ]]'
check "dev : Library Unity actif gardé" eval '[[ -f $W/unity-actif/Library/ArtifactDB/blob ]]'
check "dev écrit l'historique" eval 'grep -q "	md	" $HIST'
teardown

setup
out=$($BIN system --dry-run)
check "system : swap, instantanés, APFS, purgeable" eval '[[ $out == *"Échange (swap)"* && $out == *"Instantanés locaux"* && $out == *"Conteneur APFS"* && $out == *purgeable* ]]'
check "system : dit que le swap attend le redémarrage" eval '[[ $out == *redémarrage* ]]'
check "system --dry-run n'exécute pas sudo" eval '[[ $out == *"[aperçu] sudo tmutil thinlocalsnapshots / 999999999999 4"* && $out == *"[aperçu] sudo purge"* ]]'
out=$(print n | $BIN system)
check "system : refus = rien lancé" eval '[[ $out != *"[aperçu]"* && ! -e $HIST ]]'
teardown

setup; mkcaches
print 't' | $BIN caches >/dev/null
out=$($BIN history)
check "historique : affiche le total" eval '[[ $out == *"Libéré au total"* ]]'
out=$(MAC_CLEANER_LANG=en $BIN history)
check "historique : en anglais" eval '[[ $out == *"Freed in total"* && $out == *"Clean caches"* ]]'
teardown

tsv_ok() { local l; for l in ${(f)1}; do [[ $l == STEP$'\t'* ]] && continue; [[ $l == <1->$'\t'<->$'\t'*$'\t'*$'\t'* || $l == 0$'\t'<->$'\t'*$'\t'*$'\t'(skipped|kept) ]] || return 1; done }
col() { local l; for l in ${(f)1}; do [[ $l == *"$2"* ]] && { print -r -- "${${(@ps:\t:)l}[$3]}"; return }; done }

setup
mkfile -n 3m $HOME/gros.bin; mkfile -n 2m $HOME/moyen.bin; mkfile -n 1m $HOME/petit.bin
out=$($BIN large --list --min 1 </dev/null)
check "large --list : TSV seul sur stdout" eval 'tsv_ok "$out" && [[ ${#${(f)out}} == 2 && $out != *"Gros fichiers"* ]]'
check "large --list : taille et chemin, tri laissé à l'app" eval '[[ $(col "$out" gros.bin 2) == 3072 && $(col "$out" gros.bin 4) == $HOME/gros.bin && $(col "$out" moyen.bin 2) == 2048 && $(col "$out" gros.bin 5) == file ]]'
check "large --list : index uniques 1 et 2" eval '[[ ${(j: :)${(o)${(f)"$(print -rl -- ${${(f)out}%%$'"'"'\t'"'"'*})"}}} == "1 2" ]]'
check "large --list : aucune action, code 0" eval '$BIN large --list --min 1 </dev/null >/dev/null && [[ -e $HOME/gros.bin && ! -e $HIST ]]'
i=$(col "$out" moyen.bin 1)
out=$($BIN large --dry-run --min 1 --select $i </dev/null)
check "large --dry-run --select : aperçu de l'index choisi seul" eval '[[ $out == *"[aperçu]"*moyen.bin* && $out != *"[aperçu]"*gros.bin* && -e $HOME/moyen.bin ]]'
$BIN large --yes --min 1 --select $i </dev/null >/dev/null
check "large --yes --select : seul l'index choisi part" eval '[[ -e $MAC_CLEANER_TRASH_DIR/moyen.bin && -e $HOME/gros.bin ]]'
teardown

setup
mkdir -p $HOME/Downloads; print a > $HOME/Downloads/vieux.dmg; mkdir $HOME/Downloads/vieuxdossier; print b > $HOME/Downloads/recent.txt
old $HOME/Downloads/vieux.dmg $HOME/Downloads/vieuxdossier
out=$($BIN downloads --list --days 30 </dev/null)
check "downloads --list : vieux éléments seulement, sans question" eval 'tsv_ok "$out" && [[ ${#${(f)out}} == 2 && $out == *vieux.dmg* && $out == *vieuxdossier*dir* && $out != *recent* ]]'
i=${${(M)${(f)out}:#*vieux.dmg*}%%$'\t'*}
$BIN downloads --yes --days 30 --select $i </dev/null >/dev/null
check "downloads --yes --select : l'élément choisi part" eval '[[ -e $MAC_CLEANER_TRASH_DIR/vieux.dmg && -d $HOME/Downloads/vieuxdossier ]]'
teardown

setup
mkdir -p $HOME/docs/sub
head -c 2200000 /dev/urandom > $HOME/docs/a.bin; old $HOME/docs/a.bin
cp $HOME/docs/a.bin $HOME/docs/sub/b.bin; touch $HOME/docs/sub/b.bin
out=$($BIN duplicates --list --dir $HOME/docs --min 1 </dev/null)
check "duplicates --list : groupe, original gardé puis copie" eval 'tsv_ok "$out" && [[ ${${${(f)out}:#STEP*}[1]} == 1$'"'"'\t'"'"'*a.bin$'"'"'\t'"'"'keep && ${${${(f)out}:#STEP*}[2]} == 1$'"'"'\t'"'"'*b.bin$'"'"'\t'"'"'copy ]]'
$BIN duplicates --yes --dir $HOME/docs --min 1 --select all </dev/null >/dev/null
check "duplicates --yes --select all : la copie part, l'original reste" eval '[[ -e $MAC_CLEANER_TRASH_DIR/b.bin && -e $HOME/docs/a.bin ]]'
teardown

setup
mkdir -p $HOME/Library/LaunchAgents
/usr/libexec/PlistBuddy -c 'Add :Label string com.test.zza' $HOME/Library/LaunchAgents/com.test.zza.plist >/dev/null
/usr/libexec/PlistBuddy -c 'Add :Label string com.test.zzb' $HOME/Library/LaunchAgents/com.test.zzb.plist >/dev/null
out=$($BIN startup --list </dev/null)
check "startup --list : agents du HOME de test" eval 'tsv_ok "$out" && [[ $out == *"com.test.zza	$HOME/Library/LaunchAgents/com.test.zza.plist	agent	off"* ]]'
i=${${(M)${(f)out}:#*com.test.zzb*}%%$'\t'*}
out=$($BIN startup --dry-run --select $i </dev/null)
check "startup --dry-run --select : rien désactivé" eval '[[ $out == *"[aperçu]"*com.test.zzb* && -e $HOME/Library/LaunchAgents/com.test.zzb.plist ]]'
$BIN startup --yes --select $i </dev/null >/dev/null
check "startup --yes --select : seul l'agent choisi désactivé" eval '[[ -e $MAC_CLEANER_TRASH_DIR/com.test.zzb.plist && -e $HOME/Library/LaunchAgents/com.test.zza.plist ]]'
teardown

setup; mkrepo; mkunity vieux-unity old
W=$HOME/code
out=$($BIN dev --list </dev/null)
check "dev --list : worktrees et Unity, sans question" eval 'tsv_ok "$out" && [[ $out == *wt-fusionnee*worktree* && $out == *wt-vieille*worktree* && $out == *vieux-unity/Library$'"'"'\t'"'"'unity* && $out != *wt-sale* ]]'
i=${${(M)${(f)out}:#*wt-fusionnee*}%%$'\t'*}
out=$($BIN dev --dry-run --select $i </dev/null)
check "dev --dry-run --select : un worktree, pas de Library" eval '[[ $out == *"worktree remove"*wt-fusionnee* && $out != *"worktree remove"*wt-vieille* && $out != *"rm -rf"*vieux-unity* ]]'
$BIN dev --yes --select $i </dev/null >/dev/null
check "dev --yes --select : seul le worktree choisi supprimé" eval '[[ ! -e $W/wt-fusionnee && -d $W/wt-vieille && -f $W/vieux-unity/Library/ArtifactDB/blob ]]'
$BIN dev --yes --select "" --select-unity 1 </dev/null >/dev/null
check "dev --yes --select-unity : Library vidé sur demande explicite" eval '[[ ! -e $W/vieux-unity/Library/ArtifactDB && -d $W/vieux-unity/Library && -d $W/wt-vieille ]]'
teardown

setup; mkcaches; mkproject ancien old
out=$($BIN caches --list </dev/null)
check "caches --list : clé, taille, chemin" eval 'tsv_ok "$out" && [[ $out == *"$HOME/Library/Caches	apps"* && $out == *"	npm"* && $out == *"	nodemod"* ]]'
i=$(col "$out" "	npm	" 1)
$BIN caches --yes --select $i </dev/null >/dev/null
check "caches --yes --select : seul npm vidé" eval 'empty_dir $HOME/.npm/_cacache && [[ -f $HOME/Library/Caches/com.test.app/blob && -f $HOME/Library/Logs/test.log ]]'
i=$(col "$out" "	nodemod	" 1)
$BIN caches --yes --select $i </dev/null >/dev/null
check "caches --yes --select : node_modules sur demande" eval '[[ ! -e $HOME/code/ancien/node_modules ]]'
check "--list refusé hors des commandes à liste" eval '! $BIN ram --list </dev/null >/dev/null 2>&1 && ! $BIN uninstall --list </dev/null >/dev/null 2>&1'
teardown

setup; mkcaches; runapp ZzRun com.test.zzrun
mkdir -p $HOME/Library/Caches/com.test.zzrun; print c > $HOME/Library/Caches/com.test.zzrun/cache
mkproject ancien old
out=$($BIN caches --list </dev/null)
check "caches --list : safe/excluded en 6e colonne" eval 'tsv_ok "$out" && [[ $(col "$out" "	npm	" 6) == safe && $(col "$out" "	nodemod	" 6) == excluded && $(col "$out" "	apps	" 6) == safe ]]'
check "caches --list : app en cours en ligne skipped (index 0)" eval '[[ $(col "$out" com.test.zzrun 5) == skipped && $(col "$out" com.test.zzrun 1) == 0 && $(col "$out" com.test.zzrun 4) == $HOME/Library/Caches/com.test.zzrun ]]'
check "caches --list : rien supprimé" eval '[[ -f $HOME/Library/Caches/com.test.zzrun/cache && -f $HOME/Library/Caches/com.test.app/blob && ! -e $HIST ]]'
teardown

setup; runapp ZzRun com.test.zzrun
T1=$MAC_CLEANER_TMP_DIRS X1=$MAC_CLEANER_CLONE_DIRS
print a > $T1/vieux-a.log; print b > $T1/vieux-b.log; print r > $T1/recent.log; old $T1/vieux-a.log $T1/vieux-b.log
mkdir -p $X1/com.test.zzrun.code_sign_clone $X1/com.test.parti.code_sign_clone
print x > $X1/com.test.zzrun.code_sign_clone/f; print y > $X1/com.test.parti.code_sign_clone/f
out=$($BIN temp --list </dev/null)
check "temp --list : tmp, clone et kept" eval 'tsv_ok "$out" && [[ $(col "$out" vieux-a.log 5) == tmp && $(col "$out" com.test.parti 5) == clone && $(col "$out" com.test.zzrun 5) == kept && $(col "$out" com.test.zzrun 1) == 0 && $out != *recent.log* ]]'
check "temp --list : libellé du clone sans suffixe" eval '[[ $(col "$out" com.test.parti 3) == com.test.parti ]]'
check "temp --list : rien supprimé" eval '[[ -f $T1/vieux-a.log && -d $X1/com.test.parti.code_sign_clone && ! -e $HIST ]]'
i=$(col "$out" vieux-b.log 1)
out=$($BIN temp --dry-run --select $i </dev/null)
check "temp --dry-run --select : seul l'élément choisi" eval '[[ $out == *"[aperçu] rm -rf"*vieux-b.log* && $out != *"[aperçu]"*vieux-a.log* && -f $T1/vieux-b.log ]]'
$BIN temp --yes --select $i </dev/null >/dev/null
check "temp --yes --select : seul l'élément choisi supprimé" eval '[[ ! -e $T1/vieux-b.log && -f $T1/vieux-a.log && -d $X1/com.test.parti.code_sign_clone && -d $X1/com.test.zzrun.code_sign_clone ]]'
teardown

setup; print x > $MAC_CLEANER_TRASH_DIR/a.txt; mkdir -p $MAC_CLEANER_TRASH_DIR/dossier; head -c 100000 /dev/urandom > $MAC_CLEANER_TRASH_DIR/dossier/f
out=$($BIN trash --list </dev/null)
check "trash --list : un élément de premier niveau par ligne" eval 'tsv_ok "$out" && [[ ${#${(f)out}} == 2 && $(col "$out" a.txt 5) == file && $(col "$out" dossier 5) == dir && $(col "$out" dossier 2) -ge 90 ]]'
check "trash --list : rien vidé" eval '[[ -f $MAC_CLEANER_TRASH_DIR/a.txt && ! -e $HIST ]]'
teardown

setup; mkcaches; print x > $MAC_CLEANER_TRASH_DIR/a.txt; print a > $MAC_CLEANER_TMP_DIRS/vieux.log; old $MAC_CLEANER_TMP_DIRS/vieux.log
out=$($BIN auto --list </dev/null)
check "auto --list : sections dans l'ordre, chemin -" eval 'tsv_ok "$out" && [[ ${${(f)out}[1]} == 1$'"'"'\t'"'"'*$'"'"'\t'"'"'-$'"'"'\t'"'"'apps && ${${(f)out}[-2]} == *$'"'"'\t'"'"'temp && ${${(f)out}[-1]} == *$'"'"'\t'"'"'trash && $out == *$'"'"'\t'"'"'npm* && $out != *nodemod* ]]'
check "auto --list : rien supprimé" eval '[[ -f $MAC_CLEANER_TRASH_DIR/a.txt && -f $MAC_CLEANER_TMP_DIRS/vieux.log && -f $HOME/Library/Caches/com.test.app/blob && ! -e $HIST ]]'
teardown

setup
FAKE=$SANDBOX/bin; mkdir -p $FAKE
print -r -- '#!/bin/zsh
print -r -- "$*" >> '$SANDBOX'/sudo.log' > $FAKE/sudo
print -r -- '#!/bin/zsh
exit 1' > $FAKE/askpass
chmod +x $FAKE/sudo $FAKE/askpass
PATH=$FAKE:$PATH SUDO_ASKPASS=$FAKE/askpass $BIN system --yes </dev/null >/dev/null 2>&1
check "SUDO_ASKPASS : sudo -A partout" eval '[[ -s $SANDBOX/sudo.log ]] && ! grep -qv "^-A " $SANDBOX/sudo.log && grep -q "^-A tmutil" $SANDBOX/sudo.log && grep -q "^-A purge" $SANDBOX/sudo.log'
rm -f $SANDBOX/sudo.log
PATH=$FAKE:$PATH SUDO_ASKPASS=$FAKE/askpass $BIN ram --yes </dev/null >/dev/null 2>&1
check "SUDO_ASKPASS : ram utilise sudo -A" eval 'grep -q "^-A purge" $SANDBOX/sudo.log'
rm -f $SANDBOX/sudo.log
PATH=$FAKE:$PATH $BIN ram --yes </dev/null >/dev/null 2>&1
check "sans SUDO_ASKPASS : sudo inchangé" eval '[[ -s $SANDBOX/sudo.log ]] && ! grep -q -- "-A" $SANDBOX/sudo.log'
teardown

mkbrowsers() {
  local cr="$HOME/Library/Application Support/Google/Chrome" cc="$HOME/Library/Caches/Google/Chrome" p
  for p in Default "Profile 1"; do
    mkdir -p "$cr/$p/Network" "$cr/$p/GPUCache" "$cc/$p/Cache"
    print h > "$cr/$p/History"; print v > "$cr/$p/Visited Links"; print c > "$cr/$p/Network/Cookies"
    print g > "$cr/$p/GPUCache/data_0"; head -c 100000 /dev/urandom > "$cc/$p/Cache/blob"
    print pref > "$cr/$p/Preferences"
  done
  mkdir -p "$cr/System Profile"; print h > "$cr/System Profile/History"
  FF="$HOME/Library/Application Support/Firefox/Profiles/abc.default-release"
  mkdir -p "$FF" "$HOME/Library/Caches/Firefox/Profiles/abc.default-release/cache2"
  print c > "$FF/cookies.sqlite"; print k > "$HOME/Library/Caches/Firefox/Profiles/abc.default-release/cache2/entry"
  sqlite3 "$FF/places.sqlite" "CREATE TABLE moz_places (id INTEGER PRIMARY KEY, url TEXT, visit_count INTEGER, last_visit_date INTEGER);
    CREATE TABLE moz_historyvisits (id INTEGER PRIMARY KEY, place_id INTEGER);
    CREATE TABLE moz_bookmarks (id INTEGER PRIMARY KEY, fk INTEGER);
    INSERT INTO moz_places VALUES (1, 'https://favori.test', 3, 1), (2, 'https://visite.test', 5, 1);
    INSERT INTO moz_historyvisits VALUES (1, 1), (2, 2), (3, 2);
    INSERT INTO moz_bookmarks VALUES (1, 1);"
}

ffq() { sqlite3 "$FF/places.sqlite" "$1" }

setup; mkbrowsers
CR="$HOME/Library/Application Support/Google/Chrome"; CC="$HOME/Library/Caches/Google/Chrome"
out=$($BIN privacy --dry-run </dev/null)
check "privacy --dry-run : Chrome (2 profils) et Firefox listés" eval '[[ $out == *"Chrome · Default"* && $out == *"Chrome · Profile 1"* && $out == *"Firefox · abc.default-release"* && $out != *"System Profile"* ]]'
check "privacy --dry-run : cookies gardés, aperçu des commandes" eval '[[ $out == *"Cookies  (gardé)"* && $out == *"[aperçu] rm -f ~/Library/Application Support/Google/Chrome/Default/History"* && $out != *"[aperçu]"*Network/Cookies* ]]'
check "privacy --dry-run : rien supprimé" eval '[[ -f $CR/Default/History && -f $CC/Default/Cache/blob && $(ffq "SELECT count(*) FROM moz_historyvisits") == 3 && ! -e $HIST ]]'
out=$($BIN privacy --list </dev/null)
check "privacy --list : TSV, catégorie et navigateur" eval 'tsv_ok "$out" && [[ $(col "$out" "Profile 1 · Cookies" 5) == cookies && $(col "$out" "Profile 1 · Cookies" 6) == chrome && $(col "$out" "abc.default-release · Historique" 6) == firefox ]]'
$BIN privacy --yes </dev/null >/dev/null
check "privacy --yes : historique et cache effacés" eval '[[ ! -e $CR/Default/History && ! -e "$CR/Profile 1/Visited Links" ]] && empty_dir $CC/Default && empty_dir "$CR/Profile 1/GPUCache" && empty_dir $HOME/Library/Caches/Firefox/Profiles/abc.default-release'
check "privacy --yes : cookies et préférences gardés" eval '[[ -f $CR/Default/Network/Cookies && -f "$CR/Profile 1/Network/Cookies" && -f $FF/cookies.sqlite && -f $CR/Default/Preferences && -f "$CR/System Profile/History" ]]'
check "privacy --yes : Firefox sans visites, favori gardé" eval '[[ $(ffq "SELECT count(*) FROM moz_historyvisits") == 0 && $(ffq "SELECT url FROM moz_places") == https://favori.test ]]'
check "privacy --yes : historique m15" eval 'grep -q "	m15	" $HIST'
$BIN privacy --yes --cookies </dev/null >/dev/null
check "privacy --yes --cookies : cookies effacés" eval '[[ ! -e $CR/Default/Network/Cookies && ! -e $FF/cookies.sqlite ]]'
teardown

setup; mkbrowsers; runapp "Google Chrome" com.google.Chrome
CR="$HOME/Library/Application Support/Google/Chrome"
out=$($BIN privacy --yes </dev/null)
check "privacy : navigateur ouvert ignoré et signalé" eval '[[ -f $CR/Default/History && -f $HOME/Library/Caches/Google/Chrome/Default/Cache/blob && $out == *"Ignoré, navigateur ouvert : Chrome"* && $(ffq "SELECT count(*) FROM moz_historyvisits") == 0 ]]'
out=$($BIN privacy --list </dev/null)
check "privacy --list : navigateur ouvert en index 0" eval '[[ $(col "$out" "	running	" 1) == 0 && $(col "$out" "	running	" 6) == chrome ]]'
teardown

setup; mkdir -p $HOME/Library/Safari
chmod 000 $HOME/Library/Safari
out=$($BIN privacy --dry-run </dev/null)
check "privacy : Safari illisible signalé" eval '[[ $out == *"Safari : accès complet au disque requis"* ]]'
chmod 755 $HOME/Library/Safari
teardown

setup
FAKE=$SANDBOX/bin; mkdir -p $FAKE
for b in sudo dscacheutil killall mdutil periodic lsregister; do
  print -r -- '#!/bin/zsh
print -r -- "'$b' $*" >> '$SANDBOX'/calls.log' > $FAKE/$b
  chmod +x $FAKE/$b
done
out=$(PATH=$FAKE:$PATH MAC_CLEANER_LSREGISTER=$FAKE/lsregister $BIN maintenance --dry-run </dev/null)
check "maintenance --dry-run : aucune commande lancée" eval '[[ ! -e $SANDBOX/calls.log && ! -e $HIST ]]'
check "maintenance --dry-run : les 4 opérations en aperçu" eval '[[ $out == *"[aperçu] sudo dscacheutil -flushcache"* && $out == *"[aperçu] sudo killall -HUP mDNSResponder"* && $out == *"[aperçu] sudo mdutil -E /"* && $out == *"[aperçu] $FAKE/lsregister -kill -r -domain local -domain system -domain user"* && $out == *"[aperçu] sudo periodic daily weekly monthly"* && $out != *"›"*"(o/N)"* ]]'
out=$(PATH=$FAKE:$PATH MAC_CLEANER_LSREGISTER=$FAKE/lsregister $BIN maintenance --list </dev/null)
check "maintenance --list : 4 lignes, root ou user" eval 'tsv_ok "$out" && [[ ${#${(f)out}} == 4 && $(col "$out" "	launch	" 6) == user && $(col "$out" "	dns	" 6) == root && ! -e $SANDBOX/calls.log ]]'
PATH=$FAKE:$PATH MAC_CLEANER_LSREGISTER=$FAKE/lsregister $BIN maintenance --yes --select "1 3" </dev/null >/dev/null
check "maintenance --yes --select : seules les opérations choisies" eval 'grep -q "^sudo dscacheutil -flushcache" $SANDBOX/calls.log && grep -q "^sudo killall -HUP mDNSResponder" $SANDBOX/calls.log && grep -q "^lsregister -kill -r -domain local -domain system -domain user" $SANDBOX/calls.log && ! grep -q mdutil $SANDBOX/calls.log && ! grep -q periodic $SANDBOX/calls.log'
check "maintenance --yes : historique m14 à 0 Ko" eval 'grep -q "	m14	0	dns, launch" $HIST'
teardown

if (( $+commands[python3] )); then
  setup; mkcaches
  out=$(python3 -I $PTY $BIN -- 5 't\r' x q)
  check "terminal : touche du menu sans Entrée" eval '[[ $out == *"Caches et fichiers temporaires"* ]]'
  check "terminal : animation de fin sans erreur" eval '[[ $out == *"★ ✦ ⋆"* && $out != *"invalid"* && $out != *"bad "* ]]'
  check "terminal : nettoyage fait" eval 'empty_dir $HOME/Library/Caches'
  check "terminal : retour menu puis q" eval '[[ $out == *"À bientôt."* ]]'
  out=$(python3 -I $PTY $BIN ram -- 'n\r')
  check "terminal : la question RAM accepte une réponse" eval '[[ $out == *"(o/N) › n"* && $out != *"invalid"* ]]'
  teardown
fi

setup
mkdir -p $HOME/docs $SANDBOX/bin
head -c 3200000 /dev/urandom > $HOME/docs/gros-a.bin; cp $HOME/docs/gros-a.bin $HOME/docs/gros-b.bin
head -c 2200000 /dev/urandom > $HOME/docs/lent-a.bin; cp $HOME/docs/lent-a.bin $HOME/docs/lent-b.bin
print -r -- '#!/bin/zsh
[[ $2 == *lent* ]] && sleep 2
exec /sbin/md5 "$@"' > $SANDBOX/bin/md5
chmod +x $SANDBOX/bin/md5
zmodload zsh/datetime
t0=$EPOCHREALTIME
out=$(PATH=$SANDBOX/bin:$PATH $BIN duplicates --list --dir $HOME/docs --min 1 </dev/null | while IFS= read -r l; do print -r -- "$(( EPOCHREALTIME - t0 ))	$l"; done)
first=${${(M)${(f)out}:#*gros-a.bin*}%%$'\t'*}
last=$(( EPOCHREALTIME - t0 ))
check "--list émet ses lignes une à une (sans attendre la fin)" eval '(( first < last - 3 )) && [[ $out == *lent-b.bin* ]]'
check "--list annonce les étapes (STEP)" eval '[[ $out == *"STEP	size"*"STEP	hash"* ]]'
teardown

setup
out=$($BIN system --list </dev/null)
check "system --list : swap, conteneur et libre en TSV" eval '[[ $(col "$out" "	swap	" 5) == swap && $(col "$out" "	free	" 5) == free && $out == *"	container	"* && ! -e $HIST ]]'
mkapp ZzListApp com.test.zzlist
mkdir -p "$HOME/Library/Application Support/ZzListApp"; print x > "$HOME/Library/Application Support/ZzListApp/data"
out=$($BIN uninstall "$HOME/Applications/ZzListApp.app" --list </dev/null)
check "uninstall <app> --list : app et fichiers liés, rien déplacé" eval 'tsv_ok "$out" && [[ $(col "$out" ZzListApp.app 5) == app && $(col "$out" "Application Support" 5) == dir && -d $HOME/Applications/ZzListApp.app && ! -e $HIST ]]'
FAKE=$SANDBOX/bin; mkdir -p $FAKE
for b in sudo dscacheutil killall mdutil periodic lsregister; do
  print -r -- '#!/bin/zsh
exit 0' > $FAKE/$b
  chmod +x $FAKE/$b
done
out=$(PATH=$FAKE:$PATH MAC_CLEANER_MACHINE=1 MAC_CLEANER_LSREGISTER=$FAKE/lsregister $BIN maintenance --yes --select "1 3" </dev/null)
check "maintenance --yes machine : étapes en cours puis faites" eval '[[ $out == *"STEP	dns	running"*"STEP	dns	done"*"STEP	launch	running"*"STEP	launch	done"* ]]'
out=$($BIN maintenance --yes --select 3 </dev/null)
check "sans MAC_CLEANER_MACHINE : pas de ligne STEP" eval '[[ $out != *STEP* ]]'
teardown

print "\n$pass ok, $fail échec(s)"
(( fail == 0 ))
