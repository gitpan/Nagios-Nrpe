package Nagios::Nrpe;

use 5.010;
use strict;
use warnings;

use Moo;
# Works with Mo but one is deprived of attribute type checking.
#use Mo qw< is default >;
use Cwd;
use Carp;
use autodie qw< :io >;
use Log::Log4perl;
use Log::Dispatch::Syslog;
use English qw< -no_match_vars >;

## no critic (return)
## no critic (POD)
## no critic (Quotes)
## no critic (ProhibitMagicNumbers)

our $VERSION = '0.003';


sub exit_ok
{
    my $self    = shift;
    my $message = shift // 'Unknown';
    my $stats   = shift // '';

    $self->exit_code( $self->ok );
    $self->exit_message( $message );
    $self->exit_stats( $stats );
    $self->_exit;
};


sub exit_warning 
{
    my $self    = shift;
    my $message = shift // 'Unknown';
    my $stats   = shift // '';

    $self->exit_code( $self->warning );
    $self->exit_message( $message );
    $self->exit_stats( $stats );
    $self->_exit;
};


sub exit_critical
{
    my $self    = shift;
    my $message = shift // 'Unknown';
    my $stats   = shift // '';

    $self->exit_code( $self->critical );
    $self->exit_message( $message );
    $self->exit_stats( $stats );
    $self->_exit;
};


sub exit_unknown
{
    my $self    = shift;
    my $message = shift // 'Unknown';
    my $stats   = shift // '';

    $self->exit_code( $self->unknown );
    $self->exit_message( $message );
    $self->exit_stats( $stats );
    $self->_exit;
};


sub _exit
{
    my $self = shift;

    chomp ( my $code    = ( defined $self->exit_code ) 
            ? $self->exit_code 
            : $self->unknown
          );

    chomp ( my $message = ( defined $self->exit_message )
            ? $self->exit_message 
            : 'Unknown'
          );

    chomp ( my $stats   = ( defined $self->exit_stats ) 
            ? $self->exit_stats 
            : ''
          ); 


    say ( ( $stats =~ m/\w+/xmsi ) ? "$message|$stats" : "$message" );

    exit ( $code );
};


sub _load_logger
{
    my $self    = shift;

    my $config  = ( $self->verbose && $self->log ) ?
                   $self->_log_verbose
                  : ( ! $self->log && $self->verbose ) ?
                    $self->_log_stdout
                  : ( ! $self->log ) ?
                    $self->_log_disabled
                  : $self->_log_default;

    Log::Log4perl->init( \$config );

    my $logger = Log::Log4perl->get_logger();

    return $logger;
};


sub error
{
    my $self = shift;
    chomp ( my $message = shift // 'Unknown error' );

    $self->logger->error( $message );
    $self->exit_message( $message );
    $self->exit_code( $self->critical );
    $self->_exit;
};


sub info
{
    my $self = shift;
    chomp ( my $message = shift // 'Unknown info' );
    
    $self->logger->info( $message );
};


sub debug
{
    my $self = shift;
    chomp ( my $message = shift // 'Unknown debug' );

    $self->logger->debug( $message );
};


sub generate_check
{
    my $self       = shift;
    my $check_name = $self->check_name . '.pl';
    my $template   = $self->_template;
    my $check_path = $self->check_path;

    $check_path =~ s/(:?\/)+$//xms;
    $check_path .= '/' . $check_name;
    $template   =~ s/\[\%\s+check_name\s+\%\]/$check_name/xmsgi;

    croak "File $check_path already exists" if ( -e $check_path );

    open ( my $fh, '>',  $check_path )
    || croak "Failed to create check $check_path $ERRNO";

        print {$fh} $template;

    close ( $fh );

    return $check_path;
};


sub _log_default
{
    return <<'EOF';
log4perl.rootLogger                = DEBUG, SYSLOG
log4perl.appender.SYSLOG           = Log::Dispatch::Syslog
log4perl.appender.SYSLOG.min_level = debug
log4perl.appender.SYSLOG.ident     = Nagios::Nrpe
log4perl.appender.SYSLOG.facility  = daemon
log4perl.appender.SYSLOG.layout    = Log::Log4perl::Layout::SimpleLayout
EOF
};


sub _log_verbose
{
	return <<'EOF';
log4perl.rootLogger                = DEBUG, SYSLOG, SCREEN
log4perl.appender.SCREEN           = Log::Log4perl::Appender::Screen
log4perl.appender.SCREEN.stderr    = 0
log4perl.appender.SCREEN.layout    = Log::Log4perl::Layout::PatternLayout
log4perl.appender.SCREEN.layout.ConversionPattern = %d %p %m %n
log4perl.appender.SYSLOG           = Log::Dispatch::Syslog
log4perl.appender.SYSLOG.min_level = debug
log4perl.appender.SYSLOG.ident     = Nagios::Nrpe
log4perl.appender.SYSLOG.facility  = daemon
log4perl.appender.SYSLOG.layout    = Log::Log4perl::Layout::SimpleLayout
EOF
};


sub _log_stdout
{
	return <<'EOF';
log4perl.rootLogger              = DEBUG, SCREEN
log4perl.appender.SCREEN         = Log::Log4perl::Appender::Screen
log4perl.appender.SCREEN.stderr  = 0
log4perl.appender.SCREEN.layout  = Log::Log4perl::Layout::PatternLayout
log4perl.appender.SCREEN.layout.ConversionPattern = %d %p %m %n
EOF
};


sub _log_disabled
{
	return <<'EOF';
log4perl.rootLogger              = DEBUG, LOG1
log4perl.appender.LOG1           = Log::Log4perl::Appender::File
log4perl.appender.LOG1.filename  = /dev/null
log4perl.appender.LOG1.mode      = append
log4perl.appender.LOG1.layout    = Log::Log4perl::Layout::PatternLayout
log4perl.appender.LOG1.layout.ConversionPattern = %d %p %m %n
EOF
};


sub _template
{
	return <<'EOF';
#!/usr/bin/env perl
  
use 5.010;
use strict;
use warnings;
  
use Nagios::Nrpe;
use Getopt::Long;
use Pod::Usage;

## no critic (return)
## no critic (POD)

our $VERSION  = '0.003';

## Setup default options.
my $OPTIONS = { verbose => 0, }; 

# Accept options in from the command line.
GetOptions( $OPTIONS, 'verbose|v', 'help|h', 'man|m', );

# Basic command line options flag switch.
( $OPTIONS->{help} )     ? exit pod2usage( 1 ) 
: ( $OPTIONS->{man} )    ? exit pod2usage( -exitstatus => 0, -verbose => 2 )
:                          check( $OPTIONS );


sub check
{
    my $options = shift;
    my $nrpe    = Nagios::Nrpe->new( verbose => $options->{verbose}, log => 0 );

    # INSERT YOUR CODE LOGIC HERE.
    # SEE: perldoc Nagios::Nrpe FOR MORE INFOMATION

    $nrpe->exit_ok('OK');
};


__END__

INSERT YOUR POD HERE.

EOF
};


has ok =>
(
    is      => 'ro',
    isa     => sub {
                     croak "$_[0]: nagios ok exit code is 0"
                     if ( $_[0] ne '0' );
                   },
    default => sub { return 0 },
);


has warning =>
(
    is      => 'ro',
    isa     => sub {
                     croak "$_[0]: nagios warning exit code is 1"
                     if ( $_[0] ne '1' );
                   },
    default => sub { return 1 },
);


has critical =>
(
    is      => 'ro',
    isa     => sub {
                     croak "$_[0]: nagios critical exit code is 2"
                     if ( $_[0] ne '2' );
                   },
    default => sub { return 2 },
);


has unknown =>
(
    is      => 'ro',
    isa     => sub {
                     croak "$_[0]: nagios unknown exit code is 3"
                     if ( $_[0] ne '3');
                   },
    default => sub { return 3 },
);


has exit_code =>
(
    is  => 'rw',
    isa => sub {
                 croak "$_[0]: invalid nagios exit code"
                 if ( $_[0] !~ m/ ^ (?:0|1|2|3) $ /xms );
               },
);


has exit_message =>
(
    is  => 'rw',
    isa => sub {
                 croak "$_[0]: exit message is empty"
                 if ( $_[0] !~ m/\w+/xms );
               },
);


has exit_stats =>
(
    is  => 'rw',
    isa => sub {
                 croak "$_[0]: stats is undef"
                 if ( ! defined $_[0] );
               },
);


has logger =>
(
    is      => 'ro',
    lazy    => 1,
    isa     => sub {
                     croak "$_[0]: not a log4perl class" 
                     if ( ! $_[0]->isa('Log::Log4perl::Logger') );
                   },
    default => \&_load_logger,
);


has log =>
(
    is      => 'ro',
    isa     => sub {
                     croak "$_[0]: not a boolean"
                     if ( $_[0] !~ m/ ^ (?:0|1) $/xms );
                   },
    default => sub { return 0 },
);


has verbose =>
(
    is      => 'ro',
    isa     => sub {
                 croak "$_[0]: not a boolean" 
                 if ( $_[0] !~ m/ ^ (?:0|1) $/xms );
               },
    default => sub { return 0 },
);


has check_name =>
(
    is   => 'ro',
    lazy => 1,
    isa  => sub {
                 croak "$_[0]: invalid check name"
                 if ( $_[0] !~ m/ ^ \w+ $ /xms );
               },
);


has check_path =>
(
    is   => 'ro',
    lazy => 1,
    isa  => sub { croak "$_[0]: directory does not exist or can't write to"
                        . " directory" if ( ! -d $_[0] || ! -w $_[0] );
                },
    default => sub { return getcwd },
);


1;


__END__

=pod

=head1 NAME

Nagios::Nrpe - Small module for creating and using custom NAGIOS client side
NRPE checks on linux hosts.

=head1 DESCRIPTION

The main objective of this module is to allow one to rapidly create and use
new custom NAGIOS NRPE checks. This is done in two ways. Firstly, this module
allows one to create new check scripts on the fly. Secondly, the module gives
the user a number of necessary and/or commonly found features one might use in
NRPE checks. Thus removing much of the repetitive boilerplate when creating
new checks. Hopefully this is achieved in such a way as to avoid too many
dependencies. Finally, this over-engineered bit of code was dreamt up out of a
desire to have consistent ad hoc NAGIOS NRPE scripts. More effort to setup
than value added? Well...

=head1 VERSION

version 0.003

=head1 SYNOPSIS

    # Example check script for yum package updates.
    use Nagios::Nrpe;

    my $nrpe = Nagios::Nrpe->new( verbose => 0, log => 0, );

    $nrpe->info('Starting yum update notify check.');

    open ( my $fh, '-|', '/usr/bin/yum check-update' ) || $nrpe->error('yum failed');

        my $yum_info = { verbose => do { local $/; <$fh> } };

    close ( $fh );

    $nrpe->info('YUM: ' . $yum_info);

    my $exit_code = ( $? >> 8 );

    $nrpe->debug("YUM exit code: $exit_code");

    ( $exit_code == 0 ) ? $nrpe->exit_ok('OK')
    : ( $exit_code == 100 ) ? $nrpe->exit_warning('new updates available')
    : $nrpe->exit_unknown('unknown status');

=head2 Creating a new NRPE check

    perl nagios_nrpe.pl -name foo
    + file: /path/to/script/foo.pl

Creates a skeleton script for the new check.
The nagios_nrpe.pl script comes with this module.

=head1 OPTIONS

=head2 verbose

    my $nrpe = Nagios::Nrpe->new( verbose => 1 );

When enabled all info & debug messages will print to stdout.
If log is also turned on, will log syslog. Disabled by default.

=head2 log

    my $nrpe = Nagios::Nrpe->new( log => 1 );

When enabled all info & debug messages will log to syslog.
Disabled by default.

=head2 check_name

    my $nrpe = Nagios::Nrpe->new( check_name => 'example' );

Used for check script generation. See nagios_nrpe.pl

=head2 check_path

    my $nrpe = Nagios::Nrpe->new( check_path => '/tmp' );

Used for check script generation. See nagios_nrpe.pl

=head1 SUBROUTINES/METHODS

=head2 exit_ok

    my $nrpe = Nagios::Nrpe->new();
    $nrpe->exit_ok( 'Looks good', 'stat1=123;stat2=321;' );

Usage: Pass human readable message and then (optionally) nagios stats.
This call will exit the program with the desired exit code.

Returns: Exits with a nagios "ok" exit code.

=head2 exit_warning

    my $nrpe = Nagios::Nrpe->new();
    $nrpe->exit_ok( 'Looks interesting', 'stat1=123;stat2=321;' );

Usage: Pass human readable message and then (optionally) nagios stats.
This call will exit the program with the desired exit code.

Returns: Exits with a nagios "warning" exit code.

=head2 exit_critical

    my $nrpe = Nagios::Nrpe->new();
    $nrpe->exit_ok( 'oh god, oh god, we're all going to die', 'stat1=123;stat2=321;' );

Usage: Pass human readable message and then (optionally) nagios stats.
This call will exit the program with the desired exit code.

Returns: Exits with a nagios "critical" exit code.

=head2 exit_unknown

    my $nrpe = Nagios::Nrpe->new();
    $nrpe->exit_critical( 'I donno lol!' );

Usage: Pass human readable message and then (optionally) nagios stats.
This call will exit the program with the desired exit code.

Returns: Exits with a nagios "unknown" exit code.

=head2 error

    my $nrpe = Nagios::Nrpe->new();
    $nrpe->error( 'Not working, oh noes!' );

Usage: Error messaging.
If verbose is on will print to stdout. If log is on will log to
syslog. Please note, an error message call will cause the program to exit with
a critical nagios exit code.

Returns: exits program.

=head2 info

    my $nrpe = Nagios::Nrpe->new();
    $nrpe->info( 'Insert info message here.' );

Usage: Info messaging.
If verbose is on will print to stdout. If log is on will log to
syslog. 

Returns: Nothing.

=head2 debug

    my $nrpe = Nagios::Nrpe->new();
    $nrpe->debug( 'Insert debug message here.' );

Usage: Debug messaging.
If verbose is on will print to stdout. If log is on will log to
syslog. 

Returns: Nothing.

=head2 generate_check

    my $nrpe    = Nagios::Nrpe->new(  check_name => foo,
                                      check_path => '/tmp',
                                      verbose    => 1,
                                   );
    
    my $check_path = $nrpe->generate_check;

Usage: Generates a new NAGIOS NRPE check.

Returns: Path to newly created file.

=head2 _exit

    INTERNAL USE ONLY.

Usage: Creates a valid exit state for a NAGIOS NRPE check.

Returns: exits program. Do not pass go, do not collect $200.

=head2 _load_logger

    INTERNAL USE ONLY.

Usage: Inits the log4perl logger.

Returns: blessed ref

=head2 _log_default

    INTERNAL USE ONLY.

Returns: log4perl config.

=head2 _log_verbose

    INTERNAL USE ONLY.

Returns: log4perl config.

=head2 _log_stdout

    INTERNAL USE ONLY.

Returns: log4perl config.

=head2 _log_disabled

    INTERNAL USE ONLY.

Returns: log4perl config.

=head2 _template

    INTERNAL USE ONLY.

Returns: perl script template for new nagios nrpe check.

=head1 BUGS AND LIMITATIONS

Report bugs & issues, please email the author.

=head1 AUTHOR

Sarah Fuller, C<< <sarah at averna.id.au> >>

=head1 LICENSE AND COPYRIGHT

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

This software is copyright (c) 2012 by Sarah Fuller.

=cut
