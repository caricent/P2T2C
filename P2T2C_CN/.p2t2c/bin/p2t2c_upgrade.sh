#!/usr/bin/env bash
set -eo pipefail

usage() {
  cat <<'EOF'
Usage:
  .p2t2c/bin/p2t2c_upgrade.sh --dry-run --source PATH
  .p2t2c/bin/p2t2c_upgrade.sh --apply --source PATH
  .p2t2c/bin/p2t2c_upgrade.sh --rollback UPGRADE_DIR

Run from the target project root.
EOF
}

mode=""
source_dir=""
rollback_dir=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      mode="dry-run"
      shift
      ;;
    --apply)
      mode="apply"
      shift
      ;;
    --source)
      source_dir="${2:-}"
      shift 2
      ;;
    --rollback)
      mode="rollback"
      rollback_dir="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: unknown argument: $1" >&2
      usage
      exit 2
      ;;
  esac
done

target_root="$(pwd -P)"

ALL_MANAGED=()
MODE_PATHS=()
MODE_VALUES=()
MODE_DEFAULT=""
SOURCE_SNAPSHOT=""
TRANSACTION_ACTIVE=0
TRANSACTION_COMMITTED=0
TX_CREATED_DIRS=()
upgrade_dir=""

is_project_owned() {
  case "$1" in
    .p2t2c/project_config.yaml|.p2t2c/runs/*|.p2t2c/cache/*|.p2t2c/install/*|.p2t2c/upgrade/*)
      return 0
      ;;
    docs/sot/product/*|docs/sot/data/*|docs/sot/api/*|docs/sot/client/*|docs/sot/server/*|docs/sot/ai/*|docs/sot/testing/*)
      return 0
      ;;
    docs/adr/ADR-*.md|docs/submit_proposals/SP-*.md|docs/change_packs/CPK-*.md|docs/closure/CR-*.md|docs/closure/evidence/EV-*.jsonl|specs/*/*|src/*|tests/*|database/*|package.json)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

die() {
  echo "ERROR: $*" >&2
  exit 2
}

validate_rel_path() {
  local rel="$1" label="${2:-path}"
  case "$rel" in
    ""|/*|../*|*/../*|*/..|.|*//*|*[[:space:]]*)
      die "unsafe $label: $rel"
      ;;
  esac
}

assert_secure_directory() {
  local path="$1" label="$2"
  perl -MFcntl=:mode -e '
    my($path,$label)=@ARGV;die"ERROR: $label path must be physical absolute\n"if$path!~m{^/}||$path=~m{(?:^|/)\.\.(?:/|$)};chdir q(/)or die"ERROR: cannot hold filesystem root\n";
    for my$c(grep{length}split m{/+},$path){my@s=lstat($c);die"ERROR: unsafe $label component: $c\n"if!@s||!S_ISDIR($s[2])||S_ISLNK($s[2]);my$m=$s[2]&07777;die"ERROR: untrusted $label component: $c\n"if$s[4]!=$<&&$s[4]!=0;die"ERROR: writable non-sticky $label component: $c\n"if($m&0022)&&!($s[4]==0&&($m&01000));my($d,$i)=@s[0,1];chdir$c or die"ERROR: cannot enter $label component: $c\n";my@dot=stat(q(.));die"ERROR: $label component changed: $c\n"if$dot[0]!=$d||$dot[1]!=$i}my@f=stat(q(.));my$fm=$f[2]&07777;die"ERROR: $label directory owner mismatch: $path\n"if$f[4]!=$<;die"ERROR: $label directory is group/world writable: $path\n"if$fm&0022;
  ' "$path" "$label"||exit 2
}

assert_root_dir() {
  local root="$1" label="$2"
  assert_secure_directory "$root" "$label root"
}

permission_mode() {
  perl -e '@s=stat($ARGV[0]); @s or die "cannot stat $ARGV[0]: $!\n"; printf "%04o\n", $s[2] & 07777' "$1"
}

assert_secure_leaf() {
  local path="$1" label="$2"
  perl -MFcntl=:mode -e '
    my($path,$label)=@ARGV;my@s=lstat($path);die "ERROR: $label cannot be stated: $path\n" if !@s;
    die "ERROR: $label must be a regular file: $path\n" if !S_ISREG($s[2]);die "ERROR: $label owner mismatch: $path\n" if $s[4]!=$<;
    die "ERROR: $label must have link count 1: $path\n" if $s[3]!=1;my$m=$s[2]&07777;die "ERROR: $label has unsafe mode: $path\n" if $m&07022;
  ' "$path" "$label" || exit 2
}

assert_rel_components() {
  local root="$1" rel="$2" final_mode="$3" label="$4"
  local current next component index
  local -a components=()
  validate_rel_path "$rel" "$label path"
  assert_root_dir "$root" "$label"
  IFS='/' read -r -a components <<< "$rel"
  current="$root"
  for ((index=0; index<${#components[@]}; index++)); do
    component="${components[$index]}"
    next="$current/$component"
    [[ ! -L "$next" ]] || die "$label path component must not be a symlink: $next"
    if [[ ! -e "$next" ]]; then
      [[ "$final_mode" != "regular" ]] || die "$label file is missing: $next"
      return 0
    fi
    if [[ "$index" -lt $((${#components[@]} - 1)) ]]; then
      [[ -d "$next" ]] || die "$label parent component is not a directory: $next"
      assert_secure_directory "$next" "$label parent"
    else
      case "$final_mode" in
        regular|optional_regular)
          [[ -f "$next" ]] || die "$label final path is not a regular file: $next"
          assert_secure_leaf "$next" "$label"
          ;;
      esac
    fi
    current="$next"
  done
}

safe_mkdir_rel() {
  local root="$1" rel="$2" label="$3"
  local created created_output
  [[ "$rel" == "." || -z "$rel" ]] && return 0
  validate_rel_path "$rel" "$label directory"
  created_output="$(perl -MFcntl=:mode -e '
    my($root,$rel,$label)=@ARGV;chdir q(/)or die"ERROR: cannot hold filesystem root\n";for my$c(grep{length}split m{/+},$root){my@s=lstat($c);die"ERROR: unsafe $label root component\n"if!@s||!S_ISDIR($s[2])||S_ISLNK($s[2]);my$m=$s[2]&07777;die"ERROR: untrusted root component\n"if$s[4]!=$<&&$s[4]!=0;die"ERROR: writable root component\n"if($m&0022)&&!($s[4]==0&&($m&01000));my($d,$i)=@s[0,1];chdir$c or die"ERROR: cannot enter root component\n";my@dot=stat(q(.));die"ERROR: root component changed\n"if$dot[0]!=$d||$dot[1]!=$i}my$built=q();for my$c(split m{/},$rel){$built=length($built)?"$built/$c":$c;my@s=lstat($c);if(!@s){mkdir($c,0755)or die"ERROR: cannot create $label directory\n";@s=lstat($c);print"$built\n"}my$m=$s[2]&07777;die"ERROR: unsafe $label directory component\n"if!S_ISDIR($s[2])||S_ISLNK($s[2])||$s[4]!=$<||($m&0022);my($d,$i)=@s[0,1];chdir$c or die"ERROR: cannot enter $label directory\n";my@dot=stat(q(.));die"ERROR: $label directory changed\n"if$dot[0]!=$d||$dot[1]!=$i}
  ' "$root" "$rel" "$label")"||exit 2
  while IFS= read -r created; do [[ -n "$created" && "$TRANSACTION_ACTIVE" -eq 1 && "$root" == "$target_root" && "$rel" != .p2t2c/upgrade* ]] && TX_CREATED_DIRS+=("$created"); done <<< "$created_output"
  return 0
}

snapshot_leaf() {
  local root="$1" rel="$2"
  perl -MDigest::SHA -MFcntl=O_RDONLY,O_NOFOLLOW,:mode -MFile::Basename=dirname,basename -e '
    my($root,$rel)=@ARGV;my$parent=dirname($rel);my$base=basename($rel);my$dir="$root/$parent";chdir q(/)or die"ERROR: cannot hold filesystem root\n";for my$c(grep{length}split m{/+},$dir){my@h=lstat($c);die"ERROR: unsafe source parent component: $rel\n"if!@h||!S_ISDIR($h[2])||S_ISLNK($h[2]);my$hm=$h[2]&07777;die"ERROR: untrusted source parent component: $rel\n"if$h[4]!=$<&&$h[4]!=0;die"ERROR: writable source ancestor: $rel\n"if($hm&0022)&&!($h[4]==0&&($hm&01000));my($d,$i)=@h[0,1];chdir$c or die"ERROR: cannot enter source parent component: $rel\n";my@dot=stat(q(.));die"ERROR: source parent component changed: $rel\n"if$dot[0]!=$d||$dot[1]!=$i}my@p=stat(q(.));my$pm=$p[2]&07777;die"ERROR: unsafe held source parent: $rel\n"if$p[4]!=$<||($pm&0022);
    sysopen(my$fh,$base,O_RDONLY|O_NOFOLLOW)or die "ERROR: cannot open source leaf safely: $rel\n";binmode$fh;my@s=stat($fh);die "ERROR: source leaf is not regular: $rel\n" if !S_ISREG($s[2]);
    die "ERROR: source leaf owner mismatch: $rel\n" if $s[4]!=$<;die "ERROR: source leaf hardlink rejected: $rel\n" if $s[3]!=1;my$m=$s[2]&07777;die "ERROR: source leaf unsafe mode: $rel\n" if $m&07022;
    my$sha=Digest::SHA->new(256);$sha->addfile($fh);my$d=$sha->hexdigest;my@after=stat(".");die "ERROR: source parent identity changed: $rel\n" if $p[0]!=$after[0]||$p[1]!=$after[1];
    print join("\t",$rel,$p[0],$p[1],$s[0],$s[1],$s[4],$s[3],sprintf("%04o",$m),$d),"\n";
  ' "$root" "$rel"
}

freeze_source_files() {
  local rel line digest expected mode_value
  SOURCE_SNAPSHOT="$(mktemp "${TMPDIR:-/tmp}/p2t2c-source-snapshot.XXXXXX")" || die "cannot create source snapshot";chmod 600 "$SOURCE_SNAPSHOT";: > "$SOURCE_SNAPSHOT"
  for rel in "${ALL_MANAGED[@]}"; do
    line="$(snapshot_leaf "$source_root" "$rel")"||exit 2;digest="${line##*$'\t'}"
    if [[ "$rel" != ".p2t2c/CHECKSUMS.sha256" ]]; then expected="$(awk -v path="$rel" '$2==path {print $1}' "$source_root/.p2t2c/CHECKSUMS.sha256")"; [[ -n "$expected" && "$digest" == "$expected" ]] || die "source changed after checksum validation: $rel"; fi
    mode_value="$(printf '%s\n' "$line" | awk -F '\t' '{print $8}')"; [[ "$mode_value" == "$(expected_mode "$rel")" ]] || die "source mode changed before freeze: $rel"; printf '%s\n' "$line" >> "$SOURCE_SNAPSHOT"
  done
}

snapshot_line_for() {
  local source_base="$1" rel="$2" line
  if [[ -n "$SOURCE_SNAPSHOT" && "$source_base" == "$source_root" ]]; then line="$(awk -F '\t' -v path="$rel" '$1==path {print;exit}' "$SOURCE_SNAPSHOT")"; [[ -n "$line" ]] || die "source snapshot omits: $rel"; printf '%s\n' "$line"; else snapshot_leaf "$source_base" "$rel"; fi
}

test_pause() {
  local phase="$1" rel="$2" wanted="" ms="${P2T2C_TEST_PAUSE_MS:-}"
  case "$phase" in before_dest_identity)wanted="${P2T2C_TEST_PAUSE_BEFORE_DEST_IDENTITY_REL:-}";;after_source_snapshot)wanted="${P2T2C_TEST_PAUSE_AFTER_SOURCE_SNAPSHOT_REL:-}";;*)die "invalid internal test pause phase";;esac
  [[ -n "$wanted" ]] || return 0; validate_rel_path "$wanted" "test pause relative path"; [[ "$ms" =~ ^[1-9][0-9]{0,3}$ && "$ms" -le 5000 ]] || die "P2T2C_TEST_PAUSE_MS must be 1..5000"; [[ "$wanted" == "$rel" ]] || return 0
  printf 'P2T2C_TEST_MARKER:%s\n' "$phase">&2;perl -e 'select undef,undef,undef,$ARGV[0]/1000' "$ms"
}

directory_identity() {
  local path="$1" label="$2"
  perl -MFcntl=:mode -e 'my($p,$l)=@ARGV;chdir q(/)or die"ERROR: cannot hold filesystem root\n";for my$c(grep{length}split m{/+},$p){my@s=lstat($c);die"ERROR: unsafe $l component\n"if!@s||!S_ISDIR($s[2])||S_ISLNK($s[2]);my$m=$s[2]&07777;die"ERROR: untrusted $l component\n"if$s[4]!=$<&&$s[4]!=0;die"ERROR: writable $l ancestor\n"if($m&0022)&&!($s[4]==0&&($m&01000));my($d,$i)=@s[0,1];chdir$c or die"ERROR: cannot enter $l component\n";my@dot=stat(q(.));die"ERROR: $l component changed\n"if$dot[0]!=$d||$dot[1]!=$i}my@s=stat(q(.));my$m=$s[2]&07777;die"ERROR: unsafe held $l directory\n"if$s[4]!=$<||($m&0022);print"$s[0]\t$s[1]\n"' "$path" "$label"||exit 2
}

atomic_copy_rel() {
  local source_base="$1" source_rel="$2" destination_base="$3" destination_rel="$4" label="$5" destination_parent snapshot destination_identity
  validate_rel_path "$source_rel" "$label source path";validate_rel_path "$destination_rel" "$label destination path"
  destination_parent="$(dirname "$destination_rel")";safe_mkdir_rel "$destination_base" "$destination_parent" "$label";snapshot="$(snapshot_line_for "$source_base" "$source_rel")"||exit 2;test_pause after_source_snapshot "$source_rel";test_pause before_dest_identity "$destination_rel";destination_identity="$(directory_identity "$destination_base/$destination_parent" "$label destination parent")"||exit 2
  perl -MDigest::SHA=sha256_hex -MFcntl=O_RDONLY,O_WRONLY,O_CREAT,O_EXCL,O_NOFOLLOW,:mode -MFile::Basename=dirname,basename -e '
    my($sr,$sl,$dr,$dl,$snap,$di,$label)=@ARGV;my@e=split/\t/,$snap,-1;my@de=split/\t/,$di,-1;die"ERROR: malformed source snapshot\n"if@e!=9||$e[0]ne$sl;
    sub held{my($path,$kind)=@_;chdir q(/)or die"ERROR: cannot hold filesystem root\n";for my$c(grep{length}split m{/+},$path){my@s=lstat($c);die"ERROR: unsafe $kind parent component\n"if!@s||!S_ISDIR($s[2])||S_ISLNK($s[2]);my$m=$s[2]&07777;die"ERROR: untrusted $kind parent component\n"if$s[4]!=$<&&$s[4]!=0;die"ERROR: writable $kind ancestor\n"if($m&0022)&&!($s[4]==0&&($m&01000));my($d,$i)=@s[0,1];chdir$c or die"ERROR: cannot enter $kind parent component\n";my@dot=stat(q(.));die"ERROR: $kind parent component changed\n"if$dot[0]!=$d||$dot[1]!=$i}my@f=stat(q(.));my$fm=$f[2]&07777;die"ERROR: unsafe held $kind parent\n"if$f[4]!=$<||($fm&0022);return@f}
    my($sp,$sb)=(dirname($sl),basename($sl));my@p=held("$sr/$sp",q(source));die"ERROR: frozen source parent changed: $sl\n"if$p[0]!=$e[1]||$p[1]!=$e[2];
    sysopen(my$sf,$sb,O_RDONLY|O_NOFOLLOW)or die"ERROR: source O_NOFOLLOW open failed: $sl\n";binmode$sf;my@s=stat($sf);my$m=$s[2]&07777;die"ERROR: frozen source leaf changed: $sl\n"if!S_ISREG($s[2])||$s[0]!=$e[3]||$s[1]!=$e[4]||$s[4]!=$e[5]||$s[3]!=$e[6]||sprintf("%04o",$m)ne$e[7]||$s[4]!=$<||$s[3]!=1||($m&07022);
    local$/;my$b=<$sf>//"";close$sf;die"ERROR: frozen source digest changed: $sl\n"if sha256_hex($b)ne$e[8];my@p2=stat(".");die"ERROR: source parent changed during read: $sl\n"if$p[0]!=$p2[0]||$p[1]!=$p2[1];
    my($dp,$db)=(dirname($dl),basename($dl));my@dparent=held("$dr/$dp",q(destination));die"ERROR: frozen destination parent changed\n"if@de!=2||$dparent[0]!=$de[0]||$dparent[1]!=$de[1];
    if(lstat($db)){my@d=lstat($db);my$dm=$d[2]&07777;die"ERROR: unsafe existing destination: $dl\n"if!S_ISREG($d[2])||S_ISLNK($d[2])||$d[4]!=$<||$d[3]!=1||($dm&07022)}
    my$tmp=".p2t2c-copy-$$-".int(rand(1_000_000));sysopen(my$df,$tmp,O_WRONLY|O_CREAT|O_EXCL|O_NOFOLLOW,0600)or die"ERROR: cannot create destination temporary\n";binmode$df;print{$df}$b or do{unlink$tmp;die"ERROR: cannot write destination temporary\n"};close$df or do{unlink$tmp;die"ERROR: cannot close destination temporary\n"};chmod$m,$tmp or do{unlink$tmp;die"ERROR: cannot preserve destination mode\n"};my@temp=lstat($tmp);die"ERROR: unsafe destination temporary identity\n"if!@temp||!S_ISREG($temp[2])||$temp[4]!=$<||$temp[3]!=1||(($temp[2]&07777)!=$m);my$temp_digest=sha256_hex($b);my@dc=stat(".");die"ERROR: destination parent identity changed\n"if$dparent[0]!=$dc[0]||$dparent[1]!=$dc[1];rename$tmp,$db or do{unlink$tmp;die"ERROR: cannot atomically publish destination\n"};my$pause=$ENV{P2T2C_TEST_PAUSE_AFTER_RENAME_REL}//q();my$fail=$ENV{P2T2C_TEST_FAIL_AFTER_RENAME_REL}//q();for my$v($pause,$fail){die"ERROR: unsafe after-rename test path\n"if length($v)&&($v=~m{^/|(?:^|/)\.\.(?:/|$)|//|\s})}if($pause eq$dl){my$ms=$ENV{P2T2C_TEST_PAUSE_MS}//q();die"ERROR: P2T2C_TEST_PAUSE_MS must be 1..5000\n"if$ms!~/\A[1-9][0-9]{0,3}\z/||$ms>5000;print STDERR"P2T2C_TEST_MARKER:after_rename\n";select undef,undef,undef,$ms/1000}die"ERROR: controlled after-rename failure\n"if$fail eq$dl;my@f=lstat($db);die"ERROR: unsafe published destination\n"if!@f||!S_ISREG($f[2])||$f[4]!=$<||$f[3]!=1||(($f[2]&07777)!=$m)||$f[0]!=$temp[0]||$f[1]!=$temp[1];sysopen(my$vf,$db,O_RDONLY|O_NOFOLLOW)or die"ERROR: cannot verify published destination\n";binmode$vf;my@vs=stat($vf);local$/;my$visible=<$vf>//q();close$vf;die"ERROR: published destination identity or digest changed\n"if$vs[0]!=$temp[0]||$vs[1]!=$temp[1]||sha256_hex($visible)ne$temp_digest;
  ' "$source_base" "$source_rel" "$destination_base" "$destination_rel" "$snapshot" "$destination_identity" "$label"||exit 2
}

atomic_write_rel() {
  local root="$1" rel="$2" label="$3"
  local parent identity
  validate_rel_path "$rel" "$label path"
  parent="$(dirname "$rel")"
  safe_mkdir_rel "$root" "$parent" "$label"
  identity="$(directory_identity "$root/$parent" "$label parent")"||exit 2
  perl -MFcntl=O_WRONLY,O_CREAT,O_EXCL,O_NOFOLLOW,:mode -MFile::Basename=dirname,basename -e '
    my($r,$rel,$id,$label)=@ARGV;my@e=split/\t/,$id,-1;my($p,$b)=(dirname($rel),basename($rel));chdir q(/)or die"ERROR: cannot hold filesystem root\n";for my$c(grep{length}split m{/+},"$r/$p"){my@h=lstat($c);die"ERROR: unsafe write parent component\n"if!@h||!S_ISDIR($h[2])||S_ISLNK($h[2]);my$m=$h[2]&07777;die"ERROR: untrusted write parent component\n"if$h[4]!=$<&&$h[4]!=0;die"ERROR: writable write ancestor\n"if($m&0022)&&!($h[4]==0&&($m&01000));my($d,$i)=@h[0,1];chdir$c or die"ERROR: cannot enter write parent component\n";my@dot=stat(q(.));die"ERROR: write parent component changed\n"if$dot[0]!=$d||$dot[1]!=$i}my@s=stat(q(.));my$sm=$s[2]&07777;die"ERROR: unsafe held write parent\n"if$s[4]!=$<||($sm&0022);die"ERROR: frozen write parent changed\n"if@e!=2||$s[0]!=$e[0]||$s[1]!=$e[1];if(lstat($b)){my@d=lstat($b);my$m=$d[2]&07777;die"ERROR: unsafe existing write target\n"if!S_ISREG($d[2])||S_ISLNK($d[2])||$d[4]!=$<||$d[3]!=1||($m&07022)}my$tmp=".p2t2c-write-$$-".int(rand(1_000_000));sysopen(my$f,$tmp,O_WRONLY|O_CREAT|O_EXCL|O_NOFOLLOW,0600)or die"ERROR: cannot create write temporary\n";binmode STDIN;binmode$f;my$buf;while(read(STDIN,$buf,65536)){print{$f}$buf or do{unlink$tmp;die"ERROR: cannot write temporary\n"}}close$f or do{unlink$tmp;die"ERROR: cannot close temporary\n"};my@a=stat(".");die"ERROR: write parent changed during transaction\n"if$s[0]!=$a[0]||$s[1]!=$a[1];rename$tmp,$b or do{unlink$tmp;die"ERROR: cannot publish write target\n"};
  ' "$root" "$rel" "$identity" "$label"||exit 2
}

safe_remove_rel() {
  local root="$1" rel="$2" label="$3"
  validate_rel_path "$rel" "$label path"
  perl -MFcntl=:mode -MFile::Basename=dirname,basename -e '
    my($root,$rel,$label)=@ARGV;my($parent,$leaf)=(dirname($rel),basename($rel));chdir q(/)or die"ERROR: cannot hold filesystem root\n";for my$c(grep{length}split m{/+},"$root/$parent"){my@s=lstat($c);die"ERROR: unsafe remove parent component\n"if!@s||!S_ISDIR($s[2])||S_ISLNK($s[2]);my$m=$s[2]&07777;die"ERROR: untrusted remove parent component\n"if$s[4]!=$<&&$s[4]!=0;die"ERROR: writable remove ancestor\n"if($m&0022)&&!($s[4]==0&&($m&01000));my($d,$i)=@s[0,1];chdir$c or die"ERROR: cannot enter remove parent\n";my@dot=stat(q(.));die"ERROR: remove parent changed\n"if$dot[0]!=$d||$dot[1]!=$i}my@s=lstat($leaf);exit 0 if!@s;my$m=$s[2]&07777;die"ERROR: unsafe remove leaf\n"if!S_ISREG($s[2])||S_ISLNK($s[2])||$s[4]!=$<||$s[3]!=1||($m&07022);unlink($leaf)or die"ERROR: cannot remove $label\n";
  ' "$root" "$rel" "$label"||exit 2
}

resolve_rollback_dir() {
  local requested="$1" candidate requested_parent physical_parent name parent="$target_root/.p2t2c/upgrade"
  case "$requested" in
    /*) candidate="${requested%/}" ;;
    *) candidate="$target_root/${requested%/}" ;;
  esac
  name="$(basename "$candidate")"
  [[ -n "$name" && "$name" != */* && "$name" != "." && "$name" != ".." ]] || die "unsafe rollback directory: $requested"
  assert_rel_components "$target_root" ".p2t2c/upgrade" optional_directory "rollback parent"
  [[ -d "$parent" && ! -L "$parent" ]] || die "rollback parent directory not found: $parent"
  requested_parent="$(dirname "$candidate")"
  [[ -d "$requested_parent" && ! -L "$requested_parent" ]] || die "rollback parent is unsafe: $requested_parent"
  physical_parent="$(cd "$requested_parent" && pwd -P)"
  [[ "$physical_parent" == "$parent" ]] || die "rollback directory must be a direct child of $parent: $requested"
  [[ ! -L "$candidate" ]] || die "rollback directory must not be a symlink: $candidate"
  assert_rel_components "$target_root" ".p2t2c/upgrade/$name" optional_directory "rollback"
  [[ -d "$parent/$name" && ! -L "$parent/$name" ]] || die "rollback directory not found: $requested"
  rollback_dir="$parent/$name"
}

managed_contains() {
  local wanted="$1" rel
  for rel in "${ALL_MANAGED[@]}"; do
    [[ "$rel" == "$wanted" ]] && return 0
  done
  return 1
}

append_managed_path() {
  local manifest="$1" rel="$2" existing
  validate_rel_path "$rel" "managed path in $manifest"
  case "$rel" in
    .p2t2c/lock.sha256|.p2t2c/project_config.yaml)
      echo "ERROR: runtime or project-owned path cannot be release-managed: $rel" >&2
      exit 2
      ;;
  esac
  if is_project_owned "$rel"; then
    echo "ERROR: project-owned path cannot be release-managed: $rel" >&2
    exit 2
  fi
  for existing in "${ALL_MANAGED[@]}"; do
    if [[ "$existing" == "$rel" ]]; then
      echo "ERROR: duplicate managed path in $manifest: $rel" >&2
      exit 2
    fi
  done
  ALL_MANAGED+=("$rel")
}

load_managed_files() {
  local root="$1" manifest_rel="$2" manifest line rel
  ALL_MANAGED=()
  assert_rel_components "$root" "$manifest_rel" regular "managed-file manifest"
  manifest="$root/$manifest_rel"

  while IFS= read -r line || [[ -n "$line" ]]; do
    rel="${line#"${line%%[![:space:]]*}"}"
    rel="${rel%"${rel##*[![:space:]]}"}"
    [[ -z "$rel" || "${rel:0:1}" == "#" ]] && continue
    append_managed_path "$manifest" "$rel"
  done < "$manifest"

  for rel in \
    ".p2t2c/managed-files.txt" \
    ".p2t2c/managed-modes.txt" \
    ".p2t2c/CHECKSUMS.sha256" \
    ".p2t2c/defaults.yaml" \
    ".p2t2c/bin/check_p2t2c.pl" \
    ".p2t2c/bin/check_p2t2c.sh" \
    ".p2t2c/bin/p2t2c" \
    ".p2t2c/bin/p2t2c_close.pl" \
    ".p2t2c/bin/p2t2c_close.sh" \
    ".p2t2c/bin/p2t2c_context.pl" \
    ".p2t2c/bin/p2t2c_evidence.pl" \
    ".p2t2c/bin/p2t2c_install.sh" \
    ".p2t2c/bin/p2t2c_run.sh" \
    ".p2t2c/bin/p2t2c_upgrade.sh" \
    ".p2t2c/bin/p2t2c_verify.pl" \
    ".p2t2c/lib/P2T2C/Checker.pm" \
    ".p2t2c/schemas/closure-receipt-v2.schema.json" \
    ".p2t2c/schemas/context-capsule-v1.schema.json" \
    ".p2t2c/schemas/evidence-summary-v1.schema.json" \
    ".p2t2c/schemas/work-status-v1.schema.json" \
    ".p2t2c/skills/admit-route/SKILL.md" \
    ".p2t2c/skills/execute/SKILL.md" \
    ".p2t2c/skills/verify-close/SKILL.md" \
    "docs/closure/evidence/README.md"
  do
    if ! managed_contains "$rel"; then
      echo "ERROR: managed-file manifest omits required release asset: $rel" >&2
      exit 2
    fi
  done
}

load_managed_modes() {
  local policy="$source_root/.p2t2c/managed-modes.txt" line mode rel existing
  assert_rel_components "$source_root" ".p2t2c/managed-modes.txt" regular "managed-mode policy"
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line#"${line%%[![:space:]]*}"}"; line="${line%"${line##*[![:space:]]}"}"
    [[ -z "$line" || "${line:0:1}" == "#" ]] && continue
    mode="${line%%[[:space:]]*}"; rel="${line#"$mode"}"; rel="${rel#"${rel%%[![:space:]]*}"}"
    if [[ "$mode" == "default" ]]; then
      [[ -z "$MODE_DEFAULT" && "$rel" == "0644" ]] || die "default managed mode must be exactly 0644"
      MODE_DEFAULT="$rel"; continue
    fi
    [[ "$mode" == "0755" ]] || die "explicit managed mode must be exactly 0755: $mode"
    validate_rel_path "$rel" "managed-mode path"; managed_contains "$rel" || die "managed-mode path is not release-managed: $rel"
    for existing in "${MODE_PATHS[@]}"; do [[ "$existing" != "$rel" ]] || die "duplicate managed-mode path: $rel"; done
    MODE_PATHS+=("$rel"); MODE_VALUES+=("$mode")
  done < "$policy"
  [[ "$MODE_DEFAULT" =~ ^0[0-7]{3}$ ]] || die "managed-mode policy omits default mode"
}

expected_mode() {
  local wanted="$1" index
  for ((index=0; index<${#MODE_PATHS[@]}; index++)); do
    [[ "${MODE_PATHS[$index]}" == "$wanted" ]] && { printf '%s\n' "${MODE_VALUES[$index]}"; return; }
  done
  printf '%s\n' "$MODE_DEFAULT"
}

validate_source_checksums() {
  local checksum_file="$source_root/.p2t2c/CHECKSUMS.sha256" rel expected actual
  assert_rel_components "$source_root" ".p2t2c/CHECKSUMS.sha256" regular "source checksum inventory"
  for rel in "${ALL_MANAGED[@]}"; do
    assert_rel_components "$source_root" "$rel" regular "managed source"
  done
  if ! diff -u \
    <(for rel in "${ALL_MANAGED[@]}"; do [[ "$rel" == ".p2t2c/CHECKSUMS.sha256" ]] || printf '%s\n' "$rel"; done) \
    <(awk 'NF >= 2 { print $2 }' "$checksum_file") >&2
  then
    echo "ERROR: source checksum inventory does not match .p2t2c/managed-files.txt" >&2
    exit 2
  fi
  if ! (cd "$source_root" && shasum -a 256 -c .p2t2c/CHECKSUMS.sha256 >/dev/null); then
    echo "ERROR: source checksum verification failed" >&2
    exit 2
  fi
  for rel in "${ALL_MANAGED[@]}"; do
    expected="$(expected_mode "$rel")"; actual="$(permission_mode "$source_root/$rel")"
    [[ "$actual" == "$expected" ]] || die "managed source mode mismatch: $rel expected=$expected actual=$actual"
  done
  freeze_source_files
}

load_managed_from_lock() {
  local root="$1" lock_rel="$2" lock_file hash rel
  ALL_MANAGED=()
  assert_rel_components "$root" "$lock_rel" regular "managed lock"
  lock_file="$root/$lock_rel"
  while read -r hash rel; do
    [[ -n "$rel" ]] || continue
    append_managed_path "$lock_file" "$rel"
  done < "$lock_file"
}

sha256_file() {
  shasum -a 256 "$1" | awk '{print $1}'
}

lock_hash_for() {
  local rel="$1"
  local lock_file="$target_root/.p2t2c/lock.sha256"
  if [[ ! -f "$lock_file" ]]; then
    return 1
  fi
  awk -v path="$rel" '$2 == path {print $1}' "$lock_file" | tail -n 1
}

version_from() {
  local root="$1"
  if [[ -f "$root/.p2t2c/VERSION" ]]; then
    tr -d '[:space:]' < "$root/.p2t2c/VERSION"
  elif [[ -f "$root/P2T2C_TEMPLATE_VERSION" ]]; then
    tr -d '[:space:]' < "$root/P2T2C_TEMPLATE_VERSION"
  else
    echo "unknown"
  fi
}

obsolete_list() {
  local migration="$1"
  [[ -f "$migration" ]] || return 0
  awk '
    /BEGIN_OBSOLETE_MANAGED/ { in_list=1; next }
    /END_OBSOLETE_MANAGED/ { in_list=0; next }
    in_list && $0 !~ /^```/ && $0 !~ /^$/ { print }
  ' "$migration"
}

print_list() {
  local title="$1"
  shift
  echo
  echo "$title"
  if [[ $# -eq 0 ]]; then
    echo "- None"
    return
  fi
  local item
  for item in "$@"; do
    echo "- $item"
  done
}

cleanup_empty_legacy_dirs() {
  local dirs=(
    "sdd/templates"
    "sdd"
    "scripts"
    "prompts"
    "templates/adr"
    "templates/change_packs"
    "templates/closure"
    "templates/install"
    "templates/truth"
    "templates/upgrade"
    "templates"
    ".p2t2c/templates/change_packs"
    ".p2t2c/generated"
    ".p2t2c/evals"
    ".p2t2c/schemas"
    ".p2t2c/lib/P2T2C"
    ".p2t2c/lib"
    ".p2t2c/skills/admit-route"
    ".p2t2c/skills/execute"
    ".p2t2c/skills/verify-close"
    "docs/closure/evidence"
    "migrations/p2t2c"
    "migrations"
  )
  local dir
  for dir in "${dirs[@]}"; do
    rmdir "$target_root/$dir" 2>/dev/null || true
  done
}

write_lock() {
  local rel
  {
    for rel in "${ALL_MANAGED[@]}"; do
      assert_rel_components "$target_root" "$rel" optional_regular "lock target"
      if [[ -f "$target_root/$rel" ]]; then
        printf "%s  %s\n" "$(sha256_file "$target_root/$rel")" "$rel"
      fi
    done
  } | atomic_write_rel "$target_root" ".p2t2c/lock.sha256" "target lock"
}

rollback() {
  local dir="$1" file rel
  if [[ -z "$dir" || ! -d "$dir" ]]; then
    echo "ERROR: rollback directory not found: $dir" >&2
    exit 2
  fi

  assert_rel_components "$dir" "updated-files.txt" optional_regular "rollback updated-files inventory"
  assert_rel_components "$dir" "created-files.txt" optional_regular "rollback created-files inventory"
  assert_rel_components "$dir" "removed-files.txt" optional_regular "rollback removed-files inventory"

  if [[ -d "$dir/backup" ]]; then
    if find "$dir/backup" -type l -print -quit | grep -q .; then
      die "rollback backup contains a symlink: $dir/backup"
    fi
    while IFS= read -r file; do
      rel="${file#"$dir/backup/"}"
      validate_rel_path "$rel" "rollback backup path"
      if [[ "$rel" != ".p2t2c/lock.sha256" ]] && ! managed_contains "$rel" \
        && ! { [[ -f "$dir/updated-files.txt" ]] && grep -Fqx "$rel" "$dir/updated-files.txt"; } \
        && ! { [[ -f "$dir/removed-files.txt" ]] && grep -Fqx "$rel" "$dir/removed-files.txt"; }
      then
        die "rollback backup contains an unmanaged path: $rel"
      fi
      is_project_owned "$rel" && die "rollback backup contains a project-owned path: $rel"
      atomic_copy_rel "$dir/backup" "$rel" "$target_root" "$rel" "rollback restore"
      echo "restored: $rel"
    done < <(find "$dir/backup" -type f | LC_ALL=C sort)
  fi

  if [[ -f "$dir/created-files.txt" ]]; then
    while IFS= read -r rel; do
      [[ -z "$rel" ]] && continue
      validate_rel_path "$rel" "rollback created path"
      managed_contains "$rel" || die "rollback created-files inventory contains unmanaged path: $rel"
      is_project_owned "$rel" && die "rollback created-files inventory contains project-owned path: $rel"
      if [[ -e "$target_root/$rel" || -L "$target_root/$rel" ]]; then
        safe_remove_rel "$target_root" "$rel" "rollback created file"
        echo "removed created file: $rel"
      fi
    done < "$dir/created-files.txt"
  fi

  if [[ -f "$target_root/.p2t2c/manifest.yaml" && ! -f "$dir/backup/.p2t2c/lock.sha256" ]]; then
    write_lock
  fi
  cleanup_empty_legacy_dirs
}

assert_root_dir "$target_root" "target"

if [[ "$mode" == "rollback" ]]; then
  resolve_rollback_dir "$rollback_dir"
  assert_rel_components "$target_root" ".p2t2c/managed-files.txt" optional_regular "rollback managed manifest"
  assert_rel_components "$rollback_dir" "backup/.p2t2c/managed-files.txt" optional_regular "rollback backup manifest"
  assert_rel_components "$target_root" ".p2t2c/lock.sha256" optional_regular "rollback target lock"
  if [[ -f "$target_root/.p2t2c/managed-files.txt" ]]; then
    load_managed_files "$target_root" ".p2t2c/managed-files.txt"
  elif [[ -f "$rollback_dir/backup/.p2t2c/managed-files.txt" ]]; then
    load_managed_files "$rollback_dir/backup" ".p2t2c/managed-files.txt"
  else
    load_managed_from_lock "$target_root" ".p2t2c/lock.sha256"
  fi
  rollback "$rollback_dir"
  exit 0
fi

if [[ "$mode" != "dry-run" && "$mode" != "apply" ]]; then
  echo "ERROR: choose --dry-run, --apply, or --rollback" >&2
  usage
  exit 2
fi

if [[ -z "$source_dir" ]]; then
  echo "ERROR: --source PATH is required" >&2
  usage
  exit 2
fi

if [[ ! -d "$source_dir" ]]; then
  echo "ERROR: source directory not found: $source_dir" >&2
  exit 2
fi

source_root="$(cd "$source_dir" && pwd -P)"
assert_root_dir "$source_root" "source"
load_managed_files "$source_root" ".p2t2c/managed-files.txt"
load_managed_modes
validate_source_checksums

cleanup_target_dirs() {
  local index dir
  for ((index=${#TX_CREATED_DIRS[@]}-1; index>=0; index--)); do
    dir="${TX_CREATED_DIRS[$index]}"; [[ -d "$target_root/$dir" && ! -L "$target_root/$dir" ]] && rmdir "$target_root/$dir" 2>/dev/null || true
  done
}

upgrade_exit_trap() {
  local status=$?
  if [[ "$TRANSACTION_ACTIVE" -eq 1 && "$TRANSACTION_COMMITTED" -eq 0 ]]; then
    TRANSACTION_ACTIVE=0; set +e
    if [[ -n "$upgrade_dir" && -d "$upgrade_dir" && -f "$upgrade_dir/updated-files.txt" && -f "$upgrade_dir/created-files.txt" && -f "$upgrade_dir/removed-files.txt" ]]; then rollback "$upgrade_dir"; fi
    cleanup_target_dirs; set -e
  fi
  [[ -z "$SOURCE_SNAPSHOT" || ! -e "$SOURCE_SNAPSHOT" ]] || rm -f "$SOURCE_SNAPSHOT"
  return "$status"
}

trap upgrade_exit_trap EXIT
trap 'exit $?' ERR
trap 'exit 130' INT
trap 'exit 143' TERM
for rel in "${ALL_MANAGED[@]}"; do
  assert_rel_components "$target_root" "$rel" optional_regular "managed target"
done
assert_rel_components "$target_root" ".p2t2c/lock.sha256" optional_regular "target lock"
assert_rel_components "$target_root" ".p2t2c/project_config.yaml" optional_regular "project configuration"
target_version="$(version_from "$target_root")"
source_version="$(version_from "$source_root")"
legacy=0

if [[ ! -f "$target_root/.p2t2c/manifest.yaml" || ! -f "$target_root/.p2t2c/lock.sha256" ]]; then
  legacy=1
fi

updates=()
creates=()
removes=()
unchanged=()
skipped=()
conflicts=()
missing_source=()

for rel in "${ALL_MANAGED[@]}"; do
  if is_project_owned "$rel"; then
    skipped+=("$rel (project-owned denylist)")
    continue
  fi

  if [[ ! -f "$source_root/$rel" ]]; then
    missing_source+=("$rel")
    continue
  fi

  if [[ ! -f "$target_root/$rel" ]]; then
    creates+=("$rel")
    continue
  fi

  source_hash="$(sha256_file "$source_root/$rel")"
  target_hash="$(sha256_file "$target_root/$rel")"
  if [[ "$source_hash" == "$target_hash" ]]; then
    if [[ "$(permission_mode "$target_root/$rel")" == "$(expected_mode "$rel")" ]]; then unchanged+=("$rel"); else updates+=("$rel"); fi
    continue
  fi

  locked_hash="$(lock_hash_for "$rel" || true)"
  if [[ -n "$locked_hash" && "$target_hash" == "$locked_hash" ]]; then
    updates+=("$rel")
  elif [[ "$rel" == ".p2t2c/CHECKSUMS.sha256" && -z "$locked_hash" ]]; then
    updates+=("$rel")
  else
    conflicts+=("$rel")
  fi
done

for managed_rel in "${ALL_MANAGED[@]}"; do
  case "$managed_rel" in
    .p2t2c/migrations/*-to-*.md)
      migration="$source_root/$managed_rel"
      ;;
    *)
      continue
      ;;
  esac
  while IFS= read -r rel; do
    [[ -z "$rel" ]] && continue
    validate_rel_path "$rel" "obsolete managed path"
    if is_project_owned "$rel"; then
      skipped+=("$rel (project-owned obsolete denylist)")
      continue
    fi
    assert_rel_components "$target_root" "$rel" optional_regular "obsolete target"
    if [[ ! -f "$target_root/$rel" ]]; then
      continue
    fi
    target_hash="$(sha256_file "$target_root/$rel")"
    locked_hash="$(lock_hash_for "$rel" || true)"
    if [[ -n "$locked_hash" && "$target_hash" == "$locked_hash" ]]; then
      removes+=("$rel")
    elif [[ "$rel" == ".p2t2c/generated/phase_rules.txt" ]] \
      && grep -q "Auto-generated by check_p2t2c.sh (RULE-GOV-012)" "$target_root/$rel"
    then
      removes+=("$rel")
    elif [[ -n "$locked_hash" ]]; then
      conflicts+=("$rel (obsolete modified)")
    else
      skipped+=("$rel (unlocked obsolete path)")
    fi
  done < <(obsolete_list "$migration")
done

generated_phase_map=".p2t2c/generated/phase_rules.txt"
if [[ -f "$target_root/$generated_phase_map" ]] && [[ ! " ${removes[*]} " =~ " $generated_phase_map " ]]; then
  target_hash="$(sha256_file "$target_root/$generated_phase_map")"
  locked_hash="$(lock_hash_for "$generated_phase_map" || true)"
  if [[ -n "$locked_hash" && "$target_hash" == "$locked_hash" ]] \
    || grep -q "Auto-generated by check_p2t2c.sh (RULE-GOV-012)" "$target_root/$generated_phase_map"
  then
    removes+=("$generated_phase_map")
  elif [[ -n "$locked_hash" ]]; then
    conflicts+=("$generated_phase_map (obsolete modified)")
  else
    skipped+=("$generated_phase_map (unlocked obsolete path)")
  fi
fi

echo "P2T2C upgrade $target_version -> $source_version"
echo "Mode: $mode"
echo "Target: $target_root"
echo "Source: $source_root"

if [[ "$legacy" -eq 1 ]]; then
  echo
  echo "Legacy review: missing .p2t2c/manifest.yaml or .p2t2c/lock.sha256."
  echo "This script will not directly overwrite a legacy project. Add P2T2C upgrade metadata first or migrate manually with human review."
fi

print_list "Updated automatically" "${updates[@]}" "${creates[@]}"
print_list "Removed obsolete" "${removes[@]}"
print_list "Skipped protected or unlocked paths" "${skipped[@]}"
print_list "Conflicts" "${conflicts[@]}"
print_list "Missing from source" "${missing_source[@]}"
print_list "Unchanged" "${unchanged[@]}"

if [[ "$mode" == "dry-run" ]]; then
  [[ "${#missing_source[@]}" -eq 0 ]] || exit 1
  exit 0
fi

if [[ "${#missing_source[@]}" -gt 0 ]]; then
  echo
  echo "Apply stopped. The source release is incomplete."
  exit 1
fi

upgrade_id="$(date +%Y%m%d-%H%M%S)"
TRANSACTION_ACTIVE=1
safe_mkdir_rel "$target_root" ".p2t2c/upgrade" "upgrade transaction"
upgrade_dir="$(mktemp -d "$target_root/.p2t2c/upgrade/$upgrade_id.XXXXXX")" || die "cannot create secure upgrade transaction directory"
[[ -d "$upgrade_dir" && ! -L "$upgrade_dir" ]] || die "unsafe upgrade transaction directory: $upgrade_dir"
upgrade_id="$(basename "$upgrade_dir")"
safe_mkdir_rel "$upgrade_dir" "backup" "upgrade backup"
safe_mkdir_rel "$upgrade_dir" "conflicts" "upgrade conflicts"

if [[ "$legacy" -eq 1 ]]; then
  {
    echo "# P2T2C Upgrade Report — $upgrade_id"
    echo
    echo "Status: LEGACY_REVIEW_REQUIRED"
    echo "From: $target_version"
    echo "To: $source_version"
    echo
    echo "The target project is missing P2T2C upgrade metadata. No workflow files were overwritten."
  } | atomic_write_rel "$upgrade_dir" "upgrade-report.md" "legacy upgrade report"
  echo
  echo "Apply stopped. Legacy review report: $upgrade_dir/upgrade-report.md"
  exit 1
fi

if [[ "${#conflicts[@]}" -gt 0 ]]; then
  for item in "${conflicts[@]}"; do
    rel="${item%% (*}"
    validate_rel_path "$rel" "upgrade conflict path"
    assert_rel_components "$target_root" "$rel" optional_regular "local conflict"
    assert_rel_components "$source_root" "$rel" optional_regular "source conflict"
    if [[ -f "$target_root/$rel" ]]; then
      atomic_copy_rel "$target_root" "$rel" "$upgrade_dir" "conflicts/local/$rel" "local conflict copy"
    fi
    if [[ -f "$source_root/$rel" ]]; then
      atomic_copy_rel "$source_root" "$rel" "$upgrade_dir" "conflicts/source/$rel" "source conflict copy"
    fi
  done
  {
    echo "# P2T2C Upgrade Report — $upgrade_id"
    echo
    echo "Status: MANUAL_CONFLICT_RESOLUTION_REQUIRED"
    echo "From: $target_version"
    echo "To: $source_version"
    echo
    echo "## Conflicts"
    for rel in "${conflicts[@]}"; do
      echo "- $rel"
    done
    echo
    echo "No workflow files were updated or removed."
  } | atomic_write_rel "$upgrade_dir" "upgrade-report.md" "conflict upgrade report"
  echo
  echo "Apply stopped. Conflict report: $upgrade_dir/upgrade-report.md"
  exit 1
fi

printf '%s\n' "${updates[@]}" | sed '/^$/d' | atomic_write_rel "$upgrade_dir" "updated-files.txt" "updated-files inventory"
printf '%s\n' "${creates[@]}" | sed '/^$/d' | atomic_write_rel "$upgrade_dir" "created-files.txt" "created-files inventory"
printf '%s\n' "${removes[@]}" | sed '/^$/d' | atomic_write_rel "$upgrade_dir" "removed-files.txt" "removed-files inventory"

atomic_copy_rel "$target_root" ".p2t2c/lock.sha256" "$upgrade_dir" "backup/.p2t2c/lock.sha256" "upgrade lock backup"

for rel in "${updates[@]}" "${creates[@]}"; do
  [[ -z "$rel" ]] && continue
  if [[ -f "$target_root/$rel" ]]; then
    atomic_copy_rel "$target_root" "$rel" "$upgrade_dir" "backup/$rel" "managed upgrade backup"
  fi
  atomic_copy_rel "$source_root" "$rel" "$target_root" "$rel" "managed upgrade"
done

for rel in "${removes[@]}"; do
  [[ -z "$rel" ]] && continue
  if [[ -f "$target_root/$rel" ]]; then
    atomic_copy_rel "$target_root" "$rel" "$upgrade_dir" "backup/$rel" "obsolete managed backup"
    safe_remove_rel "$target_root" "$rel" "obsolete managed file"
  fi
done

write_lock
cleanup_empty_legacy_dirs

validation="not run"
validation_failed=0
validation_log="$upgrade_dir/validation.log"
validation_tmp="$(mktemp "$upgrade_dir/.validation.XXXXXX")" || die "cannot create validation log"
if [[ -f "$target_root/.p2t2c/bin/check_p2t2c.sh" ]]; then
  if (cd "$target_root" && bash .p2t2c/bin/check_p2t2c.sh >"$validation_tmp" 2>&1); then
    validation="bash .p2t2c/bin/check_p2t2c.sh: passed"
  else
    validation="bash .p2t2c/bin/check_p2t2c.sh: failed; see $validation_log"
    validation_failed=1
  fi
elif [[ -f "$target_root/Makefile" ]]; then
  if (cd "$target_root" && make check >"$validation_tmp" 2>&1); then
    validation="make check: passed"
  else
    validation="make check: failed; see $validation_log"
    validation_failed=1
  fi
else
  validation="required checker missing after upgrade"
  validation_failed=1
fi
mv -f "$validation_tmp" "$validation_log"

if [[ "$validation_failed" -eq 1 ]]; then
  rollback "$upgrade_dir"
  TRANSACTION_ACTIVE=0
  {
    echo "# P2T2C Upgrade Report — $upgrade_id"
    echo
    echo "Status: FAILED_ROLLED_BACK"
    echo "From: $target_version"
    echo "To: $source_version"
    echo
    echo "## Validation"
    echo "- $validation"
    echo
    echo "## Rollback"
    echo "- Restored all updated and removed managed files, removed files created by this upgrade, and restored the previous lock."
  } | atomic_write_rel "$upgrade_dir" "upgrade-report.md" "failed upgrade report"
  echo
  echo "Upgrade validation failed and the pre-apply state was restored."
  echo "Report: $upgrade_dir/upgrade-report.md"
  echo "$validation"
  exit 1
fi

{
  echo "# P2T2C Upgrade Report — $upgrade_id"
  echo
  echo "Status: APPLIED"
  echo "From: $target_version"
  echo "To: $source_version"
  echo
  echo "## Updated automatically"
  if [[ "${#updates[@]}" -eq 0 && "${#creates[@]}" -eq 0 ]]; then
    echo "- None"
  else
    for rel in "${updates[@]}" "${creates[@]}"; do
      [[ -n "$rel" ]] && echo "- $rel"
    done
  fi
  echo
  echo "## Removed obsolete"
  if [[ "${#removes[@]}" -eq 0 ]]; then
    echo "- None"
  else
    for rel in "${removes[@]}"; do
      echo "- $rel"
    done
  fi
  echo
  echo "## Skipped protected or unlocked paths"
  if [[ "${#skipped[@]}" -eq 0 ]]; then
    echo "- None"
  else
    for rel in "${skipped[@]}"; do
      echo "- $rel"
    done
  fi
  echo
  echo "## Conflicts"
  echo "- None"
  echo
  echo "## Validation"
  echo "- $validation"
  echo
  echo "## Rollback"
  echo
  echo '```bash'
  echo "bash .p2t2c/bin/p2t2c_upgrade.sh --rollback $upgrade_dir"
  echo '```'
} | atomic_write_rel "$upgrade_dir" "upgrade-report.md" "upgrade report"

TRANSACTION_COMMITTED=1
TRANSACTION_ACTIVE=0
echo
echo "Upgrade applied."
echo "Report: $upgrade_dir/upgrade-report.md"
echo "$validation"
