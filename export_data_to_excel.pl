#!/usr/bin/env perl
use strict;
use warnings;

# Modules
use Getopt::Long qw(GetOptions);
use Try::Tiny;
use Excel::Writer::XLSX;
use Log::Log4perl qw(get_logger :levels);

use FindBin qw($Bin);

use lib "$Bin/modules/lib"; # run locally
use lib "/app/modules/lib";
use DataTool::Database;

# Debug tool
#use Data::Dumper;

my $log_conf_base;
my $out_base;

if (-d "/app/" && $ENV{'RUNNING_IN_DOCKER'}) {
  $log_conf_base = "/app/conf";
  $out_base = "/app/out";
} else {
  $log_conf_base = "$Bin/conf";
  $out_base = "$Bin/out";
}

my $log_conf = "$log_conf_base/log4perl.conf";
my $logLevel = $INFO;

my $out   = "$out_base/payments_export.xlsx";
my $from  = undef;  # YYYY-MM-DD
my $to    = undef;  # YYYY-MM-DD
my $status = undef; # e.g. captured
my $debug = 0;

GetOptions(
  "out=s"    => \$out,
  "from=s"   => \$from,
  "to=s"     => \$to,
  "status=s" => \$status,
  "debug"    => \$debug,
) or die("Usage: $0 --out file.xlsx [--from YYYY-MM-DD] [--to YYYY-MM-DD] [--status captured] [--debug]\n");

for ($status, $from, $to) {
  $_ = undef if defined($_) && $_ eq '';
}

for my $date (['from', $from], ['to', $to]) {
  next unless defined $date->[1];
  die("--$date->[0] must be YYYY-MM-DD\n") unless $date->[1] =~ /^\d{4}-\d{2}-\d{2}$/;
}

if ($debug) {
  $log_conf = "$log_conf_base/log4perl_debug.conf";
  $logLevel = $DEBUG;
}

Log::Log4perl::init($log_conf);

my $logger = Log::Log4perl->get_logger();

$logger->level($logLevel);

# Connection via env vars (friendly for Docker, CI, prod, etc.)
my $pg_host = $ENV{PGHOST}     // "127.0.0.1";
my $pg_port = $ENV{PGPORT}     // "5432";
my $pg_db   = $ENV{PGDATABASE} // "demo";
my $pg_user = $ENV{PGUSER}     // "demo";
my $pg_pass = $ENV{PGPASSWORD} // "demo";

my $db = DataTool::Database->new(
  "dbi:Pg:dbname=$pg_db;host=$pg_host;port=$pg_port", 
  $pg_user, 
  $pg_pass, 
  $logger,
  1 # autocommit for export jobs is fine
);

$logger->debug("Connecting to database $pg_db at $pg_host:$pg_port as $pg_user...");

try {
  $db->connect();
} catch {
  $logger->logconfess("Database connection failed: " . $_);
};   
  
$logger->debug("Connected");

# Build a simple filtered query with placeholders.
# We’ll treat --to as inclusive end-of-day by adding 1 day and using < next_day.
my @where;
my @bind;

if (defined $status) {
  push @where, "p.status = ?";
  push @bind,  $status;
}

if (defined $from) {
  push @where, "p.created_at >= ?::date";
  push @bind,  $from;
}

if (defined $to) {
  push @where, "p.created_at < (?::date + interval '1 day')";
  push @bind,  $to;
}

my $where_sql = @where ? ("WHERE " . join(" AND ", @where)) : "";

my $sql = qq{
  SELECT
    p.payment_id,
    c.full_name,
    c.email,
    p.provider,
    (p.amount_pence::numeric / 100.0) AS amount,
    p.currency,
    p.status,
    to_char(p.created_at, 'YYYY-MM-DD HH24:MI:SSOF') AS created_at
  FROM payments p
  JOIN customers c ON c.customer_id = p.customer_id
  $where_sql
  ORDER BY p.created_at DESC
};

my ($sth, $workbook, $row_idx) = (undef, undef, 0);

try {
  $sth = $db->prepare($sql);
  $sth->execute(@bind);

  # Excel output
  $workbook  = Excel::Writer::XLSX->new($out)
    or $logger->logcroak("Could not create $out: $!");

  my $sheetname = "payments";
  my $worksheet = $workbook->add_worksheet($sheetname);

  my $fmt_header = $workbook->add_format(bold => 1);
  my $fmt_money  = $workbook->add_format(num_format => '0.00');

  my @headers = qw(
    payment_id full_name email provider amount currency status created_at
  );

  # Write header row
  for my $col (0 .. $#headers) {
    $worksheet->write(0, $col, $headers[$col], $fmt_header);
  }

  $worksheet->freeze_panes(1, 0);
  $worksheet->autofilter(0, 0, 0, $#headers);

  # Stream rows
  $row_idx = 1;
  my @max_len = map { length($_) } @headers;

  while (my $row = $sth->fetchrow_hashref) {
    my @values = @{$row}{@headers};

    for my $col (0 .. $#values) {
      my $val = $values[$col];

      # Track column width
      my $len = defined($val) ? length("$val") : 0;
      $max_len[$col] = $len if $len > $max_len[$col];

      # Amount gets numeric formatting
      if ($headers[$col] eq 'amount') {
        $worksheet->write_number($row_idx, $col, $val + 0, $fmt_money);
      } else {
        $worksheet->write($row_idx, $col, $val);
      }
    }

    $row_idx++;
  }

  # Basic autosize (rough)
  for my $col (0 .. $#headers) {
    my $width = $max_len[$col] + 2;
    $width = 12 if $width < 12;
    $width = 40 if $width > 40;
    $worksheet->set_column($col, $col, $width);
  }

  $logger->debug("Wrote worksheet $sheetname with $row_idx rows");
} catch {
  $logger->logconfess("Export failed: $_");
} finally {
  eval { $sth->finish() if $sth };
  eval { $db->disconnect() if $db };
  eval { $workbook->close() if $workbook };
};

$logger->info("Wrote $out ($row_idx rows incl header)");
