#!/usr/bin/perl

use strict;
use warnings;

use DBI;

my $usage = "USAGE: $0 <symbol-name/substring> <dbi:SQLite:dbname=file.sqlite> [login [pass]]";

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
        my $data2;
        my $row2;
        print "symbol $sym_name\n";
        $data2 = $dbh->selectall_arrayref("select name,id from depends,objects where objects.id = depends.object_id and symbol_id = $sym_id");
        print "required_by";
        foreach $row2 (@{$data2})
        {
            print " $row2->[0]";
        }
        print "\n";
        $data2 = $dbh->selectall_arrayref("select name,id from provides,objects where objects.id = provides.object_id and symbol_id = $sym_id");
        print "provided_by";
        foreach $row2 (@{$data2})
        {
            print " $row2->[0]";
        }
        print "\n";
    }
};
if ($@)
{
    print "error: $@";
}
$dbh->{RaiseError} = 0;
$dbh->rollback;
