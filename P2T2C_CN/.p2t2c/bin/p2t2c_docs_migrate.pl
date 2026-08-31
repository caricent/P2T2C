#!/usr/bin/env perl
use strict;
use warnings;
use File::Basename qw(dirname);
use Getopt::Long qw(GetOptions);
use JSON::PP ();
my$bin=dirname$0;unshift@INC,"$bin/../lib";require P2T2C::DocsMigration;
my($dry,$apply,$rollback,$map,$json,$help)=(0,0,undef,undef,0,0);
GetOptions('dry-run'=>\$dry,'apply'=>\$apply,'rollback=s'=>\$rollback,'decision-map=s'=>\$map,'json'=>\$json,'help|h'=>\$help)or usage();
my$modes=($dry?1:0)+($apply?1:0)+(defined$rollback?1:0);usage()if$help||$modes!=1;
my$J=JSON::PP->new->canonical(1)->utf8(1);my($out,$status);my$ok=eval{$out=$dry?P2T2C::DocsMigration::dry_run(decision_map=>$map):$apply?P2T2C::DocsMigration::apply(decision_map=>$map):P2T2C::DocsMigration::rollback($rollback);$status=0;1};
if(!$ok){my$e=$@||'unknown migration failure';$e=~s/[\r\n]+\z//;$out={action=>'docs-migrate',status=>'blocked',error=>substr($e,0,2048)};$status=4}
print$J->encode($out),"\n";exit$status;
sub usage{print STDERR "Usage:\n  p2t2c docs-migrate --dry-run [--decision-map FILE] [--json]\n  p2t2c docs-migrate --apply [--decision-map FILE] [--json]\n  p2t2c docs-migrate --rollback .p2t2c/docs-migrate/ID/report.json [--json]\n";exit 2}
