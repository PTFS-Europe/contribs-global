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

use CGI;
use C4::Context;
use Template;
use Template::Constants qw( :debug );

my $query = CGI->new;
my $bugzilla=$query->param('bugzilla');
my $database = $query->param('database');
my $mailaddress= $query->param('mailaddress');
my $translations = $query->param('translations');

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
    open( sdbtmp, '>/tmp/sandbox');
    print sdbtmp $bugzilla.'|'.$database.'|'.$mailaddress."|".$translations."\n";
    close(sdbtmp);
    chmod 0666, "/tmp/sandbox";
    $templatevars->{done} = 1;
}
print $query->header();
$template->process("sandbox.tt",$templatevars);

