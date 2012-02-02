#!/usr/bin/perl

use strict;
use warnings;

use DBI;

my $usage = "USAGE: $0 <object-name/substring> <dbi:SQLite:dbname=file.sqlite> [login [pass]]";

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
        my $data2;
        my $row2;
        print "object $obj_name\n";
        $data2 = $dbh->selectall_arrayref("select name,id from depends,symbols where symbols.id = depends.symbol_id and object_id = $obj_id");
        print "depends_on_symbols";
        foreach $row2 (@{$data2})
        {
            print " $row2->[0]";
        }
        print "\n";
        $data2 = $dbh->selectall_arrayref("select name,id from provides,symbols where symbols.id = provides.symbol_id and object_id = $obj_id");
        print "provides_symbols";
        foreach $row2 (@{$data2})
        {
            print " $row2->[0]";
        }
        print "\n";
        $data2 = $dbh->selectall_arrayref("select name,id from depends,provides,objects where provides.symbol_id = depends.symbol_id and objects.id = provides.object_id and depends.object_id = $obj_id group by id");
        print "depends_on_objects";
        foreach $row2 (@{$data2})
        {
            print " $row2->[0]";
        }
        print "\n";
        $data2 = $dbh->selectall_arrayref("select name,id from provides,depends,objects where depends.symbol_id = provides.symbol_id and objects.id = depends.object_id and provides.object_id = $obj_id group by id");
        print "dependent_objects";
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
