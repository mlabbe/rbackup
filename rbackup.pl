#!/usr/bin/perl -w


# Copyright (C) Frogtoss Games, Inc. 2003-2014

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see http://www.gnu.org/licenses/.


##
# Globals
my $config;

use constant VERSION => '1.5';

# Change log:
#
# 1.0 - Initial release
# 
# 1.01- MySQL dump added
#       Config file version mismatch now crashes
#
# 1.02- Rsync compress option added (not default)
#
#
# 1.1 - Remove all trailing slashes after directory names to 
#          fix a huge problem with rsync deleting everything 
#          in the repository
#       Back up own config option in the config file
#       Create a file called .lastbackuptime on remote 
#          machine with time stamp in it
#
# 1.2 - Added Subversion dumping
#
# 1.3 - Added multiple Subversion repositories
#
# 1.4 - Added remote mysql dumps
#
# 1.5 - Added multiple mysql dumps


sub GetConfigfile
{
    # The following places will be checked for the config file from top to bottom.
    my @configLocations = (
	'/etc/rbackup.conf',
      'c:\rbackup.conf',
      './rbackup.conf',
      '.\rbackup.conf',
      );

    foreach my $confloc ( @configLocations )
    {
        return $confloc if ( -e $confloc );
    }

    die "Could not find the config file.  Find a sample rbackup.conf, configure it and put it in the working directory.";
}

sub GetConfigContents
{
    my %config;

    my $configFile = GetConfigfile();
    open( CONFFILE, $configFile ) 
	or die "Could not read " . $configFile;
    my @dirList;
    while ( my $line = <CONFFILE> )
    {
        $line =~ s/\#.*//g; # Subtract comments
        $line =~ s/\r//g;
        chomp $line;

        # Store edicts in the hash directly
        $line =~ m!^(.+):\s+(.*)$!;
        if ( defined $1 and defined $2 )
        {
            $config{$1} = $2 unless ( $1 eq 'dirList' );
        } elsif ( length( $line ) > 0 )  # Push dirlist to the config file
        {
            # Remove any trailing whitespace from the dir
            $line =~ s/\s*$//g;
            # NEW v1.1 - Remove trailing '/'
            $line =~ s/\/+$//g;
            push( @dirList, $line );
        }
    }
    close( CONFFILE );

    $config{dirList} = \@dirList;

    return \%config;
}

# Write an rbackup error message.  Dies if $fatal == 1
sub WriteError
{
    my ( $msg, $fatal ) = shift;

    # Get a timestamp
    my @t = localtime( time() );  $t[5] += 1900;
    my $timestamp = "$t[3]/$t[4]/$t[5]:$t[2]:$t[1]:$t[0]";
    my $errorMsg = "[$timestamp] $msg\n";
    
    open( ERRORLOG, '>>' . $config->{errorlog} )
	or die "Could not open error log for appending.";

    print ERRORLOG $errorMsg;
    print STDERR $errorMsg;

    close( ERRORLOG );

    die() if ( defined $fatal and $fatal == 1 )
}

sub CheckDirectories
{
    my $dirList = $config->{dirList};
    
    foreach my $dir ( @$dirList )
    {
        next if ( $dir =~ m!\*! ); # We only check dirs

        unless ( -e $dir )
        {
            WriteError( "Directory $dir does not exist" );
        }
    }
}

sub BackupDirectories 
{
    my $dirList = $config->{dirList};

    my $compress = '';
    if ( $config->{rsynccompress} =~ m!1! )
    {
        $compress = '--compress';
        print "Rsync compression enabled.\n";
    }

    my $backupCount = 0;
    foreach my $dir ( @$dirList )
    {
        my $cmd = $config->{rsyncprogram} . 
            " --archive $compress --verbose --delete --rsh=" . $config->{remoteshell} . ' "' .
            $dir . '" ' .
            $config->{targetdir};

        sysex( $cmd );
        $backupCount++;
    }
	
    return $backupCount;
}

# Sysex is a system() wrapper that may log, depending on debugging state
sub sysex
{
    my $cmd = shift;

    print $cmd .  "\n";
    system( $cmd );
}

sub CheckConfigVersion
{
    if ( $config->{version} ne VERSION )
    {
        WriteError( "Config file for version " . $config->{version} . 
                    ", but this is rbackup " . VERSION, 1 );
        exit(1);
    }
}

sub PrintOutroMsg
{
    my $count = shift;

    print( "$count director(y|ies) backed up.\n" ); 
}

sub DumpMySQL
{
    return unless ( $config->{mysqldump} =~ m!yes!i );
    
    my $cmd = 
	$config->{'mysqldump.path'} . ' ' .
	'--user=' . $config->{'mysqldump.user'} . ' ' .
        '--host=' . $config->{'mysqldump.host'} . ' ' .
	'--password=' . $config->{'mysqldump.password'} . ' ' .
	'--all-databases ' .
	' > ' . $config->{'mysqldump.location'};

    sysex( $cmd );

    # 
    # As above, iterate through four more
    #
    my $num = 2;
    while ( $num <= 5 )
    {
        if ( exists $config->{"mysqldump$num"} and $config->{"mysqldump$num"} =~ m!yes!i )
        {
            my $cmd =
                $config->{"mysqldump$num.path"} . ' ' .
                '--user=' . $config->{"mysqldump$num.user"} . ' ' .
                '--host=' . $config->{"mysqldump$num.host"} . ' ' .
                '--password=' . $config->{"mysqldump$num.password"} . ' ' .
                '--all-databases ' .
                ' > ' . $config->{"mysqldump$num.location"};

            sysex( $cmd );
        }
	
        $num++;
    }
}

sub DumpSubversion
{
    my $cmd = 
      $config->{'svndump.path'} . ' ' .
      'dump ' .
      $config->{'svndump.repository'} . 
      ' > ' . $config->{'svndump.location'};

    if ( $config->{svndump} =~ m!yes!i ) 
    {
        sysex( $cmd );
    }

    #
    # As above, iterate through four more
    #
    my $num = 2;
    while ( $num <= 5 )
    {
        if ( exists $config->{"svndump$num"} and $config->{"svndump$num"} =~ m!yes!i )
        {
            my $cmd =
                $config->{"svndump$num.path"} . ' ' .
                'dump ' .
                $config->{"svndump$num.repository"} . 
                ' > ' . $config->{"svndump$num.location"};

            sysex( $cmd );

        }

        $num++;
    }
}

sub BackupConfigFile
{
    return if ( $config->{backupconfig} =~ m!no!i );

    my $configfile = GetConfigfile();

    my $cmd = $config->{rsyncprogram} .
	' --archive --compress --verbose --delete --rsh=' . $config->{remoteshell} . ' "' .
	$configfile . '" ' . $config->{targetdir};

    sysex( $cmd );
}

sub SyncLastbackupTime
{
    return if ( $config->{lastbackuptime} =~ m!no!i );

    if ( -e '.lastbackuptime' )
    {
        WriteError( ".lastbackuptime file exists already.  Maybe rbackup is already running?", 1 );
    }

    open( LASTBACKUP, ">.lastbackuptime" );
    print LASTBACKUP time();
    close( LASTBACKUP );
    
    my $cmd = $config->{rsyncprogram} .
        ' --archive --compress --verbose --delete --rsh=' . $config->{remoteshell} . 
        ' ".lastbackuptime" ' . $config->{targetdir};

    sysex( $cmd );

    unlink( '.lastbackuptime' );
}

#### 
# Begin main program

# Get parsed config file contents
$config = GetConfigContents();

# Make sure config file version is compatible with program version
CheckConfigVersion();

# Print warnings if directories don't exist
CheckDirectories();

# Dump MYSQL
DumpMySQL();

# Dump Subversion
DumpSubversion();

# Back up directories
my $backupCount = BackupDirectories();

# Back up own config file
BackupConfigFile();

# Back up a file called .lastbackuptime
SyncLastbackupTime();

# Print outro
PrintOutroMsg( $backupCount );

