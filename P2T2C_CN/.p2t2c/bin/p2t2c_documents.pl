#!/usr/bin/env perl
use strict;
use warnings;

use File::Basename qw(dirname);
use Getopt::Long qw(GetOptionsFromArray);
use JSON::PP ();

my$bin=dirname($0);unshift@INC,"$bin/../lib";require P2T2C::Documents;
my$JSON=JSON::PP->new->canonical(1)->utf8(1);
my$command=shift(@ARGV)//q();my($spec,$json,$help)=(undef,0,0);
GetOptionsFromArray(\@ARGV,'spec=s'=>\$spec,'json'=>\$json,'help|h'=>\$help)or usage();
usage()if$help||@ARGV||$command!~/\A(?:archive|validate)\z/;
my($out,$status);my$ok=eval{
    if($command eq'archive'){my$lock=P2T2C::Documents::acquire_lock();my$done=eval{P2T2C::Documents::assert_no_pending_migration();$out=P2T2C::Documents::archive_spec($spec);1};my$e=$@;
        my$released=eval{P2T2C::Documents::release_lock($lock);1};$e.=$@if!$released;die$e if!$done||!$released}
    else{P2T2C::Documents::validate_layout();$out={schema_version=>1,action=>'validate',state=>'valid'}}
    $status=0;1;
};
if(!$ok){my$e=$@||'unknown document failure';$e=~s/[\r\n]+\z//;$out={schema_version=>1,action=>$command,state=>'blocked',error=>substr($e,0,1024)};$status=4}
print$JSON->encode($out),"\n";exit$status;
sub usage{print STDERR "Usage:\n  p2t2c archive --spec NNN-name [--json]\n  p2t2c validate-docs [--json]\n";exit 2}
