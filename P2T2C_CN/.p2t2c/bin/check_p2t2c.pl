#!/usr/bin/env perl
use strict;
use warnings;
use File::Basename qw(dirname);
use File::Spec ();
use Getopt::Long qw(GetOptions);
my ($preclose,$no_cache,$help)=('',0,0);
GetOptions('pre-close-work-id=s'=>\$preclose,'no-cache'=>\$no_cache,'help|h'=>\$help)
    or do {print STDERR "ERROR: usage: check_p2t2c.sh [--pre-close-work-id ID] [--no-cache]\n";exit 2};
if ($help) {print "Usage: check_p2t2c.sh [--pre-close-work-id ID] [--no-cache]\n";exit 0}
if (@ARGV||($preclose ne ''&&$preclose!~/\A[A-Za-z0-9][A-Za-z0-9._-]*\z/)) {print STDERR "ERROR: usage: check_p2t2c.sh [--pre-close-work-id ID] [--no-cache]\n";exit 2}
my $bin=dirname(File::Spec->rel2abs($0));
unshift @INC,File::Spec->catdir(dirname($bin),'lib');
my $evidence=File::Spec->catfile($bin,'p2t2c_evidence.pl');
die "ERROR: missing or unsafe evidence core\n" if !-f$evidence||-l$evidence;
require $evidence;
require P2T2C::Checker;
my $checker=P2T2C::Checker->new(root=>'.',preclose=>$preclose,cache=>!$no_cache);
my $status=$checker->run();
print STDERR "WARNING: $_\n" for @{$checker->{warnings}};
print STDERR "ERROR: $_\n" for @{$checker->{errors}};
print $status==0?"P2T2C checks passed.\n":"P2T2C checks failed.\n";
exit $status;
