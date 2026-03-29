package Plugins::CDRipStatus::Plugin;

use strict;
use warnings;

use base qw(Slim::Plugin::OPMLBased);
use Slim::Utils::Log;
use Slim::Control::Request;

my $log = Slim::Utils::Log->addLogCategory({
    category => 'plugin.CDRipStatus',
    defaultLevel => 'ERROR',
    description => 'CDRipStatus Plugin',
});

sub initPlugin {
    my $class = shift;

    $log->error("Hello");

    Slim::Control::Request::addDispatch(
        ['cdripstatus', 'index'],
        [1, 0, 0, \&handleIndex]
    );

    $class->SUPER::initPlugin(
        feed   => \&menuHandler,
        tag    => 'cdripstatus',
        menu   => 'apps',
	is_app => 1,
        weight => 50,
    );
}

sub menuHandler {
    my ($client, $callback, $args) = @_;

    # Read status file
    my %data;
    if (open my $fh, '<', '/var/lib/squeezeboxserver/Plugins/CDRipStatus/autorip_status') {
        while (my $line = <$fh>) {
            chomp $line;
            if ($line =~ /^([^=]+)=(.*)$/) {
                $data{$1} = $2;
            }
        }
        close $fh;
    }

    # Extract values
    my $status        = $data{status} // 0;
    my $artist        = $data{artist} // 'Unknown';
    my $album         = $data{album} // 'Unknown';
    my $totalTracks   = $data{tracks} // 0;
    my $currentTrack  = $data{current_track} // 0;
    my $progress      = $data{disc_progress} // 0;

    my %statusText = (
        0 => 'Waiting for CD',
        1 => 'Getting ID',
        2 => 'Ripping CD',
    );

    my @menu = (
        { name => "Status: " . ($statusText{$status} || 'Unknown'), type => 'text', refresh => 1 },
    );

    if ($status == 2) {
        push @menu, (
            { name => "Artist: $artist", type => 'text', refresh => 1 },
            { name => "Album: $album", type => 'text', refresh => 1 },
            { name => "Total Tracks: $totalTracks", type => 'text', refresh => 1 },
        );

        if ($currentTrack == 0) {
            # Show disc scan progress instead of track progress
            push @menu, (
                { name => "Disc Scan: $progress%", type => 'text', refresh => 1 },
            );
        }
        else {
            # Normal track progress
            push @menu, (
                { name => "Track: $currentTrack / $totalTracks", type => 'text', refresh => 1 },
            );
        }
    }

    # Return the menu
    $callback->({
        items => \@menu
    });
}

sub getDisplayName {
    return 'CD Rip Status';
}

1;
