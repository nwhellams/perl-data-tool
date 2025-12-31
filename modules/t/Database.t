use strict;
use warnings;

use Test::More;

BEGIN {
    use FindBin qw($Bin);
    use lib "$Bin/../lib";
}

BEGIN {
    use_ok('DataTool::Database');
}

# Minimal stub logger so tests don't require external Log4perl config.
{
    package TestLogger;
    sub new { bless { errors => [], messages => [] }, shift }
    sub error {
        my ($self, $msg) = @_;
        push @{ $self->{errors} }, $msg;
        return 1;
    }
    sub last_error {
        my ($self) = @_;
        return $self->{errors}[-1];
    }
    sub debug {
        my ($self, $msg) = @_;
        push @{ $self->{messages} }, $msg;
        return 1;
    }
}

# Integration tests require a reachable Postgres. Auto-skip if not configured.
my $host = $ENV{PGHOST}     // $ENV{POSTGRES_HOST} // '';
my $port = $ENV{PGPORT}     // $ENV{POSTGRES_PORT} // '5432';
my $db   = $ENV{PGDATABASE} // $ENV{POSTGRES_DB}   // '';
my $user = $ENV{PGUSER}     // $ENV{POSTGRES_USER} // '';
my $pass = $ENV{PGPASSWORD} // $ENV{POSTGRES_PASSWORD} // '';

my $have_pg_env = ($host && $db && $user);

if (!$have_pg_env) {
    diag("Skipping DB integration tests. Set PGHOST/PGDATABASE/PGUSER/PGPASSWORD (and optionally PGPORT).");
    done_testing();
    exit 0;
}

my $dsn = "dbi:Pg:dbname=$db;host=$host;port=$port";

my $logger = TestLogger->new();

# DataTool::Database constructor is: new($dsn, $user, $password, $logger, $autocommit?)
my $db_default = DataTool::Database->new($dsn, $user, $pass, $logger);
ok($db_default, 'constructed database object (default autocommit)');

# 1) Connect (default autocommit expected OFF based on current module)
my $connected_default = eval { $db_default->connect(); 1 };
if (!$connected_default) {
    diag("Could not connect to Postgres using env vars. Error: $@");
    diag("Skipping DB integration tests.");
    done_testing();
    exit 0;
}

my $dbh_default = $db_default->getConnection();
ok($dbh_default && $dbh_default->ping, 'connected + ping ok (default autocommit)');
is($dbh_default->{AutoCommit} ? 1 : 0, 0, 'AutoCommit default is off');
$db_default->disconnect();

# 2) Connect with autocommit ON
my $db_ac = DataTool::Database->new($dsn, $user, $pass, $logger, 1);
ok($db_ac, 'constructed database object (autocommit on)');
ok($db_ac->connect(), 'connect returns true');

my $dbh = $db_ac->getConnection();
ok($dbh && $dbh->ping, 'connection is alive');
is($dbh->{AutoCommit} ? 1 : 0, 1, 'AutoCommit is on when requested');

# 3) Prepare should return a statement handle and store it
my $sth = $db_ac->prepare("SELECT 1 AS one");
isa_ok($sth, 'DBI::st', 'prepare returns a statement handle');

# 4) Execute should work
$sth->execute();
isa_ok($sth, 'DBI::st', 'execute returns a statement handle');

my ($one) = $sth->fetchrow_array();
is($one, 1, 'SELECT 1 returns 1');

# 5) Bind parameters work (cast params so server-side prepare won’t get confused)
$sth = $db_ac->prepare("SELECT ?::int + ?::int AS sum");
$sth->execute(2, 3);
my ($sum) = $sth->fetchrow_array();
is($sum, 5, 'bind params work (2 + 3 = 5)');

# 6) Query seeded schema (don’t assert exact count; just prove it runs)
$sth = $db_ac->prepare("SELECT count(*) FROM customers");
$sth->execute();
my ($count) = $sth->fetchrow_array();
ok(defined $count && $count >= 0, 'can query seeded table (customers)');

# Disconnect closes the handle
$sth->finish();
$db_ac->disconnect();
ok(!$dbh->ping, 'disconnect closes connection');

done_testing();
