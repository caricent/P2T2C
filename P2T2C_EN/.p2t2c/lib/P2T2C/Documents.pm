package P2T2C::Documents;
use strict;
use warnings;

use Digest::SHA qw(sha256_hex);
use Fcntl qw(:mode O_RDONLY O_WRONLY O_CREAT O_EXCL O_NOFOLLOW);
use File::Basename qw(dirname basename);
use JSON::PP ();
use Errno qw(EEXIST);

my $JSON = JSON::PP->new->canonical(1)->utf8(1);
my $DIGEST = qr/\A[0-9a-f]{64}\z/;

sub fail { die "ERROR: documents: $_[0]\n" }

sub safe_rel {
    my ($path,$allow_missing,$label)=@_; $label//=q(path);
    fail("$label path is unsafe") if !defined($path)||$path eq q()||length($path)>512
        ||$path=~m{\A/|(?:\A|/)\.\.(?:/|\z)|//|[\x00-\x1f\x7f]};
    my $current=q(); my @parts=split m{/},$path;
    for my $i (0..$#parts) {
        $current=length($current)?"$current/$parts[$i]":$parts[$i];
        my @st=lstat($current);
        if(!@st){
            fail("$label has a missing parent: $current") if $i<$#parts||!$allow_missing;
            next;
        }
        fail("$label traverses a symlink: $current") if S_ISLNK($st[2]);
        fail("$label parent is not a directory: $current") if $i<$#parts&&!S_ISDIR($st[2]);
        fail("$label leaf is not a regular file: $current") if $i==$#parts&&!S_ISREG($st[2]);
    }
    return 1;
}

sub read_safe {
    my ($path,$label)=@_; $label//=q(file);
    safe_rel($path,0,$label);
    sysopen(my $fh,$path,O_RDONLY|O_NOFOLLOW) or fail("cannot open $label: $path");
    my @st=stat($fh);
    fail("$label has unsafe identity: $path") if !S_ISREG($st[2])||$st[3]!=1||$st[4]!=$<||($st[2]&0022);
    binmode $fh; local $/; my $raw=<$fh>//q(); close $fh or fail("cannot close $label: $path");
    my @visible=lstat($path);
    fail("$label changed while reading: $path") if !@visible||S_ISLNK($visible[2])||$visible[0]!=$st[0]||$visible[1]!=$st[1];
    return $raw;
}

sub safe_dir {
    my($path,$label)=@_;$label//=q(directory);
    fail("$label path is unsafe")if!defined($path)||$path eq q()||$path=~m{\A/|(?:\A|/)\.\.(?:/|\z)|//|[\x00-\x1f\x7f]};
    my$current=q();for my$part(split m{/},$path){$current=length($current)?"$current/$part":$part;my@st=lstat($current);
        fail("$label is missing or unsafe: $current")if!@st||S_ISLNK($st[2])||!S_ISDIR($st[2])||$st[4]!=$<||($st[2]&0022)}
    return 1;
}

sub acquire_lock {
    my$lock='.p2t2c/.documents-lock';my$owner="$lock/owner";
    if(-d$lock&&!-l$lock){my$pid=eval{my$r=read_safe($owner,q(document lock));$r=~s/\s+\z//;$r};
        fail(q(another document mutation owns the project))if defined($pid)&&$pid=~/\A[1-9][0-9]*\z/&&kill(0,$pid);
        unlink$owner if-f$owner&&!-l$owner;rmdir$lock or fail(q(stale document lock cannot be recovered));}
    mkdir$lock,0700 or fail(q(another document mutation owns the project));
    sysopen(my$fh,$owner,O_WRONLY|O_CREAT|O_EXCL|O_NOFOLLOW,0600)or fail(q(cannot record document lock owner));print{$fh}"$$\n";close$fh;
    return$lock;
}

sub release_lock {
    my$lock=$_[0]//'.p2t2c/.documents-lock';unlink"$lock/owner"or fail(q(cannot remove document lock owner));rmdir$lock or fail(q(cannot release document lock));
}

sub assert_no_pending_migration {
    my$root='.p2t2c/docs-migrate';return 1 if!-e$root&&! -l$root;
    safe_dir($root,q(document migration state));opendir my$dh,$root or fail(q(cannot list document migration state));
    my@ops=sort grep{$_ ne'.'&&$_ ne'..'}readdir$dh;closedir$dh;
    for my$op(@ops){fail(q(document migration operation id is unsafe))if$op!~/\A[A-Za-z0-9._-]+\z/;my$dir="$root/$op";safe_dir($dir,q(document migration operation));
        my$report="$dir/report.json";fail("document migration operation lacks a report: $dir")if!-f$report||-l$report;
        my$obj=eval{$JSON->decode(read_safe($report,q(document migration report)))};
        fail("document migration report is invalid: $report")if$@||ref$obj ne'HASH'||($obj->{action}//q())ne'docs-migrate'||($obj->{operation_id}//q())ne$op
            ||($obj->{status}//q())!~/\A(?:applying|applied|rolling_back|rolled_back)\z/;
        fail("unfinished document migration blocks this mutation: $report")if$obj->{status}=~/\A(?:applying|rolling_back)\z/;
    }
    return 1;
}

sub yaml_scalar {
    my ($raw)=@_; $raw//=q(); $raw=~s/^\s+|\s+$//g;
    if($raw=~/\A"/){my$v=eval{JSON::PP->new->allow_nonref(1)->decode($raw)};fail(q(invalid quoted scalar))if$@||ref$v;return$v}
    if($raw=~/\A'(.*)'\z/s){my$v=$1;$v=~s/''/'/g;return$v}
    return $raw;
}

sub frontmatter {
    my ($path)=@_; my $original=read_safe($path,q(document));my$raw=$original;$raw=~s/\r\n/\n/g;
    my($head,$body)=$raw=~/\A---\n(.*?)\n---\n?(.*)\z/s;
    fail("$path has malformed frontmatter") if !defined$head;
    my(%fm,%rawfm,%seen);
    for my $line(split/\n/,$head,-1){
        next if $line=~/^\s*(?:#.*)?$/;
        my($key,$value)=$line=~/^([A-Za-z0-9_]+):[ \t]*(.*?)\s*$/;
        fail("$path frontmatter must use scalar fields") if !defined$key;
        fail("$path repeats frontmatter field: $key") if $seen{$key}++;
        $rawfm{$key}=$value;$fm{$key}=yaml_scalar($value);
    }
    return(\%fm,\%rawfm,$body,$original);
}

sub exact_fields {
    my($path,$fm,$required,$optional)=@_;
    my%allowed=map{$_=>1}(@$required,@$optional);
    fail("$path missing frontmatter field: $_") for grep{!exists$fm->{$_}}@$required;
    fail("$path has unsupported frontmatter field: $_") for grep{!$allowed{$_}}keys%$fm;
}

sub section {
    my($path,$body,@names)=@_;
    my$re=join q(|),map{quotemeta($_)}@names;
    my@matches=$body=~/^##\s+(?:$re)\s*\n(.*?)(?=^##\s+|\z)/gms;
    fail("$path must contain exactly one section: $names[0]") if @matches!=1;
    my$text=$matches[0];$text=~s/^\s+|\s+$//g;
    fail("$path section is empty: $names[0]") if $text eq q();
    return$text;
}

sub validate_proposal {
    my($path,$allow_legacy,$require_current)=@_;
    fail("proposal path is invalid: $path") if $path!~m{\Adocs/proposals/(SP-[0-9]{8}-[a-z0-9]+(?:-[a-z0-9]+)*)\.md\z};
    my$path_id=$1;my$raw=read_safe($path,q(proposal));
    if($raw!~/\A---\r?\n/){fail("$path legacy proposal heading is invalid")if!$allow_legacy||$raw!~/^#\s+\Q$path_id\E\s*$/m;return{path=>$path,legacy=>1,raw=>$raw}}
    my($fm,$rawfm,$body)=frontmatter($path);
    my@required=qw(artifact schema_version id status risk decision decision_ref specs_ref truth_ref truth_digest);
    exact_fields($path,$fm,\@required,[]);
    fail("$path artifact must be proposal") if $fm->{artifact}ne'proposal';
    fail("$path schema_version must be unquoted integer 1") if $rawfm->{schema_version}ne'1';
    fail("$path id does not match filename") if $fm->{id}ne$path_id;
    fail("$path status must be proposed or approved") if $fm->{status}!~/\A(?:proposed|approved)\z/;
    fail("$path risk must be R1 or R2") if $fm->{risk}!~/\AR[12]\z/;
    fail("$path decision is invalid") if $fm->{decision}!~/\A(?:not_required|pending|approved)\z/;
    fail("$path decision_ref is unsafe") if !defined($fm->{decision_ref})||ref($fm->{decision_ref})||length($fm->{decision_ref})>512||$fm->{decision_ref}=~/[\x00-\x1f\x7f]/;
    fail("$path specs_ref is invalid") if $fm->{specs_ref}!~m{\Adocs/specs/[0-9]{3,4}-[a-z0-9]+(?:-[a-z0-9]+)*\z};
    if($fm->{risk}eq'R1'){
        fail("$path R1 decision fields are invalid") if $fm->{decision}ne'not_required'||$fm->{decision_ref}ne'none';
        fail("$path R1 Truth fields must be none") if $fm->{truth_ref}ne'none'||$fm->{truth_digest}ne'none';
    } else {
        fail("$path R2 decision must be pending or approved") if $fm->{decision}!~/\A(?:pending|approved)\z/;
        fail("$path R2 truth_ref must point into docs/sot") if $fm->{truth_ref}!~m{\Adocs/sot/[A-Za-z0-9._/-]+\.md\z};
        if($fm->{decision}eq'pending'){
            fail("$path pending decision_ref/truth_digest must be none") if $fm->{decision_ref}ne'none'||$fm->{truth_digest}ne'none';
            fail("$path pending R2 cannot be approved") if $fm->{status}eq'approved';
        } else {
            fail("$path approved R2 requires decision_ref") if $fm->{decision_ref}eq'none';
            fail("$path approved R2 truth_ref cannot target history") if $fm->{truth_ref}=~/(?:_HISTORY|\/history)\.md\z/i;
            safe_rel($fm->{truth_ref},0,q(Truth));
            fail("$path approved R2 truth_digest is invalid") if $fm->{truth_digest}!~$DIGEST;
            if($require_current){my$manifest=read_safe('docs/sot/manifest.yaml',q(Truth manifest));my($declared)=$manifest=~/^\s*-\s+path:\s*"\Q$fm->{truth_ref}\E"\s*\n\s+sha256:\s*"([0-9a-f]{64})"\s*$/m;
                fail("$path approved R2 truth_ref is not indexed by the SOT manifest")if!defined$declared;
                fail("$path approved R2 truth_digest differs from the SOT manifest")if$declared ne$fm->{truth_digest};
                fail("$path approved R2 Truth digest is stale")if sha256_hex(read_safe($fm->{truth_ref},q(Truth)))ne$fm->{truth_digest};}
        }
    }
    section($path,$body,q(Why),q(为什么));
    section($path,$body,q(What changes),q(变更内容));
    section($path,$body,q(Non-goals),q(非目标));
    section($path,$body,q(Observable outcomes),q(可观察结果));
    section($path,$body,q(Truth impact),q(Truth 影响));
    section($path,$body,q(Decision),q(决策));
    return{path=>$path,fm=>$fm,body=>$body,raw=>$raw};
}

sub validate_design {
    my($path,$require_current)=@_;
    fail("design path is invalid: $path") if $path!~m{\A(docs/specs/[0-9]{3,4}-[a-z0-9]+(?:-[a-z0-9]+)*)/design\.md\z};
    my$dir=$1;my($fm,$rawfm,$body,$raw)=frontmatter($path);
    exact_fields($path,$fm,[qw(artifact schema_version proposal status)],[]);
    fail("$path artifact must be design") if $fm->{artifact}ne'design';
    fail("$path schema_version must be unquoted integer 1") if $rawfm->{schema_version}ne'1';
    fail("$path status must be draft or ready") if $fm->{status}!~/\A(?:draft|ready)\z/;
    my$proposal=validate_proposal($fm->{proposal},0,$require_current);
    fail("$path proposal points to a different specs directory") if $proposal->{fm}{specs_ref}ne$dir;
    section($path,$body,q(Context references),q(上下文引用));
    section($path,$body,q(Technical decisions),q(技术决策));
    section($path,$body,q(Interfaces and data flow),q(接口与数据流));
    section($path,$body,q(Data or migration design),q(数据或迁移设计));
    section($path,$body,q(Risks and trade-offs),q(风险与权衡));
    section($path,$body,q(Open questions),q(未决问题));
    return{path=>$path,dir=>$dir,fm=>$fm,proposal=>$proposal,body=>$body,raw=>$raw};
}

sub task_entries {
    my($path,$body)=@_;my$task_text=section($path,$body,q(Tasks),q(任务));
    my@entries;
    for my$line(split/\n/,$task_text){
        next if $line=~/^\s*(?:#.*)?$/;
        my($state,$text)=$line=~/^\s*-\s+\[([ xX-])\]\s+(.+?)\s*$/;
        fail("$path Tasks may contain only checkbox items") if !defined$state;
        $state=lc$state;$state='x' if $state eq'x';
        if($state eq'-'){
            my($ref)=$text=~/(?:ref|decision)\s*:\s*([A-Za-z0-9][A-Za-z0-9._:\/#-]*)/i;
            ($ref)=$text=~/依据(?:：|:)\s*([A-Za-z0-9][A-Za-z0-9._:\/#-]*)/ if !defined$ref;
            fail("$path deferred task lacks a stable user-decision reference")
                if !defined($ref)||lc($ref)=~/\A(?:none|pending|not_required|unknown)\z/;
        }
        push@entries,{state=>$state,text=>$text};
    }
    fail("$path must contain at least one task") if !@entries;
    return\@entries;
}

sub completion {
    my($path,$body)=@_;my$text=section($path,$body,q(Completion),q(完成记录));
    my%value;
    for my$key(qw(Tests Verify Known_blockers Dangerous_operations Authorization_ref Summary)){
        my$label=$key;$label=~s/_/ /g;
        my@v=$text=~/^-\s+\Q$label\E:\s*(.+?)\s*$/gmi;
        fail("$path Completion must contain exactly one $label") if @v!=1||$v[0]eq q();
        $value{$key}=$v[0];
    }
    fail("$path Tests value is invalid") if $value{Tests}!~/\A(?:not_run|passed|failed)\z/;
    fail("$path Verify value is invalid") if $value{Verify}!~/\A(?:not_run|clear|critical)\z/;
    fail("$path Known blockers value is invalid") if $value{Known_blockers}!~/\A(?:none|present)\z/;
    fail("$path Dangerous operations value is invalid") if $value{Dangerous_operations}!~/\A(?:none|pending|approved)\z/;
    fail("$path authorization binding is invalid") if ($value{Dangerous_operations}eq'approved')==($value{Authorization_ref}eq'none');
    fail("$path approved dangerous operation lacks a stable authorization reference")
        if $value{Dangerous_operations}eq'approved'&&lc($value{Authorization_ref})=~/\A(?:pending|unknown|not_required)\z/;
    return\%value;
}

sub validate_tasks {
    my($path,$require_complete,$force_truth_current)=@_;
    fail("tasks path is invalid: $path") if $path!~m{\A(docs/specs/[0-9]{3,4}-[a-z0-9]+(?:-[a-z0-9]+)*)/tasks\.md\z};
    my$dir=$1;my($fm,$rawfm,$body,$raw)=frontmatter($path);
    exact_fields($path,$fm,[qw(artifact schema_version proposal design status)],[]);
    fail("$path artifact must be implementation_tasks") if $fm->{artifact}ne'implementation_tasks';
    fail("$path schema_version must be unquoted integer 1") if $rawfm->{schema_version}ne'1';
    fail("$path status is invalid") if $fm->{status}!~/\A(?:planned|in_progress|completed)\z/;
    fail("$path design reference mismatch") if $fm->{design}ne"$dir/design.md";
    my$require_truth_current=$force_truth_current||($require_complete&&$fm->{status}ne'completed');
    my$design=validate_design($fm->{design},$require_truth_current);
    fail("$path proposal reference mismatch") if $fm->{proposal}ne$design->{fm}{proposal};
    my$entries=task_entries($path,$body);my$completion=completion($path,$body);
    if($require_complete||$fm->{status}eq'completed'){
        fail("$path cannot complete from planned status") if $require_complete&&$fm->{status}eq'planned';
        fail("$path contains incomplete tasks") if grep{$_->{state}eq' '}@$entries;
        fail("$path proposal is not approved") if $design->{proposal}{fm}{status}ne'approved';
        fail("$path design is not ready") if $design->{fm}{status}ne'ready';
        fail("$path records failed tests") if $completion->{Tests}eq'failed';
        fail("$path records unresolved Verify Critical") if $completion->{Verify}eq'critical';
        fail("$path records known blockers") if $completion->{Known_blockers}ne'none';
        fail("$path records pending dangerous operations") if $completion->{Dangerous_operations}eq'pending';
        fail("$path completion summary is still pending") if lc($completion->{Summary})eq'pending';
    }
    return{path=>$path,dir=>$dir,fm=>$fm,design=>$design,entries=>$entries,completion=>$completion,body=>$body,raw=>$raw};
}

sub validate_layout {
    return 1 if !-d'docs/proposals'&&!-d'docs/specs';
    my@proposals;
    if(-d'docs/proposals'){
        opendir my$pdh,'docs/proposals' or fail(q(cannot list docs/proposals));my@names=sort grep{$_ ne'.'&&$_ ne'..'}readdir$pdh;closedir$pdh;
        for my$name(@names){next if$name eq'README.md';fail("docs/proposals contains an unsupported entry: $name")if$name!~/\ASP-[0-9]{8}-[a-z0-9]+(?:-[a-z0-9]+)*\.md\z/;
            push@proposals,validate_proposal("docs/proposals/$name",1)}
    }
    if(-d'docs/specs'){
        opendir my$dh,'docs/specs' or fail(q(cannot list docs/specs));
        my@names=sort grep{$_ ne'.'&&$_ ne'..'&&$_ ne'README.md'}readdir$dh;closedir$dh;
        for my$name(@names){
            my$dir="docs/specs/$name";my@st=lstat($dir);
            fail("$dir is not a safe directory") if !@st||!S_ISDIR($st[2])||S_ISLNK($st[2])||$st[4]!=$<||($st[2]&0022);
            opendir my$sdh,$dir or fail("cannot list $dir");my@files=sort grep{$_ ne'.'&&$_ ne'..'}readdir$sdh;closedir$sdh;
            fail("$dir must contain exactly design.md and tasks.md") if join(q(,),@files)ne'design.md,tasks.md';
            validate_tasks("$dir/tasks.md",0);
        }
    }
    for my$proposal(@proposals){next if$proposal->{legacy};my$dir=$proposal->{fm}{specs_ref};fail("$proposal->{path} references missing specs directory: $dir")if!-d$dir}
    return 1;
}

sub install_candidate {
    my($path,$raw,$expected)=@_;my$dir=dirname($path);safe_dir($dir,q(write parent));my@before=lstat($path);
    fail(q(document disappeared before Archive))if!@before;
    my$nonce="$$-".int(rand(1_000_000));my$tmp="$dir/.p2t2c-doc-new-$nonce";my$guard="$dir/.p2t2c-doc-original-$nonce";
    my$ok=eval{
        sysopen(my$fh,$tmp,O_WRONLY|O_CREAT|O_EXCL|O_NOFOLLOW,0600)or fail("cannot create temporary document");
        binmode$fh;print{$fh}$raw or fail(q(cannot write temporary document));close$fh or fail(q(cannot close temporary document));
        chmod($before[2]&07777,$tmp) or fail(q(cannot set document mode));
        rename($path,$guard)or fail(q(cannot reserve original document));
        fail(q(document changed during Archive))if sha256_hex(read_safe($guard,q(original document)))ne sha256_hex($expected);
        link($tmp,$path)or fail($!==EEXIST?q(concurrent document preserved):q(cannot install document candidate));
        unlink$tmp or fail(q(cannot remove linked candidate));
        fail(q(installed document candidate is invalid))if sha256_hex(read_safe($path,q(candidate document)))ne sha256_hex($raw);1;
    };
    return$guard if$ok;my$error=$@;my$cleanup=eval{my$conflict;
        if(-e$guard&&!-l$guard){
            if(!-e$path){rename($guard,$path)or fail(q(cannot restore original document))}
            elsif(-f$path&&!-l$path){my$d=sha256_hex(read_safe($path,q(Archive recovery document)));
                if($d eq sha256_hex($raw)){unlink$path or fail(q(cannot remove failed candidate));rename($guard,$path)or fail(q(cannot restore original document))}
                elsif($d ne sha256_hex($expected)){$conflict="$dir/.p2t2c-doc-conflict-original-$nonce";rename($guard,$conflict)or fail(q(cannot preserve original after concurrent edit))}
                else{unlink$guard or fail(q(cannot remove duplicate Archive guard))}}
        }
        unlink$tmp if-f$tmp&&!-l$tmp;$error.="ERROR: documents: original preserved at $conflict\n"if defined$conflict;1;
    };$error.=$@if!$cleanup;die$error;
}

sub rollback_candidate {
    my($path,$guard,$candidate)=@_;my$dir=dirname($path);
    if(!-e$path){rename$guard,$path or fail(q(cannot restore original document));return}
    if(-f$path&&!-l$path&&sha256_hex(read_safe($path,q(candidate document)))eq sha256_hex($candidate)){unlink$path or fail(q(cannot remove failed candidate));rename$guard,$path or fail(q(cannot restore original document));return}
    my$conflict="$dir/.p2t2c-doc-conflict-original-$$-".int(rand(1_000_000));rename$guard,$conflict or fail(q(cannot preserve original after concurrent edit));
    fail("concurrent document edit preserved; original preserved at $conflict");
}

sub remove_archive_temp {
    my($tmp)=@_;my@st=lstat$tmp;return if!@st;
    fail(q(interrupted Archive temporary is unsafe))if S_ISLNK($st[2])||!S_ISREG($st[2])||$st[4]!=$<||($st[2]&0022);
    unlink$tmp or fail(q(cannot clean interrupted Archive temporary));
}

sub recover_archive_guard {
    my($path)=@_;my$dir=dirname($path);my@guards=glob("$dir/.p2t2c-doc-original-*");my@temps=glob("$dir/.p2t2c-doc-new-*");
    if(!@guards){remove_archive_temp($_)for@temps;return}
    fail(q(multiple interrupted Archive guards require manual recovery))if@guards>1;my$guard=$guards[0];
    if(!-e$path){rename$guard,$path or fail(q(cannot restore interrupted Archive));remove_archive_temp($_)for@temps;return}
    my$doc=eval{validate_tasks($path,1,1)};
    if($doc&&$doc->{fm}{status}eq'completed'){
        my$original=read_safe($guard,q(interrupted Archive original));my$expected=$original;
        $expected=~s/^(status:\h*)in_progress(\h*)(\r?)$/${1}completed${2}${3}/m
            or fail(q(interrupted Archive original lacks in_progress status));
        if(sha256_hex($expected)eq sha256_hex($doc->{raw})){unlink$guard or fail(q(cannot clean completed Archive guard));remove_archive_temp($_)for@temps;return}
        rollback_candidate($path,$guard,$doc->{raw});remove_archive_temp($_)for@temps;
        fail(q(concurrent edit to the Archive original was restored));
    }
    fail("interrupted Archive conflicts with current tasks; original preserved at $guard");
}

sub archive_test_pause {
    my$ms=$ENV{P2T2C_TEST_ARCHIVE_PAUSE_BEFORE_FINAL_CHECK_MS}//q();return if$ms eq q();
    fail(q(invalid Archive test pause))if$ms!~/\A[1-9][0-9]{0,3}\z/||$ms>5000;
    print STDERR "P2T2C_TEST_MARKER:archive_before_final_check\n";
    select undef,undef,undef,$ms/1000;
}

sub archive_spec {
    my($spec)=@_;fail(q(invalid spec id))if!defined$spec||$spec!~/\A[0-9]{3,4}-[a-z0-9]+(?:-[a-z0-9]+)*\z/;
    my$path="docs/specs/$spec/tasks.md";recover_archive_guard($path);my$doc=validate_tasks($path,1);
    return{schema_version=>1,action=>'archive',state=>'completed',spec=>$spec,tasks=>$path,proposal=>$doc->{fm}{proposal},design=>$doc->{fm}{design},tests=>$doc->{completion}{Tests},verify=>$doc->{completion}{Verify},idempotent=>$JSON->true}if$doc->{fm}{status}eq'completed';
    fail("$path must be in_progress before archive") if $doc->{fm}{status}ne'in_progress';
    my$updated=$doc->{raw};$updated=~s/^(status:\h*)in_progress(\h*)(\r?)$/${1}completed${2}${3}/m
        or fail("$path lacks in_progress status");
    my$original=$doc->{raw};my$guard=install_candidate($path,$updated,$original);
    archive_test_pause();
    my$ok=eval{validate_tasks($path,1,1);1};
    if(!$ok){my$error=$@;my$rolled=eval{rollback_candidate($path,$guard,$updated);1};$error.=$@if!$rolled;die$error}
    if(sha256_hex(read_safe($guard,q(Archive original)))ne sha256_hex($original)){
        my$error=q(concurrent edit to the Archive original detected);my$rolled=eval{rollback_candidate($path,$guard,$updated);1};$error.=$@if!$rolled;fail($error)}
    if(!unlink$guard){my$e=q(cannot remove archived original guard);my$r=eval{rollback_candidate($path,$guard,$updated);1};$e.=$@if!$r;fail($e)}
    return{schema_version=>1,action=>'archive',state=>'completed',spec=>$spec,tasks=>$path,
        proposal=>$doc->{fm}{proposal},design=>$doc->{fm}{design},tests=>$doc->{completion}{Tests},
        verify=>$doc->{completion}{Verify}};
}

sub json { return $JSON }
1;
