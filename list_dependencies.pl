#!/usr/bin/perl

use strict;
use warnings;

use DBI;

my $usage = "USAGE: $0 <object-name/substring> <dbi:SQLite:dbname=file.sqlite> [login] [pass]";

my $obj = shift; defined $obj or die $usage;
my $dbi = shift or die $usage;
my $dbi_login = shift;
my $dbi_pass = shift;

my $dbh = DBI->connect($dbi, $dbi_login, $dbi_pass) or die "Unable to connect to db";

$dbh->begin_work;
$dbh->{RaiseError} = 1;
eval {
    my $data = $dbh->selectall_arrayref("select name,id from objects where name like '%$obj%'");
    foreach my $row (@{$data})
    {
        my $obj_name = $row->[0];
        my $obj_id = $row->[1];
        print "$obj_name\n";
        my $data_dep = $dbh->selectall_arrayref("select name,id from depends,symbols where symbols.id = depends.symbol_id and object_id = $obj_id");
        print "depends:\n";
        foreach my $row_dep (@{$data_dep})
        {
            print "$row_dep->[0]\n";
        }
        my $data_prov = $dbh->selectall_arrayref("select name,id from provides,symbols where symbols.id = provides.symbol_id and object_id = $obj_id");
        print "provides:\n";
        foreach my $row_prov (@{$data_prov})
        {
            print "$row_prov->[0]\n";
        }
    }
};
if ($@)
{
    print "error: $@";
}
$dbh->{RaiseError} = 0;
$dbh->rollback;
