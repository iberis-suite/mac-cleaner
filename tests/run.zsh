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

print "\n$pass ok, $fail échec(s)"
(( fail == 0 ))
