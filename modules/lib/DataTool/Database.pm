package DataTool::Database;

	use strict;
	use warnings;
	use namespace::autoclean;
	use Try::Tiny;
	use DBI;
	use DBIx::Log4perl;

	$DataTool::Database::VERSION = '0.1';


=head1 NAME

DataTool::Database - database connection handler for DataTool

=head1 SYNOPSIS

Provides some basic functions to connect to a database
	...
=cut 

=head2 new

Creates a new Database object

=cut

	sub new
	{
		my $class = shift;
		my $driver = shift;
		my $db_user = shift;
		my $db_password = shift;
		my $log_object = shift;
		my $autocommit = shift || 0; # default to no autocommit

		my $self = {
			driver	     => $driver,
			db_user      => $db_user,
			db_password  => $db_password,
			log_object   => $log_object,
			autocommit   => $autocommit,
			error		 => undef,
		};
			
		bless $self, $class;
		return $self;
	}

=head2 connect

	Connects to the database using the provided credentials

=cut

	sub connect
	{
		my $this = shift;

		my $attr = {
					  RaiseError => 1, # Make database errors fatal to script
					  AutoCommit => $this->{'autocommit'},
					  PrintError => 0, # We handle errors via RaiseError
				  };

		if ($this->{'driver'} =~ /^dbi:Pg:/) {
			# PostgreSQL specific attributes
			$attr->{pg_enable_utf8} = 1; # Enable UTF-8 support
		}

		$this->{'log_object'}->debug("Connecting to database with driver " . $this->{'driver'});

		$this->{'log_object'}->debug("DBI attributes: " . join(", ", map { "$_ => " . $attr->{$_} } keys %$attr));

		try { 
			$this->{'connection'} = DBIx::Log4perl->connect(
				$this->{'driver'},
				$this->{'db_user'}, 
				$this->{'db_password'}, 
				$attr);
		} catch {
			$this->throwError('Connection to database failed! : ' . $_);
			die($_);	
		};

		return 1;
	}

=head2 throwError

Logs an error message to the log object

=cut
	sub throwError
	{
		my $this  = shift;
		my $error = shift;

		$this->{'error'} = $error;

		if (defined $this->{'log_object'}) {
			$this->{'log_object'}->error($error);
		} else {
			warn $error;
		}
	}

=head2 getError

Returns the last error message logged

=cut

	sub getError
	{
		my $this  = shift;
			
		return $this->{'error'};
	}

=head2 prepare

Prepares an SQL statement for execution

=cut

	sub prepare
	{
		my $this  = shift;
		my $sql   = shift;

		try { 
			$this->{'statement'} = $this->{'connection'}->prepare($sql);
		} catch {
			$this->throwError('prepare SQL query failed! : ' . $_);
			die($_);	
		};

		return $this->{'statement'};
	}

=head2 disconnect

Disconnect from the database

=cut

	sub disconnect
	{
		my $this  = shift;

		$this->{'connection'}->disconnect();
	}

	return 1;