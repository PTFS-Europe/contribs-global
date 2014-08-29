#!/usr/bin/perl

# Copyright BibLibre, 2012
#
# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 2 of the License, or (at your option) any later
# version.
#
# Koha is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with Koha; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

use Modern::Perl;
use CGI;
use Template;
use Template::Constants qw( :debug );
use List::MoreUtils qw ( uniq );
use YAML qw( LoadFile );

use C4::Context;

# This script display a webpage that the user can fill to request a sandbox with a patch applied, or signoff a patch previously applied
# If the user requested a sandbox, a file is written in /tmp/$tempfile, with bugzillanumber|the database to setup|the tester email|the translation requested
# If the user requested a signoff, a file is written in /tmp/$signoff with the bugzilla number|the tester email|the tester name

# Both /tmp/sandbox and /tmp/signoff are managed by a cronjob that is run every minute and delete them after setting the sandbox/signing-off the patch

my $config_filepath = $ENV{"KOHA_CONTRIB"} . "/sandbox/config.yaml";
my $conf = LoadFile( $config_filepath );
my $query          = CGI->new;

my $bugzilla       = $query->param('bugzilla');
my $database       = $query->param('database') || 0;
my $mailaddress    = $query->param('mailaddress');
my $name           = $query->param('name');
my $translations   = $query->param('translations');
my $signoff_email  = $query->param('signoff_email');
my $signoff_name   = $query->param('signoff_name');
my $signoff_number = $query->param('signoff_number');
my $tempfile = $conf->{sandbox}{tempfile};
my $signfile = $conf->{signoff}{tempfile};

my $template = Template->new();
my $templatevars;

my $dbh = C4::Context->dbh;
my $sth = $dbh->prepare('select title FROM opac_news WHERE title like "Sandbox setup%" ORDER BY idnew DESC LIMIT 1');
$sth->execute;
my ($lastcreated) = $sth->fetchrow;
$templatevars->{lastcreated} = $lastcreated;
if ($bugzilla && lc($query->param('koha')) eq 'koha') {
    # OK, we got the number, print the request on /tmp for the cronjob, after some security sanitizing
    # parameters should/must be numbers only
    unless ($bugzilla=~/\d*/ or $bugzilla eq 'master') { $bugzilla='' };
    unless ($database=~/\d*/) { $database = '' };
    open( my $sdbtmp, '>', "/tmp/$tempfile");
    print $sdbtmp $bugzilla.'|'.$database.'|'.$mailaddress."|".$name."|".$translations."\n";
    close($sdbtmp);
    chmod 0666, "/tmp/$tempfile";
    $templatevars->{done} = 1;
}
elsif ($signoff_number && $signoff_email && lc($query->param('koha')) eq 'koha') {
    # OK, we must signoff save a file with informations
    $templatevars->{signoff_needed} = 1;
    my ( $bz_applied, $applied_date );

    if ( $lastcreated =~ m|and bug \d+ on (\w+\s+\w+\s+\d+)\s+\d{2}:\d{2}:\d{2} \d{4}| ) {
        $applied_date = $1;
    }

    my $last_commit_msg = qx|git log --pretty=oneline -1|;
    if ( $last_commit_msg =~ m|^\S+\s+Bug (\d+)| ) {
        $bz_applied = $1;
    }
    if ( $bz_applied ) {
        my @datepcs = split( /\s+/, scalar(localtime) );
        my $applied_today = 0;
        if ( $applied_date =~ m|^$datepcs[0]\s+$datepcs[1]\s+$datepcs[2]$| ) {
            $applied_today = 1;
        }
        if ( $bz_applied == $signoff_number and $applied_today) {
            open( my $sdbtmp, '>', "/tmp/$signfile");
            print $sdbtmp $signoff_number.'|'.$signoff_email.'|'.($signoff_name?$signoff_name:$signoff_email);
            close($sdbtmp);
            chmod 0666, "/tmp/$signfile";
            $templatevars->{signoff_done} = 1;
        } else {
            unless ( $applied_today ) {
                $templatevars->{not_applied_today} = 1;
            }
            $templatevars->{bznumber_applied} = $bz_applied;
            $templatevars->{bznumber_needed} = $signoff_number;
            $templatevars->{signoff_done} = 0;
        }
    } else {
        $templatevars->{signoff_done} = 0;
        $templatevars->{no_patch_applied} = 1;
    }
}

opendir (my $dir, "misc/translator/po") or die $!;
my @languages;
while (my $filename = readdir($dir)) {
if ( $filename =~ s|(\w\w-\w\w).*|$1|) {
    push @languages, $filename;
}
}
close($dir);
@languages = uniq sort @languages;
$templatevars->{languages} = \@languages;

print $query->header();
$template->process("sandbox/templates/sandbox.tt",$templatevars);

