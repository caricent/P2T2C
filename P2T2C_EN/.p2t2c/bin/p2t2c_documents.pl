#!/usr/bin/env perl
use strict;
use warnings;
use File::Basename qw(dirname);
use Getopt::Long qw(GetOptionsFromArray Configure);
use JSON::PP ();

my $bin=dirname($0);unshift @INC,"$bin/../lib";
require P2T2C::DocumentActions;
my $JSON=JSON::PP->new->canonical(1)->utf8(1);
my $command=shift(@ARGV)//q();my %args;
Configure(qw(no_auto_abbrev no_ignore_case));
GetOptionsFromArray(\@ARGV,\%args,'id=s','proposal=s','spec=s','shape=s','risk=s','truth-ref=s','prepared=s','source-digest=s','record-digest=s','runtime=s','ready','json','help|h') or usage(2);
usage(0) if $args{help};usage(2) if @ARGV;
my %allowed=(create=>[qw(id spec shape risk truth-ref)],expand=>[qw(proposal prepared source-digest)],archive=>[qw(proposal spec record-digest)],validate=>[qw(proposal ready)],recover=>[qw(proposal)],compatibility=>[qw(runtime)]);
usage(2) if !exists $allowed{$command};
my %ok=map {$_=>1} (@{$allowed{$command}},'json');
usage(2) if grep {!$ok{$_}} keys %args;
$args{truth_ref}=delete $args{'truth-ref'} if exists $args{'truth-ref'};
$args{source_digest}=delete $args{'source-digest'} if exists $args{'source-digest'};
$args{record_digest}=delete $args{'record-digest'} if exists $args{'record-digest'};
my ($out,$status);
my $success=eval {
    if ($command eq 'compatibility') {
        P2T2C::DocumentActions::assert_runtime_compatible($args{runtime});
        $out={schema_version=>1,action=>'compatibility',state=>'compatible'};
    } else {
        no strict 'refs';$out=&{"P2T2C::DocumentActions::$command"}(%args);
    }
    1;
};
if ($success) {$status=0}
else {my $error=$@||'unknown document failure';$error=~s/[\r\n]+\z//;$out={schema_version=>1,action=>$command,state=>'blocked',error=>substr($error,0,4096)};$status=4}
print $JSON->encode($out),"\n";exit $status;

sub usage {
    my($status)=@_;print STDERR <<'HELP';
Usage:
  p2t2c create --id SP-YYYYMMDD-name [--shape standard|compact] [--risk R1|R2]
    [--spec NNN-name] [--truth-ref docs/sot/...md] [--json]
  p2t2c expand --proposal SP-YYYYMMDD-name --prepared DIR [--source-digest SHA256] [--json]
  p2t2c archive --proposal SP-YYYYMMDD-name [--record-digest SHA256] [--json]
  p2t2c archive --spec NNN-name [--record-digest SHA256] [--json]
  p2t2c validate-docs [--proposal SP-YYYYMMDD-name] [--ready] [--json]
  p2t2c recover --proposal SP-YYYYMMDD-name [--json]
  p2t2c compatibility --runtime RELEASE_ROOT [--json]
HELP
    exit $status;
}
