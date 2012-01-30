#!/usr/bin/perl

use strict;
use warnings;

use DBI;
use File::Temp qw(tempdir);
use File::Basename qw(basename);
use Digest::CRC qw(crc32);

my $usage = "USAGE: $0 <package.apk> <dbi:SQLite:dbname=file.sqlite> [login] [pass]";

my $apk = shift or die $usage;
my $dbi = shift or die $usage;
my $dbi_login = shift;
my $dbi_pass = shift;

my $dbh = DBI->connect($dbi, $dbi_login, $dbi_pass) or die "Unable to connect to db";

my $dir = tempdir(CLEANUP => 1);

my @libs;
system("d2j-dex2jar.sh $apk -o $dir/apk.jar 1>&2");
system("unzip $dir/apk.jar -d $dir 1>&2");
system("find $dir -type f -name '*.class' | xargs jad -r -s .java -d $dir 1>&2");
my $F;
open $F, "find $dir -type f -name '*.java' | xargs grep -e System.loadLibrary |";
while(<$F>)
{
    if (/loadLibrary\(\"(.+?)\"\)/)
    {
        push @libs => "lib$1.so";
    }
}

my $obj_cnt = 0;

$dbh->{AutoCommit} = 0;
$dbh->{RaiseError} = 1;
eval {
    my $obj_name = basename($apk);
    my $obj_crc = crc32($obj_name);
    my ($obj_id) = $dbh->selectrow_array("select id from objects where crc = $obj_crc and name = '$obj_name'");
    unless ($obj_id)
    {
        $dbh->do("insert into objects(name,crc) values('$obj_name',$obj_crc)");
        ($obj_id) = $dbh->selectrow_array("select id from objects where crc = $obj_crc and name = '$obj_name'");
        ++$obj_cnt;
    }

    foreach my $lib (@libs)
    {
        my $lib_name = $lib;
        my $lib_crc = crc32($lib_name);
        my ($lib_id) = $dbh->selectrow_array("select id from objects where crc = $lib_crc and name = '$lib_name'");
        unless ($lib_id)
        {
            $dbh->do("insert into objects(name,crc) values('$lib_name',$lib_crc)");
            ($lib_id) = $dbh->selectrow_array("select id from objects where crc = $lib_crc and name = '$lib_name'");    
            ++$obj_cnt;
        }
        $dbh->do("delete from object_depends where id = $obj_id");
        $dbh->do("insert into object_depends(id,dep_id) values($obj_id,$lib_id)");
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
    print "$obj_cnt objects added\n";
}
