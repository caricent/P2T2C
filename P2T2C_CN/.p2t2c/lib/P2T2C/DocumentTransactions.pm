package P2T2C::DocumentTransactions;
use strict;
use warnings;
use Digest::SHA qw(sha256_hex);
use File::Basename qw(dirname basename);
use Fcntl qw(:mode);
use JSON::PP ();
use POSIX ();
use P2T2C::DocsMigration ();

my $JSON = JSON::PP->new->canonical(1)->utf8(1);
my $ROOT = '.p2t2c/documents';
my $HEX = qr/\A[0-9a-f]{64}\z/;

sub fail { die "ERROR: document transaction: $_[0]\n" }
sub fs { my ($name,@args)=@_; no strict 'refs'; return &{"P2T2C::DocsMigration::$name"}(@args) }
sub identity { my @s=@_; return [$s[0]+0,$s[1]+0] }
sub same_identity { my($a,$b)=@_; return ref($a) eq 'ARRAY' && ref($b) eq 'ARRAY' && @$a==2 && @$b==2 && $a->[0]==$b->[0] && $a->[1]==$b->[1] }
sub valid_id { fail('invalid proposal identity') if !defined($_[0]) || $_[0]!~/\ASP-[0-9]{8}-[a-z0-9]+(?:-[a-z0-9]+)*\z/; return $_[0] }
sub work_root { return "$ROOT/".valid_id($_[0]) }
sub exists_leaf { return -e $_[0] || -l $_[0] }

sub hook {
    my($stage)=@_;
    POSIX::_exit(91) if ($ENV{P2T2C_TEST_DOCUMENT_EXIT_AT}//q()) eq $stage;
    fail("injected failure at $stage") if ($ENV{P2T2C_TEST_DOCUMENT_FAIL_AT}//q()) eq $stage;
    if (($ENV{P2T2C_TEST_DOCUMENT_PAUSE_AT}//q()) eq $stage) {
        my $ms=$ENV{P2T2C_TEST_DOCUMENT_PAUSE_MS}//1000;
        fail('invalid document test pause') if $ms!~/\A[1-9][0-9]{0,3}\z/ || $ms>5000;
        print STDERR "P2T2C_TEST_MARKER:document_$stage\n";
        select undef,undef,undef,$ms/1000;
    }
}

sub save {
    my($dir,$r)=@_;
    fs('write_atomic',"$dir/journal.json",$JSON->encode($r)."\n",0600);
}

sub scope_paths {
    my($r)=@_;my $proposal="docs/proposals/$r->{proposal_id}.md";
    return [$proposal] if $r->{action} eq 'archive' || ($r->{action} eq 'create' && !defined($r->{specs_ref}));
    my $spec=$r->{specs_ref};
    fail('invalid transaction specs reference') if !defined($spec) || $spec!~m{\Adocs/specs/[0-9]{3,4}-[a-z0-9]+(?:-[a-z0-9]+)*\z};
    return ["$spec/design.md","$spec/tasks.md",$proposal];
}

sub validate {
    my($dir,$r)=@_;
    fail("invalid journal: $dir") if ref($r) ne 'HASH' || ($r->{schema_version}//0)!=1 || ($r->{action}//q())!~/\A(?:create|expand|archive)\z/;
    valid_id($r->{proposal_id});
    fail('invalid operation identity') if ($r->{operation_id}//q())!~/\A[0-9a-f]+-[0-9a-f]+-[0-9a-f]+\z/;
    fail('journal identity/path mismatch') if $dir ne work_root($r->{proposal_id})."/$r->{operation_id}";
    fail('invalid journal state') if ($r->{status}//q())!~/\A(?:prepared|applying|committed|rolled_back|conflict)\z/;
    my $paths=scope_paths($r);
    fail('invalid transaction entries') if ref($r->{entries}) ne 'ARRAY' || @{$r->{entries}}!=@$paths;
    for my $i (0..$#$paths) {
        my $e=$r->{entries}[$i];
        fail('transaction path/order mismatch') if ref($e) ne 'HASH' || ($e->{path}//q()) ne $paths->[$i];
        fail('invalid transaction digest') if ($e->{after_digest}//q())!~$HEX || (defined($e->{before_digest}) && $e->{before_digest}!~$HEX);
        fail('invalid transaction mode') if ($e->{mode}//q())!~/\A0[0-7]{3}\z/ || (oct($e->{mode}) & 0022);
        fail('invalid parent identity') if defined($e->{parent_identity}) && (ref($e->{parent_identity}) ne 'ARRAY' || @{$e->{parent_identity}}!=2);
        fail('existing document requires a parent identity') if defined($e->{before_digest}) && !defined($e->{parent_identity});
        fail('invalid before identity') if defined($e->{before_digest}) && ref($e->{before_identity}) ne 'ARRAY';
        fail('unexpected update in creation') if $r->{action} eq 'create' && defined($e->{before_digest});
        fail('unexpected update in expansion') if $r->{action} eq 'expand' && (($i==$#$paths) != defined($e->{before_digest}));
        fail('archive requires an existing record') if $r->{action} eq 'archive' && !defined($e->{before_digest});
        for my $which (qw(after before)) {
            next if !defined $e->{"${which}_digest"};
            next if $r->{status}=~/\A(?:committed|rolled_back)\z/ && $r->{cleanup_done} && !exists_leaf("$dir/$which-$i");
            my $raw=fs('read_raw',"$dir/$which-$i",0,'transaction image');
            fail("transaction image changed: $dir/$which-$i") if sha256_hex($raw) ne $e->{"${which}_digest"};
        }
    }
    return $r;
}

sub reports {
    my($id)=@_;return [] if !exists_leaf($ROOT);
    fs('check_dir',$ROOT,'document transactions');
    my @ids;
    if (defined $id) { push @ids,valid_id($id) }
    else { opendir(my $dh,$ROOT) or fail('cannot list document transactions'); @ids=sort grep {$_ ne '.' && $_ ne '..'} readdir $dh;closedir $dh }
    my @reports;
    for my $work (@ids) {
        my $base=work_root($work);next if !exists_leaf($base);
        fs('check_dir',$base,'work transactions');opendir(my $dh,$base) or fail('cannot list work transactions');
        my @ops=sort grep {$_ ne '.' && $_ ne '..'} readdir $dh;closedir $dh;
        for my $op (@ops) {
            fail('unsafe transaction operation') if $op!~/\A[0-9a-f]+-[0-9a-f]+-[0-9a-f]+\z/;
            my $dir="$base/$op";fs('check_dir',$dir,'operation');
            # Before the journal is published, only private staged images exist.
            next if !exists_leaf("$dir/journal.json");
            my $r=eval {$JSON->decode(fs('read_raw',"$dir/journal.json",0,'document journal'))};
            fail("unreadable document journal: $dir") if $@;
            validate($dir,$r);push @reports,[$dir,$r];
        }
    }
    return \@reports;
}

sub assert_no_pending {
    my($id)=@_;
    for my $pair (@{reports($id)}) {
        my($dir,$r)=@$pair;
        fail("unfinished $r->{action} for $r->{proposal_id}; retry that operation or recover --proposal $r->{proposal_id}: $dir")
            if $r->{status}!~/\A(?:committed|rolled_back)\z/ || ($r->{status} eq 'committed' && !$r->{cleanup_done});
    }
    return 1;
}

sub reserved_spec {
    my($id,$action)=@_;
    for my $pair (reverse @{reports($id)}) { my $r=$pair->[1];return $r->{specs_ref} if $r->{action} eq $action && defined $r->{specs_ref} }
    return;
}

sub names {
    my($r,$i)=@_;my $tag=sha256_hex($r->{entries}[$i]{path});
    my $prefix=".p2t2c-document-$r->{operation_id}-$tag";
    return ("$prefix-new","$prefix-original","$prefix-rollback");
}

sub in_parent {
    my($e,$code)=@_;
    return fs('in_directory',dirname($e->{path}),0,'document parent',sub {
        my @st=stat q(.);fail("document parent changed: $e->{path}") if !same_identity(identity(@st),$e->{parent_identity});
        return $code->();
    });
}

sub clean_temp {
    my($e,$tmp,$after)=@_;
    return if !exists_leaf($tmp);
    my $raw=fs('read_leaf',$tmp,0,'document temporary');my @st=lstat $tmp;
    if (ref($e->{candidate_identity}) eq 'ARRAY') {
        fail('temporary identity changed; preserved') if !same_identity(identity(@st),$e->{candidate_identity});
    } else {
        # An interrupted write may precede recording its inode. This reserved
        # operation/path name may only contain a prefix of the staged image.
        fail('unrecognized interrupted temporary; preserved') if length($raw)>length($after) || substr($after,0,length($raw)) ne $raw;
    }
    unlink $tmp or fail('cannot remove document temporary');
}

sub cleanup {
    my($dir,$r)=@_;
    for my $i (0..$#{$r->{entries}}) {
        my $e=$r->{entries}[$i];my($tmp,$guard,$rollback)=names($r,$i);
        my $after=fs('read_raw',"$dir/after-$i",0,'after image');
        in_parent($e,sub {
            clean_temp($e,$tmp,$after);
            if (exists_leaf($guard)) {
                my $raw=fs('read_leaf',$guard,0,'original guard');my @st=lstat $guard;
                fail('concurrent original edit preserved in guard') if !defined($e->{before_digest}) || sha256_hex($raw) ne $e->{before_digest} || !same_identity(identity(@st),$e->{before_identity});
                unlink $guard or fail('cannot clean original guard');
            }
            fail('rollback guard requires recovery') if exists_leaf($rollback);
            return 1;
        });
    }
    $r->{cleanup_done}=JSON::PP::true;save($dir,$r);purge_images($dir,$r);
}

sub purge_images {
    my($dir,$r)=@_;
    for my $i (0..$#{$r->{entries}}) {
        for my $which (qw(before after)) {
            next if !defined $r->{entries}[$i]{"${which}_digest"};
            fs('in_directory',$dir,0,'completed transaction',sub {
                my $leaf="$which-$i";return 1 if !exists_leaf($leaf);
                my $raw=fs('read_leaf',$leaf,0,'completed transaction image');
                fail('changed transaction image preserved') if sha256_hex($raw) ne $r->{entries}[$i]{"${which}_digest"};
                unlink $leaf or fail('cannot remove completed transaction image');return 1;
            });
        }
    }
}

sub rollback {
    my($dir,$r)=@_;
    my @states;
    # Check all visible records before removing or restoring any of them.
    for my $i (0..$#{$r->{entries}}) {
        my $e=$r->{entries}[$i];my($tmp,$guard,$removed)=names($r,$i);
        if (!defined $e->{parent_identity}) {
            fail("unfinished directory reservation requires inspection; preserved: ".dirname($e->{path})) if exists_leaf(dirname($e->{path}));
            push @states,{skip=>1};next;
        }
        my $state=in_parent($e,sub {
            my $leaf=basename($e->{path});my $result={};
            if (exists_leaf($removed)) {
                my $raw=fs('read_leaf',$removed,0,'rollback candidate');my @st=lstat $removed;
                fail("unrecognized rollback candidate: $e->{path}") if !same_identity(identity(@st),$e->{candidate_identity}) || sha256_hex($raw) ne $e->{after_digest};
                $result->{removed}=1;
            }
            if (exists_leaf($leaf)) {
                my $raw=fs('read_leaf',$leaf,0,'rollback target');my @st=lstat $leaf;
                if (defined($e->{before_digest}) && same_identity(identity(@st),$e->{before_identity})) { $result->{original}=1 }
                elsif (same_identity(identity(@st),$e->{candidate_identity}) && sha256_hex($raw) eq $e->{after_digest}) { $result->{candidate}=1 }
                else { fail("concurrent edit preserved; resolve $e->{path} using $dir") }
            }
            if (exists_leaf($guard)) {
                fs('read_leaf',$guard,0,'original guard');my @st=lstat $guard;
                fail('original guard identity changed') if !same_identity(identity(@st),$e->{before_identity});
                $result->{guard}=1;
            }
            fail("missing original record and guard: $e->{path}") if defined($e->{before_digest}) && !$result->{original} && !$result->{guard};
            return $result;
        });
        push @states,$state;
    }
    for my $i (reverse 0..$#{$r->{entries}}) {
        my $e=$r->{entries}[$i];my($tmp,$guard,$removed)=names($r,$i);my $state=$states[$i];
        next if $state->{skip};
        my $after=fs('read_raw',"$dir/after-$i",0,'after image');
        in_parent($e,sub {
            my $leaf=basename($e->{path});
            if ($state->{candidate}) {
                fail('rollback reservation already exists') if exists_leaf($removed);
                rename $leaf,$removed or fail('cannot reserve rollback candidate');
                my $raw=fs('read_leaf',$removed,0,'reserved rollback candidate');my @st=lstat $removed;
                if (!same_identity(identity(@st),$e->{candidate_identity}) || sha256_hex($raw) ne $e->{after_digest}) {
                    link $removed,$leaf if !exists_leaf($leaf);
                    fail("concurrent candidate preserved at $removed");
                }
                $state->{removed}=1;
            }
            if ($state->{guard} && !$state->{original}) {
                link $guard,$leaf or fail("concurrent target preserved; original at $guard");
                unlink $guard or fail('cannot detach restored guard');
            }
            if ($state->{removed}) { unlink $removed or fail('cannot remove rolled-back candidate') }
            clean_temp($e,$tmp,$after);return 1;
        });
    }
    $r->{status}='rolled_back';$r->{cleanup_done}=JSON::PP::true;save($dir,$r);purge_images($dir,$r);
    if (defined($r->{specs_ref}) && $r->{created_spec}) {
        my $spec=$r->{specs_ref};
        fs('in_directory',dirname($spec),0,'spec parent',sub { rmdir basename($spec) if -d basename($spec);return 1 });
    }
}

sub recover {
    my($id)=@_;my $count=0;
    for my $pair (@{reports($id)}) {
        my($dir,$r)=@$pair;
        next if $r->{status} eq 'rolled_back' || ($r->{status} eq 'committed' && $r->{cleanup_done});
        my $ok=eval { $r->{status} eq 'committed' ? cleanup($dir,$r) : rollback($dir,$r);1 };
        if (!$ok) { my $err=$@;$r->{status}='conflict' if $r->{status} ne 'committed';save($dir,$r);die $err }
        $count++;
    }
    return $count;
}

sub run {
    my(%a)=@_;valid_id($a{proposal_id});assert_no_pending($a{proposal_id});
    my $id=sprintf('%016x-%x-%08x',time,$$,int(rand(0xffffffff)));
    my $dir=work_root($a{proposal_id})."/$id";
    fs('ensure_dir',$dir);
    my $r={schema_version=>1,operation_id=>$id,proposal_id=>$a{proposal_id},action=>$a{action},status=>'prepared',cleanup_done=>JSON::PP::false,entries=>[]};
    $r->{specs_ref}=$a{specs_ref} if defined $a{specs_ref};
    my $paths=scope_paths($r);
    fail('wrong number of candidates') if @{$a{entries}}!=@$paths;
    for my $i (0..$#$paths) {
        my $input=$a{entries}[$i];fail('candidate path/order mismatch') if $input->{path} ne $paths->[$i];
        my $path=$input->{path};fs('check_existing_parent_prefix',$path);
        my $before=$input->{before};my $e={path=>$path,before_digest=>defined($before)?sha256_hex($before):undef,after_digest=>sha256_hex($input->{after}),mode=>'0644'};
        if (exists_leaf(dirname($path))) { fs('in_directory',dirname($path),0,'candidate parent',sub {
            my @parent=stat q(.);$e->{parent_identity}=identity(@parent);my $leaf=basename($path);
            if (defined $before) {
                my $raw=fs('read_leaf',$leaf,0,'candidate source');my @st=lstat $leaf;
                fail("source changed before transaction: $path") if sha256_hex($raw) ne $e->{before_digest};
                $e->{before_identity}=identity(@st);$e->{mode}=sprintf('%04o',$st[2]&07777);
            } else { fail("target already exists: $path") if exists_leaf($leaf) }
            return 1;
        }) } else {
            fail('an existing candidate parent is missing') if defined $before;
            fail('only a new spec directory may be created') if !defined($r->{specs_ref}) || dirname($path) ne $r->{specs_ref};
            $e->{parent_identity}=undef;
        }
        fs('write_new',"$dir/after-$i",$input->{after},0600);
        fs('write_new',"$dir/before-$i",$before,0600) if defined $before;
        push @{$r->{entries}},$e;
    }
    validate($dir,$r);save($dir,$r);hook('prepared');
    my $ok=eval {
        $r->{status}='applying';save($dir,$r);
        if (grep {!defined($_->{parent_identity})} @{$r->{entries}}) {
            my $spec=$r->{specs_ref};my $parent_id;
            fs('in_directory',dirname($spec),0,'spec allocation parent',sub {
                mkdir basename($spec),0755 or fail("spec directory already exists: $spec");
                my @st=lstat basename($spec);$parent_id=identity(@st);return 1;
            });
            $_->{parent_identity}=$parent_id for grep {!defined($_->{parent_identity})} @{$r->{entries}};
            $r->{created_spec}=JSON::PP::true;save($dir,$r);hook('after_directory');
        }
        for my $i (0..$#{$r->{entries}}) {
            my $e=$r->{entries}[$i];my($tmp,$guard,$removed)=names($r,$i);my $after=fs('read_raw',"$dir/after-$i",0,'after image');
            in_parent($e,sub {
                fail('reserved document file already exists') if exists_leaf($tmp)||exists_leaf($guard)||exists_leaf($removed);
                fs('write_leaf_new',$tmp,$after,oct($e->{mode}),'document temporary');
                my @st=lstat $tmp;$e->{candidate_identity}=identity(@st);return 1;
            });
            save($dir,$r);
            in_parent($e,sub {
                my $leaf=basename($e->{path});
                if (defined $e->{before_digest}) {
                    my $raw=fs('read_leaf',$leaf,0,'document source');my @st=lstat $leaf;
                    fail('document changed before replacement') if sha256_hex($raw) ne $e->{before_digest} || !same_identity(identity(@st),$e->{before_identity});
                    rename $leaf,$guard or fail('cannot reserve original document');hook('after_detach_'.($i+1));
                    fail('original changed during replacement') if sha256_hex(fs('read_leaf',$guard,0,'original guard')) ne $e->{before_digest};
                }
                link $tmp,$leaf or fail("concurrent target preserved: $e->{path}");
                unlink $tmp or fail('cannot detach document temporary');return 1;
            });
            hook('after_write_'.($i+1));
        }
        hook('before_commit');$a{validate}->();
        for my $i (0..$#{$r->{entries}}) {
            my $e=$r->{entries}[$i];my($tmp,$guard)=names($r,$i);
            in_parent($e,sub {
                my $leaf=basename($e->{path});my $raw=fs('read_leaf',$leaf,0,'published document');my @st=lstat $leaf;
                fail('published document changed before commit') if sha256_hex($raw) ne $e->{after_digest} || !same_identity(identity(@st),$e->{candidate_identity});
                fail('concurrent edit to original document') if defined($e->{before_digest}) && sha256_hex(fs('read_leaf',$guard,0,'original guard')) ne $e->{before_digest};
                return 1;
            });
        }
        $r->{status}='committed';save($dir,$r);hook('after_commit');cleanup($dir,$r);1;
    };
    if (!$ok) {
        my $error=$@;
        if ($r->{status} ne 'committed') {
            my $rolled=eval {rollback($dir,$r);1};
            if (!$rolled) {$error.=$@;$r->{status}='conflict';save($dir,$r)}
        }
        die $error;
    }
    return $dir;
}

1;
