#!/usr/bin/perl

use strict;
use warnings;

use DBI;
use File::Basename qw(basename);
use Digest::CRC qw(crc32);

my $usage = "USAGE: $0 <bin/lib.so> <dbi:SQLite:dbname=file.sqlite> [login] [pass]";

my $bin = shift or die $usage;
my $dbi = shift or die $usage;
my $dbi_login = shift;
my $dbi_pass = shift;

my $dbh = DBI->connect($dbi, $dbi_login, $dbi_pass) or die "Unable to connect to db";

my $obj_cnt = 0;
my $sym_cnt = 0;
my $prov_cnt = 0;
my $dep_cnt = 0;

sub sym_add
{
    my $sym_name = shift;
    my $sym_crc = crc32($sym_name);
    my ($sym_id) = $dbh->selectrow_array("select id from symbols where crc = $sym_crc and name = '$sym_name'");
    unless ($sym_id)
    {
        $dbh->do("insert into symbols(name,crc) values('$sym_name',$sym_crc)");
        ($sym_id) = $dbh->selectrow_array("select id from symbols where crc = $sym_crc and name = '$sym_name'");    
        ++$sym_cnt;
    }
    return $sym_id;
}

my $prov_cache;
sub prov_add
{
    my $obj_id = shift;
    my $sym_id = shift;
    
    unless ($prov_cache->{$obj_id}->{$sym_id})
    {
        ++$prov_cache->{$obj_id}->{$sym_id};
        $dbh->do("insert into provides(object_id,symbol_id) values($obj_id,$sym_id)");
        ++$prov_cnt;
    }
}

my $dep_cache;
sub dep_add
{
    my $obj_id = shift;
    my $sym_id = shift;
    unless ($dep_cache->{$obj_id}->{$sym_id})
    {
        ++$dep_cache->{$obj_id}->{$sym_id};
        $dbh->do("insert into depends(object_id,symbol_id) values($obj_id,$sym_id)");
        ++$dep_cnt;
    }
}

$dbh->begin_work;
$dbh->{RaiseError} = 1;
eval {
    my $obj_name = basename($bin);
    my $obj_crc = crc32($obj_name);
    my ($obj_id) = $dbh->selectrow_array("select id from objects where crc = $obj_crc and name = '$obj_name'");
    unless ($obj_id)
    {
        $dbh->do("insert into objects(name,crc) values('$obj_name',$obj_crc)");
        ($obj_id) = $dbh->selectrow_array("select id from objects where crc = $obj_crc and name = '$obj_name'");
        ++$obj_cnt;
    }
    $dbh->do("delete from provides where object_id = $obj_id");
    $dbh->do("delete from depends where object_id = $obj_id");

    do {
        my $sym_id = sym_add($obj_name);
        prov_add($obj_id,$sym_id);
    };

    my $F;
    open $F, "arm-eabi-readelf -d $bin |";
    while(<$F>)
    {
        if(/library:\s+\[(.+?)\]/)
        {
            my $sym_id = sym_add($1);
            dep_add($obj_id,$sym_id);
        }
        if(/soname:\s+\[(.+?)\]/)
        {
            my $sym_id = sym_add($1);
            prov_add($obj_id,$sym_id);
        }
    }
};
$dbh->{RaiseError} = 0;
if ($@)
{
    print "error: $@\n";
    $dbh->rollback;
}
else
{
    $dbh->commit;
    print "added: $obj_cnt objects, $sym_cnt symbols, $dep_cnt dependencies, $prov_cnt providings\n";
}
