#!/usr/bin/env perl
package P2T2C::Evidence;
use strict;
use warnings;

use Digest::SHA qw(sha256_hex);
use Fcntl qw(:mode O_RDONLY O_NOFOLLOW);
use File::Basename qw(dirname basename);
use File::Spec ();
use File::Temp qw(tempdir);
use Getopt::Long qw(GetOptions);
use JSON::PP ();

my ($action, $file, $work_id, $target, $contract_file, $verification_profile);
my ($remaining_risk_status, $remaining_risk_ref, $cpk, $command_id, $config_file, $evidence_ref);

my $json = JSON::PP->new->canonical(1)->utf8(1)->allow_nonref(0);
my $oid_re = qr/\A(?:[0-9a-f]{40}|[0-9a-f]{64})\z/;
my $digest_re = qr/\A[0-9a-f]{64}\z/;
my $time_re = qr/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z\z/;
my $target_re = qr{\Adocs/(?:change_packs/CPK-|closure/CR-)[A-Za-z0-9._-]+\.md\z};
my $evidence_ref_re = qr{\Adocs/closure/evidence/EV-[A-Za-z0-9._-]+-[0-9a-f]{64}\.jsonl\z};
my @profiles = qw(fast impacted full governance);
my ($verification_profiles_cache,$project_policy_cache);
our $READ_CACHE;
our $FRONTMATTER_CACHE={};
our $LAST_ARTIFACT_INDEX;

sub fail {
    my ($message) = @_;
    die "ERROR: evidence: $message\n";
}

sub need {
    my ($name, $value) = @_;
    fail("missing --$name") if !defined($value) || $value eq '';
}

sub is_string {
    my ($value) = @_;
    return !ref($value) && $json->encode([$value]) =~ /\A\["/;
}

sub is_integer {
    my ($value) = @_;
    return !ref($value) && $json->encode([$value]) =~ /\A\[\d+\]\z/;
}

sub is_boolean {
    my ($value) = @_;
    return JSON::PP::is_bool($value) ? 1 : 0;
}

sub require_string {
    my ($object, $key, $label, $allow_empty) = @_;
    fail("$label.$key must be a JSON string") if !exists($object->{$key}) || !is_string($object->{$key});
    fail("$label.$key cannot be empty") if !$allow_empty && $object->{$key} eq '';
    return $object->{$key};
}

sub require_integer {
    my ($object, $key, $label) = @_;
    fail("$label.$key must be a JSON integer") if !exists($object->{$key}) || !is_integer($object->{$key});
    return 0 + $object->{$key};
}

sub require_boolean {
    my ($object, $key, $label) = @_;
    fail("$label.$key must be a JSON boolean") if !exists($object->{$key}) || !is_boolean($object->{$key});
    return $object->{$key} ? 1 : 0;
}

sub exact_keys {
    my ($object, $allowed, $label) = @_;
    my %allowed = map { $_ => 1 } @$allowed;
    for my $key (keys %$object) {
        fail("$label contains unsupported field: $key") if !$allowed{$key};
    }
}

sub read_raw {
    my ($path) = @_;
    return $READ_CACHE->{$path} if ref($READ_CACHE) eq 'HASH' && exists $READ_CACHE->{$path};
    open my $handle, '<:raw', $path or fail("cannot read $path: $!");
    local $/;
    my $raw = <$handle> // '';
    close $handle or fail("cannot close $path: $!");
    $READ_CACHE->{$path}=$raw if ref($READ_CACHE) eq 'HASH';
    return $raw;
}

sub decode_object {
    my ($raw, $label) = @_;
    my $object = eval { $json->decode($raw) };
    fail("$label is malformed JSON: $@") if $@;
    fail("$label must be a JSON object") if ref($object) ne 'HASH';
    return $object;
}

sub iso_now {
    my @t = gmtime(time());
    return sprintf('%04d-%02d-%02dT%02d:%02d:%02dZ',
        $t[5] + 1900, $t[4] + 1, $t[3], $t[2], $t[1], $t[0]);
}

sub safe_target {
    my ($value) = @_;
    need('target', $value);
    fail("unsafe evidence target: $value") if $value !~ $target_re;
    validate_safe_path($value, 1, 'evidence target');
}

sub safe_evidence_ref {
    my ($value,$allow_missing)=@_;
    fail("unsafe evidence sidecar: " . ($value // '')) if !defined($value) || $value !~ $evidence_ref_re;
    validate_safe_path($value,$allow_missing ? 1 : 0,'evidence sidecar');
}

sub validate_safe_path {
    my ($path, $allow_missing_leaf, $label) = @_;
    fail("$label path is unsafe: $path")
        if !defined($path) || $path eq '' || $path =~ m{\A/|(?:\A|/)\.\.(?:/|\z)|//} || $path =~ /[\x00-\x1f\x7f]/;
    my @parts = split m{/}, $path;
    my $current = '';
    for my $index (0 .. $#parts) {
        $current = $current eq '' ? $parts[$index] : "$current/$parts[$index]";
        my @stat = lstat($current);
        if (!@stat) {
            fail("$label missing parent path: $current") if $index < $#parts || !$allow_missing_leaf;
            next;
        }
        fail("$label path must not traverse a symlink: $current") if S_ISLNK($stat[2]);
        if ($index < $#parts) {
            fail("$label parent must be a directory: $current") if !S_ISDIR($stat[2]);
        } else {
            fail("$label leaf must be a regular file: $current") if !S_ISREG($stat[2]);
        }
    }
}

sub safe_directory_identity {
    my ($dir,$label)=@_;
    fail("$label directory path is unsafe") if !defined($dir)||$dir eq ''||$dir=~m{\A/|(?:\A|/)\.\.(?:/|\z)|//}||$dir=~/[\x00-\x1f\x7f]/;
    my $current='';
    for my $part (split m{/},$dir) {
        $current=$current eq ''?$part:"$current/$part";my@st=lstat($current);
        fail("$label directory is missing or unsafe: $current") if !@st||S_ISLNK($st[2])||!S_ISDIR($st[2]);
    }
    my@st=lstat($dir);return "$st[0]:$st[1]";
}

sub held_read_file {
    my ($dir,$name,$label,$required_mode)=@_;
    fail("$label filename is unsafe") if !defined($name)||$name!~/\A[A-Za-z0-9][A-Za-z0-9._-]{0,255}\z/;
    my$identity=safe_directory_identity($dir,$label);pipe(my$reader,my$writer)or fail("$label cannot create pipe");
    my$pid=fork();fail("$label cannot fork")if!defined$pid;
    if($pid==0){close$reader;chdir($dir)or exit 91;my@dot=stat('.');exit 92 if "$dot[0]:$dot[1]"ne$identity;sysopen(my$fh,$name,O_RDONLY|O_NOFOLLOW)or exit 93;my@st=stat($fh);exit 94 if!S_ISREG($st[2])||$st[3]!=1||$st[4]!=$<;exit 96 if defined($required_mode)&&($st[2]&0777)!=$required_mode;binmode$fh;binmode$writer;my$buf;while(read($fh,$buf,65536)){print{$writer}$buf or exit 95}close$fh;close$writer;exit 0}
    close$writer;binmode$reader;local$/;my$raw=<$reader>//'';close$reader;waitpid($pid,0);fail("$label held-directory read failed")if$?!=0;return$raw;
}

sub held_list_directory {
    my($dir,$label,$required_mode)=@_;my$identity=safe_directory_identity($dir,$label);pipe(my$r,my$w)or fail("$label cannot create pipe");my$pid=fork();fail("$label cannot fork")if!defined$pid;
    if($pid==0){close$r;chdir($dir)or exit 91;my@dot=stat('.');exit 92 if"$dot[0]:$dot[1]"ne$identity||$dot[4]!=$<;exit 96 if defined($required_mode)&&($dot[2]&0777)!=$required_mode;opendir(my$d,'.')or exit 93;binmode$w;for my$n(sort grep{$_ ne'.'&&$_ ne'..'}readdir$d){print{$w}$n,"\0"or exit 94}closedir$d;close$w;exit 0}
    close$w;binmode$r;local$/;my$raw=<$r>//'';close$r;waitpid($pid,0);fail("$label held-directory list failed")if$?!=0;my@names=grep{$_ ne''}split/\0/,$raw,-1;return\@names;
}

sub safe_reference {
    my ($value, $label) = @_;
    return if $value =~ /\A(?:user_instruction|issue_path|sp_path)\z/;
    validate_safe_path($value, 0, $label);
}

sub capture {
    my (@command) = @_;
    open my $pipe, '-|', @command or fail("cannot run @command: $!");
    local $/;
    my $output = <$pipe> // '';
    close $pipe or fail("command failed: @command");
    $output =~ s/[\r\n]+\z//;
    return $output;
}

sub quiet_system {
    my (@command) = @_;
    my $pid=fork(); fail('cannot fork quiet command') if !defined $pid;
    if ($pid==0) {
        open STDOUT,'>',File::Spec->devnull() or exit 255;
        open STDERR,'>&',\*STDOUT or exit 255;
        exec @command; exit 255;
    }
    waitpid($pid,0); return $?;
}

sub current_head {
    my $head = capture('git', 'rev-parse', '--verify', 'HEAD');
    fail('current Git HEAD is not a supported object id') if $head !~ $oid_re;
    return $head;
}

sub workspace_tree {
    my ($evidence_target,$sidecar,$transients) = @_;
    $transients||=[];
    safe_target($evidence_target);
    safe_evidence_ref($sidecar,1) if defined($sidecar) && $sidecar ne '';
    fail('current directory is not inside a Git worktree')
        if capture('git', 'rev-parse', '--is-inside-work-tree') ne 'true';
    my$git_top=capture('git','rev-parse','--show-toplevel');
    my$release_prefix=capture('git','rev-parse','--show-prefix');
    fail('Git top-level is unsafe')if$git_top eq''||!-d$git_top||-l$git_top;
    fail('Git release prefix is unsafe')if$release_prefix=~m{\A/|(?:\A|/)\.\.(?:/|\z)|//|[\x00-\x1f\x7f]};
    my$git_target=$release_prefix.$evidence_target;
    my$git_sidecar=defined($sidecar)&&$sidecar ne''?$release_prefix.$sidecar:'';
    my$git_runs=$release_prefix.'.p2t2c/runs';
    my%transient_path=map{defined($_)&&$_ ne''?($release_prefix.$_=>1):()}@$transients;
    my $temporary = tempdir('p2t2c-index.XXXXXX', TMPDIR => 1, CLEANUP => 1);
    local $ENV{GIT_INDEX_FILE} = "$temporary/index";
    if (quiet_system('git','-C',$git_top,'read-tree','HEAD') != 0) {
        quiet_system('git','-C',$git_top,'read-tree','--empty') == 0 or fail('cannot initialize temporary Git index');
    }
    quiet_system('git','-C',$git_top,'add','-u','--','.') == 0
        or fail('cannot snapshot tracked worktree changes in temporary Git index');
    quiet_system('git','-C',$git_top,'reset','-q','HEAD','--',$git_target) == 0
        or fail('cannot exclude the evidence target from the temporary Git index');
    if (defined($sidecar) && $sidecar ne '') {
        quiet_system('git','-C',$git_top,'reset','-q','HEAD','--',$git_sidecar) == 0
            or fail('cannot exclude the evidence sidecar from the temporary Git index');
    }
    for my $transient (@$transients) {
        next if !defined($transient)||$transient eq ''||!-e$transient;
        validate_safe_path($transient,0,'transaction transient');
        my @transient_stat=lstat($transient);
        fail('transaction transient identity is unsafe') if !@transient_stat||!S_ISREG($transient_stat[2])||S_ISLNK($transient_stat[2])||$transient_stat[3]!=1||$transient_stat[4]!=$<;
        quiet_system('git','-C',$git_top,'reset','-q','HEAD','--',$release_prefix.$transient)==0 or fail('cannot exclude transaction transient from temporary Git index');
    }
    quiet_system('git','-C',$git_top,'reset','-q','HEAD','--',$git_runs) == 0
        or fail('cannot exclude tracked run state from the temporary Git index');
    open my $untracked,'-|','git','-C',$git_top,'ls-files','--others','--exclude-standard','-z','--','.'
        or fail("cannot list untracked worktree files: $!");
    local $/ = "\0";
    my @pending;
    while (my $path = <$untracked>) {
        $path =~ s/\0\z//;
        next if $path eq '' || $path eq $git_target
            || ($git_sidecar ne '' && $path eq $git_sidecar)
            || $transient_path{$path}
            || $path =~ m{\A\Q$git_runs\E(?:/|\z)};
        push @pending, $path;
        if (@pending == 100) {
            quiet_system('git','-C',$git_top,'add','--',@pending) == 0
                or fail('cannot snapshot untracked worktree files in temporary Git index');
            @pending = ();
        }
    }
    close $untracked or fail('git ls-files failed while snapshotting the worktree');
    if (@pending) {
        quiet_system('git','-C',$git_top,'add','--',@pending) == 0
            or fail('cannot snapshot untracked worktree files in temporary Git index');
    }
    my $tree=capture('git','-C',$git_top,'write-tree');
    fail('temporary index did not produce a supported tree id') if $tree !~ $oid_re;
    return $tree;
}

sub validate_commit_ancestry {
    my ($base, $head, $label) = @_;
    fail("$label base/head must be supported Git object ids") if $base !~ $oid_re || $head !~ $oid_re;
    quiet_system('git', 'cat-file', '-e', "$base\^{commit}") == 0
        or fail("$label base_sha is not a local commit: $base");
    quiet_system('git', 'cat-file', '-e', "$head\^{commit}") == 0
        or fail("$label head_sha is not a local commit: $head");
    quiet_system('git', 'merge-base', '--is-ancestor', $base, $head) == 0
        or fail("$label base_sha is not an ancestor of head_sha");
}

sub git_diff_digest {
    my ($base, $head) = @_;
    open my $pipe, '-|', 'git', 'diff', '--binary', $base, $head
        or fail("cannot inspect fix diff $base..$head: $!");
    binmode $pipe;
    my $sha = Digest::SHA->new(256);
    $sha->addfile($pipe);
    close $pipe or fail("git diff failed for $base..$head");
    return $sha->hexdigest;
}

sub yaml_scalar {
    my ($raw, $label) = @_;
    $raw =~ s/^\s+|\s+$//g;
    fail("$label is empty") if $raw eq '';
    if ($raw =~ /\A"/) {
        my $decoded = eval { JSON::PP->new->allow_nonref(1)->decode($raw) };
        fail("$label has invalid double-quoted YAML scalar") if $@ || ref($decoded);
        return $decoded;
    }
    if ($raw =~ /\A'(.*)'\z/s) {
        my $value = $1;
        $value =~ s/''/'/g;
        return $value;
    }
    return $raw;
}

sub verification_config_path {
    return $config_file if defined($config_file) && $config_file ne '';
    if (-f '.p2t2c/project_config.yaml') {
        my $raw=read_raw('.p2t2c/project_config.yaml');
        return '.p2t2c/project_config.yaml' if $raw=~/^verification:\s*(?:#.*)?$/m;
    }
    return '.p2t2c/defaults.yaml' if -f '.p2t2c/defaults.yaml';
    return '.p2t2c/templates/project_config.example.yaml';
}

sub parse_verification_profiles_file {
    my ($path,$require_all) = @_;
    fail("missing verification configuration: $path") if !-f $path;
    my @lines = split /\n/, read_raw($path);
    my (%commands,%declared_profile,$in_verification,$profile,$in_commands,$in_covers,$current);
    for my $line (@lines) {
        $line =~ s/\r\z//;
        if ($line =~ /^verification:\s*(?:#.*)?$/) {
            $in_verification = 1; $profile = undef; $in_commands = 0; $in_covers = 0; $current = undef; next;
        }
        next if !$in_verification;
        last if $line =~ /^\S/;
        if ($line =~ /^  (fast|impacted|full|governance):\s*(?:#.*)?$/) {
            $profile = $1; $declared_profile{$profile}=1; $in_commands = 0; $in_covers = 0; $current = undef; next;
        }
        if (defined($profile) && $line =~ /^    commands:\s*(?:#.*)?$/) {
            $in_commands = 1; $in_covers = 0; $current = undef; next;
        }
        next if !$in_commands || !defined($profile) || $line =~ /^\s*(?:#.*)?$/;
        if ($line =~ /^      -\s+id:\s*(.+?)\s*$/) {
            my $id = yaml_scalar($1, "$path verification.$profile command id");
            fail("invalid verification command id: $id") if $id !~ /\A[A-Za-z0-9][A-Za-z0-9._-]{0,127}\z/;
            fail("duplicate verification command id in $profile: $id") if grep { $_->{id} eq $id } @{$commands{$profile} || []};
            $current = { id => $id, read_only => $json->false, parallel_group => 'none', covers => [], _metadata_declared=>0 };
            push @{$commands{$profile}}, $current;
            $in_covers = 0;
            next;
        }
        if ($line =~ /^        run:\s*(.+?)\s*$/) {
            fail("verification.$profile run appears before an id") if !$current;
            fail("verification.$profile command $current->{id} repeats run") if exists $current->{run};
            $current->{run} = yaml_scalar($1, "$path verification.$profile command run");
            $in_covers = 0;
            next;
        }
        if ($line =~ /^        read_only:\s*(true|false)\s*(?:#.*)?$/) {
            fail("verification.$profile read_only appears before an id") if !$current;
            $current->{read_only} = $1 eq 'true' ? $json->true : $json->false;
            $current->{_metadata_declared}=1;
            $in_covers = 0;
            next;
        }
        if ($line =~ /^        parallel_group:\s*(.+?)\s*$/) {
            fail("verification.$profile parallel_group appears before an id") if !$current;
            my $group = yaml_scalar($1, "$path verification.$profile command parallel_group");
            fail("invalid verification parallel_group: $group")
                if $group ne 'none' && $group !~ /\A[A-Za-z0-9][A-Za-z0-9._-]{0,63}\z/;
            $current->{parallel_group} = $group;
            $current->{_metadata_declared}=1;
            $in_covers = 0;
            next;
        }
        if ($line =~ /^        covers:\s*\[(.*?)\]\s*(?:#.*)?$/) {
            fail("verification.$profile covers appears before an id") if !$current;
            my $inside=$1;
            $current->{_metadata_declared}=1;
            if ($inside!~/^\s*$/) {
                for my $item (split /\s*,\s*/,$inside) {
                    my $ref=yaml_scalar($item,"$path verification.$profile command coverage");
                    fail("invalid verification coverage ref: $ref") if $ref!~/\A(?:fast|impacted|full|governance):[A-Za-z0-9][A-Za-z0-9._-]{0,127}\z/;
                    fail("duplicate verification coverage ref: $ref") if grep {$_ eq $ref} @{$current->{covers}};
                    push @{$current->{covers}},$ref;
                }
            }
            $in_covers=0; next;
        }
        if ($line =~ /^        covers:\s*(?:#.*)?$/) {
            fail("verification.$profile covers appears before an id") if !$current;
            $in_covers = 1;
            $current->{_metadata_declared}=1;
            next;
        }
        if ($in_covers && $line =~ /^          -\s*(.+?)\s*$/) {
            my $ref = yaml_scalar($1, "$path verification.$profile command coverage");
            fail("invalid verification coverage ref: $ref")
                if $ref !~ /\A(?:fast|impacted|full|governance):[A-Za-z0-9][A-Za-z0-9._-]{0,127}\z/;
            fail("duplicate verification coverage ref: $ref") if grep { $_ eq $ref } @{$current->{covers}};
            push @{$current->{covers}}, $ref;
            next;
        }
        if ($line =~ /^      -\s+/) {
            fail("verification.$profile commands must use {id, run} objects, not scalar commands");
        }
        last if $line =~ /^  [A-Za-z0-9_-]+:/;
    }
    for my $name (@profiles) {
        fail("verification.$name.commands must contain at least one {id, run} command")
            if ($require_all||$declared_profile{$name})&&!@{$commands{$name}||[]};
        for my $entry (@{$commands{$name}}) {
            fail("verification.$name command $entry->{id} is missing run") if !defined($entry->{run}) || $entry->{run} eq '';
            fail("verification.$name command $entry->{id} parallel_group requires read_only: true")
                if $entry->{parallel_group} ne 'none' && !$entry->{read_only};
        }
    }
    for my $source_profile (@profiles) {
        for my $entry (@{$commands{$source_profile}}) {
            for my $ref (@{$entry->{covers}}) {
                my ($target_profile,$target_id)=split /:/,$ref,2;
                fail("verification coverage cannot cover itself: $ref")
                    if $source_profile eq $target_profile && $entry->{id} eq $target_id;
                my ($target_entry)=grep { $_->{id} eq $target_id } @{$commands{$target_profile}||[]};
                next if !$target_entry && !$require_all;
                fail("verification coverage target does not exist: $ref") if !$target_entry;
                my ($source_run,$target_run)=($entry->{run},$target_entry->{run});
                $source_run =~ s/\{work_id\}/CPK-COVERAGE-PROBE/g;
                $target_run =~ s/\{work_id\}/CPK-COVERAGE-PROBE/g;
                fail("verification coverage requires identical expanded argv: $source_profile:$entry->{id} -> $ref")
                    if $source_run ne $target_run;
            }
        }
    }
    return \%commands;
}

sub parse_verification_profiles {
    return $verification_profiles_cache if $verification_profiles_cache;
    my $base_path=-f '.p2t2c/defaults.yaml'?'.p2t2c/defaults.yaml':'.p2t2c/templates/project_config.example.yaml';
    my $base=parse_verification_profiles_file($base_path,1);
    my $overlay_path=defined($config_file)&&$config_file ne ''?$config_file:(-f '.p2t2c/project_config.yaml'?'.p2t2c/project_config.yaml':undef);
    my $overlay={};
    if (defined($overlay_path)&&$overlay_path ne $base_path&&read_raw($overlay_path)=~/^verification:\s*(?:#.*)?$/m) {
        # Arrays are whole-section overrides.  Once a project declares
        # verification, all four profiles and path_mapping must be explicit;
        # silently inheriting the omitted remainder would downgrade policy.
        $overlay=parse_verification_profiles_file($overlay_path,1);
        fail("explicit verification override must declare path_mapping: $overlay_path")
            if read_raw($overlay_path)!~/^  path_mapping:\s*(?:#.*)?$/m;
    }
    my %effective;
    for my $profile (@profiles) {$effective{$profile}=exists($overlay->{$profile})?$overlay->{$profile}:$base->{$profile}}
    for my $source_profile (@profiles) {
        for my $entry (@{$effective{$source_profile}}) {
            for my $ref (@{$entry->{covers}}) {
                my ($target_profile,$target_id)=split /:/,$ref,2;
                my ($target_entry)=grep {$_->{id} eq $target_id} @{$effective{$target_profile}};
                fail("verification coverage target does not exist: $ref") if !$target_entry;
                my ($source_run,$target_run)=($entry->{run},$target_entry->{run});
                $source_run=~s/\{work_id\}/CPK-COVERAGE-PROBE/g; $target_run=~s/\{work_id\}/CPK-COVERAGE-PROBE/g;
                fail("verification coverage requires identical expanded argv: $source_profile:$entry->{id} -> $ref") if $source_run ne $target_run;
            }
        }
    }
    $verification_profiles_cache=\%effective;
    return $verification_profiles_cache;
}

sub parse_project_policy {
    return $project_policy_cache if $project_policy_cache;
    my ($enforcement, $audit_mode, $closure_on_risk);
    my @mapping;
    my @paths=grep {defined($_)&&-f$_} ('.p2t2c/defaults.yaml',defined($config_file)&&$config_file ne ''?$config_file:'.p2t2c/project_config.yaml');
    @paths=('.p2t2c/templates/project_config.example.yaml') if !@paths;
    for my $path (@paths) {
      my @lines=split /\n/,read_raw($path);
      my ($section,$in_r0,$in_mapping,$current,$declared_mapping); my @file_mapping;
      for my $line (@lines) {
        $line =~ s/\r\z//;
        if ($line =~ /^(p2t2c|methodology|verification):\s*(?:#.*)?$/) {
            $section=$1; $in_r0=0; $in_mapping=0; $current=undef; next;
        }
        if (defined($section) && $line =~ /^\S/) {
            $section=undef; $in_r0=0; $in_mapping=0; $current=undef;
        }
        next if !defined($section);
        if ($section eq 'methodology' && $line =~ /^  enforcement:\s*(.+?)\s*$/) {
            $enforcement=yaml_scalar($1,"$path methodology.enforcement"); next;
        }
        if ($section eq 'p2t2c' && $line =~ /^  r0:\s*(?:#.*)?$/) { $in_r0=1; next; }
        if ($section eq 'p2t2c' && $in_r0 && $line =~ /^    audit_mode:\s*(true|false)\s*$/) { $audit_mode=$1; next; }
        if ($section eq 'p2t2c' && $in_r0 && $line =~ /^    closure_on_residual_risk:\s*(true|false)\s*$/) { $closure_on_risk=$1; next; }
        if ($section eq 'verification' && $line =~ /^  path_mapping:\s*(?:#.*)?$/) { $in_mapping=1; $declared_mapping=1; $current=undef; next; }
        if ($section eq 'verification' && $in_mapping && $line =~ /^    -\s+pattern:\s*(.+?)\s*$/) {
            my $pattern=yaml_scalar($1,"$path path_mapping pattern");
            fail("unsafe empty path_mapping pattern") if $pattern eq '' || $pattern =~ /[\x00-\x1f\x7f]/;
            $current={pattern=>$pattern}; push @file_mapping,$current; next;
        }
        if ($section eq 'verification' && $in_mapping && $line =~ /^      profile:\s*(.+?)\s*$/) {
            fail("path_mapping profile appears before pattern") if !$current;
            my $profile=yaml_scalar($1,"$path path_mapping profile");
            fail("invalid path_mapping profile: $profile") if $profile !~ /\A(?:fast|impacted|full|governance)\z/;
            $current->{profile}=$profile; next;
        }
      }
      if ($declared_mapping) {
        fail("verification.path_mapping must not be empty in explicit override: $path") if !@file_mapping;
        fail("path_mapping entry missing profile") for grep {!exists($_->{profile})} @file_mapping;
        @mapping=@file_mapping;
      }
    }
    $enforcement //= 'advisory';
    fail("methodology.enforcement must be advisory or required") if $enforcement !~ /\A(?:advisory|required)\z/;
    $audit_mode //= 'false'; $closure_on_risk //= 'true';
    fail("verification.path_mapping must not be empty") if !@mapping;
    fail("path_mapping entry missing profile") for grep { !exists($_->{profile}) } @mapping;
    $project_policy_cache={
        methodology_enforcement=>$enforcement,
        r0_audit_mode=>$audit_mode eq 'true' ? $json->true : $json->false,
        r0_closure_on_residual_risk=>$closure_on_risk eq 'true' ? $json->true : $json->false,
        path_mapping=>\@mapping,
        path_mapping_digest=>sha256_hex($json->encode(\@mapping)),
    };
    return $project_policy_cache;
}

sub profile_requirement {
    my ($profile) = @_;
    fail("unsupported verification profile: $profile") if !defined($profile) || $profile !~ /\A(?:fast|impacted|full|governance)\z/;
    my $profiles = parse_verification_profiles();
    my $entries = $profiles->{$profile};
    my $modern=grep {$_->{_metadata_declared}} @$entries;
    my @contract = $modern
        ? map {+{id=>$_->{id},run=>$_->{run},read_only=>$_->{read_only},parallel_group=>$_->{parallel_group},covers=>$_->{covers}}} @$entries
        : map {+{id=>$_->{id},run=>$_->{run}}} @$entries;
    my $digest = sha256_hex($json->encode({ profile => $profile, commands => \@contract }));
    return {
        profile => $profile,
        profile_config_digest => $digest,
        command_ids => [map { $_->{id} } @$entries],
        commands => $entries,
    };
}

sub verification_command {
    my ($profile, $id, $id_work) = @_;
    need('command-id', $id);
    need('work-id', $id_work);
    fail('invalid --work-id') if $id_work !~ /\A[A-Za-z0-9][A-Za-z0-9._-]*\z/;
    my $requirement = profile_requirement($profile);
    my ($entry) = grep { $_->{id} eq $id } @{$requirement->{commands}};
    fail("verification.$profile has no command id: $id") if !$entry;
    my $run = $entry->{run};
    $run =~ s/\{work_id\}/$id_work/g;
    my $argv_digest = sha256_hex(join("\0", 'bash', '-c', $run) . "\0");
    my $profiles = parse_verification_profiles();
    my @covered_commands;
    for my $ref (@{$entry->{covers}}) {
        my ($covered_profile,$covered_id)=split /:/,$ref,2;
        my $covered_modern=grep {$_->{_metadata_declared}} @{$profiles->{$covered_profile}};
        my @covered_contract = $covered_modern
            ? map {+{id=>$_->{id},run=>$_->{run},read_only=>$_->{read_only},parallel_group=>$_->{parallel_group},covers=>$_->{covers}}} @{$profiles->{$covered_profile}}
            : map {+{id=>$_->{id},run=>$_->{run}}} @{$profiles->{$covered_profile}};
        push @covered_commands, {
            profile=>$covered_profile,
            command_id=>$covered_id,
            profile_config_digest=>sha256_hex($json->encode({profile=>$covered_profile,commands=>\@covered_contract})),
        };
    }
    return {
        run => $run,
        command_id => $id,
        command_label => "verification:$profile:$id",
        argv_digest => $argv_digest,
        profile_config_digest => $requirement->{profile_config_digest},
        read_only => $entry->{read_only},
        parallel_group => $entry->{parallel_group},
        covered_commands => \@covered_commands,
    };
}

sub unquote_frontmatter {
    my ($raw, $label) = @_;
    $raw =~ s/^\s+|\s+$//g;
    return yaml_scalar($raw, $label) if $raw =~ /\A["']/;
    return $raw;
}

sub frontmatter_index {
    my($path)=@_;my$text=read_raw($path);my$key="$path:".sha256_hex($text);return$FRONTMATTER_CACHE->{$key}if$FRONTMATTER_CACHE->{$key};
    my$normalized=$text;$normalized=~s/\r\n/\n/g;my($frontmatter,$body)=$normalized=~/\A---\n(.*?)\n---\n?(.*)\z/s;
    return$FRONTMATTER_CACHE->{$key}={present=>0,text=>$normalized}if!defined$frontmatter;
    my(%value,%raw,%seen,@duplicates,@non_scalar);my@lines=split/\n/,$frontmatter,-1;
    for my$line(@lines){next if$line=~/^\s*(?:#.*)?$/;my($name,$scalar)=$line=~/^([A-Za-z0-9_]+):[ \t]*(.*?)\s*$/;if(!defined$name){push@non_scalar,$line;next}push@duplicates,$name if$seen{$name}++;next if exists$value{$name};$raw{$name}=$scalar;$value{$name}=unquote_frontmatter($scalar,"$path $name")}
    return$FRONTMATTER_CACHE->{$key}={present=>1,text=>$normalized,frontmatter=>$frontmatter,body=>$body,lines=>\@lines,values=>\%value,raw_values=>\%raw,duplicates=>\@duplicates,non_scalar=>\@non_scalar};
}

sub parse_cpk {
    my ($path, $expected_id, $options) = @_;
    $options ||= {};
    fail("missing CPK: $path") if !-f $path;
    my$index=frontmatter_index($path);fail("$path has malformed or missing frontmatter")if!$index->{present};
    fail("$path frontmatter must use scalar key/value fields")if@{$index->{non_scalar}};
    fail("$path frontmatter repeats key: $index->{duplicates}[0]")if@{$index->{duplicates}};
    my$text=$index->{text};my$body=$index->{body};my@lines=@{$index->{lines}};my%value=%{$index->{values}};my%raw=%{$index->{raw_values}};
    my @required = qw(
        artifact schema_version id risk source truth_change gate_a status methodology_profile
        execution_shape production_code_change multi_agent work_pack implementer tdd_policy
        governance_change specialist_review_required truth_patch_ref truth_patch_digest
        gate_b_status gate_b_decision gate_b_ref ownership_batches legacy_startup_evidence
    );
    fail("$path missing frontmatter field: $_") for grep { !exists $value{$_} } @required;
    for my $key (qw(truth_change production_code_change multi_agent governance_change specialist_review_required legacy_startup_evidence)) {
        fail("$path $key must be an unquoted true or false") if $raw{$key} !~ /\A(?:true|false)\z/;
    }
    fail("$path artifact must be change_pack") if $value{artifact} ne 'change_pack';
    fail("$path schema_version must be the unquoted integer 3") if $raw{schema_version} ne '3';
    fail("$path id mismatch") if defined($expected_id) && $expected_id ne '' && $value{id} ne $expected_id;
    fail("$path id has invalid format") if $value{id} !~ /\ACPK-[A-Za-z0-9._-]+\z/;
    fail("$path risk must be R1 or R2") if $value{risk} !~ /\AR[12]\z/;
    fail("$path execution_shape is invalid") if $value{execution_shape} !~ /\A(?:spike|bounded|architectural)\z/;
    fail("$path spike work cannot be applied") if $value{execution_shape} eq 'spike' && $value{status} eq 'applied';
    fail("$path status is invalid") if $value{status} !~ /\A(?:ready|blocked|applied)\z/;
    fail("$path implementer has invalid format") if $value{implementer} !~ /\A[A-Za-z0-9][A-Za-z0-9._:\@\/-]{0,127}\z/;
    fail("$path tdd_policy is invalid") if $value{tdd_policy} !~ /\A(?:required|exempt|not_applicable)\z/;
    fail("$path gate_b_status is invalid") if $value{gate_b_status} !~ /\A(?:not_triggered|resolved)\z/;
    if ($value{execution_shape} eq 'architectural') {
        fail("$path architectural work_pack is invalid") if $value{work_pack} !~ m{\Aspecs/[A-Za-z0-9._-]+/work\.md\z};
        my @batches = split /,/, $value{ownership_batches}, -1;
        my %batch;
        fail("$path architectural ownership_batches must list safe comma-separated ids")
            if !@batches || grep { $_ !~ /\A[A-Za-z0-9][A-Za-z0-9._-]{0,127}\z/ || $batch{$_}++ } @batches;
    } else {
        fail("$path non-architectural work_pack must be none") if $value{work_pack} ne 'none';
        fail("$path non-architectural ownership_batches must be none") if $value{ownership_batches} ne 'none';
        fail("$path legacy_startup_evidence may be true only for architectural work") if $value{legacy_startup_evidence} ne 'false';
    }
    if ($value{risk} eq 'R1') {
        fail("$path R1 truth/gate fields are invalid")
            if $value{truth_change} ne 'false' || $value{gate_a} ne 'not_required'
            || $value{truth_patch_ref} ne 'none' || $value{truth_patch_digest} ne 'none'
            || $value{gate_b_status} ne 'not_triggered'
            || $value{gate_b_decision} ne 'none' || $value{gate_b_ref} ne 'none';
    } else {
        fail("$path R2 truth_change must be true") if $value{truth_change} ne 'true';
        fail("$path R2 gate_a is invalid") if $value{gate_a} !~ /\A(?:satisfied|pending)\z/;
        fail("$path R2 truth_patch_ref must be a safe docs/sot file")
            if $value{truth_patch_ref} !~ m{\Adocs/sot/} || $value{truth_patch_ref} =~ m{(?:\A|/)\.\.(?:/|\z)};
        validate_safe_path($value{truth_patch_ref}, 0, "$path truth_patch_ref");
        fail("$path R2 truth_patch_digest must be SHA-256") if $value{truth_patch_digest} !~ $digest_re;
        fail("$path R2 truth_patch_digest does not match current Truth file")
            if !$options->{historical_applied}
            && sha256_hex(read_raw($value{truth_patch_ref})) ne $value{truth_patch_digest};
        fail("$path applied R2 gate_a must be satisfied") if $value{status} eq 'applied' && $value{gate_a} ne 'satisfied';
    }
    if ($value{gate_b_status} eq 'not_triggered') {
        fail("$path non-triggered Gate B requires none decision/ref")
            if $value{gate_b_decision} ne 'none' || $value{gate_b_ref} ne 'none';
    } else {
        fail("$path resolved Gate B requires decision/ref")
            if $value{gate_b_decision} eq 'none' || $value{gate_b_ref} eq 'none';
        safe_reference($value{gate_b_ref}, "$path gate_b_ref");
    }

    my $start = '<!-- p2t2c:evidence:start -->';
    my $end = '<!-- p2t2c:evidence:end -->';
    my $starts = () = $body =~ /\Q$start\E/g;
    my $ends = () = $body =~ /\Q$end\E/g;
    fail("$path must contain exactly one evidence marker block") if $starts != 1 || $ends != 1;
    $body =~ s/\Q$start\E.*?\Q$end\E//s;
    my @normalized_fm = grep { $_ !~ /^status:[ \t]*/ } @lines;
    my $normalized = "---\n" . join("\n", @normalized_fm) . "\n---\n" . $body;
    my $contract_digest = sha256_hex($normalized);
    my $evidence_target = $value{risk} eq 'R1'
        ? $path
        : 'docs/closure/CR-' . ($value{id} =~ s/^CPK-//r) . '.md';
    return {
        schema_version => 1,
        work_id => $value{id},
        risk => $value{risk},
        execution_shape => $value{execution_shape},
        production_code_change => $value{production_code_change} eq 'true' ? $json->true : $json->false,
        multi_agent => $value{multi_agent} eq 'true' ? $json->true : $json->false,
        work_pack => $value{work_pack},
        implementer => $value{implementer},
        tdd_policy => $value{tdd_policy},
        governance_change => $value{governance_change} eq 'true' ? $json->true : $json->false,
        specialist_review_required => $value{specialist_review_required} eq 'true' ? $json->true : $json->false,
        gate_a => $value{gate_a},
        truth_patch_ref => $value{truth_patch_ref},
        truth_patch_digest => $value{truth_patch_digest},
        gate_b_status => $value{gate_b_status},
        gate_b_decision => $value{gate_b_decision},
        gate_b_ref => $value{gate_b_ref},
        ownership_batches => $value{ownership_batches},
        legacy_startup_evidence => $value{legacy_startup_evidence} eq 'true' ? $json->true : $json->false,
        status => $value{status},
        cpk_path => $path,
        evidence_target => $evidence_target,
        contract_digest => $contract_digest,
    };
}

sub load_context {
    my ($path) = @_;
    need('contract-file', $path);
    my $context = decode_object(read_raw($path), $path);
    my @required = qw(
        schema_version work_id risk execution_shape production_code_change multi_agent work_pack
        implementer tdd_policy governance_change specialist_review_required gate_a truth_patch_ref
        truth_patch_digest gate_b_status gate_b_decision gate_b_ref ownership_batches
        legacy_startup_evidence baseline_sha status cpk_path evidence_target contract_digest
    );
    fail("$path missing context field: $_") for grep { !exists $context->{$_} } @required;
    fail("$path schema_version must be integer 1") if require_integer($context, 'schema_version', $path) != 1;
    for my $key (qw(work_id risk execution_shape work_pack implementer tdd_policy gate_a truth_patch_ref truth_patch_digest gate_b_status gate_b_decision gate_b_ref ownership_batches baseline_sha status cpk_path evidence_target contract_digest)) {
        require_string($context, $key, $path, 0);
    }
    require_boolean($context, $_, $path) for qw(production_code_change multi_agent governance_change specialist_review_required legacy_startup_evidence);
    fail("$path contract_digest is invalid") if $context->{contract_digest} !~ $digest_re;
    fail("$path baseline_sha is invalid") if $context->{baseline_sha} !~ $oid_re;
    safe_target($context->{evidence_target});
    if ($context->{risk} eq 'R0') {
        my %core = map { $_ => $context->{$_} } qw(
            work_id risk execution_shape production_code_change multi_agent work_pack implementer
            tdd_policy governance_change specialist_review_required gate_a truth_patch_ref truth_patch_digest
            gate_b_status gate_b_decision gate_b_ref ownership_batches legacy_startup_evidence
        );
        fail("$path R0 contract digest mismatch") if sha256_hex($json->encode(\%core)) ne $context->{contract_digest};
    } else {
        my $fresh = parse_cpk($context->{cpk_path}, $context->{work_id});
        fail("$path CPK contract digest is stale") if $fresh->{contract_digest} ne $context->{contract_digest};
        for my $key (qw(risk execution_shape production_code_change multi_agent work_pack implementer tdd_policy governance_change specialist_review_required gate_a truth_patch_ref truth_patch_digest gate_b_status gate_b_decision gate_b_ref ownership_batches legacy_startup_evidence evidence_target)) {
            my $left = $json->encode([$fresh->{$key}]);
            my $right = $json->encode([$context->{$key}]);
            fail("$path context field $key is stale") if $left ne $right;
        }
    }
    return $context;
}

sub stat_mode {
    my ($path, $kind, $mode) = @_;
    my @stat = lstat($path);
    fail("missing safe run path: $path") if !@stat;
    fail("run path must not be a symlink: $path") if S_ISLNK($stat[2]);
    fail("$path must be a $kind") if $kind eq 'directory' ? !S_ISDIR($stat[2]) : !S_ISREG($stat[2]);
    fail("$path regular evidence file must have exactly one hard link") if $kind eq 'file' && $stat[3] != 1;
    my $actual = $stat[2] & 0777;
    fail(sprintf('%s mode must be %04o, got %04o', $path, $mode, $actual)) if $actual != $mode;
}

sub validate_run_state {
    my ($id_work, $cpk_path) = @_;
    need('work-id', $id_work);
    fail('invalid work id') if $id_work !~ /\A[A-Za-z0-9][A-Za-z0-9._-]*\z/;
    stat_mode('.p2t2c/runs', 'directory', 0700);
    stat_mode('.p2t2c/runs/.gitignore', 'file', 0600);
    my $run_dir = ".p2t2c/runs/$id_work";
    stat_mode($run_dir, 'directory', 0700);
    stat_mode("$run_dir/contract.json", 'file', 0600);
    stat_mode("$run_dir/events.jsonl", 'file', 0600);
    my $has_active=0;
    opendir my $dir, $run_dir or fail("cannot inspect $run_dir: $!");
    while (defined(my $entry = readdir $dir)) {
        next if $entry eq '.' || $entry eq '..';
        my $path = "$run_dir/$entry";
        my @stat = lstat($path);
        fail("unsafe symlink in run directory: $path") if @stat && S_ISLNK($stat[2]);
        if ($entry =~ /^\.(?:active-|closing|lifecycle-lock)/) {
            $has_active=1 if $entry=~/^\.active-/;
            fail("unsafe lifecycle entry in run directory: $path")
                if !@stat || (!S_ISREG($stat[2]) && !S_ISDIR($stat[2]));
        } elsif ($entry eq 'outputs') {
            stat_mode($path,'directory',0700);
        } elsif ($entry ne 'contract.json' && $entry ne 'events.jsonl') {
            fail("unexpected run entry: $path");
        }
    }
    closedir $dir;
    my $context = load_context("$run_dir/contract.json");
    fail('run contract work id mismatch') if $context->{work_id} ne $id_work;
    if (defined($cpk_path) && $cpk_path ne '') {
        fail('run contract CPK mismatch') if $context->{cpk_path} ne $cpk_path;
    }
    if (-d "$run_dir/outputs") {
        my ($events)=parse_jsonl(read_raw("$run_dir/events.jsonl"),"$run_dir/events.jsonl");
        my %event=map {($_->{event_id}//'')=>$_} @$events;
        my$output_dir="$run_dir/outputs";my$names=held_list_directory($output_dir,'failure outputs',0700);
        for my $name (@$names) {
            fail("unsafe failure log name: $name") if $name!~/\A(evt-[A-Za-z0-9._-]+)\.log\z/;
            my $id=$1;
            if (!$event{$id}) {fail("failure log has no matching event: $name") if !$has_active;next}
            my $e=$event{$id};
            fail("failure log must map to a failed command event: $name")
                if ($e->{event_type}//'')!~/\A(?:verification|exploration|tdd_red|tdd_green|mutation)\z/ || ($e->{exit_code}//0)==0;
            my $raw=held_read_file($output_dir,$name,'failure output',0600);
            fail("failure log digest mismatch: $name") if sha256_hex($raw) ne ($e->{output_digest}//'');
            fail("failure log byte count mismatch: $name") if length($raw) != ($e->{output_bytes}//-1);
        }
    }
    return $context;
}

sub parse_jsonl {
    my ($raw, $label) = @_;
    fail("$label must end with newline") if $raw ne '' && $raw !~ /\n\z/;
    my @lines = split /\n/, $raw, -1;
    pop @lines if @lines && $lines[-1] eq '';
    my @objects;
    for my $index (0 .. $#lines) {
        fail("$label line " . ($index + 1) . ' is blank') if $lines[$index] eq '';
        push @objects, decode_object($lines[$index], "$label line " . ($index + 1));
    }
    return (\@objects, \@lines);
}

sub validate_excludes {
    my ($object, $label, $expected_target) = @_;
    fail("$label.tree_excludes must be a two-item array")
        if ref($object->{tree_excludes}) ne 'ARRAY' || @{$object->{tree_excludes}} != 2;
    fail("$label.tree_excludes mismatch")
        if !is_string($object->{tree_excludes}[0]) || !is_string($object->{tree_excludes}[1])
        || $object->{tree_excludes}[0] ne '.p2t2c/runs/**'
        || $object->{tree_excludes}[1] ne $expected_target;
}

sub validate_event {
    my ($event, $index, $context, $expected_target) = @_;
    my $label = 'event[' . ($index + 1) . ']';
    my @common = qw(schema_version event_id work_id event_type contract_digest tree_sha head_sha recorded_at evidence_target tree_excludes);
    my $type = require_string($event, 'event_type', $label, 0);
    my @allowed = @common;
    if ($type =~ /\A(?:verification|exploration|tdd_red|tdd_green|mutation)\z/) {
        push @allowed, qw(started_tree_sha started_head_sha command_label argv_digest exit_code started_at finished_at duration_ms output_digest output_bytes output_lines output_summary);
        push @allowed, qw(verification_profile profile_config_digest command_id covered_commands) if $type eq 'verification';
    } elsif ($type eq 'tdd_exemption') {
        push @allowed, 'reason_digest';
    } elsif ($type eq 'route') {
        push @allowed, qw(from_risk to_risk from_shape to_shape);
    } elsif ($type eq 'isolation') {
        push @allowed, qw(workspace_kind branch baseline_sha clean);
    } elsif ($type eq 'repair') {
        push @allowed, qw(repair_round hypothesis_digest implementer failure_digest fix_base_sha fix_head_sha fix_diff_digest);
    } elsif ($type eq 'gate_b') {
        push @allowed, qw(gate_b_decision gate_b_ref);
    } elsif ($type eq 'review') {
        push @allowed, qw(implementer reviewer reviewer_session review_role scope_digest base_sha verdict critical important minor batch_id);
    } else {
        fail("$label.event_type is unsupported: $type");
    }
    if ($context->{risk} eq 'R2' && $context->{gate_a} eq 'pending'
        && $type !~ /\A(?:exploration|route|isolation)\z/) {
        fail("$label event type $type is forbidden while Gate A is pending");
    }
    exact_keys($event, \@allowed, $label);
    fail("$label.schema_version must be integer 1") if require_integer($event, 'schema_version', $label) != 1;
    fail("$label.event_id invalid") if require_string($event, 'event_id', $label, 0) !~ /\Aevt-[A-Za-z0-9._-]+\z/;
    fail("$label.work_id mismatch") if require_string($event, 'work_id', $label, 0) ne $context->{work_id};
    fail("$label.contract_digest mismatch") if require_string($event, 'contract_digest', $label, 0) ne $context->{contract_digest};
    for my $key (qw(tree_sha head_sha)) {
        fail("$label.$key must be a supported Git object id") if require_string($event, $key, $label, 0) !~ $oid_re;
    }
    fail("$label.recorded_at invalid") if require_string($event, 'recorded_at', $label, 0) !~ $time_re;
    fail("$label.evidence_target mismatch") if require_string($event, 'evidence_target', $label, 0) ne $expected_target;
    validate_excludes($event, $label, $expected_target);

    if ($type =~ /\A(?:verification|exploration|tdd_red|tdd_green|mutation)\z/) {
        for my $key (qw(started_tree_sha started_head_sha)) {
            fail("$label.$key invalid") if require_string($event, $key, $label, 0) !~ $oid_re;
        }
        fail("$label.command_label invalid") if require_string($event, 'command_label', $label, 0) !~ /\A[A-Za-z0-9][A-Za-z0-9._:\@\/-]{0,191}\z/;
        fail("$label.argv_digest invalid") if require_string($event, 'argv_digest', $label, 0) !~ $digest_re;
        my $exit = require_integer($event, 'exit_code', $label);
        fail("$label.exit_code out of range") if $exit > 255;
        fail("$label.duration_ms invalid") if require_integer($event, 'duration_ms', $label) < 0;
        require_integer($event, $_, $label) for qw(output_bytes output_lines);
        fail("$label.output_digest invalid") if require_string($event, 'output_digest', $label, 0) !~ $digest_re;
        fail("$label.output_summary is not a safe bounded summary")
            if require_string($event, 'output_summary', $label, 0) !~ /\Aexit=\d+; bytes=\d+; lines=\d+; sha256=[0-9a-f]{64}\z/
            || length($event->{output_summary}) > 256;
        fail("$label timestamp invalid") if require_string($event, 'started_at', $label, 0) !~ $time_re || require_string($event, 'finished_at', $label, 0) !~ $time_re;
        fail("$label tdd_red must fail") if $type eq 'tdd_red' && $exit == 0;
        fail("$label tdd_green must pass") if $type eq 'tdd_green' && $exit != 0;
        if ($type eq 'verification' || $type eq 'exploration') {
            fail("$label verification command changed the governed tree or HEAD")
                if $event->{started_tree_sha} ne $event->{tree_sha} || $event->{started_head_sha} ne $event->{head_sha};
        }
        if ($type eq 'verification') {
            fail("$label.verification_profile invalid") if require_string($event, 'verification_profile', $label, 0) !~ /\A(?:fast|impacted|full|governance)\z/;
            fail("$label.profile_config_digest invalid") if require_string($event, 'profile_config_digest', $label, 0) !~ $digest_re;
            fail("$label.command_id invalid") if require_string($event, 'command_id', $label, 0) !~ /\A[A-Za-z0-9][A-Za-z0-9._-]{0,127}\z/;
            if (exists $event->{covered_commands}) {
                fail("$label.covered_commands must be an array") if ref($event->{covered_commands}) ne 'ARRAY';
                my %seen_covered;
                for my $covered (@{$event->{covered_commands}}) {
                    fail("$label.covered_commands entry must be an object") if ref($covered) ne 'HASH';
                    exact_keys($covered,[qw(profile command_id profile_config_digest)],"$label.covered_commands");
                    my $p=require_string($covered,'profile',"$label.covered_commands",0);
                    my $id=require_string($covered,'command_id',"$label.covered_commands",0);
                    fail("$label covered profile invalid") if $p !~ /\A(?:fast|impacted|full|governance)\z/;
                    fail("$label covered command id invalid") if $id !~ /\A[A-Za-z0-9][A-Za-z0-9._-]{0,127}\z/;
                    fail("$label covered profile config digest invalid") if require_string($covered,'profile_config_digest',"$label.covered_commands",0) !~ $digest_re;
                    fail("$label duplicate covered command: $p:$id") if $seen_covered{"$p:$id"}++;
                    fail("$label verification cannot cover itself") if $p eq $event->{verification_profile} && $id eq $event->{command_id};
                }
            }
        }
    } elsif ($type eq 'tdd_exemption') {
        fail("$label.reason_digest invalid") if require_string($event, 'reason_digest', $label, 0) !~ $digest_re;
    } elsif ($type eq 'route') {
        fail("$label route risk invalid") if require_string($event, 'from_risk', $label, 0) !~ /\AR[012]\z/ || require_string($event, 'to_risk', $label, 0) !~ /\AR[012]\z/;
        fail("$label route shape invalid") if require_string($event, 'from_shape', $label, 0) !~ /\A(?:spike|bounded|architectural)\z/ || require_string($event, 'to_shape', $label, 0) !~ /\A(?:spike|bounded|architectural)\z/;
        my %risk_rank = (R0 => 0, R1 => 1, R2 => 2);
        my %shape_rank = (spike => 0, bounded => 1, architectural => 2);
        fail("$label route cannot downgrade risk or execution shape")
            if $risk_rank{$event->{to_risk}} < $risk_rank{$event->{from_risk}}
            || $shape_rank{$event->{to_shape}} < $shape_rank{$event->{from_shape}};
    } elsif ($type eq 'isolation') {
        fail("$label.workspace_kind invalid") if require_string($event, 'workspace_kind', $label, 0) !~ /\A(?:worktree|branch|shared_owned)\z/;
        require_string($event, 'branch', $label, 0);
        fail("$label.baseline_sha invalid") if require_string($event, 'baseline_sha', $label, 0) !~ $oid_re;
        fail("$label.baseline_sha must equal frozen run baseline") if $event->{baseline_sha} ne $context->{baseline_sha};
        require_boolean($event, 'clean', $label);
        validate_commit_ancestry($event->{baseline_sha}, $event->{head_sha}, "$label isolation");
    } elsif ($type eq 'repair') {
        my $round = require_integer($event, 'repair_round', $label);
        fail("$label.repair_round must be 1 or 2") if $round < 1 || $round > 2;
        fail("$label.hypothesis_digest invalid") if require_string($event, 'hypothesis_digest', $label, 0) !~ $digest_re;
        fail("$label.implementer mismatch") if require_string($event, 'implementer', $label, 0) ne $context->{implementer};
        fail("$label.failure_digest invalid") if require_string($event, 'failure_digest', $label, 0) !~ $digest_re;
        for my $key (qw(fix_base_sha fix_head_sha)) {
            fail("$label.$key invalid") if require_string($event, $key, $label, 0) !~ $oid_re;
        }
        fail("$label.fix_diff_digest invalid") if require_string($event, 'fix_diff_digest', $label, 0) !~ $digest_re;
        validate_commit_ancestry($event->{fix_base_sha}, $event->{fix_head_sha}, "$label fix");
        fail("$label fix_head_sha must equal event head_sha") if $event->{fix_head_sha} ne $event->{head_sha};
        fail("$label.fix_diff_digest does not match fix commits")
            if git_diff_digest($event->{fix_base_sha}, $event->{fix_head_sha}) ne $event->{fix_diff_digest};
    } elsif ($type eq 'gate_b') {
        require_string($event, 'gate_b_decision', $label, 0);
        require_string($event, 'gate_b_ref', $label, 0);
        safe_reference($event->{gate_b_ref}, "$label gate_b_ref");
    } elsif ($type eq 'review') {
        require_string($event, $_, $label, 0) for qw(implementer reviewer reviewer_session);
        fail("$label implementer mismatch") if $event->{implementer} ne $context->{implementer};
        fail("$label reviewer must differ from implementer") if $event->{reviewer} eq $event->{implementer};
        fail("$label.review_role invalid") if require_string($event, 'review_role', $label, 0) !~ /\A(?:batch|global|specialist|re_review)\z/;
        if ($event->{review_role} eq 'batch') {
            fail("$label.batch_id invalid") if require_string($event, 'batch_id', $label, 0) !~ /\A[A-Za-z0-9][A-Za-z0-9._-]{0,127}\z/;
        } elsif (exists $event->{batch_id}) {
            fail("$label.batch_id is only valid for batch review");
        }
        fail("$label.scope_digest invalid") if require_string($event, 'scope_digest', $label, 0) !~ $digest_re;
        fail("$label.base_sha invalid") if require_string($event, 'base_sha', $label, 0) !~ $oid_re;
        fail("$label.verdict invalid") if require_string($event, 'verdict', $label, 0) !~ /\A(?:pass|fail)\z/;
        require_integer($event, $_, $label) for qw(critical important minor);
        validate_commit_ancestry($event->{base_sha}, $event->{head_sha}, "$label review");
    }
    return $type;
}

sub glob_regex {
    my ($glob) = @_;
    my $regex='';
    my @chars=split //,$glob;
    for (my $i=0;$i<@chars;$i++) {
        if ($chars[$i] eq '*' && $i+1<@chars && $chars[$i+1] eq '*') { $regex.='.*'; $i++; next }
        if ($chars[$i] eq '*') { $regex.='[^/]*'; next }
        if ($chars[$i] eq '?') { $regex.='[^/]'; next }
        $regex.=quotemeta($chars[$i]);
    }
    return qr/\A$regex\z/;
}

sub derive_path_mapping {
    my ($events, $context, $final_tree, $final_head, $primary, $policy) = @_;
    my @warnings;
    my @isolation = grep { ($_->{event_type} || '') eq 'isolation' && ($_->{baseline_sha} || '') =~ $oid_re } @$events;
    my $baseline=$context->{baseline_sha};
    if (!@isolation && $policy->{methodology_enforcement} eq 'required') {
        fail('required v3 closure needs an isolation baseline for path mapping');
    } elsif (!@isolation) {
        push @warnings,'MISSING_ISOLATION_BASELINE';
    }
    validate_commit_ancestry($baseline,$final_head,'path mapping baseline');
    open my $pipe,'-|','git','diff','--name-only','--no-renames',$baseline,$final_tree
        or fail("cannot compute baseline-to-final path mapping diff: $!");
    my @paths;
    while (my $line=<$pipe>) { chomp $line; push @paths,$line if $line ne '' }
    close $pipe or fail('git diff failed while computing path mapping');
    @paths=sort @paths;
    fail('R1/R2 closure requires at least one baseline-to-final changed path')
        if $context->{risk} ne 'R0' && !@paths;
    my %matched;
    for my $path (@paths) {
        my $profile;
        for my $rule (@{$policy->{path_mapping}}) {
            if ($path =~ glob_regex($rule->{pattern})) { $profile=$rule->{profile}; last }
        }
        fail("changed path has no verification.path_mapping rule: $path") if !defined($profile);
        $matched{$profile}=1;
    }
    $matched{fast}=1 if !@paths;
    if (@warnings) { $matched{full}=1; $matched{governance}=1 }
    my %rank=(fast=>0,impacted=>1,full=>2);
    my $minimum='fast';
    for my $profile (keys %matched) {
        next if $profile eq 'governance';
        $minimum=$profile if $rank{$profile}>$rank{$minimum};
    }
    fail("verification profile $primary is below path-mapped minimum $minimum")
        if $primary eq 'governance' || $rank{$primary} < $rank{$minimum};
    return {
        baseline_sha=>$baseline,
        matched_profiles=>[grep {$matched{$_}} @profiles],
        matched_paths_digest=>sha256_hex($json->encode(\@paths)),
        path_mapping_digest=>$policy->{path_mapping_digest},
        warnings=>\@warnings,
    };
}

sub requirements_for_current_config {
    my ($context, $primary, $mapping) = @_;
    fail('spike work cannot close') if $context->{execution_shape} eq 'spike';
    fail('R2 or multi-agent closure requires verification profile full')
        if ($context->{risk} eq 'R2' || $context->{multi_agent}) && $primary ne 'full';
    my @needed = ($primary);
    my %mapped=map {$_=>1} @{$mapping->{matched_profiles}};
    push @needed, 'governance' if ($context->{governance_change} || $mapped{governance}) && $primary ne 'governance';
    return [map {
        my $r = profile_requirement($_);
        +{ profile => $r->{profile}, profile_config_digest => $r->{profile_config_digest}, command_ids => $r->{command_ids} }
    } @needed];
}

sub build_verification_plan {
    my ($ledger_file,$contract_path,$primary,$logical_target)=@_;
    safe_target($logical_target);
    my $context=load_context($contract_path);
    my $ledger_raw=read_raw($ledger_file);
    my ($events)=parse_jsonl($ledger_raw,$ledger_file);
    my $prospective_ref="docs/closure/evidence/EV-$context->{work_id}-" . sha256_hex($ledger_raw) . ".jsonl";
    my $final_tree=workspace_tree($logical_target,$prospective_ref);
    my $final_head=current_head();
    my $policy=parse_project_policy();
    my $mapping=derive_path_mapping($events,$context,$final_tree,$final_head,$primary,$policy);
    my $requirements=requirements_for_current_config($context,$primary,$mapping);
    my $profiles=parse_verification_profiles();
    my %required;
    for my $requirement (@$requirements) {
        $required{"$requirement->{profile}:$_"}=1 for @{$requirement->{command_ids}};
    }
    my (%satisfied,@executions);
    for my $requirement (@$requirements) {
        my $profile=$requirement->{profile};
        for my $id (@{$requirement->{command_ids}}) {
            my $ref="$profile:$id";
            next if $satisfied{$ref};
            my ($entry)=grep {$_->{id} eq $id} @{$profiles->{$profile}};
            fail("verification plan cannot resolve command: $ref") if !$entry;
            my $info=verification_command($profile,$id,$context->{work_id});
            push @executions, {
                profile=>$profile,command_id=>$id,read_only=>$info->{read_only},
                parallel_group=>$info->{parallel_group},covered_commands=>$info->{covered_commands},
            };
            $satisfied{$ref}=1;
            for my $covered (@{$info->{covered_commands}}) {
                my $covered_ref="$covered->{profile}:$covered->{command_id}";
                $satisfied{$covered_ref}=1 if $required{$covered_ref};
            }
        }
    }
    my $plan_core={requirements=>$requirements,executions=>\@executions,tree=>$final_tree,head=>$final_head};
    return {
        schema_version=>1,work_id=>$context->{work_id},verification_profile=>$primary,
        final_tree_sha=>$final_tree,head_sha=>$final_head,requirements=>$requirements,
        executions=>\@executions,plan_digest=>sha256_hex($json->encode($plan_core)),
    };
}

sub validate_requirements_shape {
    my ($requirements) = @_;
    fail('verification_requirements must be a non-empty array') if ref($requirements) ne 'ARRAY' || !@$requirements;
    my %profiles;
    for my $index (0 .. $#$requirements) {
        my $item = $requirements->[$index];
        my $label = "verification_requirements[$index]";
        fail("$label must be an object") if ref($item) ne 'HASH';
        exact_keys($item, [qw(profile profile_config_digest command_ids)], $label);
        my $profile = require_string($item, 'profile', $label, 0);
        fail("$label.profile invalid") if $profile !~ /\A(?:fast|impacted|full|governance)\z/;
        fail("duplicate verification requirement profile: $profile") if $profiles{$profile}++;
        fail("$label.profile_config_digest invalid") if require_string($item, 'profile_config_digest', $label, 0) !~ $digest_re;
        fail("$label.command_ids must be a non-empty array") if ref($item->{command_ids}) ne 'ARRAY' || !@{$item->{command_ids}};
        my %ids;
        for my $id (@{$item->{command_ids}}) {
            fail("$label command id invalid") if !is_string($id) || $id !~ /\A[A-Za-z0-9][A-Za-z0-9._-]{0,127}\z/;
            fail("$label duplicate command id: $id") if $ids{$id}++;
        }
    }
}

sub method_gap {
    my ($enforcement,$warnings,$code,$message)=@_;
    fail($message) if $enforcement eq 'required';
    push @$warnings,$code if !grep {$_ eq $code} @$warnings;
}

sub validate_events {
    my ($events, $context, $expected_target, $requirements, $final_tree, $final_head, $enforcement, $initial_warnings) = @_;
    $enforcement //= 'required';
    my @warnings=@{$initial_warnings || []};
    fail('ledger has no events') if !@$events;
    fail('first evidence event must be route') if ($events->[0]{event_type} || '') ne 'route';
    validate_requirements_shape($requirements);
    my (%seen, @route, @red, @green, @exemption, @isolation, @repair, @gate_b, @review, @verification);
    for my $index (0 .. $#$events) {
        my $type = validate_event($events->[$index], $index, $context, $expected_target);
        my $event_id = $events->[$index]{event_id};
        fail("duplicate event_id: $event_id") if $seen{$event_id}++;
        push @{$type eq 'route' ? \@route : $type eq 'tdd_red' ? \@red : $type eq 'tdd_green' ? \@green : $type eq 'tdd_exemption' ? \@exemption : $type eq 'isolation' ? \@isolation : $type eq 'repair' ? \@repair : $type eq 'gate_b' ? \@gate_b : $type eq 'review' ? \@review : $type eq 'verification' ? \@verification : []}, $events->[$index];
    }
    fail('closure requires at least one route event') if !@route;
    my $final_route = $route[-1];
    fail('final route does not match contract risk/execution shape')
        if $final_route->{to_risk} ne $context->{risk} || $final_route->{to_shape} ne $context->{execution_shape};

    for my $requirement (@$requirements) {
        for my $id (@{$requirement->{command_ids}}) {
            my @matching = grep {
                my $candidate=$_;
                ($candidate->{verification_profile} eq $requirement->{profile}
                    && $candidate->{command_id} eq $id
                    && $candidate->{profile_config_digest} eq $requirement->{profile_config_digest})
                || scalar grep {
                    $_->{profile} eq $requirement->{profile}
                    && $_->{command_id} eq $id
                    && $_->{profile_config_digest} eq $requirement->{profile_config_digest}
                } @{$candidate->{covered_commands} || []}
            } @verification;
            fail("missing verification event for $requirement->{profile}/$id") if !@matching;
            my $event = $matching[-1];
            fail("verification $requirement->{profile}/$id did not pass on final tree")
                if $event->{exit_code} != 0 || $event->{tree_sha} ne $final_tree || $event->{head_sha} ne $final_head;
        }
    }

    my $tdd_evidence;
    if ($context->{tdd_policy} eq 'required') {
        if (!@red || !@green) {
            method_gap($enforcement,\@warnings,'MISSING_TDD_RED_GREEN','tdd_policy required needs RED and GREEN events');
            $tdd_evidence='advisory_missing';
        }
        my ($red_index, $green_index) = (-1, -1);
        for my $i (0 .. $#$events) {
            $red_index = $i if $events->[$i]{event_type} eq 'tdd_red' && $red_index < 0;
            $green_index = $i if $events->[$i]{event_type} eq 'tdd_green';
        }
        if (@red && @green) {
            method_gap($enforcement,\@warnings,'INVALID_TDD_SEQUENCE','TDD RED must precede GREEN') if $red_index < 0 || $green_index <= $red_index;
            my $last_green = $green[-1];
            method_gap($enforcement,\@warnings,'STALE_TDD_GREEN','final TDD GREEN is not bound to final tree')
                if $last_green->{exit_code} != 0 || $last_green->{tree_sha} ne $final_tree || $last_green->{head_sha} ne $final_head;
            $tdd_evidence = (grep { /^(?:INVALID_TDD|STALE_TDD)/ } @warnings)
                ? 'advisory_missing' : 'red_green';
        }
    } elsif ($context->{tdd_policy} eq 'exempt') {
        if (!@exemption) {
            method_gap($enforcement,\@warnings,'MISSING_TDD_EXEMPTION','tdd_policy exempt needs tdd_exemption reason evidence');
            $tdd_evidence='advisory_missing';
        } else { $tdd_evidence = 'exemption' }
    } else {
        $tdd_evidence = 'not_applicable';
    }

    my $isolation_required = 1;
    my @valid_isolation = grep { $_->{clean} && $_->{tree_sha} eq $final_tree && $_->{head_sha} eq $final_head } @isolation;
    method_gap($enforcement,\@warnings,'MISSING_FINAL_ISOLATION','final clean isolation/baseline evidence is required') if !@valid_isolation;

    my %repair_round;
    my $max_repair = 0;
    for my $event (@repair) {
        fail("duplicate repair round: $event->{repair_round}") if $repair_round{$event->{repair_round}}++;
        $max_repair = $event->{repair_round} if $event->{repair_round} > $max_repair;
        my $repair_index=-1;
        for my $i (0..$#$events) { $repair_index=$i if $events->[$i]{event_id} eq $event->{event_id} }
        my @scoped;
        for my $i ($repair_index+1..$#$events) {
            my $candidate=$events->[$i];
            push @scoped,$candidate if $candidate->{event_type} eq 'review'
                && $candidate->{review_role} eq 're_review'
                && $candidate->{scope_digest} eq $event->{fix_diff_digest}
                && $candidate->{base_sha} eq $event->{fix_base_sha}
                && $candidate->{head_sha} eq $event->{fix_head_sha};
        }
        method_gap($enforcement,\@warnings,'MISSING_SCOPED_RE_REVIEW',"repair round $event->{repair_round} needs a later scoped re_review") if !@scoped;
    }

    if ($context->{gate_b_status} eq 'resolved') {
        my @matching = grep {
            $_->{gate_b_decision} eq $context->{gate_b_decision}
            && $_->{gate_b_ref} eq $context->{gate_b_ref}
            && $_->{tree_sha} eq $final_tree && $_->{head_sha} eq $final_head
        } @gate_b;
        fail('resolved Gate B requires a matching final-tree gate_b event') if !@matching;
    } elsif (@gate_b) {
        fail('gate_b event exists while gate_b_status is not_triggered');
    }

    my (%roles,%all_roles);
    for my $event (@review) {
        fail('all projected reviews must pass with zero Critical, Important, and Minor findings')
            if $event->{verdict} ne 'pass' || $event->{critical} != 0
            || $event->{important} != 0 || $event->{minor} != 0;
        $all_roles{$event->{review_role}}=1;
        $roles{$event->{review_role}} = 1 if $event->{tree_sha} eq $final_tree && $event->{head_sha} eq $final_head;
    }
    my @required_roles;
    push @required_roles, 'global' if $context->{risk} eq 'R2' || ($context->{execution_shape} eq 'bounded' && $context->{production_code_change});
    push @required_roles, 'global' if $context->{execution_shape} eq 'architectural';
    push @required_roles, 'specialist' if $context->{specialist_review_required};
    my %need_role;
    $need_role{$_} = 1 for @required_roles;
    method_gap($enforcement,\@warnings,'MISSING_REVIEW_ROLE_' . uc($_),"missing final-tree review role: $_") for grep { !$roles{$_} } sort keys %need_role;
    if ($context->{execution_shape} eq 'architectural') {
        my @batch_ids=split /,/,$context->{ownership_batches};
        for my $batch_id (@batch_ids) {
            my @matching=grep {
                $_->{review_role} eq 'batch' && ($_->{batch_id} || '') eq $batch_id
                && $_->{verdict} eq 'pass' && $_->{critical}==0 && $_->{important}==0 && $_->{minor}==0
            } @review;
            my $warning_id=uc($batch_id); $warning_id=~s/[^A-Z0-9]/_/g;
            method_gap($enforcement,\@warnings,'MISSING_BATCH_REVIEW_' . $warning_id,"missing ownership batch review: $batch_id") if !@matching;
        }
    }
    my ($global_review) = reverse grep { $_->{review_role} eq 'global' && $_->{tree_sha} eq $final_tree && $_->{head_sha} eq $final_head } @review;

    return {
        route_final_risk => $final_route->{to_risk},
        route_final_shape => $final_route->{to_shape},
        tdd_evidence => $tdd_evidence,
        isolation_required => $isolation_required,
        gate_b_event_required => $context->{gate_b_status} eq 'resolved' ? 1 : 0,
        review_roles => [sort keys %all_roles],
        max_repair_round => $max_repair,
        global_review => $global_review,
        evidence_warnings => [sort @warnings],
        evidence_completeness => @warnings ? 'advisory_incomplete' : 'complete',
    };
}

sub prepare_close {
    my (%args)=@_;
    my $ledger_file=$args{file}; my $contract_path=$args{contract_file};
    my $id_work=$args{work_id}; my $primary=$args{verification_profile}; my $logical_target=$args{target};
    safe_target($logical_target); need('verification-profile',$primary);
    my $context=load_context($contract_path);
    fail('contract work_id mismatch') if defined($id_work)&&$id_work ne ''&&$context->{work_id} ne $id_work;
    fail('contract evidence_target mismatch') if $context->{evidence_target} ne $logical_target;
    my $raw=read_raw($ledger_file); my ($events)=parse_jsonl($raw,$ledger_file);
    for my $event (@$events) {
        next if ($event->{event_type}//'') ne 'verification';
        my $info=verification_command($event->{verification_profile},$event->{command_id},$context->{work_id});
        fail("verification argv digest mismatch for $event->{verification_profile}/$event->{command_id}") if $event->{argv_digest} ne $info->{argv_digest};
        fail("verification profile digest mismatch for $event->{verification_profile}/$event->{command_id}") if $event->{profile_config_digest} ne $info->{profile_config_digest};
        fail("verification coverage differs from effective config for $event->{verification_profile}/$event->{command_id}")
            if $json->encode($event->{covered_commands}||[]) ne $json->encode($info->{covered_commands}||[]);
    }
    my $source_digest=sha256_hex($raw);
    my $sidecar_ref="docs/closure/evidence/EV-$context->{work_id}-$source_digest.jsonl";
    my $final_tree=workspace_tree($logical_target,$sidecar_ref); my $final_head=current_head();
    my $policy=parse_project_policy();
    my $mapping=derive_path_mapping($events,$context,$final_tree,$final_head,$primary,$policy);
    my $requirements=requirements_for_current_config($context,$primary,$mapping);
    my $summary=validate_events($events,$context,$logical_target,$requirements,$final_tree,$final_head,
        $policy->{methodology_enforcement},$mapping->{warnings});
    my $risk_status=$args{remaining_risk_status}//'none'; my $risk_ref=$args{remaining_risk_ref}//'none';
    fail('--remaining-risk-status must be none or recorded') if $risk_status!~/\A(?:none|recorded)\z/;
    fail('--remaining-risk-ref must be a safe non-none reference for recorded risk')
        if $risk_status eq 'recorded'&&($risk_ref!~/\A[A-Za-z0-9][A-Za-z0-9._:\@\/-]{0,511}\z/||$risk_ref eq 'none');
    fail('--remaining-risk-ref must be none when remaining-risk-status is none') if $risk_status eq 'none'&&$risk_ref ne 'none';
    my $receipt={
        schema_version=>2,receipt_type=>'closure',evidence_trust=>'local_consistency',
        evidence_storage=>'sidecar_jsonl',evidence_ref=>$sidecar_ref,
        work_id=>$context->{work_id},risk=>$context->{risk},execution_shape=>$context->{execution_shape},
        contract_digest=>$context->{contract_digest},production_code_change=>$context->{production_code_change},
        multi_agent=>$context->{multi_agent},implementer=>$context->{implementer},tdd_policy=>$context->{tdd_policy},
        governance_change=>$context->{governance_change},specialist_review_required=>$context->{specialist_review_required},
        truth_patch_ref=>$context->{truth_patch_ref},gate_b_status=>$context->{gate_b_status},
        gate_b_decision=>$context->{gate_b_decision},gate_b_ref=>$context->{gate_b_ref},gate_a=>$context->{gate_a},
        truth_patch_digest=>$context->{truth_patch_digest},ownership_batches=>$context->{ownership_batches},
        legacy_startup_evidence=>$context->{legacy_startup_evidence},event_count=>scalar(@$events),
        source_digest=>$source_digest,final_tree_sha=>$final_tree,head_sha=>$final_head,evidence_target=>$logical_target,
        tree_excludes=>['.p2t2c/runs/**',$logical_target,$sidecar_ref],verification_profile=>$primary,
        verification_requirements=>$requirements,route_final_risk=>$summary->{route_final_risk},
        route_final_shape=>$summary->{route_final_shape},tdd_evidence=>$summary->{tdd_evidence},
        isolation_required=>$summary->{isolation_required}?$json->true:$json->false,
        gate_b_event_required=>$summary->{gate_b_event_required}?$json->true:$json->false,
        review_roles=>$summary->{review_roles},max_repair_round=>$summary->{max_repair_round},
        methodology_enforcement=>$policy->{methodology_enforcement},evidence_completeness=>$summary->{evidence_completeness},
        evidence_warnings=>$summary->{evidence_warnings},path_mapping_digest=>$mapping->{path_mapping_digest},
        matched_profiles=>$mapping->{matched_profiles},matched_paths_digest=>$mapping->{matched_paths_digest},
        baseline_sha=>$mapping->{baseline_sha},remaining_risk_status=>$risk_status,remaining_risk_ref=>$risk_ref,closed_at=>iso_now(),
    };
    if ($summary->{global_review}) {
        $receipt->{reviewer}=$summary->{global_review}{reviewer};
        $receipt->{review_base_sha}=$summary->{global_review}{base_sha};
        $receipt->{review_head_sha}=$summary->{global_review}{head_sha};
    }
    my @config_paths=('.p2t2c/defaults.yaml','.p2t2c/project_config.yaml');
    my %config_state=map {$_=>(-f$_?sha256_hex(read_raw($_)):'absent')} @config_paths;
    my @target_stat=lstat($logical_target);
    my @contract_stat=lstat($contract_path); my @ledger_stat=lstat($ledger_file);
    my @engine_paths=grep {-f$_} ('.p2t2c/bin/check_p2t2c.sh','.p2t2c/bin/check_p2t2c.pl','.p2t2c/bin/p2t2c_close.pl','.p2t2c/bin/p2t2c_evidence.pl',
        glob('.p2t2c/lib/P2T2C/*.pm'),glob('.p2t2c/schemas/*.json'));
    my $prepared=bless {
        receipt=>$receipt,receipt_json=>$json->encode($receipt),events_raw=>$raw,events=>$events,
        contract_path=>$contract_path,contract_digest_raw=>sha256_hex(read_raw($contract_path)),
        ledger_path=>$ledger_file,ledger_digest_raw=>$source_digest,target=>$logical_target,sidecar=>$sidecar_ref,
        config_digests=>\%config_state,cpk_path=>$context->{cpk_path},
        engine_digests=>{map {$_=>sha256_hex(read_raw($_))} @engine_paths},
        contract_identity=>{dev=>$contract_stat[0],ino=>$contract_stat[1],mode=>$contract_stat[2]&07777},
        ledger_identity=>{dev=>$ledger_stat[0],ino=>$ledger_stat[1],mode=>$ledger_stat[2]&07777},
        target_state=>@target_stat?{exists=>1,dev=>$target_stat[0],ino=>$target_stat[1],mode=>$target_stat[2]&07777,digest=>sha256_hex(read_raw($logical_target))}:{exists=>0},
    },'P2T2C::Evidence::Prepared';
    return $prepared;
}

package P2T2C::Evidence::Prepared;
sub receipt {$_[0]{receipt}}
sub receipt_json {$_[0]{receipt_json}}
sub events_raw {$_[0]{events_raw}}
sub assert_fresh {
    my ($self)=@_;
    my @contract_stat=lstat($self->{contract_path}); my @ledger_stat=lstat($self->{ledger_path});
    for my $pair ([$self->{contract_path},\@contract_stat,$self->{contract_identity}],[$self->{ledger_path},\@ledger_stat,$self->{ledger_identity}]) {
        my ($path,$stat,$expected)=@$pair;
        P2T2C::Evidence::fail("prepared run identity changed: $path") if !@$stat||$stat->[0]!=$expected->{dev}||$stat->[1]!=$expected->{ino}||($stat->[2]&07777)!=$expected->{mode};
    }
    P2T2C::Evidence::fail('prepared contract changed') if P2T2C::Evidence::sha256_hex(P2T2C::Evidence::read_raw($self->{contract_path})) ne $self->{contract_digest_raw};
    P2T2C::Evidence::fail('prepared ledger changed') if P2T2C::Evidence::sha256_hex(P2T2C::Evidence::read_raw($self->{ledger_path})) ne $self->{ledger_digest_raw};
    for my $path (keys %{$self->{config_digests}}) {
        my $now=-f$path?P2T2C::Evidence::sha256_hex(P2T2C::Evidence::read_raw($path)):'absent';
        P2T2C::Evidence::fail("prepared config changed: $path") if $now ne $self->{config_digests}{$path};
    }
    for my $path (keys %{$self->{engine_digests}}) {P2T2C::Evidence::fail("prepared validator changed: $path") if !-f$path||P2T2C::Evidence::sha256_hex(P2T2C::Evidence::read_raw($path)) ne $self->{engine_digests}{$path}}
    if (!$self->{installed}) {
        my @st=lstat($self->{target}); my $old=$self->{target_state};
        P2T2C::Evidence::fail('prepared target existence changed') if (@st?1:0)!=$old->{exists};
        if (@st) {
            P2T2C::Evidence::fail('prepared target identity/mode changed') if $st[0]!=$old->{dev}||$st[1]!=$old->{ino}||($st[2]&07777)!=$old->{mode};
            P2T2C::Evidence::fail('prepared target content changed') if P2T2C::Evidence::sha256_hex(P2T2C::Evidence::read_raw($self->{target})) ne $old->{digest};
        }
    }
    my $receipt=$self->{receipt};
    P2T2C::Evidence::fail('prepared HEAD changed') if P2T2C::Evidence::current_head() ne $receipt->{head_sha};
    my $fresh_tree=P2T2C::Evidence::workspace_tree($self->{target},$self->{sidecar},$self->{transients});
    P2T2C::Evidence::fail("prepared final tree changed: expected $receipt->{final_tree_sha}, got $fresh_tree") if $fresh_tree ne $receipt->{final_tree_sha};
    return 1;
}
sub bind_projection {
    my($self,$artifact)=@_;my$raw=P2T2C::Evidence::read_raw($artifact);return$self->bind_projection_raw($raw);
}
sub bind_projection_raw {
    my ($self,$raw)=@_; $self->assert_fresh();
    my $projection=P2T2C::Evidence::extract_projection_text($raw,'candidate');
    P2T2C::Evidence::fail('candidate marker is not the prepared receipt') if $projection ne $self->{receipt_json}."\n";
    P2T2C::Evidence::safe_evidence_ref($self->{sidecar},0);
    my$sidecar_raw=P2T2C::Evidence::held_read_file(P2T2C::Evidence::dirname($self->{sidecar}),P2T2C::Evidence::basename($self->{sidecar}),'prepared sidecar');
    P2T2C::Evidence::fail('candidate sidecar differs from prepared events') if $sidecar_raw ne $self->{events_raw};
    $self->{artifact_digest}=P2T2C::Evidence::sha256_hex($raw);
    return 1;
}
sub set_transients {my($self,@paths)=@_;$self->{transients}=\@paths;return 1}
sub mark_installed {my($self,$raw)=@_;$self->{installed}=1;$self->{installed_raw}=$raw if defined$raw;return 1}
sub valid_for {
    my ($self,$artifact,$cpk)=@_; return 0 if !defined($self->{artifact_digest})||!$self->{installed};
    my $ok=eval {$self->assert_fresh();1}; return 0 if !$ok;
    return 0 if !defined($self->{installed_raw})||P2T2C::Evidence::sha256_hex($self->{installed_raw}) ne $self->{artifact_digest};
    return 0 if !-f$self->{sidecar};my$sidecar_raw=eval{P2T2C::Evidence::held_read_file(P2T2C::Evidence::dirname($self->{sidecar}),P2T2C::Evidence::basename($self->{sidecar}),'installed sidecar')};return 0 if$@||P2T2C::Evidence::sha256_hex($sidecar_raw)ne$self->{receipt}{source_digest};
    return 1;
}
package P2T2C::Evidence;

sub extract_projection {
    my ($artifact) = @_;
    my $text = read_raw($artifact);
    return extract_projection_text($text,$artifact);
}

sub extract_projection_text {
    my($text,$label)=@_;$label||='artifact';
    my $start = '<!-- p2t2c:evidence:start -->';
    my $end = '<!-- p2t2c:evidence:end -->';
    my $starts = () = $text =~ /\Q$start\E/g;
    my $ends = () = $text =~ /\Q$end\E/g;
    fail("$label must contain exactly one machine evidence block") if $starts != 1 || $ends != 1;
    my ($projection) = $text =~ /\Q$start\E[ \t]*\r?\n```jsonl\r?\n(.*?)```[ \t]*\r?\n\Q$end\E/s;
    fail("$label has malformed machine evidence markers/fence") if !defined($projection);
    $projection =~ s/\r\n/\n/g;
    return $projection;
}

sub context_from_receipt {
    my ($receipt) = @_;
    return {
        work_id => $receipt->{work_id}, risk => $receipt->{risk}, execution_shape => $receipt->{execution_shape},
        production_code_change => $receipt->{production_code_change}, multi_agent => $receipt->{multi_agent},
        work_pack => 'none', implementer => $receipt->{implementer}, tdd_policy => $receipt->{tdd_policy},
        governance_change => $receipt->{governance_change}, specialist_review_required => $receipt->{specialist_review_required},
        gate_a => $receipt->{gate_a}, truth_patch_ref => $receipt->{truth_patch_ref}, truth_patch_digest => $receipt->{truth_patch_digest},
        ownership_batches => $receipt->{ownership_batches}, legacy_startup_evidence => $receipt->{legacy_startup_evidence},
        gate_b_status => $receipt->{gate_b_status},
        gate_b_decision => $receipt->{gate_b_decision}, gate_b_ref => $receipt->{gate_b_ref},
        contract_digest => $receipt->{contract_digest}, evidence_target => $receipt->{evidence_target},
        baseline_sha => $receipt->{baseline_sha},
    };
}

sub validate_receipt_shape {
    my ($receipt, $target_path) = @_;
    my @allowed = qw(
        schema_version receipt_type evidence_trust work_id risk execution_shape contract_digest
        production_code_change multi_agent implementer tdd_policy governance_change
        specialist_review_required gate_a truth_patch_ref truth_patch_digest ownership_batches
        legacy_startup_evidence gate_b_status gate_b_decision gate_b_ref
        event_count source_digest final_tree_sha head_sha evidence_target tree_excludes
        verification_profile verification_requirements route_final_risk route_final_shape
        tdd_evidence isolation_required gate_b_event_required review_roles reviewer
        review_base_sha review_head_sha max_repair_round methodology_enforcement
        evidence_completeness evidence_warnings path_mapping_digest matched_profiles
        matched_paths_digest baseline_sha remaining_risk_status remaining_risk_ref closed_at
        evidence_storage evidence_ref
    );
    exact_keys($receipt, \@allowed, 'closure_receipt');
    my $receipt_schema=require_integer($receipt,'schema_version','closure_receipt');
    fail('closure_receipt.schema_version must be integer 1 or 2') if $receipt_schema != 1 && $receipt_schema != 2;
    fail('closure_receipt.receipt_type must be closure') if require_string($receipt, 'receipt_type', 'closure_receipt', 0) ne 'closure';
    fail('closure_receipt.evidence_trust must be local_consistency') if require_string($receipt, 'evidence_trust', 'closure_receipt', 0) ne 'local_consistency';
    for my $key (qw(work_id risk execution_shape contract_digest implementer tdd_policy gate_a truth_patch_ref truth_patch_digest ownership_batches gate_b_status gate_b_decision gate_b_ref source_digest final_tree_sha head_sha evidence_target verification_profile route_final_risk route_final_shape tdd_evidence methodology_enforcement evidence_completeness path_mapping_digest matched_paths_digest baseline_sha remaining_risk_status remaining_risk_ref closed_at)) {
        require_string($receipt, $key, 'closure_receipt', 0);
    }
    require_boolean($receipt, $_, 'closure_receipt') for qw(production_code_change multi_agent governance_change specialist_review_required legacy_startup_evidence isolation_required gate_b_event_required);
    require_integer($receipt, $_, 'closure_receipt') for qw(event_count max_repair_round);
    fail('closure_receipt digest/OID invalid') if $receipt->{contract_digest} !~ $digest_re || $receipt->{source_digest} !~ $digest_re || $receipt->{final_tree_sha} !~ $oid_re || $receipt->{head_sha} !~ $oid_re;
    fail('closure_receipt truth/path digests invalid')
        if ($receipt->{truth_patch_digest} ne 'none' && $receipt->{truth_patch_digest} !~ $digest_re)
        || $receipt->{path_mapping_digest} !~ $digest_re || $receipt->{matched_paths_digest} !~ $digest_re
        || $receipt->{baseline_sha} !~ $oid_re;
    fail('closure_receipt evidence_target mismatch') if $receipt->{evidence_target} ne $target_path;
    if ($receipt_schema==1) {
        fail('closure_receipt v1 cannot declare sidecar fields') if exists($receipt->{evidence_storage}) || exists($receipt->{evidence_ref});
        validate_excludes($receipt, 'closure_receipt', $target_path);
    } else {
        fail('closure_receipt.evidence_storage must be sidecar_jsonl')
            if require_string($receipt,'evidence_storage','closure_receipt',0) ne 'sidecar_jsonl';
        my $ref=require_string($receipt,'evidence_ref','closure_receipt',0);
        fail('closure_receipt evidence_ref is unsafe') if $ref !~ $evidence_ref_re;
        my $expected_ref="docs/closure/evidence/EV-$receipt->{work_id}-$receipt->{source_digest}.jsonl";
        fail('closure_receipt evidence_ref is not content-addressed for work/source digest') if $ref ne $expected_ref;
        fail('closure_receipt v2 tree_excludes mismatch')
            if ref($receipt->{tree_excludes}) ne 'ARRAY' || @{$receipt->{tree_excludes}} != 3
            || $receipt->{tree_excludes}[0] ne '.p2t2c/runs/**'
            || $receipt->{tree_excludes}[1] ne $target_path || $receipt->{tree_excludes}[2] ne $ref;
    }
    validate_requirements_shape($receipt->{verification_requirements});
    fail('closure_receipt review_roles must be an array') if ref($receipt->{review_roles}) ne 'ARRAY';
    require_string({ role => $_ }, 'role', 'closure_receipt.review_roles', 0) for @{$receipt->{review_roles}};
    fail('closure_receipt.closed_at invalid') if $receipt->{closed_at} !~ $time_re;
    fail('closure_receipt.evidence_warnings must be an array') if ref($receipt->{evidence_warnings}) ne 'ARRAY';
    fail('closure_receipt.matched_profiles must be an array') if ref($receipt->{matched_profiles}) ne 'ARRAY';
    fail('closure_receipt methodology_enforcement invalid') if $receipt->{methodology_enforcement} !~ /\A(?:required|advisory)\z/;
    fail('closure_receipt evidence_completeness invalid') if $receipt->{evidence_completeness} !~ /\A(?:complete|advisory_incomplete)\z/;
    for my $warning (@{$receipt->{evidence_warnings}}) {
        fail('closure_receipt warning code invalid') if !is_string($warning) || $warning !~ /\A[A-Z][A-Z0-9_]{2,127}\z/;
    }
    for my $profile (@{$receipt->{matched_profiles}}) {
        fail('closure_receipt matched profile invalid') if !is_string($profile) || $profile !~ /\A(?:fast|impacted|full|governance)\z/;
    }
    my %profile_rank=(fast=>0,impacted=>1,full=>2);
    my $minimum='fast';
    my %matched=map {$_=>1} @{$receipt->{matched_profiles}};
    for my $profile (grep {$_ ne 'governance'} @{$receipt->{matched_profiles}}) {
        $minimum=$profile if $profile_rank{$profile}>$profile_rank{$minimum};
    }
    fail('closure_receipt verification_profile is below matched path minimum')
        if $receipt->{verification_profile} eq 'governance'
        || $profile_rank{$receipt->{verification_profile}}<$profile_rank{$minimum};
    fail('closure_receipt R2/multi_agent primary profile must be full')
        if ($receipt->{risk} eq 'R2' || $receipt->{multi_agent}) && $receipt->{verification_profile} ne 'full';
    my %required_profile=map {$_->{profile}=>1} @{$receipt->{verification_requirements}};
    fail('closure_receipt matched governance profile lacks governance requirements')
        if ($matched{governance} || $receipt->{governance_change}) && !$required_profile{governance};
    fail('closure_receipt complete cannot carry warnings')
        if $receipt->{evidence_completeness} eq 'complete' && @{$receipt->{evidence_warnings}};
    fail('closure_receipt advisory_incomplete requires advisory enforcement and warnings')
        if $receipt->{evidence_completeness} eq 'advisory_incomplete'
        && ($receipt->{methodology_enforcement} ne 'advisory' || !@{$receipt->{evidence_warnings}});
    fail('closure_receipt remaining risk ref/status mismatch')
        if ($receipt->{remaining_risk_status} eq 'none' && $receipt->{remaining_risk_ref} ne 'none')
        || ($receipt->{remaining_risk_status} eq 'recorded' && $receipt->{remaining_risk_ref} eq 'none');
}

sub validate_artifact {
    my ($artifact, $cpk_path, $logical_target, $parsed) = @_;
    $logical_target //= $artifact;
    safe_target($logical_target);
    validate_safe_path($artifact, 0, 'evidence artifact candidate');
    my $projection = extract_projection($artifact);
    my($objects,$lines,$projection_objects);
    if(ref($parsed)eq'HASH'&&ref($parsed->{projection_objects})eq'ARRAY'){
        my$canonical=join('',map{$json->encode($_)."\n"}@{$parsed->{projection_objects}});
        fail('cached projection AST does not match current artifact bytes')if$canonical ne$projection;
        $projection_objects=[@{$parsed->{projection_objects}}];$objects=[@$projection_objects];$lines=[map{$json->encode($_)}@$projection_objects];
    }else{($objects,$lines)=parse_jsonl($projection,"$artifact evidence block");$projection_objects=[@$objects]}
    fail('machine evidence block needs a closure receipt') if !@$objects;
    my $receipt = pop @$objects;
    pop @$lines;
    validate_receipt_shape($receipt, $logical_target);
    my $raw_events;
    if (($receipt->{schema_version}||0)==2) {
        fail('receipt v2 marker must contain only the receipt') if @$objects || @$lines;
        safe_evidence_ref($receipt->{evidence_ref},0);
        my @sidecar_stat=lstat($receipt->{evidence_ref});
        fail('evidence sidecar must be owner-controlled regular file with one link')
            if !@sidecar_stat||!S_ISREG($sidecar_stat[2])||S_ISLNK($sidecar_stat[2])
            ||$sidecar_stat[3]!=1||$sidecar_stat[4]!=$<||($sidecar_stat[2]&0022);
        $raw_events=held_read_file(dirname($receipt->{evidence_ref}),basename($receipt->{evidence_ref}),'evidence sidecar');
        if(ref($parsed)eq'HASH'&&ref($parsed->{events})eq'ARRAY'){
            my$canonical=join('',map{$json->encode($_)."\n"}@{$parsed->{events}});fail('cached event AST does not match current sidecar bytes')if$canonical ne$raw_events;$objects=[@{$parsed->{events}}];$lines=[map{$json->encode($_)}@$objects];
        }else{($objects,$lines)=parse_jsonl($raw_events,$receipt->{evidence_ref})}
    } else {
        fail('machine evidence block needs events plus one closure receipt') if !@$objects;
        $raw_events=join('',map {"$_\n"} @$lines);
    }
    fail('closure_receipt.event_count mismatch') if $receipt->{event_count} != @$objects;
    fail('closure_receipt.source_digest mismatch') if $receipt->{source_digest} ne sha256_hex($raw_events);
    $LAST_ARTIFACT_INDEX={projection_objects=>$projection_objects,events=>[@$objects]};
    my $context = context_from_receipt($receipt);
    if ($context->{risk} eq 'R0') {
        my %core = map { $_ => $context->{$_} } qw(
            work_id risk execution_shape production_code_change multi_agent work_pack implementer
            tdd_policy governance_change specialist_review_required gate_a truth_patch_ref truth_patch_digest
            gate_b_status gate_b_decision gate_b_ref ownership_batches legacy_startup_evidence
        );
        fail('R0 artifact contract_digest mismatch') if sha256_hex($json->encode(\%core)) ne $context->{contract_digest};
    } else {
        my $source = $context->{risk} eq 'R1' ? ($cpk_path || $artifact) : $cpk_path;
        need('cpk', $source) if $context->{risk} eq 'R2';
        my $fresh = parse_cpk($source, $context->{work_id}, {historical_applied=>1});
        fail('artifact contract_digest no longer matches normalized CPK contract')
            if $fresh->{contract_digest} ne $context->{contract_digest};
    }
    validate_commit_ancestry($receipt->{baseline_sha},$receipt->{head_sha},'receipt path mapping baseline');
    open my $path_pipe,'-|','git','diff','--name-only','--no-renames',$receipt->{baseline_sha},$receipt->{final_tree_sha}
        or fail('cannot recompute receipt path diff');
    my @receipt_paths; while (my $line=<$path_pipe>) { chomp $line; push @receipt_paths,$line if $line ne '' }
    close $path_pipe or fail('cannot recompute receipt path diff');
    @receipt_paths=sort @receipt_paths;
    fail('closure_receipt.matched_paths_digest mismatch')
        if sha256_hex($json->encode(\@receipt_paths)) ne $receipt->{matched_paths_digest};
    my @mapping_warnings=grep {$_ eq 'MISSING_ISOLATION_BASELINE'} @{$receipt->{evidence_warnings}};
    my $summary = validate_events($objects, $context, $logical_target, $receipt->{verification_requirements},
        $receipt->{final_tree_sha}, $receipt->{head_sha}, $receipt->{methodology_enforcement}, \@mapping_warnings);
    for my $key (qw(route_final_risk route_final_shape tdd_evidence max_repair_round)) {
        fail("closure_receipt.$key mismatch") if $receipt->{$key} ne $summary->{$key};
    }
    for my $key (qw(isolation_required gate_b_event_required)) {
        fail("closure_receipt.$key mismatch") if ($receipt->{$key} ? 1 : 0) != $summary->{$key};
    }
    fail('closure_receipt.review_roles mismatch')
        if $json->encode($receipt->{review_roles}) ne $json->encode($summary->{review_roles});
    fail('closure_receipt.evidence_completeness mismatch')
        if $receipt->{evidence_completeness} ne $summary->{evidence_completeness};
    fail('closure_receipt.evidence_warnings mismatch')
        if $json->encode($receipt->{evidence_warnings}) ne $json->encode($summary->{evidence_warnings});
    if ($summary->{global_review}) {
        fail('closure_receipt reviewer/base/head missing or mismatched')
            if !exists($receipt->{reviewer}) || !exists($receipt->{review_base_sha}) || !exists($receipt->{review_head_sha})
            || $receipt->{reviewer} ne $summary->{global_review}{reviewer}
            || $receipt->{review_base_sha} ne $summary->{global_review}{base_sha}
            || $receipt->{review_head_sha} ne $summary->{global_review}{head_sha};
    }
    return ($receipt, $context, $summary);
}

sub main {
GetOptions(
    'action=s'                 => \$action,
    'file=s'                   => \$file,
    'work-id=s'                => \$work_id,
    'target=s'                 => \$target,
    'contract-file=s'          => \$contract_file,
    'verification-profile=s'   => \$verification_profile,
    'remaining-risk-status=s'  => \$remaining_risk_status,
    'remaining-risk-ref=s'     => \$remaining_risk_ref,
    'cpk=s'                    => \$cpk,
    'command-id=s'             => \$command_id,
    'config=s'                 => \$config_file,
    'evidence-ref=s'           => \$evidence_ref,
) or fail('invalid arguments');

need('action', $action);

if ($action eq 'tree') {
    safe_target($target);
    print workspace_tree($target,$evidence_ref), "\n";
    exit 0;
}
if ($action eq 'head') {
    print current_head(), "\n";
    exit 0;
}
if ($action eq 'context-cpk') {
    need('file', $file); need('work-id', $work_id);
    print $json->encode(parse_cpk($file, $work_id)), "\n";
    exit 0;
}
if ($action eq 'contract') {
    need('file', $file);
    print parse_cpk($file, $work_id)->{contract_digest}, "\n";
    exit 0;
}
if ($action eq 'profile-requirement') {
    need('verification-profile', $verification_profile);
    my $r = profile_requirement($verification_profile);
    delete $r->{commands};
    print $json->encode($r), "\n";
    exit 0;
}
if ($action eq 'project-policy') {
    print $json->encode(parse_project_policy()), "\n";
    exit 0;
}
if ($action eq 'verification-command') {
    print $json->encode(verification_command($verification_profile, $command_id, $work_id)), "\n";
    exit 0;
}
if ($action eq 'verification-plan') {
    need('file',$file); need('contract-file',$contract_file);
    need('verification-profile',$verification_profile); need('target',$target);
    print $json->encode(build_verification_plan($file,$contract_file,$verification_profile,$target)), "\n";
    exit 0;
}
if ($action eq 'validate-run-state') {
    validate_run_state($work_id, $cpk);
    print "safe run state valid\n";
    exit 0;
}
if ($action eq 'validate-ledger' || $action eq 'receipt') {
    my $prepared=prepare_close(
        file=>$file,contract_file=>$contract_file,work_id=>$work_id,
        verification_profile=>$verification_profile,target=>$target,
        remaining_risk_status=>$remaining_risk_status,remaining_risk_ref=>$remaining_risk_ref,
    );
    if ($action eq 'validate-ledger') {print "current machine evidence ledger valid\n";exit 0}
    print $prepared->receipt_json(),"\n"; exit 0;

}
if ($action eq 'validate-artifact') {
    validate_artifact($file, $cpk, $target);
    print "local-consistency closure evidence valid\n";
    exit 0;
}

fail("unsupported --action: $action");
}

unless (caller) {
    my $ok = eval { main(); 1 };
    if (!$ok) {
        my $message = $@ || "ERROR: evidence: unknown failure\n";
        print STDERR $message;
        exit 1;
    }
}
1;
