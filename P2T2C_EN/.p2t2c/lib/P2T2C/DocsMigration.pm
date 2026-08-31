package P2T2C::DocsMigration;
use strict;
use warnings;

use Digest::SHA qw(sha256_hex);
use Errno qw(EEXIST);
use Fcntl qw(:mode O_RDONLY O_WRONLY O_CREAT O_EXCL O_NOFOLLOW);
use File::Basename qw(dirname basename);
use File::Find ();
use JSON::PP ();
use POSIX qw(strftime);
use P2T2C::Documents ();

my $JSON=JSON::PP->new->canonical(1)->utf8(1);
my $ROOT='.p2t2c/docs-migrate';
my $DIGEST=qr/\A[0-9a-f]{64}\z/;

sub fail { die "ERROR: docs-migrate: $_[0]\n" }
sub digest { sha256_hex($_[0]//q()) }

sub safe_rel {
    my($path,$label)=@_;$label//=q(path);
    fail("unsafe $label") if !defined($path)||$path eq q()||length($path)>768
        ||$path=~m{\A/|(?:\A|/)\.\.?(?:/|\z)|//|[\x00-\x1f\x7f]};
    return 1;
}

sub check_root {
    my@st=lstat q(.);
    fail(q(unsafe project root)) if !@st||S_ISLNK($st[2])||!S_ISDIR($st[2])||$st[4]!=$<||($st[2]&0022);
}

sub in_directory {
    my($path,$create,$label,$code)=@_;$label//=q(directory);safe_rel($path,$label)if$path ne q(.)&&$path ne q();
    opendir(my$root,q(.))or fail(q(cannot hold project root));my@root=stat$root;
    fail(q(unsafe project root))if!@root||!S_ISDIR($root[2])||$root[4]!=$<||($root[2]&0022);
    my($result,$error);my$ok=eval{
        chdir$root or fail(q(cannot enter held project root));my$current=q();
        for my$part($path eq q(.)||$path eq q()?():split(m{/},$path)){
            $current=length($current)?"$current/$part":$part;my@visible=lstat$part;
            if(!@visible&&$create){my$mode=$current=~m{\A\.p2t2c(?:/|\z)}?0700:0755;mkdir$part,$mode or fail("cannot create directory $current");@visible=lstat$part}
            fail("unsafe $label component: $current")if!@visible||S_ISLNK($visible[2])||!S_ISDIR($visible[2])||$visible[4]!=$<||($visible[2]&0022);
            opendir(my$next,$part)or fail("cannot hold $label component: $current");my@held=stat$next;
            fail("$label component changed: $current")if!@held||$held[0]!=$visible[0]||$held[1]!=$visible[1];
            chdir$next or fail("cannot enter $label component: $current");my@dot=stat q(.);
            fail("$label component changed after entry: $current")if!@dot||$dot[0]!=$held[0]||$dot[1]!=$held[1];closedir$next;
        }
        $result=$code->();1;
    };$error=$@if!$ok;my$restored=chdir$root;my$close_ok=closedir$root;
    $error.="ERROR: docs-migrate: cannot restore held project root\n"if!$restored;$error.="ERROR: docs-migrate: cannot close held project root\n"if!$close_ok;
    die$error if!$ok||!$restored||!$close_ok;return$result;
}

sub check_dir { my($path,$label)=@_;return in_directory($path,0,$label,sub{1}) }
sub ensure_dir { return in_directory($_[0],1,q(directory),sub{1}) }

sub check_existing_parent_prefix {
    my($path)=@_;safe_rel($path,q(target));check_root();my$parent=dirname($path);return 1 if$parent eq q(.);my$current=q();
    for my$part(split m{/},$parent){$current=length($current)?"$current/$part":$part;my@st=lstat$current;return 1 if!@st;
        fail("unsafe target parent component: $current")if S_ISLNK($st[2])||!S_ISDIR($st[2])||$st[4]!=$<||($st[2]&0022)}return 1;
}

sub file_stat {
    my($path,$allow_links,$label)=@_;$label//=q(file);safe_rel($path,$label);my@st;
    in_directory(dirname($path),0,"$label parent",sub{@st=lstat basename($path);fail("missing $label: $path")if!@st;
        fail("unsafe $label: $path")if S_ISLNK($st[2])||!S_ISREG($st[2])||$st[4]!=$<||($st[2]&0022)||(!$allow_links&&$st[3]!=1);1});return@st;
}

sub read_raw {
    my($path,$allow_links,$label)=@_;$label//=q(file);safe_rel($path,$label);
    return in_directory(dirname($path),0,"$label parent",sub{my$leaf=basename$path;my@visible=lstat$leaf;fail("missing $label: $path")if!@visible;
        fail("unsafe $label: $path")if S_ISLNK($visible[2])||!S_ISREG($visible[2])||$visible[4]!=$<||($visible[2]&0022)||(!$allow_links&&$visible[3]!=1);
        sysopen(my$fh,$leaf,O_RDONLY|O_NOFOLLOW)or fail("cannot read $path");my@held=stat$fh;
        fail("$path changed while opening")if!@held||$held[0]!=$visible[0]||$held[1]!=$visible[1]||!S_ISREG($held[2])||$held[4]!=$<||($held[2]&0022)||(!$allow_links&&$held[3]!=1);
        binmode$fh;local$/;my$raw=<$fh>//q();close$fh or fail("cannot close $path");my@after=lstat$leaf;
        fail("$path changed while reading")if!@after||$after[0]!=$held[0]||$after[1]!=$held[1];return$raw});
}

sub read_leaf {
    my($leaf,$allow_links,$label)=@_;my@visible=lstat$leaf;fail("missing $label: $leaf")if!@visible;
    fail("unsafe $label: $leaf")if S_ISLNK($visible[2])||!S_ISREG($visible[2])||$visible[4]!=$<||($visible[2]&0022)||(!$allow_links&&$visible[3]!=1);
    sysopen(my$fh,$leaf,O_RDONLY|O_NOFOLLOW)or fail("cannot read $label: $leaf");my@held=stat$fh;
    fail("$label changed while opening: $leaf")if!@held||$held[0]!=$visible[0]||$held[1]!=$visible[1];binmode$fh;local$/;my$raw=<$fh>//q();
    close$fh or fail("cannot close $label: $leaf");my@after=lstat$leaf;fail("$label changed while reading: $leaf")if!@after||$after[0]!=$held[0]||$after[1]!=$held[1];return$raw;
}

sub write_leaf_new {
    my($leaf,$raw,$mode,$label)=@_;fail("$label exists: $leaf")if-e$leaf||-l$leaf;
    sysopen(my$fh,$leaf,O_WRONLY|O_CREAT|O_EXCL|O_NOFOLLOW,0600)or fail("cannot create $label: $leaf");binmode$fh;
    my$ok=eval{my$hard=$ENV{P2T2C_TEST_DOCS_MIGRATE_HARD_EXIT_AT}//q();
        if(($hard eq'rewrite_tmp_partial'&&$label eq'rewrite temporary')||($hard eq'copy_tmp_partial'&&$label eq'copy temporary')){print{$fh}substr($raw,0,int(length($raw)/2)||1);POSIX::_exit(92)}
        print{$fh}$raw or fail("cannot write $label: $leaf");close$fh or fail("cannot close $label: $leaf");chmod$mode,$leaf or fail("cannot chmod $label: $leaf");1};
    my$error=$@;close$fh if!$ok;unlink$leaf if!$ok&&-f$leaf&&!-l$leaf;die$error if!$ok;return 1;
}

sub mode_of { my@st=file_stat($_[0],$_[1],q(file));return sprintf('%04o',$st[2]&07777) }
sub sibling { my($path,$name)=@_;my$dir=dirname($path);return$dir eq q(.)?$name:"$dir/$name" }

sub write_new {
    my($path,$raw,$mode)=@_;safe_rel($path,q(write target));ensure_dir(dirname$path);
    return in_directory(dirname($path),0,q(write parent),sub{my$leaf=basename$path;fail("write target exists: $path")if-e$leaf||-l$leaf;
        my$ok=eval{sysopen(my$fh,$leaf,O_WRONLY|O_CREAT|O_EXCL|O_NOFOLLOW,0600)or fail("cannot create $path");binmode$fh;
            print{$fh}$raw or fail("cannot write $path");close$fh or fail("cannot close $path");chmod$mode,$leaf or fail("cannot chmod $path");1};
        my$error=$@;unlink$leaf if!$ok&&-f$leaf&&!-l$leaf;die$error if!$ok;return 1});
}

sub write_atomic {
    my($path,$raw,$mode)=@_;$mode//=0600;safe_rel($path,q(write target));ensure_dir(dirname$path);
    return in_directory(dirname($path),0,q(write parent),sub{my$leaf=basename$path;if(-e$leaf||-l$leaf){my@st=lstat$leaf;fail("unsafe write target: $path")if!@st||S_ISLNK($st[2])||!S_ISREG($st[2])||$st[4]!=$<||$st[3]!=1||($st[2]&0022)}
        my$tmp=".p2t2c-migrate-write-$$-".int(rand 1_000_000);sysopen(my$fh,$tmp,O_WRONLY|O_CREAT|O_EXCL|O_NOFOLLOW,0600)or fail("cannot create write temporary for $path");binmode$fh;
        my$ok=eval{print{$fh}$raw or fail("cannot write temporary for $path");close$fh or fail("cannot close temporary for $path");chmod$mode,$tmp or fail("cannot chmod temporary for $path");
            rename$tmp,$leaf or fail("cannot install $path");1};my$error=$@;close$fh if!$ok;unlink$tmp if!$ok&&-f$tmp&&!-l$tmp;die$error if!$ok;return 1});
}

sub walk_files {
    my($root)=@_;return()if!-e$root&&!-l$root;check_dir($root,q(scan root));my@files;
    File::Find::find({no_chdir=>1,wanted=>sub{
        my$path=$File::Find::name;$path=~s{\A\./}{};my@st=lstat$File::Find::name;
        fail("unsafe migration source: $path")if!@st||S_ISLNK($st[2]);
        if(S_ISDIR($st[2])){fail("unsafe migration directory: $path")if$st[4]!=$<||($st[2]&0022);return}
        fail("unsafe migration leaf: $path")if!S_ISREG($st[2])||$st[4]!=$<||$st[3]!=1||($st[2]&0022);
        push@files,$path;
    }},$root);return sort@files;
}

sub text_candidate {
    my($path)=@_;return$path=~m{(?:\.(?:md|markdown|txt|rst|adoc|ya?ml|jsonc?|toml|ini|cfg|conf|properties|env|sh|bash|zsh|fish|pl|pm|py|rb|jsx?|tsx?|mjs|cjs|java|kt|go|rs|c|h|cpp|hpp|cs|php|xml|gradle)|(?:Makefile|Dockerfile))\z}i;
}

sub active_excluded {
    my($path,$excluded)=@_;return 1 if$excluded->{$path};
    return$path=~m{\A(?:\.git|\.p2t2c|docs/reference/archive|docs/submit_proposals|docs/adr|docs/change_packs|docs/closure|specs)(?:/|\z)};
}

sub git_active_files {
    my($excluded)=@_;my$prefix=q(.);my$hint=0;for(0..8){if(-e"$prefix/.git"||-l"$prefix/.git"){$hint=1;last}$prefix.='/..'}return undef if!$hint;
    open(my$probe,'-|','git','rev-parse','--is-inside-work-tree')or return undef;my$inside=<$probe>//q();return undef if!close$probe||$inside!~/true/;
    open(my$fh,'-|','git','ls-files','-z','--cached','--others','--exclude-standard','--','.')or return undef;binmode$fh;local$/="\0";my@files;
    while(defined(my$path=<$fh>)){$path=~s/\0\z//;next if$path eq q()||active_excluded($path,$excluded)||!text_candidate($path);safe_rel($path,q(active path));my@st=lstat$path;
        next if!@st;fail("unsafe active file: $path")if S_ISLNK($st[2])||!S_ISREG($st[2])||$st[4]!=$<||$st[3]!=1||($st[2]&0022);push@files,$path}
    return undef if!close$fh;my%seen;return[sort grep{!$seen{$_}++}@files];
}

sub active_files {
    my($excluded)=@_;check_root();my$tracked=git_active_files($excluded);return@$tracked if defined$tracked;my@files;
    File::Find::find({no_chdir=>1,wanted=>sub{
        my$path=$File::Find::name;$path=~s{\A\./}{};return if$path eq q(.);my@st=lstat$File::Find::name;fail("unsafe active path: $path")if!@st;
        if(S_ISDIR($st[2])){
            if(active_excluded($path,$excluded)||$path=~m{(?:\A|/)(?:node_modules|vendor|\.venv|venv|dist|build|target|coverage|\.cache)(?:/|\z)}){$File::Find::prune=1;return}
            fail("unsafe active directory: $path")if$st[4]!=$<||($st[2]&0022);return;
        }
        return if active_excluded($path,$excluded)||!text_candidate($path);
        fail("unsafe active file: $path")if S_ISLNK($st[2])||!S_ISREG($st[2])||$st[4]!=$<||$st[3]!=1||($st[2]&0022);push@files,$path;
    }},q(.));return sort@files;
}

sub active_runs {
    return()if!-d'.p2t2c/runs';check_dir('.p2t2c/runs',q(run root));opendir my$dh,'.p2t2c/runs'or fail(q(cannot inspect runs));
    my@runs=sort grep{$_ ne q(.)&&$_ ne q(..)&&$_ ne'.gitignore'}readdir$dh;closedir$dh;return@runs;
}

sub operation_reports {
    return()if!-d$ROOT;check_dir($ROOT,q(migration state root));opendir my$dh,$ROOT or fail(q(cannot list migration state root));my@ops=sort grep{$_ ne'.'&&$_ ne'..'}readdir$dh;closedir$dh;my@reports;
    for my$op(@ops){fail(q(unsafe migration operation id))if$op!~/\A[A-Za-z0-9._-]+\z/;my$dir="$ROOT/$op";check_dir($dir,q(migration operation));my$report="$dir/report.json";
        fail("migration operation lacks report: $dir")if!-f$report||-l$report;push@reports,$report}
    return@reports;
}

sub pending_reports {
    my@pending;return@pending if!-d$ROOT;
    for my$path(operation_reports()){my$r=eval{$JSON->decode(read_raw($path,0,q(migration report)))};fail("invalid migration report: $path")if$@||ref$r ne'HASH';validate_report($r,dirname$path);
        push@pending,$path if($r->{status}//q())=~/\A(?:applying|rolling_back)\z/}
    return@pending;
}

sub template_rollback_ready {
    my$lock=P2T2C::Documents::acquire_lock();my$error;my$ok=eval{
        my$reports=0;
        if(-d$ROOT){for my$path(operation_reports()){my$report=eval{$JSON->decode(read_raw($path,0,q(migration report)))};fail("invalid migration report: $path")if$@||ref$report ne'HASH';
            validate_report($report,dirname$path);fail("document layout must be rolled back first: $path")if($report->{status}//q())ne'rolled_back';$reports++;
            for my$move(@{$report->{moves}}){fail("document layout target still exists: $move->{target}")if-e$move->{target}||-l$move->{target};fail("document layout source is not restored: $move->{source}")if!-f$move->{source}||-l$move->{source}}
        }}
        if(-d'docs/proposals'){fail(q(core proposal instances block template rollback))if grep{m{\Adocs/proposals/SP-[^/]+\.md\z}}walk_files('docs/proposals')}
        if(-d'docs/specs'){fail(q(core specs instances block template rollback))if grep{m{\Adocs/specs/[^/]+/(?:design|tasks)\.md\z}}walk_files('docs/specs')}
        for my$root(qw(docs/reference/archive/proposals docs/reference/archive/specs docs/reference/archive/adr docs/reference/archive/change_packs docs/reference/archive/closure)){
            next if!-d$root;my@files=walk_files($root);fail("migrated document layout blocks template rollback: $root")if@files;
        }1;
    };$error=$@if!$ok;my$released=eval{P2T2C::Documents::release_lock($lock);1};$error.=$@if!$released;die$error if!$ok||!$released;return 1;
}

sub front_value {
    my($raw,$key)=@_;my($head)=$raw=~/\A---\n(.*?)\n---(?:\n|\z)/s;return undef if!defined$head;
    my@v=$head=~/^\Q$key\E:\s*(.*?)\s*$/mg;return@v==1?$v[0]:undef;
}

sub has_closure_report {
    my($cpk,$id)=@_;return 0 if!-d'docs/closure';
    for my$path(walk_files('docs/closure')){next if$path!~m{/CR-[^/]+\.md\z};my$raw=read_raw($path,0,q(closure report));
        next if(front_value($raw,q(change_pack))//q())ne$cpk||(front_value($raw,q(decision))//q())ne'CLOSE';
        my$schema=front_value($raw,q(schema_version))//q();return 1 if$schema=~/\A[12]\z/;return 1 if$schema eq'3'&&has_embedded_receipt($raw,$id);
    }
    return 0;
}

sub has_embedded_receipt {
    my($raw,$id)=@_;my($evidence)=$raw=~/<!--\s*p2t2c:evidence:start\s*-->(.*?)<!--\s*p2t2c:evidence:end\s*-->/s;return 0 if!defined$evidence;
    for my$line(split/\n/,$evidence){next if$line!~/^\s*\{/;my$obj=eval{$JSON->decode($line)};next if$@||ref$obj ne'HASH';
        return 1 if($obj->{work_id}//q())eq$id&&($obj->{receipt_type}//q())eq'closure'&&($obj->{evidence_completeness}//q())eq'complete'}return 0;
}

sub assert_closed_cpks {
    return if!-d'docs/change_packs';my@cpks;
    for my$path(walk_files('docs/change_packs')){next if$path!~m{/CPK-[^/]+\.md\z};push@cpks,$path;my$raw=read_raw($path,0,q(change pack));
        my$id=front_value($raw,q(id))//q();my$risk=front_value($raw,q(risk))//q();my$status=front_value($raw,q(status))//q();
        fail("legacy CPK is not closed: $path")if$id!~/\ACPK-[A-Za-z0-9._-]+\z/||$risk!~/\AR[12]\z/||$status ne'applied';
        my$closed=$risk eq'R2'?has_closure_report($path,$id):(has_embedded_receipt($raw,$id)||has_closure_report($path,$id));
        fail("legacy CPK is not closed: $path")if!$closed;
    }
    return if!@cpks;my$evidence='./.p2t2c/bin/p2t2c_evidence.pl';fail(q(missing legacy evidence validator))if!-f$evidence||-l$evidence;
    require $evidence;require P2T2C::Checker;my$checker=P2T2C::Checker->new(root=>q(.),cache=>0);my$method=$checker->methodology_values();
    $checker->validate_cpk($_,$method)for@cpks;
    if(-d'docs/closure'){$checker->validate_cr($_,$method)for grep{m{/CR-[^/]+\.md\z}}walk_files('docs/closure')}
    fail('legacy closure validation failed: '.join('; ',@{$checker->{errors}}))if@{$checker->{errors}};
}

sub expected_target {
    my($source)=@_;
    return'docs/proposals/'.basename($source)if$source=~m{\Adocs/submit_proposals/SP-[^/]+\.md\z};
    return'docs/reference/archive/proposals/'.($source=~s{\Adocs/submit_proposals/}{}r)if$source=~m{\Adocs/submit_proposals/};
    return'docs/reference/archive/specs/'.($source=~s{\Aspecs/}{}r)if$source=~m{\Aspecs/};
    return'docs/reference/archive/adr/'.($source=~s{\Adocs/adr/}{}r)if$source=~m{\Adocs/adr/};
    return'docs/reference/archive/change_packs/'.($source=~s{\Adocs/change_packs/}{}r)if$source=~m{\Adocs/change_packs/};
    return'docs/reference/archive/closure/'.($source=~s{\Adocs/closure/}{}r)if$source=~m{\Adocs/closure/};
    fail("report move is outside legacy document roots: $source");
}

sub load_map {
    my($path,$adrs)=@_;my%needed=map{$_=>1}@$adrs;
    fail(q(ADR migration requires --decision-map))if%needed&&!defined$path;
    return({},undef,[])if!defined$path;
    safe_rel($path,q(decision map));my$raw=read_raw($path,0,q(decision map));my$obj=eval{$JSON->decode($raw)};
    fail(q(invalid decision map))if$@||ref$obj ne'HASH';
    fail("unexpected decision mapping for $_")for grep{!$needed{$_}}keys%$obj;
    my%seen;my@bindings;
    for my$adr(sort keys%needed){
        my$ref=$obj->{$adr};fail("missing decision mapping for $adr")if!defined$ref||ref$ref||$ref!~m{\A(docs/sot/[A-Za-z0-9._/-]+\.md)#(DEC-[A-Za-z0-9._-]+)\z};
        my($target,$id)=($1,$2);fail("decision mapping is reused: $ref")if$seen{$ref}++;fail("decision target cannot be history: $target")if$target=~/(?:_HISTORY|\/history)\.md\z/i;
        my$truth=read_raw($target,0,q(decision target));fail("missing decision anchor $ref")if$truth!~/^#{2,6}\s+\Q$id\E(?:\s|:|：|\z)/m;
        push@bindings,{source=>$adr,ref=>$ref,path=>$target,digest=>digest($truth)};
    }
    return($obj,{path=>$path,digest=>digest($raw)},\@bindings);
}

sub transform {
    my($raw,$replace)=@_;my@tokens;my$index=0;
    for my$old(sort{length($b)<=>length($a)||$a cmp$b}keys%$replace){my$token="\x1eP2T2C".($index++)."\x1f";fail(q(reference input contains a reserved migration token))if index($raw,$token)>=0;
        if($raw=~s/(?<![A-Za-z0-9_.\/-])\Q$old\E/$token/g){push@tokens,[$token,$replace->{$old}]}}
    for my$pair(@tokens){$raw=~s/\Q$pair->[0]\E/$pair->[1]/g}return$raw;
}

sub apply_truth_digest_updates {
    my($raw,$updates)=@_;for my$old(sort keys%$updates){$raw=~s/\Q$old\E/$updates->{$old}/g}return$raw;
}

sub managed_path_set {
    my$raw=read_raw('.p2t2c/managed-files.txt',0,q(managed file inventory));my%managed;
    for my$line(split/\r?\n/,$raw){$line=~s/^\s+|\s+$//g;next if$line eq q()||$line=~/^#/;safe_rel($line,q(managed path));$managed{$line}=1}return\%managed;
}

sub apply_release_metadata_updates {
    my($raw,$path,$rewrites,$managed)=@_;return$raw if$path ne'.p2t2c/CHECKSUMS.sha256'&&$path ne'.p2t2c/lock.sha256';
    for my$rewrite(@$rewrites){my$target=$rewrite->{path};next if!$managed->{$target}||$target eq'.p2t2c/lock.sha256'||($path eq'.p2t2c/CHECKSUMS.sha256'&&$target eq'.p2t2c/CHECKSUMS.sha256');
        my$count=($raw=~s/^\Q$rewrite->{before_digest}\E  \Q$target\E\s*$/"$rewrite->{after_digest}  $target"/mge);
        fail("release metadata lacks digest binding for $target in $path")if$count!=1}
    return$raw;
}

sub has_legacy_reference {
    my($raw)=@_;my$root=qr{(?:docs/submit_proposals/|docs/adr/|docs/change_packs/|docs/closure/|specs/)};
    return 1 if$raw=~/(?<![A-Za-z0-9_.\/-])$root/;
    return 1 if$raw=~/(?:\A|[\s`'"(=:\[])\.{1,2}\/(?:\.\.\/)*$root/;return 0;
}

sub replacement_map {
    my($moves,$map)=@_;my%replace=map{$_->{source}=>$_->{target}}@$moves;$replace{$_}=$map->{$_}for keys%$map;
    $replace{'docs/submit_proposals/'}='docs/proposals/';
    $replace{'specs/'}='docs/reference/archive/specs/';
    $replace{'docs/adr/'}='docs/reference/archive/adr/';
    $replace{'docs/change_packs/'}='docs/reference/archive/change_packs/';
    $replace{'docs/closure/'}='docs/reference/archive/closure/';
    return\%replace;
}

sub build_plan {
    my(%args)=@_;my@runs=active_runs();fail('active legacy runs block migration: '.join(',',@runs))if@runs;assert_closed_cpks();
    my@moves;my%targets;
    for my$root(qw(docs/submit_proposals specs docs/adr docs/change_packs docs/closure)){
        for my$source(walk_files($root)){my$target=expected_target($source);safe_rel($target,q(migration target));
            check_existing_parent_prefix($target);fail("migration target already exists: $target")if-e$target||-l$target;fail("duplicate migration target: $target")if$targets{$target}++;
            push@moves,{source=>$source,target=>$target,digest=>digest(read_raw($source,0,q(migration source))),mode=>mode_of($source,0)};
        }
    }
    my@adrs=sort grep{$_->{source}=~m{\Adocs/adr/ADR-[^/]+\.md\z}}@moves;my@adr_paths=map{$_->{source}}@adrs;
    my($map,$map_input,$bindings)=load_map(@adr_paths?$args{decision_map}:undef,\@adr_paths);
    my$replace=replacement_map(\@moves,$map);
    my%excluded=defined$args{decision_map}?($args{decision_map}=>1):();my@active=active_files(\%excluded);my%truth_updates;
    for my$path(@active){next if$path!~m{\Adocs/sot/.+\.md\z}||$path=~m{(?:_HISTORY|/history)\.md\z|\Adocs/sot/manifest\.yaml\z}i;my$before=read_raw($path,0,q(active Truth));my$after=transform($before,$replace);
        $truth_updates{digest($before)}=digest($after)if$after ne$before}
    my@rewrites;
    for my$path(@active){my$before=read_raw($path,0,q(active reference));my$after=apply_truth_digest_updates(transform($before,$replace),\%truth_updates);fail("unresolved active legacy reference: $path")if has_legacy_reference($after);next if$after eq$before;
        push@rewrites,{path=>$path,before_digest=>digest($before),after_digest=>digest($after),before=>$before,after=>$after,mode=>mode_of($path,0)};
    }
    for my$move(@moves){next if$move->{source}!~m{\Adocs/submit_proposals/SP-[^/]+\.md\z};my$before=read_raw($move->{source},0,q(legacy proposal));my$after=apply_truth_digest_updates(transform($before,$replace),\%truth_updates);fail("unresolved legacy proposal reference: $move->{source}")if has_legacy_reference($after);next if$after eq$before;
        push@rewrites,{path=>$move->{target},before_digest=>digest($before),after_digest=>digest($after),before=>$before,after=>$after,mode=>$move->{mode}};
    }
    my$managed=managed_path_set();
    for my$metadata_path('.p2t2c/CHECKSUMS.sha256','.p2t2c/lock.sha256'){my$before=read_raw($metadata_path,0,q(release metadata));my$after=apply_release_metadata_updates($before,$metadata_path,\@rewrites,$managed);next if$after eq$before;
        push@rewrites,{path=>$metadata_path,before_digest=>digest($before),after_digest=>digest($after),before=>$before,after=>$after,mode=>mode_of($metadata_path,0)}}
    my%rewrite_after=map{$_->{path}=>$_->{after_digest}}@rewrites;for my$binding(@$bindings){$binding->{after_digest}=$rewrite_after{$binding->{path}}if$rewrite_after{$binding->{path}}}
    my%rewrite_seen;fail("duplicate rewrite path: $_->{path}")for grep{$rewrite_seen{$_->{path}}++}@rewrites;
    return{schema_version=>1,moves=>\@moves,rewrites=>\@rewrites,decision_map=>$map,decision_map_input=>$map_input,decision_bindings=>$bindings,truth_digest_updates=>\%truth_updates};
}

sub report_core {
    my($report)=@_;my$core={schema_version=>$report->{schema_version},operation_id=>$report->{operation_id},moves=>$report->{moves},rewrites=>$report->{rewrites},
        decision_map=>$report->{decision_map},decision_map_input=>$report->{decision_map_input},decision_bindings=>$report->{decision_bindings}};
    $core->{truth_digest_updates}=$report->{truth_digest_updates}if exists$report->{truth_digest_updates};return$core;
}

sub plan_digest { digest($JSON->encode(report_core($_[0]))) }

sub test_failure {
    my($point)=@_;my$wanted=$ENV{P2T2C_TEST_DOCS_MIGRATE_FAIL_AT}//q();return if$wanted eq q();
    fail(q(unsafe docs-migrate failure-injection point))if$wanted!~/\A(?:after_stage|after_rewrite|after_first_source_unlink|rollback_after_first_rewrite)\z/;
    fail("controlled failure at $point")if$wanted eq$point;
}

sub save_report {
    my($dir,$report)=@_;$report->{plan_digest}=plan_digest($report);write_atomic("$dir/report.json",$JSON->encode($report)."\n",0600);
}

sub rewrite_allowed {
    my($path)=@_;safe_rel($path,q(rewrite path));
    return 1 if$path eq'.p2t2c/CHECKSUMS.sha256'||$path eq'.p2t2c/lock.sha256';
    fail("unsafe rewrite scope: $path")if$path=~m{\A(?:\.git|\.p2t2c|docs/reference/archive|docs/submit_proposals|docs/adr|docs/change_packs|docs/closure|specs)(?:/|\z)};
    fail("unsupported rewrite file: $path")if!text_candidate($path);return 1;
}

sub validate_report {
    my($report,$dir)=@_;fail(q(invalid migration report object))if ref$report ne'HASH'||($report->{schema_version}//0)!=1||($report->{action}//q())ne'docs-migrate';
    fail(q(invalid migration report status))if($report->{status}//q())!~/\A(?:applying|applied|rolling_back|rolled_back)\z/;
    my$id=basename($dir);fail(q(migration report operation mismatch))if($report->{operation_id}//q())ne$id||$id!~/\A[A-Za-z0-9._-]+\z/;
    fail(q(migration report plan digest mismatch))if($report->{plan_digest}//q())!~$DIGEST||plan_digest($report)ne$report->{plan_digest};
    fail(q(invalid migration report arrays))if ref($report->{moves})ne'ARRAY'||ref($report->{rewrites})ne'ARRAY'||ref($report->{decision_map})ne'HASH'||ref($report->{decision_bindings})ne'ARRAY';
    if(defined(my$input=$report->{decision_map_input})){fail(q(invalid decision-map input binding))if ref$input ne'HASH'||($input->{digest}//q())!~$DIGEST;safe_rel($input->{path},q(decision-map input))}
    my(%sources,%targets,%move_by_target);
    for my$move(@{$report->{moves}}){fail(q(invalid migration move))if ref$move ne'HASH';my($source,$target)=@$move{qw(source target)};
        safe_rel($source,q(move source));safe_rel($target,q(move target));fail("invalid move mapping: $source")if expected_target($source)ne$target;
        fail("duplicate move source: $source")if$sources{$source}++;fail("duplicate move target: $target")if$targets{$target}++;
        fail("invalid move digest or mode: $source")if($move->{digest}//q())!~$DIGEST||($move->{mode}//q())!~/\A0[0-7]{3}\z/;$move_by_target{$target}=$move;
    }
    my@adrs=sort grep{m{\Adocs/adr/ADR-[^/]+\.md\z}}keys%sources;my%map=%{$report->{decision_map}};my%refs;
    fail("decision map keys do not match ADR moves")if join("\0",@adrs)ne join("\0",sort keys%map);
    for my$adr(@adrs){my$ref=$map{$adr};fail("invalid report decision mapping: $adr")if!defined$ref||ref$ref||$ref!~m{\Adocs/sot/[A-Za-z0-9._/-]+\.md#DEC-[A-Za-z0-9._-]+\z}||$refs{$ref}++}
    my%binding=map{ref($_)eq'HASH'&&defined($_->{source})?($_->{source}=>$_):()}@{$report->{decision_bindings}};
    fail(q(decision binding keys do not match decision map))if join("\0",sort keys%binding)ne join("\0",@adrs);
    for my$adr(@adrs){my$b=$binding{$adr};fail("invalid decision binding: $adr")if($b->{ref}//q())ne$map{$adr}||($b->{digest}//q())!~$DIGEST||($b->{ref}//q())!~m{\A(.*)#};fail("invalid decision binding path: $adr")if($b->{path}//q())ne$1;
        my($rewrite)=grep{$_->{path}eq$b->{path}}@{$report->{rewrites}};fail("invalid decision after-binding: $adr")if$rewrite&&exists($b->{after_digest})&&$b->{after_digest}ne$rewrite->{after_digest}||!$rewrite&&exists$b->{after_digest}}
    my$replace=replacement_map($report->{moves},\%map);my$truth_updates=$report->{truth_digest_updates}//{};fail(q(invalid Truth digest updates))if ref$truth_updates ne'HASH';
    fail(q(invalid Truth digest update))for grep{$_!~$DIGEST||($truth_updates->{$_}//q())!~$DIGEST}keys%$truth_updates;my%rewrites;
    for my$rewrite(@{$report->{rewrites}}){fail(q(invalid migration rewrite))if ref$rewrite ne'HASH';my$path=$rewrite->{path};rewrite_allowed($path);
        fail("duplicate rewrite path: $path")if$rewrites{$path}++;fail("invalid rewrite digest or mode: $path")if($rewrite->{before_digest}//q())!~$DIGEST||($rewrite->{after_digest}//q())!~$DIGEST||($rewrite->{mode}//q())!~/\A0[0-7]{3}\z/;
        fail("rewrite of a moved file is only allowed for active SP: $path")if$move_by_target{$path}&&$path!~m{\Adocs/proposals/SP-[^/]+\.md\z};
        my$backup="$dir/backup/".digest($path);my$before=read_raw($backup,0,q(rewrite backup));
        fail("rewrite backup digest mismatch: $path")if digest($before)ne$rewrite->{before_digest};
        my$derived=transform($before,$replace);$derived=apply_truth_digest_updates($derived,$truth_updates)if$path ne'.p2t2c/CHECKSUMS.sha256'&&$path ne'.p2t2c/lock.sha256';
        $derived=apply_release_metadata_updates($derived,$path,$report->{rewrites},managed_path_set());
        fail("rewrite transformation mismatch: $path")if digest($derived)ne$rewrite->{after_digest};
    }
    return{move_by_target=>\%move_by_target,rewrite_paths=>\%rewrites};
}

sub revalidate_bindings {
    my($report,$after_rewrite)=@_;if(my$input=$report->{decision_map_input}){my$raw=read_raw($input->{path},0,q(decision map));fail(q(decision map changed before apply))if digest($raw)ne$input->{digest}}
    for my$b(@{$report->{decision_bindings}}){my$raw=read_raw($b->{path},0,q(decision target));my$expected=$after_rewrite?($b->{after_digest}//$b->{digest}):$b->{digest};fail("decision target changed before apply: $b->{path}")if digest($raw)ne$expected;
        my($id)=$b->{ref}=~/#(DEC-[A-Za-z0-9._-]+)\z/;fail("decision anchor disappeared before apply: $b->{ref}")if$raw!~/^#{2,6}\s+\Q$id\E(?:\s|:|：|\z)/m}
}

sub cas_replace {
    my($path,$expected,$new_raw,$mode,$op)=@_;safe_rel($path,q(rewrite target));my$new_digest=digest($new_raw);
    return in_directory(dirname($path),0,q(rewrite parent),sub{my$leaf=basename$path;my$current=read_leaf($leaf,0,q(rewrite target));fail("rewrite input changed: $path")if digest($current)ne$expected;
        my$tag=digest($path);my$guard=".p2t2c-migrate-$op-$tag-original";my$tmp=".p2t2c-migrate-$op-$tag-new";
        fail("stale rewrite temporary exists: $path")if-e$guard||-l$guard||-e$tmp||-l$tmp;link$leaf,$guard or fail("cannot reserve rewrite original: $path");
        my$ok=eval{write_leaf_new($tmp,$new_raw,$mode,q(rewrite temporary));my@path=lstat$leaf;my@held=lstat$guard;
            fail("rewrite target changed before install: $path")if!@path||!@held||$path[0]!=$held[0]||$path[1]!=$held[1]||digest(read_leaf($leaf,1,q(rewrite target)))ne$expected;
            unlink$leaf or fail("cannot detach rewrite target: $path");
            POSIX::_exit(91)if($ENV{P2T2C_TEST_DOCS_MIGRATE_HARD_EXIT_AT}//q())eq'cas_after_detach';
            link$tmp,$leaf or fail($!==EEXIST?"concurrent rewrite target preserved: $path":"cannot install rewrite target: $path");
            fail("rewrite after-image mismatch: $path")if digest(read_leaf($leaf,1,q(rewrite after-image)))ne$new_digest;
            unlink$tmp or fail("cannot remove rewrite temporary: $path");unlink$guard or fail("cannot remove rewrite guard: $path");1};
        return 1 if$ok;my$error=$@;my$cleanup=eval{
            if(-f$leaf&&!-l$leaf){my$d=digest(read_leaf($leaf,1,q(rewrite recovery target)));
                if($d eq$new_digest){unlink$leaf or fail("cannot remove failed rewrite candidate: $path")}
                elsif($d ne$expected){fail("concurrent rewrite preserved; original remains at $guard")}}
            if(!-e$leaf&&-f$guard&&!-l$guard){link$guard,$leaf or fail("cannot restore rewrite original: $path")}
            if(-f$leaf&&!-l$leaf&&digest(read_leaf($leaf,1,q(restored rewrite)))eq$expected){unlink$guard if-f$guard&&!-l$guard;unlink$tmp if-f$tmp&&!-l$tmp;1}else{fail("rewrite original not restored: $path")}
        };$error.=$@if!$cleanup;die$error});
}

sub copy_temp_name { my($path,$op)=@_;return".p2t2c-migrate-$op-".digest($path)."-copy" }

sub publish_copy {
    my($path,$raw,$mode,$op)=@_;safe_rel($path,q(copy target));ensure_dir(dirname$path);my$expected=digest($raw);
    return in_directory(dirname($path),0,q(copy parent),sub{my$leaf=basename$path;my$tmp=copy_temp_name($path,$op);fail("copy target exists: $path")if-e$leaf||-l$leaf;
        if(-e$tmp||-l$tmp){fail("unsafe stale copy temporary: $path")if-l$tmp;my$d=digest(read_leaf($tmp,1,q(copy temporary)));unlink$tmp or fail("cannot remove stale copy temporary: $path")if$d ne$expected}
        write_leaf_new($tmp,$raw,$mode,q(copy temporary))if!-e$tmp;
        my@tmp=lstat$tmp;fail("copy temporary mismatch: $path")if digest(read_leaf($tmp,1,q(copy temporary)))ne$expected||sprintf('%04o',$tmp[2]&07777)ne sprintf('%04o',$mode);
        link$tmp,$leaf or fail($!==EEXIST?"concurrent copy target preserved: $path":"cannot publish copy target: $path");unlink$tmp or fail("cannot remove copy temporary: $path");
        my@leaf=lstat$leaf;fail("copy after-image mismatch: $path")if digest(read_leaf($leaf,0,q(copy after-image)))ne$expected||sprintf('%04o',$leaf[2]&07777)ne sprintf('%04o',$mode);return 1});
}

sub recover_copy_temporary {
    my($path,$expected,$mode,$op,$restore_leaf)=@_;my$tmp=copy_temp_name($path,$op);return if!-e$tmp&&! -l$tmp;safe_rel($path,q(copy recovery));
    in_directory(dirname($path),0,q(copy recovery parent),sub{my$leaf=basename$path;my$name=copy_temp_name($path,$op);fail("unsafe copy recovery temporary: $path")if-l$name;
        my@tmp=lstat$name;my$raw=read_leaf($name,1,q(copy recovery temporary));
        if(digest($raw)ne$expected||sprintf('%04o',$tmp[2]&07777)ne$mode){unlink$name or fail("cannot remove incomplete copy temporary: $path");return 1}
        if($restore_leaf){
            if(!-e$leaf&&! -l$leaf){link$name,$leaf or fail("cannot restore interrupted copy: $path")}
            else{my@leaf=lstat$leaf;fail("interrupted copy conflicts: $path")if-l$leaf||digest(read_leaf($leaf,1,q(copy recovery leaf)))ne$expected||sprintf('%04o',$leaf[2]&07777)ne$mode}
        }
        unlink$name or fail("cannot clean copy recovery temporary: $path");return 1});
}

sub recover_rewrite_artifacts {
    my($report,$dir,$rewrite)=@_;my$path=$rewrite->{path};my$tag=digest($path);my$op=$report->{operation_id};my$guard=".p2t2c-migrate-$op-$tag-original";
    my$tmp=".p2t2c-migrate-$op-$tag-new";my$recovery=".p2t2c-migrate-$op-$tag-recover";my$before=read_raw("$dir/backup/".digest($path),0,q(rewrite backup));
    my$before_digest=$rewrite->{before_digest};my$after_digest=$rewrite->{after_digest};
    in_directory(dirname($path),0,q(rewrite recovery parent),sub{my$leaf=basename$path;return 1 if!-e$guard&&! -l$guard&&!-e$tmp&&! -l$tmp&&!-e$recovery&&! -l$recovery;
        my$before_source;
        for my$name($guard,$tmp,$recovery){next if!-e$name&&! -l$name;fail("unsafe rewrite recovery artifact: $path")if-l$name;my@st=lstat$name;my$d=digest(read_leaf($name,1,q(rewrite recovery artifact)));
            if(($name eq$recovery||$name eq$tmp)&&($d ne$before_digest&&$d ne$after_digest||sprintf('%04o',$st[2]&07777)ne$rewrite->{mode})){unlink$name or fail("cannot remove incomplete rewrite recovery temporary: $path");next}
            fail("rewrite recovery artifact mismatch: $path")if$d ne$before_digest&&$d ne$after_digest||sprintf('%04o',$st[2]&07777)ne$rewrite->{mode};$before_source=$name if$d eq$before_digest}
        my$current;if(-e$leaf||-l$leaf){fail("unsafe rewrite recovery leaf: $path")if-l$leaf;$current=digest(read_leaf($leaf,1,q(rewrite recovery leaf)));fail("rewrite recovery conflict: $path")if$current ne$before_digest&&$current ne$after_digest}
        if(!defined$before_source){
            if(-e$recovery&&!-l$recovery){unlink$recovery or fail("cannot replace rewrite recovery temporary: $path")}
            write_leaf_new($recovery,$before,oct($rewrite->{mode}),q(rewrite recovery temporary));$before_source=$recovery;
        }
        if(!defined$current||$current ne$before_digest){unlink$leaf or fail("cannot detach interrupted rewrite: $path")if defined$current;link$before_source,$leaf or fail("cannot restore interrupted rewrite: $path")}
        for my$name($guard,$tmp,$recovery){unlink$name or fail("cannot clean rewrite recovery artifact: $path")if-e$name&&! -l$name}
        fail("rewrite recovery failed: $path")if digest(read_leaf($leaf,0,q(restored rewrite)))ne$before_digest;return 1});
}

sub remove_expected {
    my($path,$expected,$mode,$ignore_mode)=@_;safe_rel($path,q(remove target));
    return in_directory(dirname($path),0,q(remove parent),sub{my$leaf=basename$path;my$raw=read_leaf($leaf,0,q(remove target));my@st=lstat$leaf;
        fail("remove target changed: $path")if digest($raw)ne$expected||(!$ignore_mode&&sprintf('%04o',$st[2]&07777)ne$mode);unlink$leaf or fail("cannot remove $path");1});
}

sub expected_target_digest {
    my($report,$target)=@_;for my$rewrite(@{$report->{rewrites}}){return$rewrite->{after_digest}if$rewrite->{path}eq$target}
    for my$move(@{$report->{moves}}){return$move->{digest}if$move->{target}eq$target}fail("unknown move target: $target");
}

sub preflight_apply {
    my($report)=@_;revalidate_bindings($report,0);my%move_target=map{$_->{target}=>1}@{$report->{moves}};
    for my$move(@{$report->{moves}}){fail("migration source changed: $move->{source}")if digest(read_raw($move->{source},0,q(migration source)))ne$move->{digest}||mode_of($move->{source},0)ne$move->{mode};
        fail("migration target appeared: $move->{target}")if-e$move->{target}||-l$move->{target}}
    for my$rewrite(@{$report->{rewrites}}){next if$move_target{$rewrite->{path}};fail("rewrite input changed: $rewrite->{path}")if digest(read_raw($rewrite->{path},0,q(rewrite input)))ne$rewrite->{before_digest}||mode_of($rewrite->{path},0)ne$rewrite->{mode}}
}

sub preflight_rollback {
    my($report)=@_;my%rewrite=map{$_->{path}=>$_}@{$report->{rewrites}};
    for my$move(@{$report->{moves}}){fail("rollback source already exists: $move->{source}")if-e$move->{source}||-l$move->{source};my$expected=$rewrite{$move->{target}}?$rewrite{$move->{target}}{after_digest}:$move->{digest};
        fail("rollback target changed: $move->{target}")if digest(read_raw($move->{target},0,q(rollback target)))ne$expected||mode_of($move->{target},0)ne$move->{mode}}
    for my$rewrite(@{$report->{rewrites}}){fail("rollback rewrite changed: $rewrite->{path}")if digest(read_raw($rewrite->{path},0,q(rollback rewrite)))ne$rewrite->{after_digest}||mode_of($rewrite->{path},0)ne$rewrite->{mode}}
}

sub restore_legacy {
    my($report,$dir)=@_;my$id=$report->{operation_id};my%move_by_target=map{$_->{target}=>$_}@{$report->{moves}};
    my$pause_ms=$ENV{P2T2C_TEST_DOCS_MIGRATE_PAUSE_BEFORE_ROLLBACK_MS}//q();
    if(($report->{status}//q())eq'rolling_back'&&$pause_ms ne q()){
        fail(q(invalid rollback test pause))if$pause_ms!~/\A[1-9][0-9]{0,3}\z/||$pause_ms>5000;print STDERR "P2T2C_TEST_MARKER:before_rollback_mutation\n";select undef,undef,undef,$pause_ms/1000}
    for my$move(@{$report->{moves}}){recover_copy_temporary($move->{target},$move->{digest},$move->{mode},$id,0);recover_copy_temporary($move->{source},$move->{digest},$move->{mode},$id,1)}
    recover_rewrite_artifacts($report,$dir,$_)for@{$report->{rewrites}};
    my$restored_rewrites=0;for my$rewrite(reverse@{$report->{rewrites}}){my$path=$rewrite->{path};
        if(!-e$path&&! -l$path){my$move=$move_by_target{$path};next if$move&&-f$move->{source}&&digest(read_raw($move->{source},1,q(unstaged move source)))eq$move->{digest};fail("rollback rewrite target is missing: $path")}
        my$current=read_raw($path,1,q(rewrite rollback));my$d=digest($current);next if$d eq$rewrite->{before_digest};
        fail("rollback rewrite conflict: $path")if$d ne$rewrite->{after_digest};my$before=read_raw("$dir/backup/".digest($path),0,q(rewrite backup));cas_replace($path,$rewrite->{after_digest},$before,oct($rewrite->{mode}),$id);
        test_failure(q(rollback_after_first_rewrite))if($report->{status}//q())eq'rolling_back'&&++$restored_rewrites==1}
    for my$move(reverse@{$report->{moves}}){my($source,$target)=@$move{qw(source target)};
        if(!-e$target&&! -l$target){fail("rollback lost both move paths: $source")if!-f$source||digest(read_raw($source,1,q(unstaged move source)))ne$move->{digest};next}
        my$target_raw=read_raw($target,0,q(move rollback target));
        fail("rollback move target changed: $target")if digest($target_raw)ne$move->{digest}||mode_of($target,0)ne$move->{mode};
        if(-e$source||-l$source){fail("rollback source conflicts: $source")if digest(read_raw($source,0,q(move rollback source)))ne$move->{digest}}
        else{publish_copy($source,$target_raw,oct($move->{mode}),$id)}
        remove_expected($target,$move->{digest},$move->{mode},1);
    }
}

sub restore_applied {
    my($report,$dir)=@_;my$id=$report->{operation_id};my$replace=replacement_map($report->{moves},$report->{decision_map});my$truth_updates=$report->{truth_digest_updates}//{};my$managed=managed_path_set();my@errors;
    for my$move(@{$report->{moves}}){my($source,$target)=@$move{qw(source target)};my$ok=eval{
        if(!-e$target&&! -l$target){my$raw=read_raw($source,0,q(reapply source));fail("reapply source changed: $source")if digest($raw)ne$move->{digest};publish_copy($target,$raw,oct($move->{mode}),$id)}1};push@errors,$@if!$ok}
    for my$rewrite(@{$report->{rewrites}}){my$ok=eval{recover_rewrite_artifacts($report,$dir,$rewrite);my$path=$rewrite->{path};my$current=read_raw($path,0,q(reapply rewrite));my$d=digest($current);
        if($d eq$rewrite->{before_digest}){my$before=read_raw("$dir/backup/".digest($path),0,q(rewrite backup));my$after=transform($before,$replace);$after=apply_truth_digest_updates($after,$truth_updates)if$path ne'.p2t2c/CHECKSUMS.sha256'&&$path ne'.p2t2c/lock.sha256';
            $after=apply_release_metadata_updates($after,$path,$report->{rewrites},$managed);fail("reapply transformation mismatch: $path")if digest($after)ne$rewrite->{after_digest};cas_replace($path,$rewrite->{before_digest},$after,oct($rewrite->{mode}),$id)}
        elsif($d ne$rewrite->{after_digest}){fail("concurrent rewrite remains outside the migration image: $path")}1};push@errors,$@if!$ok}
    for my$move(@{$report->{moves}}){my$ok=eval{my$expected=expected_target_digest($report,$move->{target});fail("reapply target mismatch: $move->{target}")if digest(read_raw($move->{target},0,q(reapply target)))ne$expected||mode_of($move->{target},0)ne$move->{mode};
        remove_expected($move->{source},$move->{digest},$move->{mode})if-e$move->{source}&&! -l$move->{source};1};push@errors,$@if!$ok}
    fail('cannot restore applied migration state: '.join(q(; ),@errors))if@errors;return 1;
}

sub cleanup_empty_legacy_dirs {
    my@dirs=qw(docs/submit_proposals specs docs/adr docs/change_packs docs/closure/evidence docs/closure);
    for my$root(@dirs){next if!-d$root||-l$root;my@subdirs;
        File::Find::find({no_chdir=>1,wanted=>sub{push@subdirs,$File::Find::name if-d$File::Find::name&&!-l$File::Find::name}},$root);
        for my$dir(sort{length($b)<=>length($a)}@subdirs){rmdir$dir if-d$dir&&!-l$dir}
    }
}

sub recover_pending {
    return if!-d$ROOT;for my$path(operation_reports()){my$report=eval{$JSON->decode(read_raw($path,0,q(migration report)))};fail("invalid migration report: $path")if$@||ref$report ne'HASH';my$dir=dirname$path;validate_report($report,$dir);
        next if($report->{status}//q())!~/\A(?:applying|rolling_back)\z/;restore_legacy($report,$dir);$report->{status}='rolled_back';$report->{rolled_back_at}=strftime('%Y-%m-%dT%H:%M:%SZ',gmtime);save_report($dir,$report)}
}

sub public_plan {
    my($plan,$mode,$status)=@_;return{action=>'docs-migrate',mode=>$mode,status=>$status,moves=>$plan->{moves},
        rewrites=>[map{{path=>$_->{path},before_digest=>$_->{before_digest},after_digest=>$_->{after_digest},mode=>$_->{mode}}}@{$plan->{rewrites}}],
        decision_map=>$plan->{decision_map},decision_map_input=>$plan->{decision_map_input},decision_bindings=>$plan->{decision_bindings},truth_digest_updates=>$plan->{truth_digest_updates}};
}

sub dry_run {
    my(%args)=@_;my@pending=pending_reports();fail('unfinished migration requires apply/rollback recovery: '.join(',',@pending))if@pending;
    my$plan=build_plan(%args);my$status=@{$plan->{moves}}||@{$plan->{rewrites}}?'planned':'not_applicable';return public_plan($plan,'dry-run',$status);
}

sub apply {
    my(%args)=@_;my$lock=P2T2C::Documents::acquire_lock();my($result,$error,$active,$dir);
    my$ok=eval{
        recover_pending();my$plan=build_plan(%args);if(!@{$plan->{moves}}&&!@{$plan->{rewrites}}){$result=public_plan($plan,'apply','not_applicable');return 1}
        ensure_dir($ROOT);my$id=strftime('%Y%m%dT%H%M%SZ',gmtime)."-$$-".int(rand 1_000_000);$dir="$ROOT/$id";ensure_dir($dir);ensure_dir("$dir/backup");
        $active={action=>'docs-migrate',mode=>'apply',schema_version=>1,operation_id=>$id,status=>'applying',created_at=>strftime('%Y-%m-%dT%H:%M:%SZ',gmtime),
            moves=>$plan->{moves},rewrites=>[map{{path=>$_->{path},before_digest=>$_->{before_digest},after_digest=>$_->{after_digest},mode=>$_->{mode}}}@{$plan->{rewrites}}],
            decision_map=>$plan->{decision_map},decision_map_input=>$plan->{decision_map_input},decision_bindings=>$plan->{decision_bindings},truth_digest_updates=>$plan->{truth_digest_updates}};
        for my$rewrite(@{$plan->{rewrites}}){write_new("$dir/backup/".digest($rewrite->{path}),$rewrite->{before},0600)}save_report($dir,$active);validate_report($active,$dir);preflight_apply($active);
        for my$move(@{$active->{moves}}){my$raw=read_raw($move->{source},0,q(migration source));publish_copy($move->{target},$raw,oct($move->{mode}),$id)}test_failure(q(after_stage));
        for my$rewrite(@{$plan->{rewrites}}){cas_replace($rewrite->{path},$rewrite->{before_digest},$rewrite->{after},oct($rewrite->{mode}),$id)}test_failure(q(after_rewrite));revalidate_bindings($active,1);
        my$unlinked=0;for my$move(@{$active->{moves}}){my$expected=expected_target_digest($active,$move->{target});fail("migration after-image mismatch: $move->{target}")if digest(read_raw($move->{target},0,q(migration after-image)))ne$expected;
            fail("migration target mode changed: $move->{target}")if mode_of($move->{target},0)ne$move->{mode};remove_expected($move->{source},$move->{digest},$move->{mode});test_failure(q(after_first_source_unlink))if++$unlinked==1}
        revalidate_bindings($active,1);cleanup_empty_legacy_dirs();P2T2C::Documents::validate_layout();$active->{status}='applied';$active->{applied_at}=strftime('%Y-%m-%dT%H:%M:%SZ',gmtime);save_report($dir,$active);$result={%$active,report=>"$dir/report.json"};1;
    };$error=$@if!$ok;
    if(!$ok&&$active&&$dir){my$recovered=eval{validate_report($active,$dir);restore_legacy($active,$dir);$active->{status}='rolled_back';$active->{rolled_back_at}=strftime('%Y-%m-%dT%H:%M:%SZ',gmtime);save_report($dir,$active);1};$error.=$@if!$recovered}
    my$released=eval{P2T2C::Documents::release_lock($lock);1};$error.=$@if!$released;die$error if!$ok||!$released;return$result;
}

sub rollback {
    my($path)=@_;safe_rel($path,q(report));fail("report must be inside $ROOT")if$path!~m{\A\Q$ROOT\E/[A-Za-z0-9._-]+/report\.json\z};
    my$lock=P2T2C::Documents::acquire_lock();my($result,$error,$active_report,$active_dir,$rolling);my$ok=eval{
        recover_pending();my$report=$JSON->decode(read_raw($path,0,q(migration report)));my$dir=dirname$path;validate_report($report,$dir);
        fail(q(migration report is not applied))if($report->{status}//q())ne'applied';preflight_rollback($report);
        $active_report=$report;$active_dir=$dir;$report->{status}='rolling_back';save_report($dir,$report);$rolling=1;restore_legacy($report,$dir);$report->{status}='rolled_back';$report->{rolled_back_at}=strftime('%Y-%m-%dT%H:%M:%SZ',gmtime);save_report($dir,$report);$result=$report;1;
    };$error=$@if!$ok;
    if(!$ok&&$rolling&&$active_report){my$reapplied=eval{restore_applied($active_report,$active_dir);1};my$reapply_error=$@;
        $active_report->{status}='applied';delete$active_report->{rolled_back_at};
        if($reapplied){delete$active_report->{rollback_recovery_error_digest}}
        else{$active_report->{rollback_recovery_error_digest}=digest($reapply_error);$error.=$reapply_error}
        my$saved=eval{save_report($active_dir,$active_report);1};$error.=$@if!$saved}
    my$released=eval{P2T2C::Documents::release_lock($lock);1};$error.=$@if!$released;die$error if!$ok||!$released;return$result;
}

1;
