#!/usr/bin/perl

# Koha sign off script
# Copyright (C) 2013 C & P Bibliography Services
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

=head1 SYNOPSIS

Building on the concepts of the sandbox, this script allows for users
sign off on patches in their git install by using a fixed toolbar at the
top of every page in Koha to get bug information and trigger the sign off.

In order to use this script, make it available via Apache/Plack/whatever
at /cgi-bin/koha/signoff.pl, and install WWW::Bugzilla and git-bz, then
copy the Javascript at the end of this file into intranetuserjs or
opacuserjs (but note that if you are using it via the OPAC you may need
special rewrite rules to handle it).

=head1 TODO

Make this script more asynchronous. At the moment everything is fully
synchronous, which makes it slow.

There is currently no authentication. As this script requires that the
user provide a login and password for Bugzilla, that is not as bad as it
sounds, but some sort of authentication would be good.

There is currently no mechanism for applying patches from Bugzilla, so
anything that is going to be signed off must be manually applied using
git-bz before this script can be used. The ability to apply patches off
Bugzilla would be very useful.

=cut

use Modern::Perl;
use Data::Dumper;
use CGI;
use JSON;
use WWW::Bugzilla;

my $query = CGI->new;
my $op    = $query->param('op');

my @log = `git log --reverse --pretty=oneline kc/master..HEAD 2>/dev/null`;
my @patches;

foreach (@log) {
    if (/([0-9a-f]*) (.*)$/) {
        push @patches, { 'commit' => $1, 'label' => $2 };
    }
}

my $name       = $query->param('name');
my $server     = "bugs.koha-community.org/bugzilla3/";
my $email      = $query->param('email');
my $password   = $query->param('password');
my $bug_number = $query->param('bug');

my $bz;
if ( $server && $email && $password && $bug_number ) {
    $bz = WWW::Bugzilla->new(
        server     => $server,
        email      => $email,
        password   => $password,
        bug_number => $bug_number
    );
}

print $query->header( -type => 'application/json' );
if ( $op eq 'retrieve' ) {
    my @attachments;
    my $summary = '';
    if ($bz) {
        @attachments = grep { $_->{'obsolete'} == 0 } $bz->list_attachments();
        $summary = $bz->summary;
    }
    print to_json(
        {
            'patches'     => \@patches,
            'attachments' => \@attachments,
            'summary'     => $summary
        }
    );
}
elsif ( $op eq 'signoff' ) {
    my @signoffs     = $query->param('signoff[]');
    my @obsolete     = $query->param('obsolete[]');
    my $signoff_list = join( ' ', @signoffs );

    my $output =
`git filter-branch -f --msg-filter 'cat - && ( echo "$signoff_list" | grep -q "\$GIT_COMMIT" && echo "Signed-off-by: $name <$email>" || true)' kc/master..HEAD 2>/dev/null`;

    @log = `git log --reverse --pretty=oneline kc/master..HEAD 2>/dev/null`;
    my @newpatches;
    foreach (@log) {
        if (/([0-9a-f]*) (.*)$/) {
            push @newpatches, { 'commit' => $1, 'label' => $2 };
        }
    }

    my @uploads;
    foreach my $signoff (@signoffs) {
        for my $patch ( 0 .. $#patches ) {
            if ( $signoff eq $patches[$patch]->{'commit'} ) {
                push @uploads, $newpatches[$patch];
            }
        }
    }

    if (@uploads) {
        my $diagnostics = '';
        foreach (@uploads) {
            $diagnostics .=
              `yes|git bz attach $bug_number $_->{'commit'} 2>/dev/null`;
        }

        foreach (@obsolete) {
            $bz->obsolete_attachment( 'id' => $_ );
        }
        eval {

         # This is sickening, but WWW::Bugzilla is rather limited and will not
         # accept custom statuses using the nice ->change_status() object method
            $bz->{'status'} = 'Signed Off';
            $bz->additional_comments(
"Patch tested and signoff automatically uploaded by $name <$email>"
            );
            $bz->commit;
        };
        if ($@) {
            print to_json(
                {
                    'error' => "Encountered errors changing Bugzilla status: $@"
                }
            );
        }
    }
    else {
        print to_json (
            { 'error' => 'No patches were selected for signoff.' } );
    }
    print to_json( { 'success' => '1' } );
}

__END__

This script is used with the following Javascript (for intranetuserjs or opacuserjs):

$(document).ready(function () {
    $('#doc3').after('<div class="navbar navbar-fixed-top" style="z-index: 10000;"> <div id="signoff-pane" class="navbar-inner"> <h4 style="float: left; margin-right: 2em;">Preview changes</h4> <ul class="nav" style="float: none;"> <li><img id="signoff-loading" style="margin-top: 8px; display: none;" src="/intranet-tmpl/prog/img/loading-small.gif"></li> <li><input type="text" id="bz-name" placeholder="Name" size="15" style="margin-top: 8px;"></li> <li><input type="text" id="bz-email" placeholder="E-mail (Bugzilla login)" size="15" style="margin-top: 8px;"></li> <li><input type="password" id="bz-password" placeholder="Bugzilla password" size="15" style="margin-top: 8px;"></li> <li><input type="text" id="bugno" placeholder="Bug no." size="6" style="margin-top: 8px;"></li> <li><button class="btn btn-small" id="retrieve-bug">Retrieve</button></li> </ul> <ul id="bug-retrieved" class="nav" style="float:none;"> </ul> </div> </div>');
    $('#bz-name').val($.cookie('bzname'));
    $('#bz-email').val($.cookie('bzemail'));
    $('body').style('margin-top: 40px;');
    $('#retrieve-bug').click(function () {
        signoff_ajax("retrieve", { }, function (data) {
            var patches = '';
            var attachments = '';
            for (var ii in data.patches) {
                patches = patches + '<li><a><label><input type="checkbox" class="patch-select" value="' + data.patches[ii].commit + '"/> ' + data.patches[ii].label + '</label></a></li>';
            }
            for (var ii in data.attachments) {
                attachments = attachments + '<li><a><label><input type="checkbox" class="obsolete-select" value="' + data.attachments[ii].id + '"/> ' + data.attachments[ii].name + '</label></a></li>';
            }
            $('#bug-retrieved').html('<li><div style="margin-top: 8px;">' + data.summary + '</div></li><li class="dropdown"><button class="btn btn-small dropdown-toggle" data-toggle="dropdown">Sign off <b class="caret"></b></button><ul class="dropdown-menu"><li><a><h5>Patches to sign off</h5></a></li>' + patches + '<li class="divider"></li><li><a><h5>Patches to obsolete</h5></a></li>' + attachments + '<li class="divider"></li><li><a href="#" id="submit-signoff" class="btn">Submit sign off</a></li></ul></li>');
            $('#submit-signoff').click(function () {
                var patches = [];
                var obsoletes = [];
                $('.patch-select:checked').each(function () {
                    patches.push($(this).val());
                });
                $('.obsolete-select:checked').each(function () {
                    obsoletes.push($(this).val());
                });
                signoff_ajax("signoff", { signoff: patches, obsolete: obsoletes }, function (data) {
                    $('#signoff-loading').hide();
                    alert(JSON.stringify(data));
                    $('#bug-retrieved').empty();
                });
            });
            if (data.summary.length > 0) {
                $('#bz-name').hide();
                $('#bz-email').hide();
                $('#bz-password').hide();
                $('#signoff-loading').hide();
                $.cookie('bzname', $('#bz-name').val());
                $.cookie('bzemail', $('#bz-email').val());
            }
        });
    });
});

function signoff_ajax(operation, submitdata, callback) {
    $('#signoff-loading').show();
    $.ajax({
        url: "/cgi-bin/koha/signoff.pl",
        dataType: "json",
        data: $.extend({
            op: operation,
            bug: $('#bugno').val(),
            name: $('#bz-name').val(),
            email: $('#bz-email').val(),
            password: $('#bz-password').val(),
            }, submitdata),
        success: callback
    });
}

