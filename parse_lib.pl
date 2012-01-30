#!/usr/bin/perl

use strict;
use warnings;

use DBI;
use File::Temp qw(tempdir);
use File::Basename qw(basename);
use Digest::CRC qw(crc32);

my $usage = "USAGE: $0 <lib.so> <dbi:SQLite:dbname=file.sqlite> [login] [pass]";

my $lib = shift or die $usage;
my $dbi = shift or die $usage;
my $dbi_login = shift;
my $dbi_pass = shift;

my $dbh = DBI->connect($dbi, $dbi_login, $dbi_pass) or die "Unable to connect to db";

my $dir = tempdir(CLEANUP => 1);

my $obj_cnt = 0;
my $sym_cnt = 0;

$dbh->begin_work;
$dbh->{RaiseError} = 1;
eval {
    my $obj_name = basename($lib);
    my $obj_crc = crc32($obj_name);
    my ($obj_id) = $dbh->selectrow_array("select id from objects where crc = $obj_crc and name = '$obj_name'");
    unless ($obj_id)
    {
        $dbh->do("insert into objects(name,crc) values('$obj_name',$obj_crc)");
        ($obj_id) = $dbh->selectrow_array("select id from objects where crc = $obj_crc and name = '$obj_name'");
        ++$obj_cnt;
    }
    $dbh->do("delete from object_symbol_provides where object_id = $obj_id");
    $dbh->do("delete from object_symbol_depends where object_id = $obj_id");

    my $sym_name = $obj_name;
    my $sym_crc = crc32($sym_name);
    my ($sym_id) = $dbh->selectrow_array("select id from symbols where crc = $sym_crc and name = '$sym_name'");
    unless ($sym_id)
    {
        $dbh->do("insert into symbols(name,crc) values('$sym_name',$sym_crc)");
        ($sym_id) = $dbh->selectrow_array("select id from symbols where crc = $sym_crc and name = '$sym_name'");    
        ++$sym_cnt;
    }
    $dbh->do("insert into object_symbol_provides(object_id,symbol_id) values($obj_id,$sym_id)");

    my $F;
    open $F, "arm-eabi-nm -D $lib |";
    while(<$F>)
    {
        if(/^(\S+)?\s+\S+\s+(\S+)/)
        {
            my $sym_defined = $1;
            $sym_name = $2;
            $sym_crc = crc32($sym_name);
            ($sym_id) = $dbh->selectrow_array("select id from symbols where crc = $sym_crc and name = '$sym_name'");
            unless ($sym_id)
            {
                $dbh->do("insert into symbols(name,crc) values('$sym_name',$sym_crc)");
                ($sym_id) = $dbh->selectrow_array("select id from symbols where crc = $sym_crc and name = '$sym_name'");    
                ++$sym_cnt;
            }
            if ($sym_defined)
            {
                $dbh->do("insert into object_symbol_provides(object_id,symbol_id) values($obj_id,$sym_id)");
            }
            else
            {
                $dbh->do("insert into object_symbol_depends(object_id,symbol_id) values($obj_id,$sym_id)");
            }
        }
    }
};
$dbh->{RaiseError} = 0;
if ($@)
{
    $dbh->rollback;
}
else
{
    $dbh->commit;
    print "$obj_cnt objects added, $sym_cnt symbols added\n";
}

