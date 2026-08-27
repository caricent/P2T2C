#!/usr/bin/env perl
use strict;
use warnings;

use Digest::SHA qw(sha256_hex);
use Fcntl qw(:mode);
use File::Spec ();
use JSON::PP ();
use POSIX qw(strftime);

my $json = JSON::PP->new->canonical(1)->utf8(1)->allow_nonref(0);
my $null = undef;
my $command = shift(@ARGV) // '';
my ($phase, $work_id, $intent, $intent_file);
my $json_flag = 0;

while (@ARGV) {
    my $arg = shift @ARGV;
    if ($arg eq '--phase') { @ARGV or usage(); $phase = shift @ARGV; next }
    if ($arg eq '--work-id') { @ARGV or usage(); $work_id = shift @ARGV; next }
    if ($arg eq '--intent') { @ARGV or usage(); $intent = shift @ARGV; next }
    if ($arg eq '--intent-file') { @ARGV or usage(); $intent_file = shift @ARGV; next }
    if ($arg eq '--json') { $json_flag = 1; next }
    usage();
}

usage() if $command !~ /\A(?:context|status|evidence-summary)\z/;
usage() if defined($work_id) && $work_id !~ /\A[A-Za-z0-9][A-Za-z0-9._-]{0,191}\z/;
usage() if $command eq 'context' && (!defined($phase) || $phase !~ /\A(?:admit-route|execute|verify-close)\z/);
usage() if $command ne 'context' && !defined($work_id);
usage() if defined($intent) && defined($intent_file);
usage() if $command ne 'context' && (defined($intent) || defined($intent_file) || defined($phase));
die "ERROR: run from a P2T2C project root\n" if !-d '.p2t2c' || !-d 'docs';

sub usage {
    print STDERR "ERROR: invalid context command arguments\n";
    exit 2;
}

sub now_iso {
    return strftime('%Y-%m-%dT%H:%M:%SZ', gmtime(time()));
}

sub read_raw {
    my ($path) = @_;
    open my $fh, '<:raw', $path or die "cannot read $path\n";
    local $/;
    my $raw = <$fh> // '';
    close $fh or die "cannot close $path\n";
    return $raw;
}

sub safe_repo_file {
    my ($path) = @_;
    die "unsafe path\n" if !defined($path) || $path eq '' || length($path) > 512 || $path =~ m{\A/|(?:\A|/)\.\.(?:/|\z)|//|[\x00-\x1f\x7f]};
    my @parts = split m{/}, $path;
    my $current = '';
    for my $i (0 .. $#parts) {
        $current = $current eq '' ? $parts[$i] : "$current/$parts[$i]";
        my @st = lstat($current);
        die "missing path\n" if !@st;
        die "symlink path\n" if S_ISLNK($st[2]);
        die "unsafe parent\n" if $i < $#parts && !S_ISDIR($st[2]);
        die "unsafe file\n" if $i == $#parts && (!S_ISREG($st[2]) || $st[3] != 1);
    }
    return 1;
}

sub decode_object {
    my ($raw) = @_;
    my $object = eval { $json->decode($raw) };
    die "malformed JSON\n" if $@ || ref($object) ne 'HASH';
    return $object;
}

sub scalar_value {
    my ($value) = @_;
    $value //= '';
    $value =~ s/^\s+|\s+$//g;
    if ($value =~ /\A"/) {
        my $decoded = eval { JSON::PP->new->allow_nonref(1)->decode($value) };
        return $decoded if !$@ && !ref($decoded);
    }
    if ($value =~ /\A'(.*)'\z/s) { my $v = $1; $v =~ s/''/'/g; return $v }
    return $value;
}

sub frontmatter {
    my ($path) = @_;
    safe_repo_file($path);
    my $raw = read_raw($path);
    $raw =~ s/\r\n/\n/g;
    my ($fm) = $raw =~ /\A---\n(.*?)\n---(?:\n|\z)/s;
    die "missing frontmatter\n" if !defined($fm);
    my %values;
    for my $line (split /\n/, $fm) {
        next if $line =~ /^\s*(?:#.*)?$/;
        my ($key, $value) = $line =~ /^([A-Za-z0-9_]+):[ \t]*(.*?)\s*$/;
        next if !defined($key);
        $values{$key} = scalar_value($value);
    }
    return (\%values, $raw);
}

sub parse_inline_list {
    my ($raw) = @_;
    return [] if !defined($raw) || $raw !~ /\A\[(.*)\]\z/;
    my $inside = $1;
    return [] if $inside =~ /^\s*$/;
    return [map { scalar_value($_) } split /\s*,\s*/, $inside];
}

sub manifest_data {
    my $path = 'docs/sot/manifest.yaml';
    safe_repo_file($path);
    my $raw = read_raw($path);
    my (@truth, @adrs, $section, $current);
    for my $line (split /\r?\n/, $raw) {
        if ($line =~ /\A(truth_documents|adrs):\s*\z/) { $section = $1; $current = undef; next }
        if ($line =~ /^\S/ && $line !~ /\A(?:truth_documents|adrs):/) { $section = undef; $current = undef; next }
        next if !defined($section);
        if ($line =~ /^  - path:\s*(.+?)\s*$/) {
            $current = { path => scalar_value($1), sha256 => '', rule_ids => [], topics => [] };
            push @{$section eq 'truth_documents' ? \@truth : \@adrs}, $current;
            next;
        }
        next if !$current;
        if ($line =~ /^    (sha256|id|status):\s*(.+?)\s*$/) { $current->{$1} = scalar_value($2); next }
        if ($line =~ /^    (rule_ids|topics):\s*(\[.*\])\s*$/) { $current->{$1} = parse_inline_list($2); next }
    }
    for my $entry (@truth, @adrs) {
        safe_repo_file($entry->{path});
        die "stale manifest digest\n" if $entry->{sha256} !~ /\A[0-9a-f]{64}\z/
            || sha256_hex(read_raw($entry->{path})) ne $entry->{sha256};
    }
    return { path => $path, digest => sha256_hex($raw), truth => \@truth, adrs => \@adrs };
}

sub discover_project_truth {
    my ($indexed) = @_;
    my %indexed = map { $_->{path} => 1 } @$indexed;
    my @paths;
    my $walk;
    $walk = sub {
        my ($dir) = @_;
        my @dir_stat = lstat($dir);
        return if !@dir_stat || S_ISLNK($dir_stat[2]) || !S_ISDIR($dir_stat[2]);
        opendir my $dh, $dir or die "cannot inspect Truth directory\n";
        my @entries = sort grep { $_ ne '.' && $_ ne '..' } readdir $dh;
        closedir $dh or die "cannot close Truth directory\n";
        for my $entry (@entries) {
            last if @paths >= 256;
            my $path = "$dir/$entry";
            my @st = lstat($path);
            next if !@st || S_ISLNK($st[2]);
            if (S_ISDIR($st[2])) { $walk->($path); next }
            next if !S_ISREG($st[2]) || $st[3] != 1 || $path !~ /\.md\z/i;
            next if $path =~ /(?:\A|\/)[^\/]*HISTORY\.md\z/i || $indexed{$path};
            push @paths, $path;
            return if @paths >= 256;
        }
    };
    $walk->('docs/sot');
    @paths = sort @paths;
    my @selected = @paths;
    splice @selected, 1 if @selected > 1;
    my @locators;
    for my $path (@selected) {
        push @locators, { path => $path, sha256 => sha256_hex(read_raw($path)), rule_ids => [], topics => [] };
    }
    return (\@locators, scalar(@paths));
}

sub parse_methodology_file {
    my ($path, $required) = @_;
    return undef if !-f $path;
    my @lines = split /\r?\n/, read_raw($path);
    my @declarations=grep {/^methodology:/} @lines;
    return undef if !@declarations;
    die "duplicate methodology section\n" if @declarations != 1;
    die "methodology must use block mapping form\n" if $declarations[0] !~ /^methodology:\s*(?:#.*)?$/;
    my (%value, %seen, $inside, $review);
    for my $line (@lines) {
        if (!$inside) { if ($line =~ /^methodology:\s*(?:#.*)?$/) { $inside=1; next } else { next } }
        last if $line =~ /^\S/;
        next if $line =~ /^\s*(?:#.*)?$/;
        if ($line =~ /^  review:\s*(?:#.*)?$/) { die "duplicate methodology.review\n" if $seen{review}++; $review=1; next }
        if ($line =~ /^  ([A-Za-z0-9_]+):\s*(.+?)\s*$/) {
            my ($key,$raw)=($1,$2); die "duplicate methodology key\n" if $seen{$key}++;
            die "unsupported methodology key\n" if $key !~ /\A(?:profile|enforcement|tdd|debugging|isolation|parallel_execution|fan_out|wait_strategy)\z/;
            $value{$key}=scalar_value($raw); $review=0; next;
        }
        if ($review && $line =~ /^    (r1_production_code|r2):\s*(.+?)\s*$/) {
            my ($key,$raw)=($1,$2); die "duplicate methodology review key\n" if $seen{"review.$key"}++;
            $value{$key}=scalar_value($raw); next;
        }
        die "malformed methodology section\n";
    }
    return undef if !$inside;
    my @keys=qw(profile enforcement tdd debugging r1_production_code r2 isolation parallel_execution);
    push @keys,qw(fan_out wait_strategy) if ($value{profile}//'') eq 'p2t2c-adaptive-v2';
    die "explicit methodology section is incomplete\n" if grep {!defined($value{$_})||$value{$_} eq ''} @keys;
    die "unsupported methodology profile\n" if $value{profile}!~/\A(?:p2t2c-balanced-v1|p2t2c-adaptive-v2)\z/;
    die "invalid methodology enforcement\n" if $value{enforcement}!~/\A(?:advisory|required)\z/;
    return \%value;
}

sub methodology {
    my $base=parse_methodology_file('.p2t2c/defaults.yaml',1)
        // parse_methodology_file('.p2t2c/templates/project_config.example.yaml',1)
        // die "missing methodology defaults\n";
    my $overlay=parse_methodology_file('.p2t2c/project_config.yaml',0);
    my $effective=$overlay||$base;
    return {profile=>$effective->{profile},enforcement=>$effective->{enforcement}};
}

sub quiet_exec {
    my (@argv)=@_;
    my $pid=fork(); die "cannot fork helper\n" if !defined $pid;
    if ($pid==0) {
        open STDOUT,'>',File::Spec->devnull() or exit 127;
        open STDERR,'>',File::Spec->devnull() or exit 127;
        exec @argv; exit 127;
    }
    waitpid($pid,0); return $? == -1 ? 127 : ($? >> 8);
}

sub quiet_capture {
    my (@argv)=@_;
    my $pid=open my $fh,'-|'; die "cannot fork helper\n" if !defined $pid;
    if ($pid==0) {
        open STDERR,'>',File::Spec->devnull() or exit 127;
        exec @argv; exit 127;
    }
    local $/; my $out=<$fh>//''; return undef if !close $fh;
    $out=~s/[\r\n]+\z//; return $out;
}

sub boolish {
    my ($value) = @_;
    return $json->true if ref($value) && JSON::PP::is_bool($value) && $value;
    return $json->false if ref($value) && JSON::PP::is_bool($value);
    return $value eq 'true' ? $json->true : $json->false;
}

sub cpk_context {
    my ($id) = @_;
    my $path = "docs/change_packs/$id.md";
    return undef if !-f $path;
    my ($fm) = frontmatter($path);
    return {
        work_id => $id, risk => ($fm->{risk} // 'undetermined'),
        execution_shape => ($fm->{execution_shape} // 'undetermined'),
        status => ($fm->{status} // 'undetermined'), gate_a => ($fm->{gate_a} // 'undetermined'),
        contract_digest => undef, baseline_sha => undef,
        implementer => ($fm->{implementer} // ''), work_pack => ($fm->{work_pack} // 'none'),
        truth_patch_ref => ($fm->{truth_patch_ref} // 'none'),
        truth_patch_digest => ($fm->{truth_patch_digest} // 'none'),
        tdd_policy => ($fm->{tdd_policy} // 'not_applicable'),
        production_code_change => boolish($fm->{production_code_change} // 'false'),
        multi_agent => boolish($fm->{multi_agent} // 'false'),
        governance_change => boolish($fm->{governance_change} // 'false'),
        specialist_review_required => boolish($fm->{specialist_review_required} // 'false'),
        ownership_batches => ($fm->{ownership_batches} // 'none'),
        cpk_path => $path,
        evidence_target => (($fm->{risk} // '') eq 'R1' ? $path : 'docs/closure/CR-' . ($id =~ s/^CPK-//r) . '.md'),
    };
}

sub work_context {
    my ($id) = @_;
    my $run = ".p2t2c/runs/$id";
    my $contract = "$run/contract.json";
    if (-f $contract) {
        my @argv=('perl','.p2t2c/bin/p2t2c_evidence.pl','--action','validate-run-state','--work-id',$id);
        my $cpk="docs/change_packs/$id.md"; push @argv,('--cpk',$cpk) if -f $cpk;
        die "active run integrity invalid\n" if !-f '.p2t2c/bin/p2t2c_evidence.pl' || quiet_exec(@argv)!=0;
        safe_repo_file($contract);
        my $ctx = decode_object(read_raw($contract));
        $ctx->{cpk_path} //= ($id =~ /^CPK-/ ? "docs/change_packs/$id.md" : 'none');
        $ctx->{work_pack} //= 'none';
        return ($ctx, 'active_run');
    }
    my $ctx = cpk_context($id);
    return ($ctx, 'cpk') if $ctx;
    return (undef, 'none');
}

sub jsonl_lines {
    my ($raw) = @_;
    die "JSONL must end with newline\n" if $raw ne '' && $raw !~ /\n\z/;
    my @lines = split /\n/, $raw, -1;
    pop @lines if @lines && $lines[-1] eq '';
    die "JSONL contains a blank line\n" if grep { $_ eq '' } @lines;
    return \@lines;
}

sub parse_jsonl {
    my ($raw) = @_;
    my @objects;
    for my $line (@{jsonl_lines($raw)}) {
        push @objects, decode_object($line);
    }
    return \@objects;
}

sub artifact_evidence {
    my ($target, $id) = @_;
    return undef if !defined($target) || !-f $target;
    safe_repo_file($target);
    my $raw = read_raw($target);
    my ($block) = $raw =~ /<!-- p2t2c:evidence:start -->\s*```(?:jsonl|json)\s*\n(.*?)```\s*<!-- p2t2c:evidence:end -->/s;
    return undef if !defined($block);
    my @projection_lines = @{jsonl_lines($block)};
    my $objects = [map { decode_object($_) } @projection_lines];
    return undef if !@$objects;
    my $receipt = $objects->[-1];
    return undef if ($receipt->{receipt_type} // '') ne 'closure';
    my ($events, $evidence_ref, $source_digest);
    if (($receipt->{schema_version} // 0) >= 2 || ($receipt->{evidence_storage} // '') eq 'sidecar_jsonl') {
        $evidence_ref = $receipt->{evidence_ref} // die "receipt lacks evidence ref\n";
        $source_digest = $receipt->{source_digest} // die "receipt lacks source digest\n";
        my $expected = "docs/closure/evidence/EV-$id-$source_digest.jsonl";
        die "sidecar path mismatch\n" if $evidence_ref ne $expected;
        safe_repo_file($evidence_ref);
        my $sidecar = read_raw($evidence_ref);
        die "sidecar digest mismatch\n" if sha256_hex($sidecar) ne $source_digest;
        $events = parse_jsonl($sidecar);
        die "sidecar event count mismatch\n" if ($receipt->{event_count} // -1) != @$events;
    } else {
        pop @$objects;
        pop @projection_lines;
        $events = $objects;
        my $event_raw = join('', map { "$_\n" } @projection_lines);
        $source_digest = $receipt->{source_digest} // sha256_hex($event_raw);
        die "inline event count mismatch\n" if ($receipt->{event_count} // -1) != @$events;
        die "inline event digest mismatch\n" if sha256_hex($event_raw) ne $source_digest;
    }
    return { receipt => $receipt, events => $events, evidence_ref => $evidence_ref,
        source_digest => $source_digest, target => $target };
}

sub closed_evidence {
    my ($id, $ctx) = @_;
    my @targets;
    if ($id =~ /^R0-(.+)$/) { push @targets, "docs/closure/CR-$1.md" }
    elsif ($ctx) {
        push @targets, $ctx->{evidence_target} if $ctx->{evidence_target};
        push @targets, $ctx->{cpk_path} if ($ctx->{risk} // '') eq 'R1';
    }
    my %seen;
    for my $target (grep { defined($_) && !$seen{$_}++ } @targets) {
        my $found = artifact_evidence($target, $id);
        return $found if $found;
    }
    return undef;
}

sub capture {
    my (@argv) = @_;
    open my $pipe, '-|', @argv or return undef;
    local $/;
    my $out = <$pipe> // '';
    return undef if !close $pipe;
    $out =~ s/[\r\n]+\z//;
    return $out;
}

sub current_binding {
    my ($target) = @_;
    my $head = capture('git', 'rev-parse', '--verify', 'HEAD');
    my $tree;
    if (defined($target) && -f '.p2t2c/bin/p2t2c_evidence.pl') {
        $tree = capture('perl', '.p2t2c/bin/p2t2c_evidence.pl', '--action', 'tree', '--target', $target);
    }
    return { head_sha => $head, tree_sha => $tree };
}

sub log_ref {
    my ($id, $event) = @_;
    return undef if !defined($event->{event_id}) || ($event->{exit_code} // 0) == 0;
    my $path = ".p2t2c/runs/$id/outputs/$event->{event_id}.log";
    return undef if !-f $path;
    eval { safe_repo_file($path) } or return undef;
    my $raw = read_raw($path);
    return undef if defined($event->{output_digest}) && sha256_hex($raw) ne $event->{output_digest};
    return $path;
}

sub summarize_events {
    my ($id, $events, $final_tree, $final_head) = @_;
    my (%count, %verification, %roles, %batches, @failures, $route, $max_repair);
    my ($red, $green, $exemption) = (0, 0, 0);
    my ($critical, $important, $minor) = (0, 0, 0);
    for my $event (@$events) {
        my $type = $event->{event_type} // 'unknown';
        $count{$type}++;
        $route = $event if $type eq 'route';
        $red = 1 if $type eq 'tdd_red'; $green = 1 if $type eq 'tdd_green';
        $exemption = 1 if $type eq 'tdd_exemption';
        if ($type eq 'repair') { my $r = $event->{repair_round} // 0; $max_repair = $r if !$max_repair || $r > $max_repair }
        if ($type eq 'review') {
            die "invalid review role\n" if !defined($event->{review_role}) || $event->{review_role} !~ /\A(?:batch|global|specialist|re_review)\z/;
            $roles{$event->{review_role}} = 1 if defined($event->{review_role});
            $batches{$event->{batch_id}} = 1 if defined($event->{batch_id});
            $critical = $event->{critical} if ($event->{critical} // 0) > $critical;
            $important = $event->{important} if ($event->{important} // 0) > $important;
            $minor = $event->{minor} if ($event->{minor} // 0) > $minor;
        }
        if ($type eq 'verification') {
            die "invalid verification profile\n" if !defined($event->{verification_profile}) || $event->{verification_profile} !~ /\A(?:fast|impacted|full|governance)\z/;
            die "invalid verification command id\n" if !defined($event->{command_id}) || $event->{command_id} !~ /\A[A-Za-z0-9][A-Za-z0-9._-]{0,127}\z/;
            my $key = ($event->{verification_profile} // '') . ':' . ($event->{command_id} // '');
            $verification{$key} = {
                profile => ($event->{verification_profile} // ''), command_id => ($event->{command_id} // ''),
                exit_code => 0 + ($event->{exit_code} // 0), tree_sha => ($event->{tree_sha} // undef),
                fresh => (defined($final_tree) && defined($final_head) && ($event->{tree_sha} // '') eq $final_tree
                    && ($event->{head_sha} // '') eq $final_head) ? $json->true : $json->false,
                covered_by => undef,
            };
            if (ref($event->{covered_commands}) eq 'ARRAY') {
                for my $covered (@{$event->{covered_commands}}) {
                    next if ref($covered) ne 'HASH';
                    die "invalid covered verification\n" if !defined($covered->{profile}) || $covered->{profile} !~ /\A(?:fast|impacted|full|governance)\z/
                        || !defined($covered->{command_id}) || $covered->{command_id} !~ /\A[A-Za-z0-9][A-Za-z0-9._-]{0,127}\z/;
                    my $covered_key = ($covered->{profile} // '') . ':' . ($covered->{command_id} // '');
                    $verification{$covered_key} = {
                        profile => ($covered->{profile} // ''), command_id => ($covered->{command_id} // ''),
                        exit_code => 0 + ($event->{exit_code} // 0), tree_sha => ($event->{tree_sha} // undef),
                        fresh => (defined($final_tree) && defined($final_head) && ($event->{tree_sha} // '') eq $final_tree
                            && ($event->{head_sha} // '') eq $final_head) ? $json->true : $json->false,
                        covered_by => $key,
                    };
                }
            }
        }
        if (exists($event->{exit_code}) && $event->{exit_code} != 0) {
            push @failures, {
                event_id => ($event->{event_id} // ''), event_type => $type,
                profile => ($event->{verification_profile} // undef), command_id => ($event->{command_id} // undef),
                exit_code => 0 + $event->{exit_code}, log_ref => log_ref($id, $event),
            };
            shift @failures while @failures > 8;
        }
    }
    my @verification = map { $verification{$_} } sort keys %verification;
    @verification = @verification[-32 .. -1] if @verification > 32;
    my @batch_list = sort keys %batches;
    @batch_list = @batch_list[0 .. 31] if @batch_list > 32;
    return {
        counts => \%count, route => $route, verification => \@verification,
        failures => \@failures, roles => [sort keys %roles], batches => \@batch_list,
        findings => { critical => $critical, important => $important, minor => $minor },
        max_repair => 0 + ($max_repair // 0), repair_count => 0 + ($count{repair} // 0),
        tdd => ($red && $green ? 'red_green' : $exemption ? 'exemption' : 'not_recorded'),
    };
}

sub status_object {
    my ($id) = @_;
    my ($ctx, $source) = work_context($id);
    my $closed = closed_evidence($id, $ctx);
    if (!$ctx && !$closed) {
        return ({ schema_version => 1, kind => 'work_status', work_id => $id, state => 'missing', source => 'none',
            contract => undef, binding => { head_sha => capture('git','rev-parse','--verify','HEAD'), tree_sha => undef },
            paths => { cpk => undef, work_pack => undef, run => undef, ledger => undef, evidence_target => undef, evidence_ref => undef },
            progress => { event_count => 0, route_count => 0, verification_count => 0, review_count => 0, repair_round => 0 },
            required_profiles => [], satisfied_profiles => [], latest_failures => [],
            blockers => [{ code => 'WORK_NOT_FOUND', ref => undef }], next_legal_actions => [] }, 3);
    }
    my $events = $closed ? $closed->{events} : [];
    my $ledger = ".p2t2c/runs/$id/events.jsonl";
    if (!$closed && -f $ledger) { safe_repo_file($ledger); $events = parse_jsonl(read_raw($ledger)) }
    my $receipt = $closed ? $closed->{receipt} : undef;
    my $target = $closed ? $closed->{target} : ($ctx ? $ctx->{evidence_target} : undef);
    my $binding = $closed ? { head_sha => $receipt->{head_sha}, tree_sha => $receipt->{final_tree_sha} }
        : current_binding($target);
    my $summary = summarize_events($id, $events, $binding->{tree_sha}, $binding->{head_sha});
    my @required = $receipt && ref($receipt->{verification_requirements}) eq 'ARRAY'
        ? map { $_->{profile} } @{$receipt->{verification_requirements}} : ();
    my ($canonical_primary,$canonical_close_ok);
    if (!$receipt && $ctx && -f $ledger) {
        my @primary=(($ctx->{risk}//'') eq 'R2'||$ctx->{multi_agent})?('full'):qw(fast impacted full);
        for my $candidate (@primary) {
            my $plan=quiet_capture('perl','.p2t2c/bin/p2t2c_evidence.pl','--action','verification-plan',
                '--file',$ledger,'--contract-file',".p2t2c/runs/$id/contract.json",
                '--verification-profile',$candidate,'--target',$target);
            next if !defined $plan;
            my $decoded=eval {$json->decode($plan)}; next if $@||ref($decoded) ne 'HASH'||ref($decoded->{requirements}) ne 'ARRAY';
            $canonical_primary=$candidate; @required=map {$_->{profile}} @{$decoded->{requirements}}; last;
        }
        if (defined $canonical_primary) {
            $canonical_close_ok=quiet_exec('perl','.p2t2c/bin/p2t2c_evidence.pl','--action','validate-ledger',
                '--file',$ledger,'--contract-file',".p2t2c/runs/$id/contract.json",'--work-id',$id,
                '--verification-profile',$canonical_primary,'--target',$target)==0 ? 1 : 0;
        }
    }
    my %required_seen; @required = grep { /\A(?:fast|impacted|full|governance)\z/ && !$required_seen{$_}++ } @required;
    my %satisfied = map { $_->{fresh} && $_->{exit_code} == 0 ? ($_->{profile} => 1) : () } @{$summary->{verification}};
    my $state = $closed ? 'closed' : (($ctx->{status} // '') eq 'blocked' || ($ctx->{gate_a} // '') eq 'pending' ? 'blocked' : 'active');
    my @blockers;
    push @blockers, { code => 'GATE_A_PENDING', ref => ($ctx->{cpk_path} // undef) } if $ctx && ($ctx->{gate_a} // '') eq 'pending';
    push @blockers, { code => 'CONTRACT_BLOCKED', ref => ($ctx->{cpk_path} // undef) } if $ctx && ($ctx->{status} // '') eq 'blocked';
    if (!$closed && $ctx && ($ctx->{truth_patch_ref} // 'none') ne 'none') {
        safe_repo_file($ctx->{truth_patch_ref});
        push @blockers, { code => 'CONTRACT_TRUTH_STALE', ref => $ctx->{truth_patch_ref} }
            if ($ctx->{truth_patch_digest} // '') ne sha256_hex(read_raw($ctx->{truth_patch_ref}));
    }
    my %roles = map { $_ => 1 } @{$summary->{roles}};
    my %batches = map { $_ => 1 } @{$summary->{batches}};
    my $profiles_ready = !grep { !$satisfied{$_} } @required;
    my $reviews_ready = 1;
    $reviews_ready = 0 if $ctx && (($ctx->{risk} // '') eq 'R2' || ($ctx->{execution_shape} // '') eq 'architectural'
        || (($ctx->{execution_shape} // '') eq 'bounded' && $ctx->{production_code_change})) && !$roles{global};
    $reviews_ready = 0 if $ctx && $ctx->{specialist_review_required} && !$roles{specialist};
    if ($ctx && ($ctx->{execution_shape} // '') eq 'architectural') {
        for my $batch (split /,/, ($ctx->{ownership_batches} // '')) { $reviews_ready = 0 if $batch ne '' && !$batches{$batch} }
    }
    $reviews_ready = 0 if $summary->{findings}{critical} || $summary->{findings}{important} || $summary->{findings}{minor};
    my $tdd_ready = !$ctx || ($ctx->{tdd_policy} // '') eq 'not_applicable'
        || (($ctx->{tdd_policy} // '') eq 'required' && $summary->{tdd} eq 'red_green')
        || (($ctx->{tdd_policy} // '') eq 'exempt' && $summary->{tdd} eq 'exemption');
    my $status_ready = $ctx && ((($ctx->{risk} // '') eq 'R2' && ($ctx->{status} // '') eq 'applied')
        || (($ctx->{risk} // '') ne 'R2' && ($ctx->{status} // '') eq 'ready'));
    if ($state eq 'active' && $status_ready && $canonical_close_ok) {
        $state = 'closable';
    }
    my @next = $state eq 'closed' ? () : @blockers ? ('safe_exploration','resolve_blocker')
        : !($summary->{counts}{route} // 0) ? ('record_route')
        : $state eq 'closable' ? ('validate_close') : ('continue_current_phase','run_verification');
    return ({
        schema_version => 1, kind => 'work_status', work_id => $id, state => $state,
        source => ($closed ? 'closure' : $source),
        contract => $ctx ? { risk => ($ctx->{risk} // 'undetermined'), execution_shape => ($ctx->{execution_shape} // 'undetermined'),
            status => ($ctx->{status} // 'undetermined'), gate_a => ($ctx->{gate_a} // 'undetermined'),
            contract_digest => ($ctx->{contract_digest} // undef), baseline_sha => ($ctx->{baseline_sha} // undef),
            implementer => ($ctx->{implementer} // '') } : undef,
        binding => $binding,
        paths => { cpk => ($ctx && ($ctx->{cpk_path} // '') ne 'none' ? $ctx->{cpk_path} : undef),
            work_pack => ($ctx && ($ctx->{work_pack} // '') ne 'none' ? $ctx->{work_pack} : undef),
            run => (-d ".p2t2c/runs/$id" ? ".p2t2c/runs/$id" : undef),
            ledger => (-f $ledger ? $ledger : undef), evidence_target => $target,
            evidence_ref => ($closed ? $closed->{evidence_ref} : undef) },
        progress => { event_count => scalar(@$events), route_count => 0 + ($summary->{counts}{route} // 0),
            verification_count => 0 + ($summary->{counts}{verification} // 0), review_count => 0 + ($summary->{counts}{review} // 0),
            repair_round => $summary->{max_repair} },
        required_profiles => \@required, satisfied_profiles => [sort keys %satisfied],
        latest_failures => $summary->{failures}, blockers => \@blockers, next_legal_actions => \@next,
    }, 0);
}

sub evidence_object {
    my ($id) = @_;
    my ($ctx) = work_context($id);
    my $closed = closed_evidence($id, $ctx);
    my $ledger = ".p2t2c/runs/$id/events.jsonl";
    die "work evidence not found\n" if !$closed && !-f $ledger;
    my ($events, $receipt, $state, $ledger_ref, $evidence_ref, $digest);
    if ($closed) {
        ($events, $receipt, $state, $evidence_ref, $digest) = ($closed->{events}, $closed->{receipt}, 'closed', $closed->{evidence_ref}, $closed->{source_digest});
    } else {
        safe_repo_file($ledger); my $raw = read_raw($ledger);
        ($events, $state, $ledger_ref, $digest) = (parse_jsonl($raw), 'active', $ledger, sha256_hex($raw));
    }
    my $binding = $receipt ? { contract_digest => ($receipt->{contract_digest} // undef), baseline_sha => ($receipt->{baseline_sha} // undef),
        final_tree_sha => ($receipt->{final_tree_sha} // undef), head_sha => ($receipt->{head_sha} // undef) }
        : { contract_digest => ($ctx->{contract_digest} // undef), baseline_sha => ($ctx->{baseline_sha} // undef),
            final_tree_sha => current_binding($ctx->{evidence_target})->{tree_sha}, head_sha => capture('git','rev-parse','--verify','HEAD') };
    my $summary = summarize_events($id, $events, $binding->{final_tree_sha}, $binding->{head_sha});
    my $route = $summary->{route};
    my @warnings = $receipt && ref($receipt->{evidence_warnings}) eq 'ARRAY' ? @{$receipt->{evidence_warnings}} : ();
    @warnings = @warnings[0 .. 63] if @warnings > 64;
    return {
        schema_version => 1, kind => 'evidence_summary', work_id => $id, state => $state,
        trust => ($receipt ? ($receipt->{evidence_trust} // 'local_consistency') : 'local_consistency'),
        source => { ledger_ref => $ledger_ref, evidence_ref => $evidence_ref, digest => $digest,
            event_count => scalar(@$events), receipt_schema => ($receipt ? 0 + ($receipt->{schema_version} // 1) : undef) },
        binding => $binding,
        route => { risk => ($route ? $route->{to_risk} : $ctx->{risk}), execution_shape => ($route ? $route->{to_shape} : $ctx->{execution_shape}) },
        tdd => { policy => ($receipt ? $receipt->{tdd_policy} : $ctx->{tdd_policy}), evidence => ($receipt ? $receipt->{tdd_evidence} : $summary->{tdd}) },
        verification => $summary->{verification},
        reviews => { roles => $summary->{roles}, batches => $summary->{batches}, %{$summary->{findings}} },
        repairs => { max_round => $summary->{max_repair}, count => $summary->{repair_count} },
        completeness => ($receipt ? ($receipt->{evidence_completeness} // 'complete') : 'in_progress'),
        warnings => \@warnings,
        remaining_risk => { status => ($receipt ? ($receipt->{remaining_risk_status} // 'none') : 'unknown'),
            ref => ($receipt ? ($receipt->{remaining_risk_ref} // 'none') : undef) },
        blockers => [],
    };
}

sub context_object {
    my $manifest = manifest_data();
    my ($ctx,$ctx_source) = defined($work_id) ? work_context($work_id) : (undef,undef);
    my $intent_info;
    if (defined($intent_file)) {
        my $raw;
        if ($intent_file eq '-') { local $/; $raw = <STDIN> // '' }
        else { $raw = read_raw($intent_file) }
        $intent_info = { sha256 => sha256_hex($raw), bytes => length($raw) };
    } elsif (defined($intent)) {
        $intent_info = { sha256 => sha256_hex($intent), bytes => length($intent) };
    }
    my @truth = @{$manifest->{truth}};
    my (@unindexed, $unindexed_count);
    if ($ctx && ($ctx->{truth_patch_ref} // 'none') ne 'none') {
        @truth = grep { $_->{path} eq $ctx->{truth_patch_ref} } @truth;
        if (!@truth) {
            die "unsafe contract Truth ref\n" if $ctx->{truth_patch_ref} !~ m{\Adocs/sot/};
            safe_repo_file($ctx->{truth_patch_ref});
            @truth = ({ path => $ctx->{truth_patch_ref}, sha256 => sha256_hex(read_raw($ctx->{truth_patch_ref})), rule_ids => [], topics => [] });
        }
    } elsif (!$ctx && $phase eq 'admit-route') {
        my ($found, $count) = discover_project_truth($manifest->{truth});
        @unindexed = @$found; $unindexed_count = $count;
    }
    @truth = @truth[0..7] if @truth > 8;
    my @truth_refs = map { { path => $_->{path}, digest => $_->{sha256}, rule_ids => $_->{rule_ids} } } (@truth, @unindexed);
    @truth_refs = @truth_refs[0 .. 7] if @truth_refs > 8;
    my $skill = ".p2t2c/skills/$phase/SKILL.md";
    my @reads = ($skill, $manifest->{path});
    push @reads, $ctx->{cpk_path} if $ctx && ($ctx->{cpk_path} // '') ne 'none';
    if ($ctx && ($ctx->{work_pack} // '') ne 'none') { safe_repo_file($ctx->{work_pack}); push @reads, $ctx->{work_pack} }
    my @profiles;
    if ($ctx && (($ctx->{risk} // '') eq 'R2' || $ctx->{multi_agent})) { push @profiles, 'full' }
    push @profiles, 'governance' if $ctx && $ctx->{governance_change};
    my @blockers;
    push @blockers, { code => 'GATE_A_PENDING', ref => ($ctx->{cpk_path} // undef) } if $ctx && ($ctx->{gate_a} // '') eq 'pending';
    my $historical_closed=$ctx && ($ctx_source//'') ne 'active_run' && ($ctx->{status}//'') eq 'applied'
        && (($ctx->{risk}//'') eq 'R1' || -f($ctx->{evidence_target}//''));
    if (!$historical_closed && $ctx && ($ctx->{truth_patch_ref} // 'none') ne 'none' && @truth) {
        push @blockers, { code => 'CONTRACT_TRUTH_STALE', ref => $ctx->{truth_patch_ref} }
            if ($ctx->{truth_patch_digest} // '') ne $truth[0]{sha256};
    }
    my @allowed = @blockers ? ('read_truth','safe_exploration','resolve_gate_a')
        : $phase eq 'admit-route' ? ('read_truth','classify_route','create_or_update_contract')
        : $phase eq 'execute' ? ('read_truth','execute_owned_work','record_evidence')
        : ('read_truth','verify_final_tree','review','validate_close');
    unshift @allowed, 'discover_project_truth' if $unindexed_count;
    my @cold_refs = ('docs/sot/governance/P2T2C_GOVERNANCE_HISTORY.md','docs/reference/','docs/closure/evidence/');
    push @cold_refs, 'docs/sot/' if $unindexed_count;
    my @warnings = $ctx ? () : ('ROUTE_REQUIRES_AGENT_JUDGMENT');
    push @warnings, 'UNINDEXED_PROJECT_TRUTH' if $unindexed_count;
    return {
        schema_version => 1, kind => 'context_capsule', phase => $phase, generated_at => now_iso(),
        intent => $intent_info, work_id => $work_id, methodology => methodology(),
        route => { risk => ($ctx ? ($ctx->{risk} // 'undetermined') : 'undetermined'),
            execution_shape => ($ctx ? ($ctx->{execution_shape} // 'undetermined') : 'undetermined'),
            gate_a => ($ctx ? ($ctx->{gate_a} // 'undetermined') : 'undetermined'),
            status => ($ctx ? ($ctx->{status} // 'undetermined') : 'undetermined'),
            source => ($ctx ? 'contract' : 'unbound') },
        manifest => { path => $manifest->{path}, digest => $manifest->{digest} },
        truth_refs => \@truth_refs, required_reads => \@reads, required_profiles => \@profiles,
        allowed_actions => \@allowed,
        cold_refs => \@cold_refs, blockers => \@blockers, warnings => \@warnings,
    };
}

sub emit_invalid {
    my ($kind, $id, $error) = @_;
    $error //= 'invalid state'; $error =~ s/[\r\n]+/ /g; $error = substr($error, 0, 192);
    if ($kind eq 'work_status') {
        return { schema_version => 1, kind => $kind, work_id => ($id // ''), state => 'invalid', source => 'none',
            contract => undef, binding => { head_sha => undef, tree_sha => undef },
            paths => { cpk => undef, work_pack => undef, run => undef, ledger => undef, evidence_target => undef, evidence_ref => undef },
            progress => { event_count => 0, route_count => 0, verification_count => 0, review_count => 0, repair_round => 0 },
            required_profiles => [], satisfied_profiles => [], latest_failures => [],
            blockers => [{ code => 'INTEGRITY_INVALID', ref => $error }], next_legal_actions => [] };
    }
    return { schema_version => 1, kind => 'evidence_summary', work_id => ($id // ''), state => 'invalid', trust => undef,
        source => { ledger_ref => undef, evidence_ref => undef, digest => undef, event_count => 0, receipt_schema => undef },
        binding => { contract_digest => undef, baseline_sha => undef, final_tree_sha => undef, head_sha => undef },
        route => { risk => 'undetermined', execution_shape => 'undetermined' },
        tdd => { policy => 'unknown', evidence => 'unknown' }, verification => [],
        reviews => { roles => [], batches => [], critical => 0, important => 0, minor => 0 },
        repairs => { max_round => 0, count => 0 }, completeness => 'invalid', warnings => [],
        remaining_risk => { status => 'unknown', ref => undef }, blockers => [{ code => 'INTEGRITY_INVALID', ref => $error }] };
}

my ($output, $exit_code);
if ($command eq 'context') {
    $output = eval { context_object() };
    if ($@) {
        my $error = $@; $error =~ s/[\r\n]+/ /g;
        $output = { schema_version => 1, kind => 'context_capsule', phase => $phase, generated_at => now_iso(),
            intent => undef, work_id => $work_id, methodology => { profile => 'p2t2c-adaptive-v2', enforcement => 'advisory' },
            route => { risk => 'undetermined', execution_shape => 'undetermined', gate_a => 'undetermined', status => 'invalid', source => 'unbound' },
            manifest => { path => 'docs/sot/manifest.yaml', digest => undef }, truth_refs => [], required_reads => [],
            required_profiles => [], allowed_actions => [], cold_refs => [],
            blockers => [{ code => 'INTEGRITY_INVALID', ref => substr($error,0,192) }], warnings => [] };
        $exit_code = 4;
    }
} elsif ($command eq 'status') {
    my $result = eval { [status_object($work_id)] };
    if ($@) { $output = emit_invalid('work_status',$work_id,$@); $exit_code = 4 }
    else { ($output, $exit_code) = @$result }
} else {
    $output = eval { evidence_object($work_id) };
    if ($@) { $output = emit_invalid('evidence_summary',$work_id,$@); $exit_code = $@ =~ /not found/ ? 3 : 4 }
}

print $json->encode($output), "\n";
exit($exit_code // 0);
