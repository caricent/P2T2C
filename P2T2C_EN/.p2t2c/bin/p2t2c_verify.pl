#!/usr/bin/env perl
use strict;
use warnings;

use File::Basename qw(dirname);
use Getopt::Long qw(GetOptions);
use JSON::PP ();
use Time::HiRes qw(usleep);

my ($work_id,$profile,$show_output,$help)=(undef,undef,0,0);
my $jobs=4;
GetOptions(
    'work-id=s'=>\$work_id,
    'profile=s'=>\$profile,
    'jobs=i'=>\$jobs,
    'show-output'=>\$show_output,
    'help|h'=>\$help,
) or die "ERROR: invalid verify arguments\n";
if ($help) {
    print "Usage: p2t2c verify --work-id ID --profile fast|impacted|full|governance [--jobs 1..8] [--show-output]\n";
    exit 0;
}
die "ERROR: valid --work-id is required\n" if !defined($work_id) || $work_id !~ /\A[A-Za-z0-9][A-Za-z0-9._-]*\z/;
die "ERROR: valid --profile is required\n" if !defined($profile) || $profile !~ /\A(?:fast|impacted|full|governance)\z/;
die "ERROR: --jobs must be between 1 and 8\n" if $jobs<1 || $jobs>8;
die "ERROR: run from the project root containing .p2t2c and docs\n" if !-d '.p2t2c' || -l '.p2t2c' || !-d 'docs';

my $bin=dirname($0);
my $helper="$bin/p2t2c_evidence.pl";
my $runner="$bin/p2t2c_run.sh";
my $run_dir=".p2t2c/runs/$work_id";
my $contract="$run_dir/contract.json";
my $ledger="$run_dir/events.jsonl";
die "ERROR: missing safe run state\n" if !-d $run_dir || -l $run_dir || !-f $contract || -l $contract || !-f $ledger || -l $ledger;

my $json=JSON::PP->new->canonical(1)->utf8(1);
open my $cf,'<:raw',$contract or die "ERROR: cannot read $contract: $!\n";
local $/; my $contract_raw=<$cf>; close $cf;
my $context=eval {$json->decode($contract_raw)};
die "ERROR: malformed run contract\n" if $@ || ref($context) ne 'HASH';
my $target=$context->{evidence_target};
die "ERROR: invalid evidence target\n" if !defined($target) || $target !~ m{\Adocs/(?:change_packs/CPK-|closure/CR-)[A-Za-z0-9._-]+\.md\z};

sub capture {
    my (@argv)=@_;
    open my $fh,'-|',@argv or die "ERROR: cannot run @argv: $!\n";
    local $/; my $out=<$fh>//'';
    close $fh or die "ERROR: command failed: @argv\n";
    $out=~s/[\r\n]+\z//;
    return $out;
}

my $plan_raw=capture('perl',$helper,'--action','verification-plan','--file',$ledger,
    '--contract-file',$contract,'--verification-profile',$profile,'--target',$target);
my $plan=eval {$json->decode($plan_raw)};
die "ERROR: malformed verification plan\n" if $@ || ref($plan) ne 'HASH' || ref($plan->{executions}) ne 'ARRAY';

my $token=substr(unpack('H*',pack('Nnn',time(),$$,int(rand(65535)))),0,24);
my $lock="$run_dir/.lifecycle-lock";
my $marker="$run_dir/.active-batch-$token";
sub acquire_lock {
    for (1..200) {
        if (mkdir($lock,0700)) {
            open my $owner,'>',$lock.'/owner' or die "ERROR: cannot own lifecycle lock\n";
            chmod 0600,$lock.'/owner'; print {$owner} $token,"\n"; close $owner; return;
        }
        usleep(100_000);
    }
    die "ERROR: timed out waiting for run lifecycle lock\n";
}
sub release_lock {
    unlink $lock.'/owner' or die "ERROR: cannot release lifecycle owner\n";
    rmdir $lock or die "ERROR: cannot release lifecycle lock\n";
}
my $marker_owned=0;
my $controller_pid=$$;
sub cleanup_marker {
    return if !$marker_owned||$$!=$controller_pid;
    eval { acquire_lock(); unlink $marker; $marker_owned=0; release_lock(); 1 };
}
END { cleanup_marker() }
$SIG{INT}=sub {cleanup_marker(); exit 130};
$SIG{TERM}=sub {cleanup_marker(); exit 143};

acquire_lock();
if (-e "$run_dir/.closing") {release_lock();die "ERROR: run is closing\n"}
open my $mf,'>',$marker or die "ERROR: cannot create batch marker: $!\n";
chmod 0600,$marker; print {$mf} $token,"\n"; close $mf; $marker_owned=1;
release_lock();

sub run_one {
    my ($execution)=@_;
    my @argv=('bash',$runner,'--work-id',$work_id,'--event-type','verification',
        '--verification-profile',$execution->{profile},'--command-id',$execution->{command_id});
    push @argv,'--show-output' if $show_output;
    system(@argv);
    return $? == -1 ? 127 : ($? >> 8);
}

my $failed=0;
my @items=@{$plan->{executions}};
for (my $index=0;$index<@items;) {
    my $item=$items[$index];
    my $parallel=$item->{read_only} && ($item->{parallel_group}||'none') ne 'none';
    if (!$parallel) {
        $failed=1 if run_one($item)!=0;
        $index++;
        next;
    }
    my $group=$item->{parallel_group};
    my @wave;
    while ($index<@items && @wave<$jobs && $items[$index]{read_only}
        && ($items[$index]{parallel_group}||'none') eq $group) {
        push @wave,$items[$index++];
    }
    my %children;
    for my $execution (@wave) {
        my $pid=fork(); die "ERROR: cannot fork verification command\n" if !defined $pid;
        if ($pid==0) { exit(run_one($execution)) }
        $children{$pid}=1;
    }
    while (%children) {
        my $pid=wait(); last if $pid<0;
        delete $children{$pid}; $failed=1 if ($?>>8)!=0;
    }
}

my $end_tree=capture('perl',$helper,'--action','tree','--target',$target);
my $end_head=capture('perl',$helper,'--action','head');
$failed=1 if $end_tree ne $plan->{final_tree_sha} || $end_head ne $plan->{head_sha};
cleanup_marker();
if ($failed) {
    print STDERR "P2T2C verification batch failed; plan=$plan->{plan_digest}\n";
    exit 1;
}
print STDERR "P2T2C verification batch passed; plan=$plan->{plan_digest}\n";
exit 0;
