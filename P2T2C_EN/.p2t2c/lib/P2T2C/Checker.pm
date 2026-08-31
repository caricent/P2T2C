package P2T2C::Checker;
use strict;
use warnings;

use Digest::SHA qw(sha256_hex);
use File::Basename qw(basename dirname);
use File::Find ();
use File::Path qw(make_path);
use File::Spec ();
use Cwd qw(abs_path);
use Fcntl qw(:mode O_WRONLY O_CREAT O_EXCL O_NOFOLLOW);
use JSON::PP ();
use P2T2C::Documents ();

sub new {
    my ($class,%args)=@_;
    return bless {
        root=>$args{root}//'.', preclose=>$args{preclose}//'', cache=>$args{cache}//1,
        errors=>[],warnings=>[],raw=>{%{$args{raw_overrides}||{}}},fm=>{},preclose_used=>0,
        json=>JSON::PP->new->canonical(1)->utf8(1),prevalidated=>$args{prevalidated}||{},
        semantic_validated=>{},extra_artifacts=>$args{extra_artifacts}||[],
    },$class;
}

sub error { push @{$_[0]{errors}},$_[1] }
sub warning { push @{$_[0]{warnings}},$_[1] }
sub raw {
    my ($self,$path)=@_;
    return $self->{raw}{$path} if exists $self->{raw}{$path};
    open my $fh,'<:raw',$path or return $self->{raw}{$path}=undef;
    local $/; my $raw=<$fh>//''; close $fh;
    return $self->{raw}{$path}=$raw;
}
sub fm {
    my ($self,$path)=@_;
    return $self->{fm}{$path} if exists $self->{fm}{$path};
    if(defined(&P2T2C::Evidence::frontmatter_index)){
        local$P2T2C::Evidence::READ_CACHE=$self->{raw};my$index=eval{P2T2C::Evidence::frontmatter_index($path)};
        if(!$@&&$index->{present}){my%value=%{$index->{values}};$value{_duplicates}=[@{$index->{duplicates}}];$value{_non_scalar}=[@{$index->{non_scalar}}];return$self->{fm}{$path}=\%value}
    }
    my $raw=$self->raw($path);
    return $self->{fm}{$path}={} if !defined($raw) || $raw!~/\A---\r?\n(.*?)\r?\n---/s;
    my (%value,%seen,@duplicates,@non_scalar);
    for my $line (split /\r?\n/,$1,-1) {
        next if $line=~/^\s*(?:#.*)?$/;
        my ($key,$v)=$line=~/^([A-Za-z0-9_]+):[ \t]*(.*?)\s*$/;
        if (!defined $key) { push @non_scalar,$line; next }
        push @duplicates,$key if $seen{$key}++;
        next if exists $value{$key};
        $v=~s/^"|"$//g; $value{$key}=$v;
    }
    $value{_duplicates}=\@duplicates; $value{_non_scalar}=\@non_scalar;
    return $self->{fm}{$path}=\%value;
}
sub files {
    my ($self,$root,$test)=@_; my @files;
    return @files if !-d $root;
    File::Find::find({no_chdir=>1,wanted=>sub {push @files,$File::Find::name if -f _ && $test->($File::Find::name)}},$root);
    return sort @files;
}
sub capture {
    my ($self,@cmd)=@_; open my $fh,'-|',@cmd or return undef;
    local $/; my $out=<$fh>//''; return undef if !close $fh;
    $out=~s/[\r\n]+\z//; return $out;
}
sub quiet_system {
    my ($self,@cmd)=@_; my $pid=fork(); return 255 if !defined $pid;
    if ($pid==0) {
        open STDOUT,'>',File::Spec->devnull() or exit 255;
        open STDERR,'>&',\*STDOUT or exit 255;
        exec @cmd; exit 255;
    }
    waitpid($pid,0); return $?;
}
sub phrase {
    my ($self,$file,$phrase)=@_; my $raw=$self->raw($file); return if !defined $raw;
    $self->error("$file missing phrase: $phrase") if index($raw,$phrase)<0;
}
sub front { my ($self,$file,$key)=@_; return $self->fm($file)->{$key}//'' }

sub methodology_scalar {my($raw)=@_;$raw=~s/^\s+|\s+$//g;$raw=~s/^"|"$//g;return$raw}
sub parse_methodology_file {
    my($self,$path)=@_;return{present=>0,values=>{},keys=>{}}if!-f$path;
    my@lines=split/\r?\n/,$self->raw($path);my($inside,$review,%values,%keys,%seen,$sections);
    my%top=map{$_=>1}qw(profile enforcement tdd debugging isolation parallel_execution fan_out wait_strategy);
    my%review_keys=map{$_=>1}qw(r1_production_code r2);
    for my$line(@lines){
        if($line=~/^methodology:\s*(?:#.*)?$/){$sections++;$inside=1;$review=0;next}
        if($inside&&$line=~/^\S/){$inside=0;$review=0}
        next if!$inside||$line=~/^\s*(?:#.*)?$/;
        if($line=~/^  review:\s*(?:#.*)?$/){$review=1;$keys{review}=1;next}
        if($line=~/^  ([A-Za-z0-9_]+):\s*(.+?)\s*$/){my($key,$raw)=($1,$2);$review=0;$self->error("$path methodology has unsupported field: $key")if!$top{$key};$self->error("$path methodology repeats field: $key")if$seen{$key}++;$values{$key}=methodology_scalar($raw);$keys{$key}=1;next}
        if($line=~/^    ([A-Za-z0-9_]+):\s*(.+?)\s*$/&&$review){my($key,$raw)=($1,$2);$self->error("$path methodology.review has unsupported field: $key")if!$review_keys{$key};my$name="review.$key";$self->error("$path methodology repeats field: $name")if$seen{$name}++;$values{$key}=methodology_scalar($raw);$keys{$name}=1;next}
        $self->error("$path methodology subtree is malformed: $line");
    }
    $self->error("$path repeats methodology section")if($sections||0)>1;
    return{present=>($sections?1:0),values=>\%values,keys=>\%keys};
}
sub methodology_values {
    my($self)=@_;my$defaults=$self->parse_methodology_file('.p2t2c/defaults.yaml');
    my$project=$self->parse_methodology_file('.p2t2c/project_config.yaml');
    $self->{methodology_defaults}=$defaults;$self->{methodology_override}=$project;
    return $project->{present}?$project->{values}:$defaults->{values};
}

sub cache_key {
    my ($self,$artifact,$cpk)=@_;
    return if !$self->{cache} || $self->{preclose};
    my $afm=$self->fm($artifact); my $work=$afm->{work_id}//$afm->{id}//'';
    return if $work eq '' || -d ".p2t2c/runs/$work";
    my @deps=($artifact,'.p2t2c/defaults.yaml','.p2t2c/project_config.yaml'); push @deps,$cpk if defined($cpk)&&$cpk ne '';
    my $raw=$self->raw($artifact)//'';
    my ($sidecar)=$raw=~/"evidence_ref":"([^"]+)"/;
    push @deps,$sidecar if defined $sidecar;
    if (defined($cpk)&&$cpk ne '') { my $truth=$self->front($cpk,'truth_patch_ref'); push @deps,$truth if $truth ne ''&&$truth ne 'none' }
    my %dep_stat;
    for my $dep (@deps) {
        my @st=lstat($dep); return if !@st||!S_ISREG($st[2])||S_ISLNK($st[2])||$st[3]!=1||$st[4]!=$<;
        $dep_stat{$dep}={dev=>$st[0],ino=>$st[1],mode=>$st[2]&07777,uid=>$st[4],nlink=>$st[3]};
        return if $self->quiet_system('git','ls-files','--error-unmatch','--',$dep)!=0;
        return if $self->quiet_system('git','diff','--quiet','HEAD','--',$dep)!=0;
    }
    my @engine=('.p2t2c/bin/check_p2t2c.pl','.p2t2c/bin/p2t2c_evidence.pl');
    push @engine,$self->files('.p2t2c/lib/P2T2C',sub {$_[0]=~/\.pm\z/});
    push @engine,$self->files('.p2t2c/schemas',sub {$_[0]=~/\.json\z/});
    my @validator=map {[$_,sha256_hex($self->raw($_)//'')]} sort @engine;
    my @dependencies=map {[$_,sha256_hex($self->raw($_)//''),$dep_stat{$_}]} @deps;
    my $head=$self->capture('git','rev-parse','--verify','HEAD')//return;
    my $common_raw=$self->capture('git','rev-parse','--git-common-dir')//return;
    my $common=abs_path($common_raw)//return; my @repo_stat=stat($common); return if !@repo_stat;
    my $object_format=$self->capture('git','rev-parse','--show-object-format')//'sha1';
    my $effective={profiles=>[map {my$r=P2T2C::Evidence::profile_requirement($_);delete$r->{commands};$r} qw(fast impacted full governance)],policy=>P2T2C::Evidence::parse_project_policy(),methodology=>$self->methodology_values()};
    my $payload={schema=>1,head=>$head,repo=>{path=>$common,dev=>$repo_stat[0],ino=>$repo_stat[1],object_format=>$object_format},validator=>\@validator,dependencies=>\@dependencies,effective_config_digest=>sha256_hex($self->{json}->encode($effective)),artifact=>$artifact};
    return sha256_hex($self->{json}->encode($payload));
}
sub cache_hit {
    my ($self,$key)=@_; return 0 if !defined $key;
    my $root='.p2t2c/cache';my$dir="$root/checker-v1";
    for my $parent ($root,$dir) {my@pst=lstat($parent);return 0 if!@pst||!S_ISDIR($pst[2])||S_ISLNK($pst[2])||$pst[4]!=$<||($pst[2]&0077)}
    my@ig=lstat("$root/.gitignore");return 0 if!@ig||!S_ISREG($ig[2])||S_ISLNK($ig[2])||$ig[3]!=1||$ig[4]!=$<||($ig[2]&0777)!=0600;
    my $path="$dir/$key.json"; my @st=lstat($path);
    return 0 if !@st || !S_ISREG($st[2]) || S_ISLNK($st[2]) || $st[3]!=1 || $st[4]!=$< || ($st[2]&0777)!=0600;
    my $obj=eval {$self->{json}->decode($self->raw($path)//'')};
    return 0 if $@||ref($obj)ne'HASH'||($obj->{key}//'')ne$key||($obj->{kind}//'')ne'parsed_index'||ref($obj->{index})ne'HASH';
    return $obj;
}
sub cache_store {
    my ($self,$key,$index)=@_; return if !defined $key||ref($index)ne'HASH';
    my $root='.p2t2c/cache'; my $dir="$root/checker-v1";
    return if (-e $root && (!-d $root||-l $root||(stat($root))[4]!=$<)) || (-e $dir&&(!-d $dir||-l $dir||(stat($dir))[4]!=$<));
    make_path($dir,{mode=>0700}); chmod 0700,$root,$dir;
    my $ignore="$root/.gitignore";
    if (-e$ignore) {my@ig=lstat($ignore);return if!@ig||!S_ISREG($ig[2])||S_ISLNK($ig[2])||$ig[3]!=1||$ig[4]!=$<||($ig[2]&0777)!=0600}
    if (!-e $ignore) {
        if (sysopen(my $ig,$ignore,O_WRONLY|O_CREAT|O_EXCL|O_NOFOLLOW,0600)) {print {$ig} "*\n";close $ig}
    }
    my $tmp="$dir/.$key-$$-".int(rand(1_000_000));
    return if !sysopen(my $fh,$tmp,O_WRONLY|O_CREAT|O_EXCL|O_NOFOLLOW,0600);
    print {$fh} $self->{json}->encode({schema=>1,key=>$key,kind=>'parsed_index',index=>$index}),"\n"; close $fh;
    rename $tmp,"$dir/$key.json" or unlink $tmp;
}
sub validate_machine {
    my ($self,$artifact,$cpk,$logical)=@_;
    my $prepared=$self->{prevalidated}{$logical||$artifact};
    if(ref($prepared)eq'P2T2C::Evidence::Prepared'){
        if($prepared->valid_for($artifact,$cpk)){return}
        $self->error("$artifact prepared target binding is no longer valid");return;
    }
    my $artifact_raw=$self->raw($artifact)//''; my $cpk_raw=defined($cpk)&&$cpk ne ''?($self->raw($cpk)//''):'';
    my $semantic_key=sha256_hex(join("\0",$logical||$artifact,sha256_hex($artifact_raw),sha256_hex($cpk_raw)));
    return if exists $self->{semantic_validated}{$semantic_key};
    my $key=$self->cache_key($artifact,$cpk);
    my$cached=$self->cache_hit($key); # parsed input only; never semantic authority
    local $P2T2C::Evidence::READ_CACHE=$self->{raw};
    local $P2T2C::Evidence::LAST_ARTIFACT_INDEX;
    my$parsed=$cached&&ref($cached->{index}{artifact_ast})eq'HASH'?$cached->{index}{artifact_ast}:undef;
    my $ok=eval {P2T2C::Evidence::validate_artifact($artifact,$cpk,$logical,$parsed);1};
    if(!$ok&&$parsed){$P2T2C::Evidence::LAST_ARTIFACT_INDEX=undef;$ok=eval{P2T2C::Evidence::validate_artifact($artifact,$cpk,$logical,undef);1}}
    if (!$ok) {my $e=$@;$e=~s/^ERROR: evidence:\s*//;$e=~s/\s+\z//;$self->{semantic_validated}{$semantic_key}=0;$self->error("$artifact has invalid machine-bound closure evidence: $e");return}
    $self->{semantic_validated}{$semantic_key}=1;
    my%artifact_fm=%{$self->fm($artifact)};delete@artifact_fm{qw(_duplicates _non_scalar)};
    my$index={artifact=>$artifact,artifact_digest=>sha256_hex($artifact_raw),frontmatter=>\%artifact_fm};
    $index->{artifact_ast}=$P2T2C::Evidence::LAST_ARTIFACT_INDEX if ref($P2T2C::Evidence::LAST_ARTIFACT_INDEX)eq'HASH';
    if(defined($cpk)&&$cpk ne''){my%cpk_fm=%{$self->fm($cpk)};delete@cpk_fm{qw(_duplicates _non_scalar)};$index->{cpk}={path=>$cpk,digest=>sha256_hex($cpk_raw),frontmatter=>\%cpk_fm}}
    if($artifact_raw=~/"evidence_ref":"([^"]+)"/){my$ref=$1;$index->{sidecar}={path=>$ref,digest=>(-f$ref?sha256_hex($self->raw($ref)//''):'missing')}}
    $self->cache_store($key,$index);
}

sub validate_cpk {
    my ($self,$file,$method)=@_; my $fm=$self->fm($file); my $base=basename($file,'.md');
    $self->error("$file artifact must be change_pack") if ($fm->{artifact}//'') ne 'change_pack';
    $self->error("$file id must match filename: $base") if ($fm->{id}//'') ne $base;
    $self->error("$file source must be user_instruction, issue_path, or sp_path") if ($fm->{source}//'')!~/\A(?:user_instruction|issue_path|sp_path)\z/;
    my $risk=$fm->{risk}//''; my $status=$fm->{status}//''; my $schema=$fm->{schema_version}//'';
    $self->error("$file has invalid status: $status") if $status!~/\A(?:ready|blocked|applied)\z/;
    $self->error("$file schema_version must be 1, 2, or 3 when declared") if $schema ne ''&&$schema!~/\A[123]\z/;
    my $profile=$fm->{methodology_profile}//'';
    $self->error("$file has unsupported methodology_profile: $profile") if $profile ne ''&&$profile!~/\A(?:p2t2c-balanced-v1|p2t2c-adaptive-v2)\z/;
    if (($method->{enforcement}//'advisory') eq 'required'&&$profile eq 'p2t2c-balanced-v1'&&$risk eq 'R1') {
        $self->error("$file required-mode R1 must declare production_code_change: true or false") if ($fm->{production_code_change}//'')!~/\A(?:true|false)\z/;
    }
    if ($schema eq '3') {
        my $ok=eval {P2T2C::Evidence::parse_cpk($file,$base,{historical_applied=>$status eq 'applied'});1};
        if (!$ok) {my $e=$@;$e=~s/^ERROR: evidence:\s*//;$e=~s/\s+\z//;$self->error("$file violates the controlled v3 CPK contract: $e")}
        $self->error("$file schema_version 3 requires methodology_profile: p2t2c-adaptive-v2") if ($fm->{methodology_profile}//'') ne 'p2t2c-adaptive-v2';
        my $shape=$fm->{execution_shape}//'';
        $self->error("$file spike work can never be applied or closed") if $shape eq 'spike'&&$status eq 'applied';
        if ($shape eq 'architectural') {my $work=$fm->{work_pack}//'';$self->error("$file architectural work must reference specs/<feature>/work.md") if $work!~m{\Aspecs/[^/]+/work\.md\z};$self->error("$file references missing architectural work pack: $work") if !-f $work}
        elsif (($fm->{work_pack}//'') ne 'none') {$self->error("$file non-architectural work_pack must be none")}
    }
    if ($risk eq 'R1') {
        $self->error("$file R1 must use truth_change: false") if ($fm->{truth_change}//'') ne 'false';
        $self->error("$file R1 must use gate_a: not_required") if ($fm->{gate_a}//'') ne 'not_required';
    } elsif ($risk eq 'R2') {
        $self->error("$file R2 must use truth_change: true") if ($fm->{truth_change}//'') ne 'true';
        $self->error("$file R2 gate_a must be satisfied or pending") if ($fm->{gate_a}//'')!~/\A(?:satisfied|pending)\z/;
        $self->error("$file cannot be applied while gate_a is pending") if ($fm->{gate_a}//'') eq 'pending'&&$status eq 'applied';
    } else {$self->error("$file risk must be R1 or R2")}
    if ($schema eq '3'&&$status eq 'applied') {
        if ($risk eq 'R1') {$self->validate_machine($file,undef,$file)}
        elsif ($risk eq 'R2') {
            my $cr='docs/closure/CR-'.($base=~s/^CPK-//r).'.md';
            if (!-f $cr) {
                if ($self->{preclose} eq ($fm->{id}//'')) {
                    my $ok=eval {P2T2C::Evidence::validate_run_state($fm->{id},$file);1};
                    if ($ok) {$self->{preclose_used}=1} else {$self->error("$file pre-close exemption has unsafe run state: $@")}
                } else {$self->error("$file applied R2 requires automatic closure report: $cr")}
            } else {$self->validate_machine($cr,$file,$cr)}
        }
    }
}

sub validate_spec {
    my ($self,$file)=@_; my $fm=$self->fm($file); return if ($fm->{artifact}//'') ne 'execution_spec';
    my $cpk=$fm->{change_pack}//''; $self->error("$file must reference a docs/change_packs/CPK-*.md path") if $cpk!~m{\Adocs/change_packs/CPK-.*\.md\z};
    return $self->error("$file references missing CPK: $cpk") if !-f $cpk;
    my $cfm=$self->fm($cpk); $self->error("$file cannot execute while referenced CPK gate_a is pending") if ($cfm->{gate_a}//'') eq 'pending';
    if (($cfm->{schema_version}//'') eq '3') {$self->error("$file v3 spec/plan/tasks are forbidden unless architectural legacy_startup_evidence is true") if ($cfm->{execution_shape}//'') ne 'architectural'||($cfm->{legacy_startup_evidence}//'') ne 'true'}
    $self->error("$file is missing sibling plan.md") if !-f dirname($file).'/plan.md'; $self->error("$file is missing sibling tasks.md") if !-f dirname($file).'/tasks.md';
}
sub validate_work {
    my ($self,$file)=@_; my $fm=$self->fm($file); my $cpk=$fm->{change_pack}//'';
    $self->error("$file artifact must be execution_work") if ($fm->{artifact}//'') ne 'execution_work';
    $self->error("$file schema_version must be 1") if ($fm->{schema_version}//'') ne '1';
    return $self->error("$file references missing CPK: $cpk") if $cpk!~m{\Adocs/change_packs/CPK-.*\.md\z}||!-f $cpk;
    my $cfm=$self->fm($cpk); $self->error("$file must reference a schema_version 3 CPK") if ($cfm->{schema_version}//'') ne '3';
    $self->error("$file must reference an architectural CPK") if ($cfm->{execution_shape}//'') ne 'architectural';
    $self->error("$file cannot execute while referenced CPK gate_a is pending") if ($cfm->{gate_a}//'') eq 'pending';
    $self->error("$file does not match the CPK work_pack: ".($cfm->{work_pack}//'')) if ($cfm->{work_pack}//'') ne $file;
}

sub validate_cr {
    my ($self,$file,$method)=@_; my $fm=$self->fm($file); my $base=basename($file,'.md'); my $schema=$fm->{schema_version}//''; my $risk=$fm->{risk}//'';
    $self->error("$file artifact must be closure_report") if ($fm->{artifact}//'') ne 'closure_report';
    $self->error("$file id must match filename: $base") if ($fm->{id}//'') ne $base;
    $self->error("$file risk must be R0, R1, or R2") if $risk!~/\AR[012]\z/;
    $self->error("$file decision must be CLOSE") if ($fm->{decision}//'') ne 'CLOSE';
    $self->error("$file truth_drift must be none or resolved") if ($fm->{truth_drift}//'')!~/\A(?:none|resolved)\z/;
    if ($schema eq '3') {
        $self->error("$file schema_version 3 frontmatter has duplicate or non-scalar controlled keys") if @{$fm->{_duplicates}||[]}||@{$fm->{_non_scalar}||[]};
        $self->error("$file schema_version 3 CR risk must be R0 or R2") if $risk!~/\A(?:R0|R2)\z/;
        $self->error("$file schema_version 3 requires verification_policy: machine_bound") if ($fm->{verification_policy}//'') ne 'machine_bound';
        $self->error("$file schema_version 3 requires evidence_trust: local_consistency") if ($fm->{evidence_trust}//'') ne 'local_consistency';
        $self->error("$file schema_version 3 CR cannot use spike") if ($fm->{execution_shape}//'')!~/\A(?:bounded|architectural)\z/;
        $self->error("$file schema_version 3 requires final_tree_sha") if ($fm->{final_tree_sha}//'')!~/\A(?:[0-9a-f]{40}|[0-9a-f]{64})\z/;
        $self->error("$file schema_version 3 requires evidence_digest") if ($fm->{evidence_digest}//'')!~/\A[0-9a-f]{64}\z/;
        $self->error("$file schema_version 3 requires contract_digest") if ($fm->{contract_digest}//'')!~/\A[0-9a-f]{64}\z/;
        my $remaining=$fm->{remaining_risk_status}//'';my$rref=$fm->{remaining_risk_ref}//'';
        $self->error("$file schema_version 3 has invalid remaining_risk_status") if $remaining!~/\A(?:none|recorded)\z/;
        $self->error("$file remaining risk ref/status mismatch") if ($remaining eq'none'&&$rref ne'none')||($remaining eq'recorded'&&($rref eq'none'||$rref eq''));
        my $cpk=$risk eq 'R2'?($fm->{change_pack}//''):undef;
        if ($risk eq 'R2'&&(!defined($cpk)||$cpk!~m{\Adocs/change_packs/CPK-.*\.md\z}||!-f $cpk)) {$self->error("$file R2 must reference an existing CPK");return}
        my $work_id=$fm->{work_id}//'';my$expected;
        if ($risk eq'R2') {
            my$cfm=$self->fm($cpk);$expected='docs/closure/CR-'.($work_id=~s/^CPK-//r).'.md';
            $self->error("$file must reference a schema_version 3 R2 CPK") if ($cfm->{schema_version}//'')ne'3'||($cfm->{risk}//'')ne'R2';
            $self->error("$file referenced R2 CPK must be applied") if ($cfm->{status}//'')ne'applied';
            $self->error("$file work_id must equal its CPK id") if $work_id ne($cfm->{id}//'');
            $self->error("$file execution_shape must match its CPK") if ($fm->{execution_shape}//'')ne($cfm->{execution_shape}//'');
            $self->error("$file work_pack must match its CPK") if ($fm->{work_pack}//'')ne($cfm->{work_pack}//'');
        } else {
            $expected='docs/closure/CR-'.($work_id=~s/^R0-//r).'.md';
            $self->error("$file R0 change_pack/work_pack must be none") if ($fm->{change_pack}//'')ne'none'||($fm->{work_pack}//'')ne'none';
            $self->error("$file R0 work_id must start with R0-") if $work_id!~/\AR0-/;
        }
        $self->error("$file path must be the automatic work mapping: $expected") if $file ne$expected;
        my$artifact_raw=$self->raw($file)//'';
        for my$field(qw(final_tree_sha contract_digest)) {$self->error("$file $field is not backed by its receipt") if $artifact_raw!~/"\Q$field\E":"\Q$fm->{$field}\E"/}
        $self->error("$file evidence_digest is not backed by its receipt") if $artifact_raw!~/"source_digest":"\Q$fm->{evidence_digest}\E"/;
        if (($fm->{evidence_ref}//'') ne '') {$self->error("$file evidence_ref is not backed by its receipt") if $artifact_raw!~/"evidence_ref":"\Q$fm->{evidence_ref}\E"/}
        if (($fm->{evidence_event_count}//'') ne '') {$self->error("$file evidence_event_count is not backed by its receipt") if $artifact_raw!~/"event_count":\Q$fm->{evidence_event_count}\E(?:,|})/}
        $self->validate_machine($file,$cpk,$file); return;
    }
    my $raw=$self->raw($file)//'';
    my $cpk=$fm->{change_pack}//''; my $execution=$fm->{execution_pack}//'';
    if ($risk eq 'R0') {
        $self->error("$file R0 change_pack must be none") if $cpk ne 'none';
        $self->error("$file R0 execution_pack must be none") if $execution ne 'none';
    } else {
        $self->error("$file $risk must reference an existing CPK") if $cpk!~m{\Adocs/change_packs/CPK-.*\.md\z}||!-f$cpk;
        $self->error("$file $risk must reference an execution_pack") if $execution eq 'none'||$execution eq '';
        $self->error("$file references missing execution_pack: $execution") if $execution ne ''&&$execution ne 'none'&&!-e$execution;
    }
    $self->error("$file missing verification evidence section") if $raw!~/^## (?:Verification Evidence|验证证据)$/m;
    $self->error("$file missing remaining risks section") if $raw!~/^## (?:Remaining Risks|剩余风险)$/m;
    $self->error("$file must record at least one actual verification command and result") if $raw!~/^\| `[^`]+` \| (?:Pass|Fail|Not run)/m;
    my $policy=$fm->{verification_policy}//'';
    $self->error("$file schema_version 2 requires verification_policy: fresh_pass") if $schema eq '2'&&$policy ne 'fresh_pass';
    if ($policy ne '') {
        $self->error("$file verification_policy must be fresh_pass") if $policy ne 'fresh_pass';
        $self->error("$file fresh_pass closure needs a passing verification command") if $raw!~/^\| `[^`]+` \| Pass \|/m;
        $self->error("$file fresh_pass closure cannot retain a failed verification command") if $raw=~/^\| `[^`]+` \| Fail \|/m;
    }
    my $cpk_profile=$cpk ne ''&&-f$cpk?$self->front($cpk,'methodology_profile'):'';
    if (($method->{enforcement}//'advisory') eq 'required'&&$cpk_profile eq 'p2t2c-balanced-v1') {
        $self->error("$file missing method evidence section") if $raw!~/^## (?:Method Evidence|方法证据)$/m;
        $self->error("$file must record RED evidence or an exemption with alternative evidence")
            if $raw!~/^- (?:Test-first: RED .+Fail|测试先行：RED .+Fail|Test-first: Exemption: .+; Alternative evidence: .+|测试先行：豁免：.+；替代证据：.+)/m;
        $self->error("$file missing root-cause repair record") if $raw!~/^- (?:Root-cause repair record:|根因修复记录：).+[^:\s]/m;
        $self->error("$file missing isolation and baseline evidence") if $raw!~/^- (?:Isolation and baseline:|隔离与基线：).+[^:\s]/m;
        my $production=-f$cpk?$self->front($cpk,'production_code_change'):'';
        if ($risk eq 'R2'||($production eq 'true'&&($method->{r1_production_code}//'') eq 'required')) {
            $self->error("$file requires a passing independent review with zero Critical and Important findings")
                if $raw!~/^- (?:Independent review: Pass; Critical: 0; Important: 0;|独立审查：通过；Critical：0；Important：0；)/m;
        }
    }
}

sub validate_truth_manifest {
    my ($self)=@_; my $raw=$self->raw('docs/sot/manifest.yaml')//'';
    $self->error('docs/sot/manifest.yaml schema_version must be 1') if $raw!~/^schema_version:\s*1\s*$/m;
    $self->error('docs/sot/manifest.yaml workflow is required') if $raw!~/^workflow:\s*"[^"]+"\s*$/m;
    $self->error('docs/sot/manifest.yaml truth_root must be docs/sot') if $raw!~/^truth_root:\s*"docs\/sot"\s*$/m;
    my @blocks=$raw=~/(?:^|\n)  - path:\s*"([^"]+)"\n    sha256:\s*"([0-9a-f]{64})"\n    rule_ids:\s*\[([^\]]*)\]/g;
    my %declared_truth;
    for (my $i=0;$i<@blocks;$i+=3) {
        my ($path,$declared,$ids_raw)=@blocks[$i..$i+2];
        $declared_truth{$path}=1;
        if (!-f$path||-l$path) {$self->error("docs/sot/manifest.yaml references missing or unsafe Truth: $path");next}
        my $actual=sha256_hex($self->raw($path)//'');
        $self->error("docs/sot/manifest.yaml digest mismatch for $path") if $actual ne $declared;
        my @declared_ids=sort($ids_raw=~/"(RULE-[A-Z]+-[0-9]+)"/g);
        my @actual_ids=sort(($self->raw($path)//'')=~/^#{2,3}\s+(RULE-[A-Z]+-[0-9]+)/mg);
        $self->error("docs/sot/manifest.yaml rule_ids mismatch for $path") if join("\0",@declared_ids) ne join("\0",@actual_ids);
        my($truth_block)=$raw=~/(^  - path:\s*"\Q$path\E"\s*\n.*?)(?=^  - path:|^adrs:|\z)/ms;
        my($decision_raw)=($truth_block//'')=~/^\s*decision_ids:\s*\[([^\]]*)\]/m;
        my@declared_decisions=sort(($decision_raw//'')=~/"(DEC-[A-Z0-9._-]+)"/g);
        my@actual_decisions=sort(($self->raw($path)//'')=~/^#{2,3}\s+(DEC-[A-Z0-9._-]+)/mg);
        $self->error("docs/sot/manifest.yaml decision_ids mismatch for $path") if join("\0",@declared_decisions) ne join("\0",@actual_decisions);
        $self->error("docs/sot/manifest.yaml topics missing for $path") if ($truth_block//'')!~/^\s*topics:\s*\[[^\]]*"[^\]]+\]/m;
    }
    $self->error('docs/sot/manifest.yaml must declare at least one Truth locator with digest and rule_ids') if !@blocks;
    for my $path ($self->files('docs/sot',sub {$_[0]=~/\.md\z/&&$_[0]!~/(?:_HISTORY|\/history)\.md\z/i})) {
        $self->warning("UNINDEXED_PROJECT_TRUTH: $path") if !$declared_truth{$path};
    }
    my @adrs=$raw=~/(?:^|\n)  - path:\s*"([^"]+)"\n    id:\s*"([^"]+)"\n    sha256:\s*"([0-9a-f]{64})"\n    status:\s*"([^"]+)"\n    topics:\s*\[([^\]]*)\]/g;
    for (my $i=0;$i<@adrs;$i+=5) {
        my ($path,$id,$digest,$status,$topics)=@adrs[$i..$i+4];
        if (!-f$path||-l$path) {$self->error("docs/sot/manifest.yaml references missing or unsafe ADR: $path");next}
        $self->error("docs/sot/manifest.yaml ADR digest mismatch for $path") if sha256_hex($self->raw($path)//'') ne $digest;
        $self->error("docs/sot/manifest.yaml ADR id/path mismatch for $path") if basename($path)!~/^\Q$id\E(?:-|\.)/;
        $self->error("docs/sot/manifest.yaml ADR status invalid for $path") if $status!~/\A(?:Accepted|Superseded|Deprecated|Proposed)\z/;
        $self->error("docs/sot/manifest.yaml ADR topics missing for $path") if $topics!~/"[^"]+"/;
    }
}

sub validate_obsolete {
    my ($self)=@_; my %locked; my $lock=$self->raw('.p2t2c/lock.sha256')//'';
    $locked{$2}=$1 while $lock=~/^([0-9a-f]{64})\s+(.+)$/mg;
    for my $migration ($self->files('.p2t2c/migrations',sub {$_[0]=~/\.md\z/})) {
        my $raw=$self->raw($migration)//''; my ($list)=$raw=~/BEGIN_OBSOLETE_MANAGED\s*\n(.*?)\nEND_OBSOLETE_MANAGED/s; next if !defined$list;
        for my $path (split /\r?\n/,$list) {next if $path=~/^\s*(?:```|#|$)/;$path=~s/^\s+|\s+$//g;$self->error("obsolete locked managed file still exists: $path") if $locked{$path}&&-e$path}
    }
}

sub run {
    my ($self)=@_;
    if ($self->{preclose}) {
        my $id=$self->{preclose}; my $cpk="docs/change_packs/$id.md";
        my $ok=eval {P2T2C::Evidence::validate_run_state($id,-f$cpk?$cpk:undef);1};
        if (!$ok) {my$e=$@;$e=~s/^ERROR: evidence:\s*//;$e=~s/\s+\z//;$self->error("unsafe pre-close run state for $id: $e")}
        else {$self->{preclose_used}=1}
    }
    my $config_ok=eval {P2T2C::Evidence::parse_verification_profiles();P2T2C::Evidence::parse_project_policy();1};
    if(!$config_ok){my$e=$@;$e=~s/^ERROR: evidence:\s*//;$e=~s/\s+\z//;$self->error("invalid effective verification configuration: $e")}
    my $manifest='.p2t2c/managed-files.txt'; my $mraw=$self->raw($manifest);
    my @required;
    if (!defined $mraw) {$self->error("missing managed file manifest: $manifest")}
    else {for my $line (split /\r?\n/,$mraw) {next if $line=~/^\s*(?:#.*)?$/;$line=~s/^\s+|\s+$//g;if($line=~m{\A/|(?:\A|/)\.\.(?:/|\z)|//}){$self->error("$manifest contains unsafe path: $line");next}push @required,$line}}
    $self->error("$manifest contains no managed paths") if !@required;
    $self->error("missing required file: $_") for grep {!-f $_} @required;
    $self->phrase('.p2t2c/VERSION','0.15.0'); $self->phrase('.p2t2c/manifest.yaml','version: "0.15.0"');
    $self->phrase('docs/sot/manifest.yaml','truth_root: "docs/sot"');
    $self->phrase('docs/sot/governance/P2T2C_GOVERNANCE.md','RULE-GOV-009');
    $self->phrase('docs/sot/governance/P2T2C_GOVERNANCE.md','RULE-GOV-018');
    my $language=''; my $sot=$self->raw('docs/sot/manifest.yaml')//''; $language=$1 if $sot=~/^language:\s*"?([^"\s]+)"?/m;
    if ($language eq 'en-US') {$self->phrase('P2T2C_README.md','Core Workflow');$self->phrase('P2T2C_AGENTS.md','AI Entry')}
    elsif ($language eq 'zh-CN') {$self->phrase('P2T2C_README.md','核心工作流');$self->phrase('P2T2C_AGENTS.md','AI 入口')}
    else {$self->error("unknown docs/sot/manifest.yaml language: $language")}
    my $method=$self->methodology_values(); my $enforcement=$method->{enforcement}//'advisory';
    my$method_defaults=$self->{methodology_defaults};
    for my$key(qw(profile enforcement tdd debugging isolation parallel_execution fan_out wait_strategy review.r1_production_code review.r2)){
        $self->error(".p2t2c/defaults.yaml methodology missing $key")if!$method_defaults->{keys}{$key};
    }
    my $override=$self->raw('.p2t2c/project_config.yaml')//'';my$method_override=$self->{methodology_override};
    if ($method_override->{present}) {
        for my $key (qw(profile enforcement tdd debugging isolation parallel_execution review.r1_production_code review.r2)) {
            $self->error(".p2t2c/project_config.yaml explicit methodology override missing $key") if !$method_override->{keys}{$key};
        }
        if (($method->{profile}//'') eq 'p2t2c-adaptive-v2') {
            for my $key (qw(fan_out wait_strategy)) {$self->error(".p2t2c/project_config.yaml explicit adaptive methodology override missing $key") if !$method_override->{keys}{$key}}
        }
    }
    if ($override=~/^p2t2c:\s*$/m&&$override=~/^  r0:\s*$/m) {
        $self->error('.p2t2c/project_config.yaml explicit p2t2c.r0 override must declare audit_mode and closure_on_residual_risk')
            if $override!~/^    audit_mode:\s*(?:true|false)/m||$override!~/^    closure_on_residual_risk:\s*(?:true|false)/m;
    }
    $self->error('.p2t2c/project_config.yaml methodology.enforcement must be advisory or required') if $enforcement!~/\A(?:advisory|required)\z/;
    $self->error('.p2t2c/project_config.yaml methodology.tdd must be risk_aware') if ($method->{tdd}//'') ne 'risk_aware';
    $self->error('.p2t2c/project_config.yaml methodology.debugging must be root_cause_first') if ($method->{debugging}//'') ne 'root_cause_first';
    $self->error('.p2t2c/project_config.yaml methodology.review.r1_production_code must be required') if ($method->{r1_production_code}//'') ne 'required';
    $self->error('.p2t2c/project_config.yaml methodology.review.r2 must be required') if ($method->{r2}//'') ne 'required';
    $self->error('.p2t2c/project_config.yaml methodology.isolation must be auto') if ($method->{isolation}//'') ne 'auto';
    if (($method->{profile}//'') eq 'p2t2c-adaptive-v2') {
        $self->error('.p2t2c/project_config.yaml adaptive-v2 methodology.parallel_execution must be owned_isolated_only') if ($method->{parallel_execution}//'') ne 'owned_isolated_only';
        $self->error('.p2t2c/project_config.yaml adaptive-v2 methodology.fan_out must be controller_only') if ($method->{fan_out}//'') ne 'controller_only';
        $self->error('.p2t2c/project_config.yaml adaptive-v2 methodology.wait_strategy must be event_driven') if ($method->{wait_strategy}//'') ne 'event_driven';
    } elsif (($method->{profile}//'') eq 'p2t2c-balanced-v1') {
        $self->error('.p2t2c/project_config.yaml balanced-v1 methodology.parallel_execution must be r2_independent_only') if ($method->{parallel_execution}//'') ne 'r2_independent_only';
    } else {$self->error('.p2t2c/project_config.yaml methodology.profile must be p2t2c-balanced-v1 or p2t2c-adaptive-v2')}
    if ($enforcement eq 'required') {
        if (($method->{profile}//'') eq 'p2t2c-adaptive-v2') {
        } elsif (($method->{profile}//'') eq 'p2t2c-balanced-v1') {
        }
    } elsif (-f '.p2t2c/project_config.yaml') {$self->warning('methodology enforcement is advisory; set methodology.enforcement: required to enforce method evidence for new declared artifacts')}
    my @cpk=$self->files('docs/change_packs',sub {$_[0]=~m{/CPK-[^/]+\.md\z}});push@cpk,grep{m{\Adocs/change_packs/CPK-[^/]+\.md\z}}@{$self->{extra_artifacts}};my%cpk_seen;@cpk=grep{!$cpk_seen{$_}++}@cpk;$self->validate_cpk($_,$method) for @cpk;
    my @spec=$self->files('specs',sub {$_[0]=~m{/spec\.md\z}}); for (@spec) {(-f $_&&$self->raw($_)=~/\A---/)?$self->validate_spec($_):$self->error("$_ is an execution spec instance without frontmatter")}
    my @work=$self->files('specs',sub {$_[0]=~m{/work\.md\z}}); for (@work) {(-f $_&&$self->raw($_)=~/\A---/)?$self->validate_work($_):$self->error("$_ is an execution work instance without frontmatter")}
    my @cr=$self->files('docs/closure',sub {$_[0]=~m{/CR-[^/]+\.md\z}});push@cr,grep{m{\Adocs/closure/CR-[^/]+\.md\z}}@{$self->{extra_artifacts}};my%cr_seen;@cr=grep{!$cr_seen{$_}++}@cr;$self->validate_cr($_,$method) for @cr;
    my$core_ok=eval{P2T2C::Documents::validate_layout();1};
    if(!$core_ok){my$e=$@;$e=~s/^ERROR: documents:\s*//;$e=~s/\s+\z//;$self->error("invalid core document layout: $e")}
    $self->validate_truth_manifest(); $self->validate_obsolete();
    if ($language eq 'en-US') {
        for my $path ('P2T2C_AGENTS.md','P2T2C_README.md',$self->files('docs',sub {1}),$self->files('.p2t2c/prompts',sub {1}),$self->files('.p2t2c/templates',sub {1})) {
            next if !-f$path||$path=~m{\Adocs/reference/archive(?:/|\z)}; $self->error("English release root contains CJK text in managed docs") if ($self->raw($path)//'')=~/\p{Han}/;
        }
    }
    my(%rules,%decisions); for my $truth ($self->files('docs/sot',sub {$_[0]=~/\.md\z/&&$_[0]!~/(?:_HISTORY|\/history)\.md\z/i})) {my $raw=$self->raw($truth)//'';$rules{$1}++ while $raw=~/^#{2,3}\s+(RULE-[A-Z]+-[0-9]+)/mg;$decisions{$1}++ while $raw=~/^#{2,3}\s+(DEC-[A-Z0-9._-]+)/mg}
    my @dup=sort grep {$rules{$_}>1} keys %rules; $self->error('duplicate current Rule IDs: '.join(',',@dup)) if @dup;
    my@dup_decisions=sort grep{$decisions{$_}>1}keys%decisions;$self->error('duplicate current Decision IDs: '.join(',',@dup_decisions))if@dup_decisions;
    return @{$self->{errors}}?1:0;
}

1;
