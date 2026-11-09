package P2T2C::DocumentActions;
use strict;
use warnings;
use Digest::SHA qw(sha256_hex);
use File::Basename qw(basename);
use JSON::PP ();
use P2T2C::Documents ();
use P2T2C::DocumentTransactions ();

sub fail { P2T2C::Documents::fail($_[0]) }
sub id { P2T2C::DocumentTransactions::valid_id($_[0]) }
sub proposal_path { return 'docs/proposals/'.id($_[0]).'.md' }
sub exists_path { return -e $_[0] || -l $_[0] }
sub spec_id {
    my($value)=@_;fail('invalid spec id') if !defined($value)||$value!~/\A[0-9]{3,4}-[a-z0-9]+(?:-[a-z0-9]+)*\z/;
    return $value;
}

sub work {
    my($identity,$ready,$inside_transaction)=@_;
    my $path=proposal_path($identity);
    P2T2C::DocumentTransactions::assert_no_pending($identity) if !$inside_transaction;
    my $p=P2T2C::Documents::validate_proposal($path,0,0);
    if ($p->{shape} eq 'compact') {
        P2T2C::Documents::assert_compact_complete($p) if $ready;
        return {proposal=>$p,record=>$p,path=>$path,shape=>'compact',status=>$p->{fm}{work_status},document_schema_version=>2};
    }
    my $dir=$p->{fm}{specs_ref};my $tasks=P2T2C::Documents::validate_tasks("$dir/tasks.md",$ready||0);
    fail('proposal/tasks ownership mismatch') if $tasks->{fm}{proposal} ne $path;
    return {proposal=>$p,record=>$tasks,path=>$tasks->{path},shape=>'standard',status=>$tasks->{fm}{status},spec=>basename($dir),document_schema_version=>1};
}

sub public_work {
    my($w)=@_;
    my $out={proposal=>$w->{proposal}{path},record=>$w->{path},shape=>$w->{shape},work_status=>$w->{status},document_schema_version=>$w->{document_schema_version},source_digest=>sha256_hex($w->{proposal}{raw}),record_digest=>sha256_hex($w->{record}{raw})};
    @{$out}{qw(spec tasks design)}=($w->{spec},$w->{path},$w->{record}{fm}{design}) if $w->{shape} eq 'standard';
    return $out;
}

sub validate {
    my(%a)=@_;my $mode=$a{ready}?'ready':'structure';
    if (defined $a{proposal}) {
        my $w=work($a{proposal},$a{ready});
        return {schema_version=>1,action=>'validate',state=>'valid',mode=>$mode,%{public_work($w)}};
    }
    P2T2C::DocumentTransactions::assert_no_pending();
    P2T2C::Documents::validate_layout();
    if ($a{ready} && -d 'docs/proposals') {
        opendir(my $dh,'docs/proposals') or fail('cannot list proposals');my @names=sort grep {/^SP-.*\.md$/} readdir $dh;closedir $dh;
        for my $name (@names) {
            my $p=P2T2C::Documents::validate_proposal("docs/proposals/$name",1,0);
            work($p->{fm}{id},1) if !$p->{legacy};
        }
    }
    return {schema_version=>1,action=>'validate',state=>'valid',mode=>$mode};
}

sub locked {
    my($code)=@_;my $lock=P2T2C::Documents::acquire_lock();my($out,$error);
    my $ok=eval {P2T2C::Documents::assert_no_pending_migration();$out=$code->();1};$error=$@ if !$ok;
    my $released=eval {P2T2C::Documents::release_lock($lock);1};$error.=$@ if !$released;
    die $error if !$ok||!$released;return $out;
}

sub template {
    my($name,$identity,$spec)=@_;
    my $raw=P2T2C::Documents::read_safe(".p2t2c/templates/core/$name",'template');
    $raw=~s/SP-YYYYMMDD-short-title/$identity/g;
    $raw=~s/NNN-short-title/$spec/g if defined $spec;
    return $raw;
}

sub field {
    my($raw,$key,$value)=@_;
    my($head,$body)=$raw=~/\A(---\r?\n.*?\r?\n---)(.*)\z/s;
    fail('malformed generated frontmatter') if !defined $head;
    my $count=$head=~s/^\Q$key\E:[^\r\n]*/$key: $value/mg;
    fail("missing or duplicate generated field: $key") if $count!=1;
    return $head.$body;
}

sub validate_candidates {
    my($identity,$map)=@_;
    local $P2T2C::Documents::READ_OVERLAY=$map;
    my $w=work($identity,0,1);
    if ($w->{shape} eq 'standard' && $w->{proposal}{fm}{risk} eq 'R2' && $w->{proposal}{fm}{decision} eq 'approved') {
        P2T2C::Documents::validate_design($w->{record}{fm}{design},1);
    }
    return $w;
}

sub allocate_spec {
    my($identity,$requested)=@_;
    return spec_id($requested) if defined $requested;
    my $reserved=P2T2C::DocumentTransactions::reserved_spec($identity,'create');
    return basename($reserved) if defined $reserved;
    P2T2C::DocumentTransactions::fs('check_dir','docs/specs','specs root');
    opendir(my $dh,'docs/specs') or fail('cannot allocate spec');my @names=readdir $dh;closedir $dh;
    my $max=0;for (@names) { $max=$1 if /\A([0-9]{3,4})-/ && $1>$max }
    fail('spec number space exhausted') if $max>=9999;
    my($slug)=$identity=~/\ASP-[0-9]{8}-(.+)\z/;
    return sprintf('%03d-%s',$max+1,$slug);
}

sub create {
    my(%a)=@_;my $identity=id($a{id});my $shape=$a{shape}//'standard';my $risk=$a{risk}//'R1';
    fail('shape must be compact or standard') if $shape!~/\A(?:compact|standard)\z/;
    fail('risk must be R1 or R2') if $risk!~/\AR[12]\z/;
    fail('compact permits R1 only') if $shape eq 'compact' && $risk ne 'R1';
    fail('compact does not allocate a spec') if $shape eq 'compact' && defined $a{spec};
    fail('R1 does not bind a new Truth file') if $risk eq 'R1' && defined $a{truth_ref};
    fail('R2 creation requires --truth-ref docs/sot/...md') if $risk eq 'R2' && (!defined($a{truth_ref}) || $a{truth_ref}!~m{\Adocs/sot/[A-Za-z0-9._/-]+\.md\z});
    return locked(sub {
        P2T2C::DocumentTransactions::recover($identity);
        my $path=proposal_path($identity);
        if (exists_path($path)) {
            my $w=work($identity,0);
            fail('existing identity has a different shape or risk') if $w->{shape} ne $shape || $w->{proposal}{fm}{risk} ne $risk;
            fail('existing identity has a different spec') if defined($a{spec}) && $a{spec} ne ($w->{spec}//q());
            fail('existing identity has a different Truth target') if defined($a{truth_ref}) && $a{truth_ref} ne $w->{proposal}{fm}{truth_ref};
            return {schema_version=>1,action=>'create',state=>'existing',idempotent=>JSON::PP::true,%{public_work($w)}};
        }
        P2T2C::DocumentTransactions::fs('check_dir','docs/proposals','proposal root');
        my(%map,@entries,$spec);
        if ($shape eq 'compact') { $map{$path}=template('COMPACT_SP_TEMPLATE.md',$identity) }
        else {
            $spec=allocate_spec($identity,$a{spec});my $dir="docs/specs/$spec";
            fail("spec directory already exists: $dir") if exists_path($dir);
            $map{$path}=template('SP_TEMPLATE.md',$identity,$spec);
            if ($risk eq 'R2') {
                for my $pair ([risk=>'R2'],[status=>'proposed'],[decision=>'pending'],[truth_ref=>$a{truth_ref}]) {
                    $map{$path}=field($map{$path},@$pair);
                }
            }
            $map{"$dir/design.md"}=template('design.md',$identity,$spec);
            $map{"$dir/tasks.md"}=template('tasks.md',$identity,$spec);
            push @entries,map {{path=>$_,after=>$map{$_}}} ("$dir/design.md","$dir/tasks.md");
        }
        push @entries,{path=>$path,after=>$map{$path}};
        validate_candidates($identity,\%map);
        P2T2C::DocumentTransactions::run(action=>'create',proposal_id=>$identity,
            defined($spec)?(specs_ref=>"docs/specs/$spec"):(),entries=>\@entries,
            validate=>sub {validate_candidates($identity,{})});
        my $w=work($identity,0);
        return {schema_version=>1,action=>'create',state=>'created',%{public_work($w)}};
    });
}

sub expand {
    my(%a)=@_;my $identity=id($a{proposal});
    fail('expansion requires --prepared relative-directory') if !defined $a{prepared};
    P2T2C::DocumentTransactions::fs('check_dir',$a{prepared},'prepared candidates');
    my $expected=$a{source_digest};
    if (!defined $expected && exists_path("$a{prepared}/source.sha256")) {
        $expected=P2T2C::Documents::read_safe("$a{prepared}/source.sha256",'prepared source binding');$expected=~s/\s+\z//;
    }
    fail('expansion requires --source-digest SHA256 or prepared/source.sha256') if !defined($expected)||$expected!~/\A[0-9a-f]{64}\z/;
    return locked(sub {
        P2T2C::DocumentTransactions::recover($identity);
        my $w=work($identity,0);
        if ($w->{shape} eq 'standard') {
            my $prior;
            for my $pair (reverse @{P2T2C::DocumentTransactions::reports($identity)}) {
                my $r=$pair->[1];next if $r->{action} ne 'expand' || $r->{status} ne 'committed';
                $prior=$r;last;
            }
            fail('work is already standard and has no matching expansion') if !$prior || $prior->{entries}[-1]{before_digest} ne $expected;
            return {schema_version=>1,action=>'expand',state=>'expanded',idempotent=>JSON::PP::true,%{public_work($w)}};
        }
        fail('completed compact cannot expand') if $w->{status} eq 'completed';
        fail('compact source changed after candidates were prepared') if sha256_hex($w->{proposal}{raw}) ne $expected;
        my $proposal=P2T2C::Documents::read_safe("$a{prepared}/proposal.md",'prepared proposal');
        my($fm)=P2T2C::Documents::frontmatter("$a{prepared}/proposal.md",$proposal);
        fail('expansion candidate must be standard proposal v1 with the same ID') if ($fm->{schema_version}//q()) ne '1' || ($fm->{id}//q()) ne $identity;
        my $dir=$fm->{specs_ref};fail('expansion has an invalid specs_ref') if !defined($dir)||$dir!~m{\Adocs/specs/[0-9]{3,4}-[a-z0-9]+(?:-[a-z0-9]+)*\z};
        my $reserved=P2T2C::DocumentTransactions::reserved_spec($identity,'expand');
        fail('retry must retain the allocated specs reference') if defined($reserved) && $reserved ne $dir;
        fail("expansion target already exists: $dir") if exists_path($dir);
        my %map=($w->{proposal}{path}=>$proposal,
            "$dir/design.md"=>P2T2C::Documents::read_safe("$a{prepared}/design.md",'prepared design'),
            "$dir/tasks.md"=>P2T2C::Documents::read_safe("$a{prepared}/tasks.md",'prepared tasks'));
        my $candidate=validate_candidates($identity,\%map);
        fail('expansion must preserve execution state') if $candidate->{status} ne $w->{status};
        for my $key (qw(Tests Verify Dangerous_operations Authorization_ref Summary)) {
            fail("expansion changed recorded $key") if $candidate->{record}{completion}{$key} ne $w->{record}{completion}{$key};
        }
        fail('expansion cannot clear an existing blocker') if $w->{record}{completion}{Known_blockers} eq 'present' && $candidate->{record}{completion}{Known_blockers} ne 'present';
        my %entries; $entries{$_->{state}."\0".$_->{text}}++ for @{$candidate->{record}{entries}};
        for my $old (@{$w->{record}{entries}}) {fail('expansion lost or changed a controlled task') if !$entries{$old->{state}."\0".$old->{text}}--}
        my @changes=map {{path=>$_,after=>$map{$_}}} ("$dir/design.md","$dir/tasks.md");
        push @changes,{path=>$w->{proposal}{path},before=>$w->{proposal}{raw},after=>$proposal};
        P2T2C::DocumentTransactions::run(action=>'expand',proposal_id=>$identity,specs_ref=>$dir,entries=>\@changes,validate=>sub {validate_candidates($identity,{})});
        return {schema_version=>1,action=>'expand',state=>'expanded',%{public_work(work($identity,0))}};
    });
}

sub archive {
    my(%a)=@_;
    fail('record-digest must be a SHA-256') if defined($a{record_digest}) && $a{record_digest}!~/\A[0-9a-f]{64}\z/;
    fail('choose exactly one of --proposal or --spec') if (defined($a{proposal})?1:0)+(defined($a{spec})?1:0)!=1;
    id($a{proposal}) if defined $a{proposal};spec_id($a{spec}) if defined $a{spec};
    return locked(sub {
        my $identity=$a{proposal};
        if (defined $a{spec}) {
            my $path="docs/specs/$a{spec}/tasks.md";
            P2T2C::Documents::recover_standard_archive($path);
            my($fm)=P2T2C::Documents::frontmatter($path);
            ($identity)=($fm->{proposal}//q())=~m{\Adocs/proposals/(SP-[0-9]{8}-[a-z0-9]+(?:-[a-z0-9]+)*)\.md\z};
            id($identity);
        }
        P2T2C::DocumentTransactions::recover($identity);
        my $proposal=P2T2C::Documents::validate_proposal(proposal_path($identity),0,0);
        if ($proposal->{shape} eq 'standard') {
            my $dir=$proposal->{fm}{specs_ref};my $design=P2T2C::Documents::validate_design("$dir/design.md",0);
            fail('proposal/design ownership mismatch') if $design->{fm}{proposal} ne $proposal->{path};
            P2T2C::Documents::recover_standard_archive("$dir/tasks.md");
        }
        my $w=work($identity,1);
        fail('main record changed after external acceptance checks') if defined($a{record_digest}) && sha256_hex($w->{record}{raw}) ne $a{record_digest};
        if ($w->{shape} eq 'standard') {
            fail('spec/proposal identity mismatch') if defined($a{spec}) && $w->{spec} ne $a{spec};
            my $out=P2T2C::Documents::archive_spec($w->{spec},$a{record_digest});
            return $out if defined $a{spec};
            return {%$out,%{public_work(work($identity,1))}};
        }
        fail('compact has no spec; use --proposal') if defined $a{spec};
        my $result={schema_version=>1,action=>'archive',state=>'completed',tests=>$w->{record}{completion}{Tests},verify=>$w->{record}{completion}{Verify}};
        return {%$result,%{public_work($w)},idempotent=>JSON::PP::true} if $w->{status} eq 'completed';
        my $updated=field($w->{record}{raw},'work_status','completed');
        P2T2C::DocumentTransactions::run(action=>'archive',proposal_id=>$identity,
            entries=>[{path=>$w->{path},before=>$w->{record}{raw},after=>$updated}],validate=>sub {work($identity,1,1)});
        return {%$result,%{public_work(work($identity,1))}};
    });
}

sub recover {
    my(%a)=@_;my $identity=id($a{proposal});
    return locked(sub {my $n=P2T2C::DocumentTransactions::recover($identity);return {schema_version=>1,action=>'recover',state=>$n?'recovered':'not_applicable',proposal=>proposal_path($identity),operations=>$n}});
}

sub runtime_capabilities {
    my($runtime)=@_;
    fail('runtime directory is required') if !defined($runtime)||!-d$runtime||-l$runtime;
    my $supports_compact=0;
    my $supports_standard=-f "$runtime/.p2t2c/bin/p2t2c_documents.pl" && -f "$runtime/.p2t2c/lib/P2T2C/Documents.pm";
    my $manifest="$runtime/.p2t2c/manifest.yaml";
    if (-f $manifest && !-l $manifest) {
        open my $fh,'<',$manifest or fail('cannot read runtime capabilities');local $/;my $raw=<$fh>;close $fh;
        $supports_standard=1 if $raw=~/^  (?:document_formats: "[^"\n]*standard-v1[^"\n]*"|new_work_profile: "p2t2c-core-v1")\s*$/m;
        $supports_compact=1 if $raw=~/^  document_formats: "standard-v1,compact-v2"\s*$/m;
    }
    return {standard=>$supports_standard?1:0,compact=>$supports_compact?1:0};
}

sub assert_runtime_compatible {
    my($runtime)=@_;
    P2T2C::DocumentTransactions::assert_no_pending();
    my $cap=runtime_capabilities($runtime);
    my @blocked;
    if (-d 'docs/proposals') {
        opendir(my $dh,'docs/proposals') or fail('cannot inspect formats for downgrade');my @names=sort grep {/^SP-.*\.md$/} readdir $dh;closedir $dh;
        for my $name (@names) {
            my $path="docs/proposals/$name";my $p=P2T2C::Documents::validate_proposal($path,1,0);
            push @blocked,$path if !$p->{legacy} && (($p->{fm}{schema_version} eq '1' && !$cap->{standard}) || ($p->{fm}{schema_version} eq '2' && !$cap->{compact}));
        }
    }
    fail('target runtime cannot read these records (completed included): '.join(', ',@blocked)) if @blocked;
    return 1;
}

1;
