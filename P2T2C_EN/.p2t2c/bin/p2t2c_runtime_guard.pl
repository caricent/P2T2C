#!/usr/bin/env perl
use strict;
use warnings;
use File::Basename qw(dirname basename);
use Cwd qw(abs_path);
use Errno qw(EINTR);
use POSIX ();

my $bin=dirname($0);unshift @INC,"$bin/../lib";
require P2T2C::DocumentActions;
my $check=(@ARGV && $ARGV[0] eq '--check') ? shift(@ARGV) : q();
my $target=shift(@ARGV)//die "ERROR: runtime guard requires a target\n";
chdir $target or die "ERROR: cannot enter guarded target\n";
P2T2C::DocsMigration::check_root();
if ($check) {
    my $owner=shift(@ARGV)//q();
    my $record=P2T2C::Documents::read_safe('.p2t2c/.documents-lock/owner','upgrade lock');$record=~s/\s+\z//;
    die "ERROR: invalid inherited document lock\n" if @ARGV || $owner!~/\A[1-9][0-9]*\z/ || $owner ne $record || !kill(0,$owner);
    exit 0;
}
my $runtime=shift(@ARGV)//die "ERROR: runtime guard requires runtime capabilities\n";
my $script=shift(@ARGV)//die "ERROR: runtime guard requires a managed script\n";
die "ERROR: unexpected guarded script\n" if basename($script)!~/\Ap2t2c_(?:install|upgrade)\.sh\z/ || !-f$script || -l$script;
P2T2C::DocsMigration::ensure_dir('.p2t2c');
my $lock=P2T2C::Documents::acquire_lock();
my($status,$error);
my $ok=eval {
    P2T2C::Documents::assert_no_pending_migration();
    P2T2C::DocumentActions::assert_runtime_compatible($runtime);
    local $ENV{P2T2C_RUNTIME_LOCK_OWNER}="$$";
    my($child,$signal);
    local $SIG{INT}=sub {$signal=2;kill 'INT',$child if defined($child) && $child>0};
    local $SIG{TERM}=sub {$signal=15;kill 'TERM',$child if defined($child) && $child>0};
    $child=fork();die "ERROR: cannot start managed runtime operation\n" if !defined $child;
    if (!$child) {
        $SIG{INT}='DEFAULT';$SIG{TERM}='DEFAULT';
        exec('bash',$script,@ARGV) or POSIX::_exit(127);
    }
    kill $signal,$child if $signal;
    my $wait;do {$wait=waitpid($child,0)} while $wait==-1 && $!==EINTR;
    die "ERROR: cannot wait for managed runtime operation\n" if $wait!=$child;
    my $result=$?;
    $status=$result&127 ? 128+($result&127) : $result>>8;
    $status=128+$signal if $signal;
    1;
};$error=$@ if !$ok;
my $released=eval {P2T2C::Documents::release_lock($lock);1};$error.=$@ if !$released;
die $error if !$ok||!$released;
exit $status;
