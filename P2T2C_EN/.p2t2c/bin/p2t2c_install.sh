#!/usr/bin/env bash
set -eo pipefail

usage() {
  cat <<'EOF'
Usage:
  .p2t2c/bin/p2t2c_install.sh --dry-run --target PATH
  .p2t2c/bin/p2t2c_install.sh --apply --target PATH

Run from the P2T2C source repository.
EOF
}

mode=""
target_dir=""

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
    --target)
      target_dir="${2:-}"
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

if [[ "$mode" != "dry-run" && "$mode" != "apply" ]]; then
  echo "ERROR: choose --dry-run or --apply" >&2
  usage
  exit 2
fi

if [[ -z "$target_dir" ]]; then
  echo "ERROR: --target PATH is required" >&2
  usage
  exit 2
fi

script_dir="$(cd "$(dirname "$0")" && pwd -P)"
source_root="$(cd "$script_dir/../.." && pwd -P)"
target_root=""

INSTALL_FILES=()
MODE_PATHS=()
MODE_VALUES=()
MODE_DEFAULT=""
SOURCE_SNAPSHOT=""
TRANSACTION_ACTIVE=0
TRANSACTION_COMMITTED=0
TX_CREATED_DIRS=()
APPLIED_INSTALLED=()
APPLIED_MODE_REPAIRS=()
install_dir=""
lock_existed=0
project_config_created=0

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
    my($path,$label)=@ARGV;die "ERROR: $label path must be physical absolute\n"if$path!~m{^/}||$path=~m{(?:^|/)\.\.(?:/|$)};
    chdir q(/) or die "ERROR: cannot hold filesystem root\n";my@parts=grep{length}split m{/+},$path;
    for my$c(@parts){my@s=lstat($c);die "ERROR: unsafe $label component: $c\n"if!@s||!S_ISDIR($s[2])||S_ISLNK($s[2]);my$m=$s[2]&07777;die "ERROR: untrusted $label component: $c\n"if$s[4]!=$<&&$s[4]!=0;die "ERROR: writable non-sticky $label component: $c\n"if($m&0022)&&!($s[4]==0&&($m&01000));my($d,$i)=@s[0,1];chdir$c or die "ERROR: cannot enter $label component: $c\n";my@dot=stat(q(.));die "ERROR: $label component changed: $c\n"if$dot[0]!=$d||$dot[1]!=$i}
    my@final=stat(q(.));my$fm=$final[2]&07777;die "ERROR: $label directory owner mismatch: $path\n"if$final[4]!=$<;die "ERROR: $label directory is group/world writable: $path\n"if$fm&0022;
  ' "$path" "$label" || exit 2
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
    my($path,$label)=@ARGV; my @s=lstat($path); die "ERROR: $label cannot be stated: $path\n" if !@s;
    die "ERROR: $label must be a regular file: $path\n" if !S_ISREG($s[2]);
    die "ERROR: $label owner mismatch: $path\n" if $s[4]!=$<;
    die "ERROR: $label must have link count 1: $path\n" if $s[3]!=1;
    my $mode=$s[2]&07777; die "ERROR: $label has unsafe mode: $path\n" if $mode&07022;
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
    my($root,$rel,$label)=@ARGV;chdir q(/)or die"ERROR: cannot hold filesystem root\n";
    for my$c(grep{length}split m{/+},$root){my@s=lstat($c);die"ERROR: unsafe $label root component\n"if!@s||!S_ISDIR($s[2])||S_ISLNK($s[2]);my$m=$s[2]&07777;die"ERROR: untrusted $label root component\n"if$s[4]!=$<&&$s[4]!=0;die"ERROR: writable root component\n"if($m&0022)&&!($s[4]==0&&($m&01000));my($d,$i)=@s[0,1];chdir$c or die"ERROR: cannot enter root component\n";my@dot=stat(q(.));die"ERROR: root component changed\n"if$dot[0]!=$d||$dot[1]!=$i}
    my$built=q();for my$c(split m{/},$rel){$built=length($built)?"$built/$c":$c;my@s=lstat($c);if(!@s){mkdir($c,0755)or die"ERROR: cannot create $label directory\n";@s=lstat($c);print"$built\n"}my$m=$s[2]&07777;die"ERROR: unsafe $label directory component\n"if!S_ISDIR($s[2])||S_ISLNK($s[2])||$s[4]!=$<||($m&0022);my($d,$i)=@s[0,1];chdir$c or die"ERROR: cannot enter $label directory\n";my@dot=stat(q(.));die"ERROR: $label directory changed\n"if$dot[0]!=$d||$dot[1]!=$i}
  ' "$root" "$rel" "$label")" || exit 2
  while IFS= read -r created; do
    [[ -n "$created" && "$TRANSACTION_ACTIVE" -eq 1 && "$root" == "$target_root" && "$rel" != .p2t2c/install* ]] && TX_CREATED_DIRS+=("$created")
  done <<< "$created_output"
  return 0
}

prepare_target_root() {
  local requested="$1" candidate probe parent base component
  local -a missing=()
  case "$requested" in
    /*) candidate="${requested%/}" ;;
    *) candidate="$PWD/${requested%/}" ;;
  esac
  [[ -n "$candidate" ]] || candidate="/"
  case "$candidate" in
    */../*|*/..|*/./*) die "target path must not contain dot traversal: $requested" ;;
  esac
  probe="$candidate"
  while [[ ! -e "$probe" && ! -L "$probe" ]]; do
    base="$(basename "$probe")"
    [[ "$base" != "." && "$base" != ".." && -n "$base" ]] || die "unsafe target component: $base"
    missing=("$base" "${missing[@]}")
    parent="$(dirname "$probe")"
    [[ "$parent" != "$probe" ]] || die "cannot resolve target root: $requested"
    probe="$parent"
  done
  [[ ! -L "$probe" ]] || die "target path must not traverse a symlink: $probe"
  [[ -d "$probe" ]] || die "target ancestor is not a directory: $probe"
  target_root="$(cd "$probe" && pwd -P)"
  for component in "${missing[@]}"; do
    [[ ! -L "$target_root/$component" ]] || die "target path component must not be a symlink: $target_root/$component"
    if [[ -e "$target_root/$component" ]]; then
      [[ -d "$target_root/$component" ]] || die "target path component is not a directory: $target_root/$component"
    else
      mkdir "$target_root/$component" || die "cannot create target directory: $target_root/$component"
    fi
    target_root="$target_root/$component"
  done
  target_root="$(cd "$target_root" && pwd -P)"
  assert_root_dir "$target_root" "target"
}

snapshot_leaf() {
  local root="$1" rel="$2"
  perl -MDigest::SHA -MFcntl=O_RDONLY,O_NOFOLLOW,:mode -MFile::Basename=dirname,basename -e '
    my($root,$rel)=@ARGV; my $parent=dirname($rel); my $base=basename($rel); my $dir="$root/$parent";
    chdir q(/)or die"ERROR: cannot hold filesystem root\n";for my$c(grep{length}split m{/+},$dir){my@h=lstat($c);die"ERROR: unsafe source parent component: $rel\n"if!@h||!S_ISDIR($h[2])||S_ISLNK($h[2]);my$hm=$h[2]&07777;die"ERROR: untrusted source parent component: $rel\n"if$h[4]!=$<&&$h[4]!=0;die"ERROR: writable source ancestor: $rel\n"if($hm&0022)&&!($h[4]==0&&($hm&01000));my($d,$i)=@h[0,1];chdir$c or die"ERROR: cannot enter source parent component: $rel\n";my@dot=stat(q(.));die"ERROR: source parent component changed: $rel\n"if$dot[0]!=$d||$dot[1]!=$i}my@p=stat(q(.));my$pm=$p[2]&07777;die"ERROR: unsafe held source parent: $rel\n"if$p[4]!=$<||($pm&0022);
    sysopen(my $fh,$base,O_RDONLY|O_NOFOLLOW) or die "ERROR: cannot open source leaf safely: $rel\n";
    binmode $fh; my @s=stat($fh); die "ERROR: source leaf is not regular: $rel\n" if !S_ISREG($s[2]);
    die "ERROR: source leaf owner mismatch: $rel\n" if $s[4]!=$<; die "ERROR: source leaf hardlink rejected: $rel\n" if $s[3]!=1;
    my $mode=$s[2]&07777; die "ERROR: source leaf unsafe mode: $rel\n" if $mode&07022;
    my $sha=Digest::SHA->new(256); $sha->addfile($fh); my $digest=$sha->hexdigest; my @after=stat(".");
    die "ERROR: source parent identity changed: $rel\n" if $p[0]!=$after[0]||$p[1]!=$after[1];
    print join("\t",$rel,$p[0],$p[1],$s[0],$s[1],$s[4],$s[3],sprintf("%04o",$mode),$digest),"\n";
  ' "$root" "$rel"
}

freeze_source_files() {
  local rel line digest expected mode_value
  SOURCE_SNAPSHOT="$(mktemp "${TMPDIR:-/tmp}/p2t2c-source-snapshot.XXXXXX")" || die "cannot create source snapshot"
  chmod 600 "$SOURCE_SNAPSHOT"
  : > "$SOURCE_SNAPSHOT"
  for rel in "${INSTALL_FILES[@]}"; do
    line="$(snapshot_leaf "$source_root" "$rel")" || exit 2
    digest="${line##*$'\t'}"
    if [[ "$rel" != ".p2t2c/CHECKSUMS.sha256" ]]; then
      expected="$(awk -v path="$rel" '$2==path {print $1}' "$source_root/.p2t2c/CHECKSUMS.sha256")"
      [[ -n "$expected" && "$digest" == "$expected" ]] || die "source changed after checksum validation: $rel"
    fi
    mode_value="$(printf '%s\n' "$line" | awk -F '\t' '{print $8}')"
    [[ "$mode_value" == "$(expected_mode "$rel")" ]] || die "source mode changed before freeze: $rel"
    printf '%s\n' "$line" >> "$SOURCE_SNAPSHOT"
  done
}

snapshot_line_for() {
  local source_base="$1" rel="$2" line
  if [[ -n "$SOURCE_SNAPSHOT" && "$source_base" == "$source_root" ]]; then
    line="$(awk -F '\t' -v path="$rel" '$1==path {print; exit}' "$SOURCE_SNAPSHOT")"
    [[ -n "$line" ]] || die "source snapshot omits: $rel"
    printf '%s\n' "$line"
  else
    snapshot_leaf "$source_base" "$rel"
  fi
}

test_pause() {
  local phase="$1" rel="$2" wanted="" ms="${P2T2C_TEST_PAUSE_MS:-}"
  case "$phase" in
    before_dest_identity) wanted="${P2T2C_TEST_PAUSE_BEFORE_DEST_IDENTITY_REL:-}" ;;
    after_source_snapshot) wanted="${P2T2C_TEST_PAUSE_AFTER_SOURCE_SNAPSHOT_REL:-}" ;;
    *) die "invalid internal test pause phase" ;;
  esac
  [[ -n "$wanted" ]] || return 0
  validate_rel_path "$wanted" "test pause relative path"
  [[ "$ms" =~ ^[1-9][0-9]{0,3}$ && "$ms" -le 5000 ]] || die "P2T2C_TEST_PAUSE_MS must be 1..5000"
  [[ "$wanted" == "$rel" ]] || return 0
  printf 'P2T2C_TEST_MARKER:%s\n' "$phase" >&2
  perl -e 'select undef,undef,undef,$ARGV[0]/1000' "$ms"
}

directory_identity() {
  local path="$1" label="$2"
  perl -MFcntl=:mode -e '
    my($path,$label)=@ARGV;chdir q(/)or die"ERROR: cannot hold filesystem root\n";for my$c(grep{length}split m{/+},$path){my@s=lstat($c);die"ERROR: unsafe $label component\n"if!@s||!S_ISDIR($s[2])||S_ISLNK($s[2]);my$m=$s[2]&07777;die"ERROR: untrusted $label component\n"if$s[4]!=$<&&$s[4]!=0;die"ERROR: writable $label ancestor\n"if($m&0022)&&!($s[4]==0&&($m&01000));my($d,$i)=@s[0,1];chdir$c or die"ERROR: cannot enter $label component\n";my@dot=stat(q(.));die"ERROR: $label component changed\n"if$dot[0]!=$d||$dot[1]!=$i}my@s=stat(q(.));my$m=$s[2]&07777;die"ERROR: unsafe held $label directory\n"if$s[4]!=$<||($m&0022);print"$s[0]\t$s[1]\n";
  ' "$path" "$label" || exit 2
}

atomic_copy_rel() {
  local source_base="$1" source_rel="$2" destination_base="$3" destination_rel="$4" label="$5"
  local destination_parent snapshot destination_identity
  validate_rel_path "$source_rel" "$label source path"
  validate_rel_path "$destination_rel" "$label destination path"
  destination_parent="$(dirname "$destination_rel")"
  safe_mkdir_rel "$destination_base" "$destination_parent" "$label"
  snapshot="$(snapshot_line_for "$source_base" "$source_rel")" || exit 2
  test_pause after_source_snapshot "$source_rel"
  test_pause before_dest_identity "$destination_rel"
  destination_identity="$(directory_identity "$destination_base/$destination_parent" "$label destination parent")" || exit 2
  perl -MDigest::SHA=sha256_hex -MFcntl=O_RDONLY,O_WRONLY,O_CREAT,O_EXCL,O_NOFOLLOW,:mode -MFile::Basename=dirname,basename -e '
    my($sroot,$srel,$droot,$drel,$snapshot,$dest_identity,$label)=@ARGV; my @e=split /\t/,$snapshot,-1;my @de=split /\t/,$dest_identity,-1;
    sub held {my($path,$kind)=@_;chdir q(/)or die"ERROR: cannot hold filesystem root\n";for my$c(grep{length}split m{/+},$path){my@s=lstat($c);die"ERROR: unsafe $kind parent component\n"if!@s||!S_ISDIR($s[2])||S_ISLNK($s[2]);my$m=$s[2]&07777;die"ERROR: untrusted $kind parent component\n"if$s[4]!=$<&&$s[4]!=0;die"ERROR: writable $kind ancestor\n"if($m&0022)&&!($s[4]==0&&($m&01000));my($d,$i)=@s[0,1];chdir$c or die"ERROR: cannot enter $kind parent component\n";my@dot=stat(q(.));die"ERROR: $kind parent component changed\n"if$dot[0]!=$d||$dot[1]!=$i}my@f=stat(q(.));my$fm=$f[2]&07777;die"ERROR: unsafe held $kind parent\n"if$f[4]!=$<||($fm&0022);return@f}
    die "ERROR: malformed source snapshot\n" if @e!=9||$e[0] ne $srel;
    my($sp,$sb)=(dirname($srel),basename($srel));my @p=held("$sroot/$sp",q(source));die "ERROR: frozen source parent changed: $srel\n" if $p[0]!=$e[1]||$p[1]!=$e[2];
    sysopen(my $sf,$sb,O_RDONLY|O_NOFOLLOW) or die "ERROR: source O_NOFOLLOW open failed: $srel\n"; binmode $sf;
    my @s=stat($sf); my $mode=$s[2]&07777;
    die "ERROR: frozen source leaf changed: $srel\n" if !S_ISREG($s[2])||$s[0]!=$e[3]||$s[1]!=$e[4]||$s[4]!=$e[5]||$s[3]!=$e[6]||sprintf("%04o",$mode) ne $e[7]||$s[4]!=$<||$s[3]!=1||($mode&07022);
    local $/; my $bytes=<$sf>//""; close $sf; die "ERROR: frozen source digest changed: $srel\n" if sha256_hex($bytes) ne $e[8];
    my @p2=stat("."); die "ERROR: source parent changed during read: $srel\n" if $p[0]!=$p2[0]||$p[1]!=$p2[1];
    my($dp,$db)=(dirname($drel),basename($drel));my @dparent=held("$droot/$dp",q(destination));
    die "ERROR: frozen destination parent changed\n" if @de!=2||$dparent[0]!=$de[0]||$dparent[1]!=$de[1];
    if (lstat($db)) {my @d=lstat($db);my $dm=$d[2]&07777;die "ERROR: unsafe existing destination: $drel\n" if !S_ISREG($d[2])||S_ISLNK($d[2])||$d[4]!=$<||$d[3]!=1||($dm&07022)}
    my $tmp=".p2t2c-copy-$$-".int(rand(1_000_000)); sysopen(my $df,$tmp,O_WRONLY|O_CREAT|O_EXCL|O_NOFOLLOW,0600) or die "ERROR: cannot create destination temporary\n";
    binmode $df; print {$df} $bytes or do {unlink $tmp;die "ERROR: cannot write destination temporary\n"}; close $df or do {unlink $tmp;die "ERROR: cannot close destination temporary\n"};
    chmod $mode,$tmp or do {unlink $tmp;die "ERROR: cannot preserve destination mode\n"};my@temp=lstat($tmp);die"ERROR: unsafe destination temporary identity\n"if!@temp||!S_ISREG($temp[2])||$temp[4]!=$<||$temp[3]!=1||(($temp[2]&07777)!=$mode);my$temp_digest=sha256_hex($bytes);my @dcheck=stat(".");
    die "ERROR: destination parent identity changed\n" if $dparent[0]!=$dcheck[0]||$dparent[1]!=$dcheck[1];
    rename $tmp,$db or do {unlink $tmp;die "ERROR: cannot atomically publish destination\n"};
    my$pause=$ENV{P2T2C_TEST_PAUSE_AFTER_RENAME_REL}//q();my$fail=$ENV{P2T2C_TEST_FAIL_AFTER_RENAME_REL}//q();for my$v($pause,$fail){die"ERROR: unsafe after-rename test path\n"if length($v)&&($v=~m{^/|(?:^|/)\.\.(?:/|$)|//|\s})}if($pause eq$drel){my$ms=$ENV{P2T2C_TEST_PAUSE_MS}//q();die"ERROR: P2T2C_TEST_PAUSE_MS must be 1..5000\n"if$ms!~/\A[1-9][0-9]{0,3}\z/||$ms>5000;print STDERR"P2T2C_TEST_MARKER:after_rename\n";select undef,undef,undef,$ms/1000}die"ERROR: controlled after-rename failure\n"if$fail eq$drel;
    my @final=lstat($db);die "ERROR: unsafe published destination\n" if !@final||!S_ISREG($final[2])||$final[4]!=$<||$final[3]!=1||(($final[2]&07777)!=$mode)||$final[0]!=$temp[0]||$final[1]!=$temp[1];sysopen(my$vf,$db,O_RDONLY|O_NOFOLLOW)or die"ERROR: cannot verify published destination\n";binmode$vf;my@vs=stat($vf);local$/;my$visible=<$vf>//q();close$vf;die"ERROR: published destination identity or digest changed\n"if$vs[0]!=$temp[0]||$vs[1]!=$temp[1]||sha256_hex($visible)ne$temp_digest;
  ' "$source_base" "$source_rel" "$destination_base" "$destination_rel" "$snapshot" "$destination_identity" "$label" || exit 2
}

atomic_write_rel() {
  local root="$1" rel="$2" label="$3"
  local parent identity
  validate_rel_path "$rel" "$label path"
  parent="$(dirname "$rel")"
  safe_mkdir_rel "$root" "$parent" "$label"
  identity="$(directory_identity "$root/$parent" "$label parent")" || exit 2
  perl -MFcntl=O_WRONLY,O_CREAT,O_EXCL,O_NOFOLLOW,:mode -MFile::Basename=dirname,basename -e '
    my($root,$rel,$identity,$label)=@ARGV;my@e=split/\t/,$identity,-1;my($parent,$base)=(dirname($rel),basename($rel));
    chdir q(/)or die"ERROR: cannot hold filesystem root\n";for my$c(grep{length}split m{/+},"$root/$parent"){my@s=lstat($c);die"ERROR: unsafe write parent component\n"if!@s||!S_ISDIR($s[2])||S_ISLNK($s[2]);my$m=$s[2]&07777;die"ERROR: untrusted write parent component\n"if$s[4]!=$<&&$s[4]!=0;die"ERROR: writable write ancestor\n"if($m&0022)&&!($s[4]==0&&($m&01000));my($d,$i)=@s[0,1];chdir$c or die"ERROR: cannot enter write parent component\n";my@dot=stat(q(.));die"ERROR: write parent component changed\n"if$dot[0]!=$d||$dot[1]!=$i}my@p=stat(q(.));my$pm=$p[2]&07777;die"ERROR: unsafe held write parent\n"if$p[4]!=$<||($pm&0022);die "ERROR: frozen write parent changed\n" if @e!=2||$p[0]!=$e[0]||$p[1]!=$e[1];
    if(lstat($base)){my@d=lstat($base);my$m=$d[2]&07777;die "ERROR: unsafe existing write target\n" if !S_ISREG($d[2])||S_ISLNK($d[2])||$d[4]!=$<||$d[3]!=1||($m&07022)}
    my$tmp=".p2t2c-write-$$-".int(rand(1_000_000));sysopen(my$fh,$tmp,O_WRONLY|O_CREAT|O_EXCL|O_NOFOLLOW,0600)or die "ERROR: cannot create write temporary\n";
    binmode STDIN;binmode $fh;my$buffer;while(read(STDIN,$buffer,65536)){print{$fh}$buffer or do{unlink$tmp;die "ERROR: cannot write temporary\n"}}close$fh or do{unlink$tmp;die "ERROR: cannot close temporary\n"};
    my@after=stat(".");die "ERROR: write parent changed during transaction\n" if $p[0]!=$after[0]||$p[1]!=$after[1];rename$tmp,$base or do{unlink$tmp;die "ERROR: cannot publish write target\n"};
  ' "$root" "$rel" "$identity" "$label" || exit 2
}

safe_remove_rel() {
  local root="$1" rel="$2" label="$3"
  validate_rel_path "$rel" "$label path"
  perl -MFcntl=:mode -MFile::Basename=dirname,basename -e '
    my($root,$rel,$label)=@ARGV;my($parent,$leaf)=(dirname($rel),basename($rel));chdir q(/)or die"ERROR: cannot hold filesystem root\n";
    for my$c(grep{length}split m{/+},"$root/$parent"){my@s=lstat($c);die"ERROR: unsafe remove parent component\n"if!@s||!S_ISDIR($s[2])||S_ISLNK($s[2]);my$m=$s[2]&07777;die"ERROR: untrusted remove parent component\n"if$s[4]!=$<&&$s[4]!=0;die"ERROR: writable remove ancestor\n"if($m&0022)&&!($s[4]==0&&($m&01000));my($d,$i)=@s[0,1];chdir$c or die"ERROR: cannot enter remove parent\n";my@dot=stat(q(.));die"ERROR: remove parent changed\n"if$dot[0]!=$d||$dot[1]!=$i}
    my@s=lstat($leaf);exit 0 if!@s;my$m=$s[2]&07777;die"ERROR: unsafe remove leaf\n"if!S_ISREG($s[2])||S_ISLNK($s[2])||$s[4]!=$<||$s[3]!=1||($m&07022);unlink($leaf)or die"ERROR: cannot remove $label\n";
  ' "$root" "$rel" "$label" || exit 2
}

managed_contains() {
  local wanted="$1" rel
  for rel in "${INSTALL_FILES[@]}"; do
    [[ "$rel" == "$wanted" ]] && return 0
  done
  return 1
}

load_managed_files() {
  local manifest="$1" line rel existing
  assert_rel_components "$source_root" ".p2t2c/managed-files.txt" regular "managed-file manifest"

  while IFS= read -r line || [[ -n "$line" ]]; do
    rel="${line#"${line%%[![:space:]]*}"}"
    rel="${rel%"${rel##*[![:space:]]}"}"
    [[ -z "$rel" || "${rel:0:1}" == "#" ]] && continue
    case "$rel" in
      /*|../*|*/../*|*/..|.|*//*)
        echo "ERROR: unsafe managed path in $manifest: $rel" >&2
        exit 2
        ;;
      .p2t2c/lock.sha256|.p2t2c/project_config.yaml)
        echo "ERROR: runtime or project-owned path cannot be release-managed: $rel" >&2
        exit 2
        ;;
    esac
    if is_project_owned "$rel"; then
      echo "ERROR: project-owned path cannot be release-managed: $rel" >&2
      exit 2
    fi
    for existing in "${INSTALL_FILES[@]}"; do
      if [[ "$existing" == "$rel" ]]; then
        echo "ERROR: duplicate managed path in $manifest: $rel" >&2
        exit 2
      fi
    done
    INSTALL_FILES+=("$rel")
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
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [[ -z "$line" || "${line:0:1}" == "#" ]] && continue
    mode="${line%%[[:space:]]*}"
    rel="${line#"$mode"}"; rel="${rel#"${rel%%[![:space:]]*}"}"
    if [[ "$mode" == "default" ]]; then
      [[ -z "$MODE_DEFAULT" && "$rel" == "0644" ]] || die "default managed mode must be exactly 0644"
      MODE_DEFAULT="$rel"
      continue
    fi
    [[ "$mode" == "0755" ]] || die "explicit managed mode must be exactly 0755: $mode"
    validate_rel_path "$rel" "managed-mode path"
    managed_contains "$rel" || die "managed-mode path is not release-managed: $rel"
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
  for rel in "${INSTALL_FILES[@]}"; do
    assert_rel_components "$source_root" "$rel" regular "managed source"
  done
  if ! diff -u \
    <(for rel in "${INSTALL_FILES[@]}"; do [[ "$rel" == ".p2t2c/CHECKSUMS.sha256" ]] || printf '%s\n' "$rel"; done) \
    <(awk 'NF >= 2 { print $2 }' "$checksum_file") >&2
  then
    echo "ERROR: source checksum inventory does not match .p2t2c/managed-files.txt" >&2
    exit 2
  fi
  if ! (cd "$source_root" && shasum -a 256 -c .p2t2c/CHECKSUMS.sha256 >/dev/null); then
    echo "ERROR: source checksum verification failed" >&2
    exit 2
  fi
  for rel in "${INSTALL_FILES[@]}"; do
    expected="$(expected_mode "$rel")"; actual="$(permission_mode "$source_root/$rel")"
    [[ "$actual" == "$expected" ]] || die "managed source mode mismatch: $rel expected=$expected actual=$actual"
  done
  freeze_source_files
}

load_managed_files "$source_root/.p2t2c/managed-files.txt"
load_managed_modes
validate_source_checksums

cleanup_target_dirs() {
  local index dir
  for ((index=${#TX_CREATED_DIRS[@]}-1; index>=0; index--)); do
    dir="${TX_CREATED_DIRS[$index]}"
    [[ -n "$target_root" && -d "$target_root/$dir" && ! -L "$target_root/$dir" ]] && rmdir "$target_root/$dir" 2>/dev/null || true
  done
}

rollback_install_transaction() {
  local index rel
  [[ "$TRANSACTION_ACTIVE" -eq 1 ]] || return 0
  TRANSACTION_ACTIVE=0
  set +e
  for ((index=${#APPLIED_MODE_REPAIRS[@]}-1; index>=0; index--)); do
    rel="${APPLIED_MODE_REPAIRS[$index]}"
    [[ -n "$install_dir" && -f "$install_dir/mode-backup/$rel" ]] \
      && atomic_copy_rel "$install_dir/mode-backup" "$rel" "$target_root" "$rel" "install mode rollback"
  done
  if [[ "$project_config_created" -eq 1 ]]; then safe_remove_rel "$target_root" ".p2t2c/project_config.yaml" "failed install project configuration"; fi
  for ((index=${#APPLIED_INSTALLED[@]}-1; index>=0; index--)); do
    rel="${APPLIED_INSTALLED[$index]}"; safe_remove_rel "$target_root" "$rel" "failed install file"
  done
  if [[ "$lock_existed" -eq 1 && -n "$install_dir" && -f "$install_dir/pre-apply-lock.sha256" ]]; then
    atomic_copy_rel "$install_dir" "pre-apply-lock.sha256" "$target_root" ".p2t2c/lock.sha256" "restored target lock"
  elif [[ "$lock_existed" -eq 0 && -n "$target_root" && -e "$target_root/.p2t2c/lock.sha256" ]]; then
    safe_remove_rel "$target_root" ".p2t2c/lock.sha256" "failed install lock"
  fi
  cleanup_target_dirs
  set -e
}

install_exit_trap() {
  local status=$?
  if [[ "$TRANSACTION_ACTIVE" -eq 1 && "$TRANSACTION_COMMITTED" -eq 0 ]]; then rollback_install_transaction; fi
  [[ -z "$SOURCE_SNAPSHOT" || ! -e "$SOURCE_SNAPSHOT" ]] || rm -f "$SOURCE_SNAPSHOT"
  return "$status"
}

trap install_exit_trap EXIT
trap 'exit $?' ERR
trap 'exit 130' INT
trap 'exit 143' TERM
prepare_target_root "$target_dir"

for rel in "${INSTALL_FILES[@]}"; do
  assert_rel_components "$target_root" "$rel" optional_regular "managed target"
done
assert_rel_components "$target_root" ".p2t2c/lock.sha256" optional_regular "target lock"
assert_rel_components "$target_root" ".p2t2c/project_config.yaml" optional_regular "project configuration"

sha256_file() {
  shasum -a 256 "$1" | awk '{print $1}'
}

write_lock() {
  local rel
  {
    for rel in "${INSTALL_FILES[@]}"; do
      assert_rel_components "$target_root" "$rel" optional_regular "lock target"
      assert_rel_components "$source_root" "$rel" regular "lock source"
      if [[ -f "$target_root/$rel" ]] \
        && [[ "$(sha256_file "$target_root/$rel")" == "$(sha256_file "$source_root/$rel")" ]]
      then
        printf "%s  %s\n" "$(sha256_file "$target_root/$rel")" "$rel"
      fi
    done
  } | atomic_write_rel "$target_root" ".p2t2c/lock.sha256" "target lock"
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

installed=()
unchanged=()
mode_repairs=()
conflicts=()
skipped=()
missing_source=()

already_installed=0
if [[ -f "$target_root/.p2t2c/manifest.yaml" ]]; then
  already_installed=1
fi

project_config_action="kept existing project configuration"
if [[ ! -e "$target_root/.p2t2c/project_config.yaml" ]]; then
  project_config_action="create .p2t2c/project_config.yaml from the adaptive advisory template"
fi

if [[ "$already_installed" -eq 1 ]]; then
  echo "P2T2C install"
  echo "Mode: $mode"
  echo "Source: $source_root"
  echo "Target: $target_root"
  echo
  echo "Project already uses P2T2C; use upgrade instead."
  if [[ "$mode" == "dry-run" ]]; then
    exit 0
  fi
  echo
  echo "Install stopped. Use p2t2c-upgrade for this project."
  exit 1
fi

for rel in "${INSTALL_FILES[@]}"; do
  if is_project_owned "$rel"; then
    skipped+=("$rel (denylist)")
    continue
  fi

  if [[ ! -f "$source_root/$rel" ]]; then
    missing_source+=("$rel")
    continue
  fi

  if [[ ! -f "$target_root/$rel" ]]; then
    installed+=("$rel")
    continue
  fi

  if [[ "$(sha256_file "$source_root/$rel")" == "$(sha256_file "$target_root/$rel")" ]]; then
    if [[ "$(permission_mode "$target_root/$rel")" == "$(expected_mode "$rel")" ]]; then unchanged+=("$rel"); else mode_repairs+=("$rel"); fi
  else
    conflicts+=("$rel")
  fi
done

echo "P2T2C install"
echo "Mode: $mode"
echo "Source: $source_root"
echo "Target: $target_root"

print_list "Installed" "${installed[@]}"
print_list "Unchanged" "${unchanged[@]}"
print_list "Mode repairs" "${mode_repairs[@]}"
print_list "Conflicts" "${conflicts[@]}"
print_list "Skipped denied paths" "${skipped[@]}"
print_list "Missing from source" "${missing_source[@]}"
echo
echo "Project configuration: $project_config_action"

if [[ "$mode" == "dry-run" ]]; then
  [[ "${#missing_source[@]}" -eq 0 ]] || exit 1
  exit 0
fi

if [[ "${#missing_source[@]}" -gt 0 ]]; then
  echo
  echo "Install stopped. The source release is incomplete."
  exit 1
fi

install_id="$(date +%Y%m%d-%H%M%S)"
TRANSACTION_ACTIVE=1
safe_mkdir_rel "$target_root" ".p2t2c/install" "install transaction"
install_dir="$(mktemp -d "$target_root/.p2t2c/install/$install_id.XXXXXX")" || die "cannot create secure install transaction directory"
[[ -d "$install_dir" && ! -L "$install_dir" ]] || die "unsafe install transaction directory: $install_dir"
install_id="$(basename "$install_dir")"
lock_existed=0
project_config_created=0
if [[ -f "$target_root/.p2t2c/lock.sha256" ]]; then
  lock_existed=1
  atomic_copy_rel "$target_root" ".p2t2c/lock.sha256" "$install_dir" "pre-apply-lock.sha256" "pre-apply lock backup"
fi

for rel in "${installed[@]}"; do
  [[ -z "$rel" ]] && continue
  APPLIED_INSTALLED+=("$rel")
  atomic_copy_rel "$source_root" "$rel" "$target_root" "$rel" "managed install"
done

for rel in "${mode_repairs[@]}"; do
  [[ -n "$rel" ]] || continue
  atomic_copy_rel "$target_root" "$rel" "$install_dir" "mode-backup/$rel" "install mode backup"
  APPLIED_MODE_REPAIRS+=("$rel")
  atomic_copy_rel "$source_root" "$rel" "$target_root" "$rel" "install mode repair"
done

if [[ ! -e "$target_root/.p2t2c/project_config.yaml" ]]; then
  project_config_created=1
  atomic_copy_rel "$source_root" ".p2t2c/templates/project_config.example.yaml" "$target_root" ".p2t2c/project_config.yaml" "project configuration"
fi

write_lock

validation="not run"
install_status="APPLIED"
apply_failed=0
validation_log="$install_dir/validation.log"
validation_tmp="$(mktemp "$install_dir/.validation.XXXXXX")" || die "cannot create validation log"
if [[ "${#conflicts[@]}" -gt 0 ]]; then
  validation="not run due unresolved install conflicts"
  apply_failed=1
elif [[ -f "$target_root/.p2t2c/bin/check_p2t2c.sh" ]]; then
  if (cd "$target_root" && bash .p2t2c/bin/check_p2t2c.sh >"$validation_tmp" 2>&1); then
    validation="bash .p2t2c/bin/check_p2t2c.sh: passed"
  else
    validation="bash .p2t2c/bin/check_p2t2c.sh: failed; see $validation_log"
    apply_failed=1
  fi
else
  validation="required checker missing after install"
  apply_failed=1
fi
mv -f "$validation_tmp" "$validation_log"

if [[ "$apply_failed" -eq 1 ]]; then
  install_status="FAILED_ROLLED_BACK"
  rollback_install_transaction
fi

{
  echo "# P2T2C Install Report — $install_id"
  echo
  echo "Status: $install_status"
  echo "Source: \`$source_root\`"
  echo "Target: \`$target_root\`"
  echo
  echo "## Installed"
  if [[ "${#installed[@]}" -eq 0 ]]; then
    echo "- None"
  else
    for rel in "${installed[@]}"; do
      echo "- $rel"
    done
  fi
  echo
  echo "## Unchanged"
  if [[ "${#unchanged[@]}" -eq 0 ]]; then
    echo "- None"
  else
    for rel in "${unchanged[@]}"; do
      echo "- $rel"
    done
  fi
  echo
  echo "## Mode repairs"
  if [[ "${#mode_repairs[@]}" -eq 0 ]]; then echo "- None"; else for rel in "${mode_repairs[@]}"; do echo "- $rel"; done; fi
  echo
  echo "## Conflicts"
  if [[ "${#conflicts[@]}" -eq 0 ]]; then
    echo "- None"
  else
    for rel in "${conflicts[@]}"; do
      echo "- $rel"
    done
  fi
  echo
  echo "## Skipped denied paths"
  if [[ "${#skipped[@]}" -eq 0 ]]; then
    echo "- None"
  else
    for rel in "${skipped[@]}"; do
      echo "- $rel"
    done
  fi
  echo
  echo "## Validation"
  echo "- $validation"
  echo
  echo "## Rollback"
  if [[ "$apply_failed" -eq 1 ]]; then
    echo "- Restored the pre-apply state; only this failed install report and validation log remain."
  else
    echo "- Not required."
  fi
  echo
  echo "## Project configuration"
  echo "- $project_config_action"
  echo
  echo "## Suggested manual integration"
  echo
  if [[ "${#conflicts[@]}" -eq 0 ]]; then
    echo "- None"
  else
    echo "- Existing files were not overwritten."
    echo "- If an AI tool only auto-loads root-level AGENTS.md, reference P2T2C_AGENTS.md from the project-owned AGENTS.md."
    echo "- Keep existing project README and Makefile unchanged."
    echo "- Link to P2T2C_README.md from project docs if needed."
  fi
} | atomic_write_rel "$install_dir" "install-report.md" "install report"

echo
if [[ "$apply_failed" -eq 1 ]]; then
  echo "Install failed and was rolled back."
  echo "Report: $install_dir/install-report.md"
  echo "$validation"
  exit 1
fi
if [[ "$lock_existed" -eq 1 && -f "$install_dir/pre-apply-lock.sha256" ]]; then
  safe_remove_rel "$install_dir" "pre-apply-lock.sha256" "pre-apply lock backup"
fi
for rel in "${APPLIED_MODE_REPAIRS[@]}"; do
  [[ -f "$install_dir/mode-backup/$rel" ]] && safe_remove_rel "$install_dir/mode-backup" "$rel" "mode backup cleanup"
done
TRANSACTION_COMMITTED=1
TRANSACTION_ACTIVE=0
echo "Install applied."
echo "Report: $install_dir/install-report.md"
echo "$validation"
