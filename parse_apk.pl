#!/usr/bin/perl

use strict;
use warnings;

use DBI;
use File::Temp qw(tempdir);
use File::Basename qw(basename);
use Digest::CRC qw(crc32);
use XML::Parser;

my $usage = "USAGE: $0 <package.apk> <dbi:SQLite:dbname=file.sqlite> [login] [pass]";

my $apk = shift or die $usage;
my $dbi = shift or die $usage;
my $dbi_login = shift;
my $dbi_pass = shift;

my $dbh = DBI->connect($dbi, $dbi_login, $dbi_pass) or die "Unable to connect to db";

my $dir = tempdir(CLEANUP => 1);

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

sub xml_tree_parse
{
    my $xml_tree = shift;
    my $callbacks = shift;
    for (my $i = 0; $i < scalar @{$xml_tree}; $i+=2)
    {
        my $tag_name = $xml_tree->[$i];
        if ($tag_name)
        {
            my $tag_contents = $xml_tree->[$i+1];
            my $attrs = shift @{$tag_contents};
            my $inner_xml_tree = $tag_contents;

            if (exists($callbacks->{$tag_name}))
            {
                $callbacks->{$xml_tree->[$i]}->($attrs);
            }

            xml_tree_parse($inner_xml_tree, $callbacks);
        }
    }
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
    my $obj_name = basename($apk);
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
    
    my $F_zip;
    open $F_zip, "unzip -d $dir/apk $apk |";
    while (<$F_zip>)
    {
        if (/(\S+\.so)$/)
        {
            my $lib_name = basename($1);
            my $lib_id = add_sym($lib_name);
            prov_add($obj_id,$lib_id);
            ++$obj_cnt;
        }
    }
    
    my $F_xml;
    open $F_xml, "AXMLPrinter.sh $dir/apk/AndroidManifest.xml |";
    my $xml = XML::Parser->new(Style => 'Tree');
    my $xml_tree = $xml->parse($F_xml);
    my $pkg_name;
    my $activity_callback = sub {
        my $attrs = shift;
        
        my $name = $attrs->{'android:name'};
        if (substr($name,0,1) ne ".")
        {
            $name = "." . $name;
        }
        $name = $pkg_name . $name;
        my $sym_id = sym_add($name);
        prov_add($obj_id,$sym_id);
        
        if (exists($attrs->{'android:permission'}))
        {
            my $sym_id = sym_add($attrs->{'android:permission'});
            dep_add($obj_id,$sym_id);
        }
        
        if (exists($attrs->{'android:readPermission'}))
        {
            my $sym_id = sym_add($attrs->{'android:readPermission'});
            dep_add($obj_id,$sym_id);
        }
        
        if (exists($attrs->{'android:writePermission'}))
        {
            my $sym_id = sym_add($attrs->{'android:writePermission'});
            dep_add($obj_id,$sym_id);
        }
    };
    xml_tree_parse($xml_tree, {
        'manifest' => sub {
            my $attrs = shift;
            $pkg_name = $attrs->{'package'};
         },
        'permission' => sub {
            my $attrs = shift;
            my $sym_id = sym_add($attrs->{'android:name'});
            prov_add($obj_id,$sym_id);
        },
        'uses-permission' => sub {
            my $attrs = shift;
            my $sym_id = sym_add($attrs->{'android:name'});
            dep_add($obj_id,$sym_id);
        },
        'activity' => $activity_callback,
        'service' => $activity_callback,
        'receiver' => $activity_callback,
        'provider' => $activity_callback,
        });

    my $dex_file = "$dir/apk/classes.dex";
    unless (-e $dex_file)
    {
        my $odex_file = substr($apk,0,rindex($apk,".apk")) . ".odex";
        if (-e $odex_file)
        {
            $dex_file = "$dir/dex";
            system("baksmali.sh -x -o $dir/smali $odex_file 1>&2");
            system("smali.sh -o $dex_file $dir/smali 1>&2");
        }
        else
        {
            undef $dex_file;
        }
    }
    
    if ($dex_file)
    {
        my $jar_file = "$dir/jar";
        my $class_dir = "$dir/class";
        system("d2j-dex2jar.sh $dex_file -o $jar_file 1>&2");
        system("unzip -d $class_dir -q $jar_file 1>&2");
        my $F_java;
        open $F_java, "find $class_dir -type f -name '*.class' | xargs -L 1 jad.sh -p |";
        my $current_package_name = "";
        my %imports;
        my %packages;
        my %classes;
        while (<$F_java>)
        {
            if (/loadLibrary\(\"(.+?)\"\)/)
            {
                my $lib_name = "lib$1.so";
                my $lib_id = sym_add($lib_name);
                dep_add($obj_id,$lib_id);
            }
            if (/^import\s+(\S+);/)
            {
                my $target = $1;
                if (substr($target,length($target)-1,1) eq "*")
                {
                    $target = substr($target,0,length($target)-2);
                }
                ++$imports{$target};
            }
            if (/^package\s+(\S+);/)
            {
                $current_package_name = $1;
                ++$packages{$current_package_name};
            }
            if (/^\s*(?:public\s+)?(?:final\s+)?class\s+(\S+)/)
            {
                my $class_name = $1;
                my $full_class_name = "$current_package_name.$class_name";
                ++$classes{$full_class_name};
            }
        }
        # Apps are isolated, removig internal dependencies.
        foreach my $class (keys %classes)
        {
            #print "removed class $class\n";
            delete $imports{$class};
        }
        foreach my $package (keys %packages)
        {
            #print "removed package $package\n";
            delete $imports{$package};
        }
        foreach my $import (keys %imports)
        {
            #print "added import $import\n";
            my $sym_id = sym_add($import);
            dep_add($obj_id,$sym_id);
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
