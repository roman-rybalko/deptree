#!/usr/bin/perl

use strict;
use warnings;

use DBI;
use File::Basename qw(basename);
use Digest::CRC qw(crc32);

my $usage = "USAGE: $0 <object.apk/jar/so> <dbi:SQLite:dbname=file.sqlite> [login] [pass]";

my $obj = shift or die $usage;
my $dbi = shift or die $usage;
my $dbi_login = shift;
my $dbi_pass = shift;

my $dbh = DBI->connect($dbi, $dbi_login, $dbi_pass) or die "Unable to connect to db";

my %obj_ids;

sub obj_upper
{
    my $obj_id = shift;
    my $data = $dbh->selectall_arrayref("select object_id from depends where symbol_id in (select symbol_id from provides where object_id = $obj_id)");
    my @obj_ids;
    foreach my $row (@{$data})
    {
        push @obj_ids => $row->[0];
    }
    return @obj_ids;
}

sub obj_lower
{
    my $obj_id = shift;
    my $data = $dbh->selectall_arrayref("select object_id from provides where symbol_id in (select symbol_id from depends where object_id = $obj_id)");
    my @obj_ids;
    foreach my $row (@{$data})
    {
        push @obj_ids => $row->[0];
    }
    return @obj_ids;
}

sub obj_remove
{
    my $obj_id = shift;
    
    if (exists($obj_ids{$obj_id}))
    {
        return;
    }
    
    $obj_ids{$obj_id} = 1;
    
    my @obj_ids;

    # upper objects in tree, obligatory (dependency is removed)
    foreach my $upper_obj_id (obj_upper($obj_id))
    {
        obj_remove($upper_obj_id);
    }
    
    # lower objects in tree, optional (may be are not needed)
    foreach my $lower_obj_id (obj_lower($obj_id))
    {
        my $remove_flag = 1;
        foreach my $upper_obj_id (obj_upper($lower_obj_id))
        {
            unless (exists($obj_ids{$upper_obj_id}))
            {
                $remove_flag = 0;
                last;
            }
        }
        if ($remove_flag)
        {
            obj_remove($lower_obj_id);
        }
    }
}

$dbh->begin_work;
$dbh->{RaiseError} = 1;
eval {
    my $obj_name = basename($obj);
    my $obj_crc = crc32($obj_name);
    my ($obj_id) = $dbh->selectrow_array("select id from objects where crc = $obj_crc and name = '$obj_name'");
    unless ($obj_id)
    {
        print "Unable to find object $obj_name crc=$obj_crc\n";
        exit 1;
    }
    
    obj_remove($obj_id);
    
    foreach $obj_id (keys %obj_ids)
    {
        my ($obj_name) = $dbh->selectrow_array("select name from objects where id = $obj_id");
        print "$obj_name\n";
    }
};
if ($@)
{
    print "error: $@";
}
$dbh->{RaiseError} = 0;
$dbh->rollback;

