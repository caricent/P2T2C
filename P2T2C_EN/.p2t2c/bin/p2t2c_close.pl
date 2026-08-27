#!/usr/bin/env perl
use strict;
use warnings;

use Digest::SHA qw(sha256_hex);
use Errno qw(EEXIST);
use Fcntl qw(:mode O_RDONLY O_WRONLY O_CREAT O_EXCL O_NOFOLLOW);
use File::Basename qw(dirname basename);
use File::Path qw(make_path);
use File::Spec ();
use Getopt::Long qw(GetOptions);
use JSON::PP ();
use MIME::Base64 qw(encode_base64 decode_base64);
use Time::HiRes qw(usleep);

my ($work_id,$profile,$risk_status,$risk_ref,$help)=(undef,undef,'none','none',0);
GetOptions('work-id=s'=>\$work_id,'verification-profile=s'=>\$profile,
    'remaining-risk-status=s'=>\$risk_status,'remaining-risk-ref=s'=>\$risk_ref,'help|h'=>\$help)
    or die "ERROR: invalid close arguments\n";
if ($help) {print "Usage: p2t2c_close.sh --work-id ID --verification-profile fast|impacted|full|governance [--remaining-risk-status none|recorded] [--remaining-risk-ref SAFE_REF]\n";exit 0}
die "ERROR: valid --work-id is required\n" if !defined($work_id)||$work_id!~/\A[A-Za-z0-9][A-Za-z0-9._-]*\z/;
die "ERROR: --verification-profile is required\n" if !defined($profile)||$profile!~/\A(?:fast|impacted|full|governance)\z/;
die "ERROR: --remaining-risk-status must be none or recorded\n" if $risk_status!~/\A(?:none|recorded)\z/;
die "ERROR: run from a safe project root\n" if !-d'.p2t2c'||-l'.p2t2c'||!-d'docs';

my $bin=dirname(File::Spec->rel2abs($0)); unshift @INC,File::Spec->catdir(dirname($bin),'lib');
my $evidence="$bin/p2t2c_evidence.pl"; require $evidence; require P2T2C::Checker;
my $json=JSON::PP->new->canonical(1)->utf8(1);
my $run_dir=".p2t2c/runs/$work_id"; my $contract="$run_dir/contract.json"; my $ledger="$run_dir/events.jsonl";
my $cpk="docs/change_packs/$work_id.md";
die "ERROR: missing or unsafe run state\n" if !-d$run_dir||-l$run_dir||!-f$contract||-l$contract||!-f$ledger||-l$ledger;
my $context=P2T2C::Evidence::validate_run_state($work_id,-f$cpk?$cpk:undef);
my $risk=$context->{risk}; my $shape=$context->{execution_shape}; my $target=$context->{evidence_target};
die "ERROR: spike work cannot close\n" if $shape eq 'spike';
my $change_pack='none';
if ($risk eq 'R0') {
    die "ERROR: R0 audit must not have a CPK\n" if -f$cpk;
    my $policy=P2T2C::Evidence::parse_project_policy();
    if ($risk_status eq 'none') {die "ERROR: R0 closure without residual risk requires p2t2c.r0.audit_mode: true\n" if !$policy->{r0_audit_mode};die "ERROR: remaining-risk-ref is only valid for recorded residual risk\n" if $risk_ref ne 'none'}
    else {die "ERROR: R0 residual-risk closure is disabled by project policy\n" if !$policy->{r0_closure_on_residual_risk};die "ERROR: recorded R0 risk requires --remaining-risk-ref SAFE_REF\n" if $risk_ref!~/\A[A-Za-z0-9][A-Za-z0-9._:\@\/-]{0,511}\z/||$risk_ref eq 'none'}
} elsif ($risk eq 'R1'||$risk eq 'R2') {
    die "ERROR: closure requires its CPK\n" if !-f$cpk;
    my $fresh=P2T2C::Evidence::parse_cpk($cpk,$work_id);
    die "ERROR: R1 close requires fresh status: ready\n" if $risk eq 'R1'&&$fresh->{status} ne 'ready';
    die "ERROR: R2 CPK must be applied before closure\n" if $risk eq 'R2'&&$fresh->{status} ne 'applied';
    die "ERROR: remaining-risk-ref is only supported for R0 residual-risk closure\n" if $risk_ref ne 'none';
    $change_pack=$cpk;
} else {die "ERROR: unsupported contract risk\n"}

my $token=substr(sha256_hex(join(':',$$,$work_id,time(),rand())),0,24); my $lock="$run_dir/.lifecycle-lock"; my $closing="$run_dir/.closing";
sub acquire_lock {for(1..200){if(mkdir($lock,0700)){sysopen(my$fh,"$lock/owner",O_WRONLY|O_CREAT|O_EXCL|O_NOFOLLOW,0600)or die"ERROR: cannot own lifecycle lock\n";print{$fh}$token,"\n";close$fh;return}usleep(100_000)}die"ERROR: timed out waiting for lifecycle lock\n"}
sub release_lock {unlink "$lock/owner" or die"ERROR: cannot release lifecycle owner\n";rmdir$lock or die"ERROR: cannot release lifecycle lock\n"}
acquire_lock(); opendir(my$rd,$run_dir)or die$!; my@active=grep{/^\.active-/}readdir$rd;closedir$rd;
if(@active||-e$closing){release_lock();die"ERROR: cannot close while verification/runner is active\n"}
sysopen(my$cm,$closing,O_WRONLY|O_CREAT|O_EXCL|O_NOFOLLOW,0600)or do{release_lock();die"ERROR: another close owns this run\n"};print{$cm}$token,"\n";close$cm;release_lock();

my ($candidate,$backup,$sidecar_tmp,$sidecar_created,$target_installed,$had_target,$committed,$quarantine,$run_quarantined,$target_txn,$target_initial_raw,$target_initial_mode)=('', '', '',0,0,0,0,'',0,undef,'',0644);
sub secure_temp {my($dir,$kind)=@_;for(1..64){my$p="$dir/.p2t2c-$kind-".substr(sha256_hex(join(':',$$,$kind,time(),rand(),$_)),0,24);if(sysopen(my$fh,$p,O_WRONLY|O_CREAT|O_EXCL|O_NOFOLLOW,0600)){return($p,$fh)}next if$!==EEXIST;die"ERROR: cannot create $kind: $!\n"}die"ERROR: cannot allocate $kind\n"}
sub quiet_system {my$pid=fork();die"ERROR: cannot fork quiet command\n"if!defined$pid;if($pid==0){open STDOUT,'>',File::Spec->devnull()or exit 255;open STDERR,'>&',\*STDOUT or exit 255;exec@_;exit 255}waitpid($pid,0);return$?}
sub held_sidecar_install {
    my($dir,$name,$raw)=@_;my$identity=P2T2C::Evidence::safe_directory_identity($dir,'sidecar parent');pipe(my$r,my$w)or die"ERROR: cannot create sidecar pipe\n";my$pid=fork();die"ERROR: cannot fork sidecar writer\n"if!defined$pid;
    if($pid==0){close$r;chdir($dir)or exit 91;my@dot=stat(q(.));exit 92 if"$dot[0]:$dot[1]"ne$identity;my$created=0;if(lstat($name)){sysopen(my$fh,$name,O_RDONLY|O_NOFOLLOW)or exit 93;my@st=stat($fh);exit 94 if!S_ISREG($st[2])||$st[3]!=1||$st[4]!=$<||($st[2]&0022);binmode$fh;local$/;my$old=<$fh>//'';close$fh;exit 95 if$old ne$raw}else{my$tmp='.p2t2c-sidecar-'.substr(sha256_hex(join(':',$$,time(),rand())),0,24);sysopen(my$fh,$tmp,O_WRONLY|O_CREAT|O_EXCL|O_NOFOLLOW,0600)or exit 96;binmode$fh;print{$fh}$raw or exit 97;close$fh or exit 98;link($tmp,$name)or exit 99;unlink($tmp)or exit 100;$created=1}sysopen(my$final,$name,O_RDONLY|O_NOFOLLOW)or exit 101;my@final=stat($final);exit 102 if!S_ISREG($final[2])||$final[3]!=1||$final[4]!=$<;binmode$final;local$/;my$final_raw=<$final>//'';close$final;exit 103 if$final_raw ne$raw;print{$w}join('|',$identity,$created,"$final[0]:$final[1]",$final[2]&0777);close$w;exit 0}
    close$w;local$/;my$result=<$r>//'';close$r;waitpid($pid,0);die"ERROR: held sidecar install failed\n"if$?!=0;my($dir_identity,$created,$file_identity,$mode)=split/\|/,$result,4;return($dir_identity,$created?1:0,$file_identity,0+$mode);
}
sub held_sidecar_remove {
    my($dir,$name,$identity,$file_identity,$mode,$digest)=@_;my$pid=fork();return 0 if!defined$pid;if($pid==0){chdir($dir)or exit 91;my@dot=stat(q(.));exit 92 if"$dot[0]:$dot[1]"ne$identity;sysopen(my$fh,$name,O_RDONLY|O_NOFOLLOW)or exit 93;my@st=stat($fh);exit 94 if!S_ISREG($st[2])||$st[3]!=1||$st[4]!=$<||"$st[0]:$st[1]"ne$file_identity||($st[2]&0777)!=$mode;binmode$fh;local$/;my$raw=<$fh>//'';close$fh;exit 95 if sha256_hex($raw)ne$digest;unlink($name)or exit 96;exit 0}waitpid($pid,0);return$?==0?1:0;
}
sub held_sidecar_commit_check {
    my($dir,$name,$identity,$file_identity,$mode,$digest)=@_;my$pid=fork();return 0 if!defined$pid;if($pid==0){chdir($dir)or exit 91;my@dot=stat(q(.));exit 92 if"$dot[0]:$dot[1]"ne$identity;sysopen(my$fh,$name,O_RDONLY|O_NOFOLLOW)or exit 93;my@st=stat($fh);exit 94 if!S_ISREG($st[2])||$st[3]!=1||$st[4]!=$<||"$st[0]:$st[1]"ne$file_identity||($st[2]&0777)!=$mode;binmode$fh;local$/;my$raw=<$fh>//'';close$fh;exit 95 if sha256_hex($raw)ne$digest;exit 0}waitpid($pid,0);return$?==0?1:0;
}
sub start_target_transaction {
    my($dir,$leaf)=@_;die"ERROR: unsafe target leaf\n"if$leaf!~/\A[A-Za-z0-9][A-Za-z0-9._-]{0,254}\z/;my$identity=P2T2C::Evidence::safe_directory_identity($dir,'target parent');my$absolute=File::Spec->rel2abs($dir);pipe(my$cmd_r,my$cmd_w)or die"ERROR: target transaction pipe failed\n";pipe(my$res_r,my$res_w)or die"ERROR: target transaction pipe failed\n";my$pid=fork();die"ERROR: target transaction fork failed\n"if!defined$pid;
    if($pid==0){close$cmd_w;close$res_r;select((select($res_w),$|=1)[0]);chdir($absolute)or exit 91;my@dot=stat(q(.));exit 92 if"$dot[0]:$dot[1]"ne$identity;my($initialized,$had,$original_raw,$original_mode,$original_devino,$candidate,$candidate_digest,$candidate_mode,$installed,$installed_devino,$installed_digest,$installed_mode)=(0,0,'',0644,'','','',0644,0,'','',0644);my$j=JSON::PP->new->canonical(1)->utf8(1);
        my$visible=sub{my@st=lstat($absolute);return@st&&S_ISDIR($st[2])&&!S_ISLNK($st[2])&&"$st[0]:$st[1]"eq$identity};
        my$read_leaf=sub{my($name)=@_;sysopen(my$fh,$name,O_RDONLY|O_NOFOLLOW)or return;my@st=stat($fh);return if!S_ISREG($st[2])||$st[3]!=1||$st[4]!=$<;binmode$fh;local$/;my$raw=<$fh>//'';close$fh;return($raw,$st[2]&0777,"$st[0]:$st[1]")};
        while(my$line=<$cmd_r>){my$q=eval{$j->decode($line)};last if$@||ref($q)ne'HASH';my$r={ok=>$j->true};my$op=$q->{op}//'';my$ok=eval{
            if($op eq'init'){die"repeat init"if$initialized;$initialized=1;if(lstat($leaf)){my($raw,$mode,$devino)=$read_leaf->($leaf);die"unsafe target"if!defined$raw;$had=1;$original_raw=$raw;$original_mode=$mode;$original_devino=$devino}$r->{had_target}=$had?$j->true:$j->false;$r->{raw}=encode_base64($original_raw,'');$r->{mode}=$original_mode;$r->{identity}=$identity}
            elsif($op eq'create'){die"not initialized"if!$initialized;die"target parent not visible"if!$visible->();my$raw=decode_base64($q->{raw}//'');$candidate_digest=sha256_hex($raw);$candidate_mode=($q->{mode}//0644)&0777;for(1..64){my$name='.p2t2c-candidate-'.substr(sha256_hex(join(':',$$,time(),rand(),$_)),0,24);if(sysopen(my$fh,$name,O_WRONLY|O_CREAT|O_EXCL|O_NOFOLLOW,0600)){binmode$fh;print{$fh}$raw or die"candidate write";close$fh or die"candidate close";chmod($candidate_mode,$name)or die"candidate mode";$candidate=$name;$r->{leaf}=$name;last}next if$!==EEXIST;die"candidate create"}die"candidate allocation"if!$candidate}
            elsif($op eq'read'){my$name=$q->{leaf}//$leaf;my($raw,$mode)=$read_leaf->($name);die"held target read failed"if!defined$raw;$r->{raw}=encode_base64($raw,'');$r->{mode}=$mode}
            elsif($op eq'install'){die"target parent not visible"if!$visible->();die"candidate mismatch"if!$candidate||($q->{leaf}//'')ne$candidate;if($had){my($raw,$ignored_mode,$devino)=$read_leaf->($leaf);die"original target changed"if!defined$raw||$devino ne$original_devino||sha256_hex($raw)ne sha256_hex($original_raw)}else{die"target appeared"if lstat($leaf)}rename($candidate,$leaf)or die"target install";$candidate='';$installed=1;my($raw,$mode,$devino)=$read_leaf->($leaf);die"installed target mismatch"if!defined$raw||sha256_hex($raw)ne$candidate_digest||$mode!=$candidate_mode;$installed_devino=$devino;$installed_digest=sha256_hex($raw);$installed_mode=$mode}
            elsif($op eq'visible'){die"target parent mapping changed"if!$visible->()}
            elsif($op eq'commit_check'){die"target parent mapping changed"if!$visible->();die"target is not installed"if!$installed;my($raw,$mode,$devino)=$read_leaf->($leaf);die"installed target leaf changed"if!defined$raw||$devino ne$installed_devino||$mode!=$installed_mode||sha256_hex($raw)ne$installed_digest}
            elsif($op eq'rollback'){if($installed){if($had){my$tmp='.p2t2c-restore-'.substr(sha256_hex(join(':',$$,time(),rand())),0,24);sysopen(my$fh,$tmp,O_WRONLY|O_CREAT|O_EXCL|O_NOFOLLOW,0600)or die"restore create";binmode$fh;print{$fh}$original_raw or die"restore write";close$fh;chmod($original_mode,$tmp)or die"restore mode";rename($tmp,$leaf)or die"restore rename"}elsif(lstat($leaf)){my@st=lstat($leaf);die"unsafe installed target"if!S_ISREG($st[2])||S_ISLNK($st[2])||$st[3]!=1;unlink($leaf)or die"remove installed target"}$installed=0}if($candidate&&lstat($candidate)){my@st=lstat($candidate);die"unsafe candidate"if!S_ISREG($st[2])||S_ISLNK($st[2])||$st[3]!=1;unlink($candidate)or die"candidate cleanup"}$candidate=''}
            elsif($op eq'stop'){if($candidate&&lstat($candidate)){unlink($candidate)or die"candidate cleanup"}$r->{stop}=$j->true}
            else{die"unsupported target transaction op"}1};if(!$ok){$r={ok=>$j->false,error=>substr($@||'target transaction failed',0,192)}}print{$res_w}$j->encode($r),"\n";last if$r->{stop}}
        close$cmd_r;close$res_w;exit 0}
    close$cmd_r;close$res_w;select((select($cmd_w),$|=1)[0]);return{pid=>$pid,cmd=>$cmd_w,res=>$res_r,identity=>$identity,dir=>$dir,leaf=>$leaf};
}
sub target_transaction_call {
    my($txn,$request)=@_;my$j=JSON::PP->new->canonical(1)->utf8(1);print{$txn->{cmd}}$j->encode($request),"\n"or die"ERROR: target transaction command failed\n";my$line=readline($txn->{res});die"ERROR: target transaction ended\n"if!defined$line;my$r=$j->decode($line);die"ERROR: target transaction: ".($r->{error}//'failed')."\n"if!$r->{ok};return$r;
}
sub stop_target_transaction {my($txn)=@_;return if!$txn;eval{target_transaction_call($txn,{op=>'stop'})};close$txn->{cmd};close$txn->{res};waitpid($txn->{pid},0)}
sub cleanup_quarantine {
    my($runs,$path)=@_;return 0 if$ENV{P2T2C_TEST_FORCE_CLEANUP_FAILURE};my$name=basename($path);return 0 if$name!~/\A\.closed-[A-Za-z0-9._-]+\z/;my$runs_identity=P2T2C::Evidence::safe_directory_identity($runs,'runs parent');my@q=lstat($path);return 0 if!@q||!S_ISDIR($q[2])||S_ISLNK($q[2])||$q[4]!=$<;my$q_identity="$q[0]:$q[1]";my$pid=fork();return 0 if!defined$pid;
        if($pid==0){chdir($runs)or exit 91;my@rd=stat(q(.));exit 92 if"$rd[0]:$rd[1]"ne$runs_identity;chdir($name)or exit 93;my@held=stat(q(.));exit 94 if"$held[0]:$held[1]"ne$q_identity;opendir(my$d,q(.))or exit 95;my@entries=grep{$_ ne'.'&&$_ ne'..'}readdir$d;closedir$d;for my$entry(@entries){if($entry eq'outputs'){my@od=lstat($entry);exit 96 if!@od||!S_ISDIR($od[2])||S_ISLNK($od[2])||($od[2]&0777)!=0700;chdir($entry)or exit 97;opendir(my$o,q(.))or exit 98;for my$log(grep{$_ ne'.'&&$_ ne'..'}readdir$o){my@st=lstat($log);exit 99 if$log!~/\Aevt-[A-Za-z0-9._-]+\.log\z/||!@st||!S_ISREG($st[2])||S_ISLNK($st[2])||$st[3]!=1||($st[2]&0777)!=0600;unlink($log)or exit 100}closedir$o;chdir(q(..))or exit 101;rmdir(q(outputs))or exit 102}else{my@st=lstat($entry);exit 103 if$entry!~/\A(?:contract\.json|events\.jsonl|\.closing|\.target-backup-[A-Za-z0-9]+)\z/||!@st||!S_ISREG($st[2])||S_ISLNK($st[2])||$st[3]!=1;unlink($entry)or exit 104}}chdir(q(..))or exit 105;my@again=lstat($name);exit 106 if!@again||"$again[0]:$again[1]"ne$q_identity;rmdir($name)or exit 107;exit 0}
    waitpid($pid,0);return$?==0?1:0;
}
sub rollback {
    return if$committed;
    if($run_quarantined&&$quarantine&&-d$quarantine&&!-e$run_dir){rename($quarantine,$run_dir);$run_quarantined=0}
    if($target_txn){eval{target_transaction_call($target_txn,{op=>'rollback'})};stop_target_transaction($target_txn);$target_txn=undef;$target_installed=0;$candidate=''}
    unlink$backup if$backup&&-f$backup&&!-l$backup;
    unlink$sidecar_tmp if$sidecar_tmp&&-f$sidecar_tmp&&!-l$sidecar_tmp;
    if($sidecar_created&&$context->{_sidecar}){held_sidecar_remove($context->{_sidecar_dir},$context->{_sidecar_name},$context->{_sidecar_identity},$context->{_sidecar_file_identity},$context->{_sidecar_mode},$context->{_sidecar_digest})}
    if(-f$closing&&!-l$closing){open my$f,'<',$closing;my$o=<$f>//'';close$f;if($o=~/^\Q$token\E/){eval{acquire_lock();unlink$closing;release_lock()}}}
}

my $ok=eval {
    $target_txn=start_target_transaction(dirname($target),basename($target));my$initial=target_transaction_call($target_txn,{op=>'init'});$had_target=$initial->{had_target}?1:0;$target_initial_raw=decode_base64($initial->{raw}//'');$target_initial_mode=$initial->{mode}//0644;
    my $prepared=P2T2C::Evidence::prepare_close(file=>$ledger,contract_file=>$contract,work_id=>$work_id,
        verification_profile=>$profile,target=>$target,remaining_risk_status=>$risk_status,remaining_risk_ref=>$risk_ref);
    my $receipt=$prepared->receipt(); my $receipt_json=$prepared->receipt_json(); my $sidecar=$receipt->{evidence_ref}; $context->{_sidecar}=$sidecar;
    die "ERROR: unsafe evidence parents\n" if !-d'docs'||-l'docs'||!-d'docs/closure'||-l'docs/closure';
    my$sidecar_dir=dirname($sidecar);my$sidecar_name=basename($sidecar);die"ERROR: evidence directory must already exist\n"if!-d$sidecar_dir||-l$sidecar_dir;
    my($sidecar_identity,$created,$sidecar_file_identity,$sidecar_mode)=held_sidecar_install($sidecar_dir,$sidecar_name,$prepared->events_raw());$sidecar_created=$created;
    @{$context}{qw(_sidecar_dir _sidecar_name _sidecar_identity _sidecar_file_identity _sidecar_mode _sidecar_digest)}=($sidecar_dir,$sidecar_name,$sidecar_identity,$sidecar_file_identity,$sidecar_mode,$receipt->{source_digest});

    my $base;
    if($had_target){$base=$target_initial_raw}
    else {
        die"ERROR: missing persistent evidence target\n"if$risk eq'R1';
        my$language=P2T2C::Evidence::read_raw('docs/sot/manifest.yaml')=~/^language:\s*"?zh-CN"?/m?'zh-CN':'en-US';
        my$id=basename($target,'.md');my$drift=$context->{gate_b_status}eq'resolved'?'resolved':'none';
        my$summary=$language eq'zh-CN'?'## 自动收口摘要':'## Automated Closure Summary';my$risks=$language eq'zh-CN'?'## 剩余风险':'## Remaining Risks';
        $base="---\nartifact: closure_report\nschema_version: 3\nid: $id\nwork_id: $work_id\nrisk: $risk\nexecution_shape: $shape\nchange_pack: $change_pack\nwork_pack: $context->{work_pack}\ntruth_drift: $drift\ndecision: CLOSE\nverification_policy: machine_bound\nevidence_trust: local_consistency\ncontract_digest: $context->{contract_digest}\nfinal_tree_sha: $receipt->{final_tree_sha}\nevidence_digest: $receipt->{source_digest}\nevidence_ref: $sidecar\nevidence_event_count: $receipt->{event_count}\nreview_base_sha: ".($receipt->{review_base_sha}//'none')."\nreview_head_sha: ".($receipt->{review_head_sha}//'none')."\nremaining_risk_status: $risk_status\nremaining_risk_ref: $risk_ref\n---\n\n# $id\n\n$summary\n\n- Generated from local-consistency machine evidence.\n\n$risks\n\n- ".($risk_status eq'none'?'None':'Recorded in the governing work context.')."\n";
    }
    if($risk eq'R1'){$base=~s/^status:[ \t]*[^\r\n]+/status: applied/m or die"ERROR: CPK has no status field\n"}
    else {my%fields=(work_id=>$work_id,evidence_trust=>'local_consistency',contract_digest=>$context->{contract_digest},final_tree_sha=>$receipt->{final_tree_sha},evidence_digest=>$receipt->{source_digest},evidence_ref=>$sidecar,evidence_event_count=>$receipt->{event_count},review_base_sha=>$receipt->{review_base_sha}//'none',review_head_sha=>$receipt->{review_head_sha}//'none',remaining_risk_status=>$risk_status,remaining_risk_ref=>$risk_ref);for my$key(sort keys%fields){my$value=$fields{$key};if($base=~/^\Q$key\E:[ \t]*/m){$base=~s/^\Q$key\E:[ \t]*[^\r\n]+/$key: $value/m}else{$base=~s/\A---\r?\n(.*?)\r?\n---\r?\n/"---\n$1\n$key: $value\n---\n"/se or die"ERROR: malformed target frontmatter\n"}}}
    my$start='<!-- p2t2c:evidence:start -->';my$end='<!-- p2t2c:evidence:end -->';my$block="$start\n```jsonl\n$receipt_json\n```\n$end";my$starts=()=$base=~/\Q$start\E/g;my$ends=()=$base=~/\Q$end\E/g;die"ERROR: mismatched evidence markers\n"if$starts!=$ends||$starts>1;if($starts){$base=~s/\Q$start\E.*?\Q$end\E/$block/s}else{$base=~s/[ \t\r\n]*\z//;$base.="\n\n## Machine Closure Evidence\n\n$block\n"}
    my$target_created=target_transaction_call($target_txn,{op=>'create',raw=>encode_base64($base,''),mode=>0644});$candidate=$target_created->{leaf};my$candidate_path=dirname($target)."/$candidate";
    $prepared->set_transients($candidate_path);
    my$candidate_read=target_transaction_call($target_txn,{op=>'read',leaf=>$candidate});my$candidate_raw=decode_base64($candidate_read->{raw}//'');
    $prepared->bind_projection_raw($candidate_raw);
    $prepared->assert_fresh();
    if(($ENV{P2T2C_TEST_TARGET_PAUSE_BEFORE_INSTALL_MS}//'')=~/\A([1-9][0-9]{0,3})\z/){print STDERR"P2T2C_TEST_HOOK: before-target-install\n";usleep($1*1000)}
    target_transaction_call($target_txn,{op=>'install',leaf=>$candidate});$candidate='';$target_installed=1;my$installed=target_transaction_call($target_txn,{op=>'read'});my$installed_raw=decode_base64($installed->{raw}//'');$prepared->mark_installed($installed_raw);
    die"ERROR: normal checker entrypoint failed after atomic evidence projection\n" if quiet_system('bash','.p2t2c/bin/check_p2t2c.sh','--help')!=0;
    my$checker=P2T2C::Checker->new(root=>'.',cache=>0,prevalidated=>{$target=>$prepared},raw_overrides=>{$target=>$installed_raw},extra_artifacts=>[$target]);my$status=$checker->run();
    if($status){print STDERR"ERROR: $_\n"for@{$checker->{errors}};die"ERROR: normal P2T2C checker failed after atomic evidence projection\n"}
    if(($ENV{P2T2C_TEST_TARGET_PAUSE_AFTER_CHECK_MS}//'')=~/\A([1-9][0-9]{0,3})\z/){print STDERR"P2T2C_TEST_HOOK: after-check-before-commit\n";usleep($1*1000)}
    target_transaction_call($target_txn,{op=>'commit_check'});
    held_sidecar_commit_check($context->{_sidecar_dir},$context->{_sidecar_name},$context->{_sidecar_identity},$context->{_sidecar_file_identity},$context->{_sidecar_mode},$context->{_sidecar_digest})or die"ERROR: sidecar commit binding changed\n";
    P2T2C::Evidence::validate_run_state($work_id,-f$cpk?$cpk:undef);
    if($backup){my$held_backup="$run_dir/.target-backup-$token";rename($backup,$held_backup)or die"ERROR: cannot stage rollback backup in run transaction: $!\n";$backup=$held_backup}
    acquire_lock();die"ERROR: close marker ownership lost\n"if!-f$closing||P2T2C::Evidence::read_raw($closing)!~/^\Q$token\E/;opendir(my$d,$run_dir)or die$!;my@active=grep{/^\.active-/}readdir$d;closedir$d;die"ERROR: runner became active during close\n"if@active;release_lock();
    my$runs_dir=dirname($run_dir);$quarantine="$runs_dir/.closed-$work_id-$token";die"ERROR: cleanup quarantine already exists\n"if-e$quarantine||-l$quarantine;
    target_transaction_call($target_txn,{op=>'commit_check'});held_sidecar_commit_check($context->{_sidecar_dir},$context->{_sidecar_name},$context->{_sidecar_identity},$context->{_sidecar_file_identity},$context->{_sidecar_mode},$context->{_sidecar_digest})or die"ERROR: sidecar commit binding changed\n";
    rename($run_dir,$quarantine)or die"ERROR: cannot atomically quarantine closed run: $!\n";$run_quarantined=1;
    target_transaction_call($target_txn,{op=>'commit_check'});held_sidecar_commit_check($context->{_sidecar_dir},$context->{_sidecar_name},$context->{_sidecar_identity},$context->{_sidecar_file_identity},$context->{_sidecar_mode},$context->{_sidecar_digest})or die"ERROR: sidecar post-quarantine binding changed\n";
    $committed=1;$run_quarantined=0;$target_installed=0;$sidecar_created=0;stop_target_transaction($target_txn);$target_txn=undef;
    $backup='';
    my$cleaned=eval{cleanup_quarantine($runs_dir,$quarantine)}||0;
    print STDERR"WARNING: committed close retained cleanup quarantine: $quarantine\n"if!$cleaned;
    print"P2T2C closure projected, checked, and committed: $target\n";1;
};
if(!$ok){my$error=$@||"ERROR: unknown close failure\n";rollback();print STDERR$error;exit 2}
exit 0;
