#!/usr/bin/perl

use strict;
use warnings;

use DBI;

my $usage = "USAGE: $0 <symbol-name/substring> <dbi:SQLite:dbname=file.sqlite> [login] [pass]";

my $sym = shift; defined $sym or die $usage;
my $dbi = shift or die $usage;
my $dbi_login = shift;
my $dbi_pass = shift;

my $dbh = DBI->connect($dbi, $dbi_login, $dbi_pass) or die "Unable to connect to db";

$dbh->begin_work;
$dbh->{RaiseError} = 1;
eval {
    my $data = $dbh->selectall_arrayref("select name,id from symbols where name like '%$sym%'");
    foreach my $row (@{$data})
    {
        my $sym_name = $row->[0];
        my $sym_id = $row->[1];
        print "$sym_name\n";
        my $data_dep = $dbh->selectall_arrayref("select name,id from depends,objects where objects.id = depends.object_id and symbol_id = $sym_id");
        print "required by:\n";
        foreach my $row_dep (@{$data_dep})
        {
            print "$row_dep->[0]\n";
        }
        my $data_prov = $dbh->selectall_arrayref("select name,id from provides,objects where objects.id = provides.object_id and symbol_id = $sym_id");
        print "provided by:\n";
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
