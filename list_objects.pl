#!/usr/bin/perl

use strict;
use warnings;

use DBI;

my $usage = "USAGE: $0 <object-name/substring> <dbi:SQLite:dbname=file.sqlite> [login [pass]]";

my $name = shift; defined $name or die $usage;
my $dbi = shift or die $usage;
my $dbi_login = shift;
my $dbi_pass = shift;

my $dbh = DBI->connect($dbi, $dbi_login, $dbi_pass) or die "Unable to connect to db";

$dbh->begin_work;
$dbh->{RaiseError} = 1;
eval {
    my $data = $dbh->selectall_arrayref("select name,id from objects where name like '%$name%'");
    foreach my $row (@{$data})
    {
        my $obj_name = $row->[0];
        my $obj_id = $row->[1];
        my ($dep_cnt) = $dbh->selectrow_array("select count(*) from depends where object_id = $obj_id");
        my ($prov_cnt) = $dbh->selectrow_array("select count(*) from provides where object_id = $obj_id");
        print "$obj_name $dep_cnt dependencies $prov_cnt providings\n";
    }
};
if ($@)
{
    print "error: $@";
}
$dbh->{RaiseError} = 0;
$dbh->rollback;
