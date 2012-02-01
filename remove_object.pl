#!/usr/bin/perl

use strict;
use warnings;

use DBI;
use File::Basename qw(basename);
use Digest::CRC qw(crc32);
use constant {
    REMOVE_REASON_DEPENDENCY => 1,
    REMOVE_REASON_NOT_NEEDED => 2,
};

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
    my $data = $dbh->selectall_arrayref("select object_id from depends where symbol_id in (select symbol_id from provides where object_id = $obj_id) group by object_id");
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
    my $data = $dbh->selectall_arrayref("select object_id from provides where symbol_id in (select symbol_id from depends where object_id = $obj_id) group by object_id");
    my @obj_ids;
    foreach my $row (@{$data})
    {
        push @obj_ids => $row->[0];
    }
    return @obj_ids;
}

sub obj_remove_upper
{
    my $obj_id = shift;
    
    if (exists $obj_ids{$obj_id})
    {
        return;
    }
    
    $obj_ids{$obj_id} = REMOVE_REASON_DEPENDENCY;
    
    foreach my $upper_obj_id_obj_id (obj_upper($obj_id))
    {
        obj_remove_upper($upper_obj_id_obj_id);
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
    
    obj_remove_upper($obj_id);
    
    my %check_obj_ids = %obj_ids;
    while (%check_obj_ids)
    {
        my %remove_obj_ids;
        foreach $obj_id (keys %check_obj_ids)
        {
            foreach my $lower_obj_id (obj_lower($obj_id))
            {
                if (exists $obj_ids{$lower_obj_id})
                {
                    next;
                }
                my $remove_flag = 1;
                foreach my $upper_obj_id (obj_upper($lower_obj_id))
                {
                    if (! exists $obj_ids{$upper_obj_id})
                    {
                        $remove_flag = 0;
                        last;
                    }
                }
                if ($remove_flag)
                {
                    $remove_obj_ids{$lower_obj_id} = REMOVE_REASON_NOT_NEEDED;
                }
            }
        }
        foreach my $remove_obj_id (keys %remove_obj_ids)
        {
            $obj_ids{$remove_obj_id} = $remove_obj_ids{$remove_obj_id};
        }
        %check_obj_ids = %remove_obj_ids;
    }
    
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
