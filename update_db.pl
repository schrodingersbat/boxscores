#!/usr/bin/perl

# updates database with latest information from box scores
# To keep DB up to date, run with scheduled tasks or chron daily

# we'll use some of the same subroutines for boootstrapping and updating
use save_to_db;
use DBI();
my $dbh = DBI->connect("DBI:mysql:database=boxes2014;host=localhost", 'boxer', 'boxer', {'RaiseError' => 1});
$dbh->{'dbh'}->{'PrintError'} = 1;
use XML::Simple;
my $xs = new XML::Simple(ForceArray => 1, KeepRoot => 1, KeyAttr => 'boxscore');
my $xsp = new XML::Simple(ForceArray => 1, KeepRoot => 1, KeyAttr => 'game');
use LWP;
my $browser = LWP::UserAgent->new; 

# to prevent partial loading of games in progress, only load a day's games
# after 12:00 PM GMT

my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) 
     = gmtime(time() - 60*60*36);
my $fmon = length($mon + 1) == 1 ? '0' . ($mon + 1) : ($mon + 1);
#my $fday = length($mday) == 1 ?  '0' . $mon : $mday;
my $fday = length($mday) == 1 ?  '0' . $mday : $mday;

# build base url for fetching box scores and start fetching
my $baseurl = 'http://gd2.mlb.com/components/game/mlb/year_' . (1900 + $year) .
    '/month_' . $fmon .
    '/day_' . $fday . '/';

# fetch names of all games played
my $response = $browser->get($baseurl);
die "Couldn't get $baseurl: ", $response->status_line, "\n"
    unless $response->is_success;
my $dirhtml = $response->content;

# now, load the box score for each game played that day
while($dirhtml =~ m/<a href=\"(gid_.+)\/\"/g ) {
    my $game = $1;
    print "fetching box score for game $game\n";
    my $boxurl = $baseurl . $game . "/boxscore.xml";
    my $response = $browser->get($boxurl);
    die "Couldn't get $boxurl: ", $response->status_line, "\n"
	unless $response->is_success;
    my $box = $xs->XMLin($response->content);
    save_batting_and_fielding($dbh, $box);
    save_pitching($dbh, $box);
    save_game($dbh, $box);

    my $playersurl = $baseurl . $game . "/players.xml";
    my $response = $browser->get($playersurl);
    die "Couldn't get $playersurl: ", $response->status_line, "\n"
	unless $response->is_success;
    my $roster = $xsp->XMLin($response->content);
    save_roster($dbh, $box, $roster);
}
