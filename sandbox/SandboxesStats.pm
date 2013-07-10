package SandboxesStats;

use Modern::Perl;
use DBI;

use YAML qw( LoadFile );

my $config_filepath = q|/home/koha/contrib/sandbox/config.yaml|;

my $conf = LoadFile( $config_filepath );


my $db_driver = $conf->{database}{driver} || q|mysql|;
my $db_name = $conf->{database}{name};
my $db_port = $conf->{database}{port} || 3306;
my $db_host = $conf->{database}{host};
my $db_user = $conf->{database}{user};
my $db_passwd = $conf->{database}{passwd};

my $dbh = DBI->connect(
    "DBI:$db_driver:dbname=$db_name;host=$db_host;port=$db_port",
    $db_user,
    $db_passwd,
    {'RaiseError' => $ENV{DEBUG}?1:0 }
) or die $DBI::errstr;

sub signoff {
    my ( $params ) = @_;
    my $name = $params->{name};
    my $email = $params->{email};
    my $bznumber = $params->{bznumber};
    my $host = $params->{host};
    $dbh->do(
        q|INSERT INTO stats(name, email, bznumber, action, host) values(?, ?, ?, 'signoff', ?)|,
        {},
        $name, $email, $bznumber, $host
    );
}

sub apply {
    my ( $params ) = @_;
    my $name = $params->{name};
    my $email = $params->{email};
    my $bznumber = $params->{bznumber};
    my $host = $params->{host};
    $dbh->do(
        q|INSERT INTO stats(name, email, bznumber, action, host) values(?, ?, ?, 'apply', ?)|,
        {},
        $name, $email, $bznumber, $host
    );
}

1;
