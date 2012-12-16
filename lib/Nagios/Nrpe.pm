package Nagios::Nrpe;

use 5.010;
use strict;
use warnings;

use Moose;
use Cwd;
use Carp;
use autodie qw< :io >;
use Log::Log4perl;
use Log::Dispatch::Syslog;
use English qw< -no_match_vars >;
use Data::Dumper;

## no critic (return)
## no critic (POD)
## no critic (Quotes)
## no critic (ProhibitMagicNumbers)

our $VERSION = '0.006';


sub exit_ok
{
    my $self    = shift;
    my $message = shift // 'Unknown';
    my $stats   = shift // $self->exit_stats;

    $self->exit_code( $self->ok );
    $self->exit_message( $message );
    $self->exit_stats( $stats );
    $self->_exit;
};


sub exit_warning 
{
    my $self    = shift;
    my $message = shift // 'Unknown';
    my $stats   = shift // $self->exit_stats;

    $self->exit_code( $self->warning );
    $self->exit_message( $message );
    $self->exit_stats( $stats );
    $self->_exit;
};


sub exit_critical
{
    my $self    = shift;
    my $message = shift // 'Unknown';
    my $stats   = shift // $self->exit_stats;

    $self->exit_code( $self->critical );
    $self->exit_message( $message );
    $self->exit_stats( $stats );
    $self->_exit;
};


sub exit_unknown
{
    my $self    = shift;
    my $message = shift // 'Unknown';
    my $stats   = shift // $self->exit_stats;

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

    ( $code == $self->critical ) ?
      $self->log_error( 'Exit with status CRITICAL: ' . $message )
    : ( $code == $self->warning ) ?
      $self->log_warn( 'Exit with status WARNING: ' . $message )
    : ( $code == $self->ok ) ?
      $self->log_info( 'Exit with status OK: ' . $message )
    : $self->log_warn( 'Exit with status UNKNOWN: ' . $message );

    my $stats_str;

    if ( $self->exit_stats )
    {
        for my $key ( sort { $a cmp $b } keys %{ $self->exit_stats } )
        {
            $stats_str .= $key . '=' . $self->exit_stats->{ $key } . ';';
        }

        if ( $stats_str )
        {
            $stats_str =~ s/\R//xmsg;
        }
    }

    say ( ( $stats_str ) ? "$message|$stats_str" : $message );

    exit ( $code );
};


sub _load_logger
{
    my $self    = shift;

    Log::Log4perl->init( \$self->_log_config );

    my $logger = Log::Log4perl->get_logger();

    return $logger;
};


sub log_error
{
    my $self = shift;
    chomp ( my $message = shift // 'Unknown error' );

    $self->logger->error( $message );
};


sub log_warn
{
    my $self = shift;
    chomp ( my $message = shift // 'Unknown warn' );

    $self->logger->warn( $message );
};


sub log_info
{
    my $self = shift;
    chomp ( my $message = shift // 'Unknown info' );

    $self->logger->info( $message );
};


sub log_debug
{
    my $self = shift;
    chomp ( my $message = shift // 'Unknown debug' );

    $self->logger->debug( $message );
};


sub generate_check
{
    my $self       = shift;
    my $check_name = ( $self->check_name =~ m/\.pl$/xms ) ?
                       $self->check_name
                     : $self->check_name . '.pl';

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


sub _log_config
{
    my $self = shift;
    chomp ( my $check_name = $self->check_name // 'Nagios-Nrpe' );

    my $log_level = ( $self->log =~ m/^(:?off|error|warn|info|debug)$/xmsi ) ?
                      uc ( $self->log )
                    : croak 'Log level not supported, options are: '
                            . 'off, error, warn, info & debug';

    my $root_logger  = ( $log_level ne 'OFF' && $self->verbose ) ?
                         "$log_level, SYSLOG, SCREEN"
                       : ( $log_level eq 'OFF' && $self->verbose ) ?
                         'ALL, SCREEN'
                       : "$log_level, SYSLOG";

    my $log_config = <<'EOF';
    log4perl.rootLogger                = [% root_logger %]
    log4perl.appender.SCREEN           = Log::Log4perl::Appender::Screen
    log4perl.appender.SCREEN.stderr    = 0
    log4perl.appender.SCREEN.layout    = Log::Log4perl::Layout::PatternLayout
    log4perl.appender.SCREEN.layout.ConversionPattern = %d %p %m %n
    log4perl.appender.SYSLOG           = Log::Dispatch::Syslog
    log4perl.appender.SYSLOG.min_level = debug
    log4perl.appender.SYSLOG.ident     = [% check_name %]
    log4perl.appender.SYSLOG.facility  = daemon
    log4perl.appender.SYSLOG.layout    = Log::Log4perl::Layout::SimpleLayout
EOF

    $log_config =~ s/\[\%\s+root_logger\s+\%\]/$root_logger/xmsgi;
    $log_config =~ s/\[\%\s+check_name\s+\%\]/$check_name/xmsgi;

    return $log_config;
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
    my $nrpe    = Nagios::Nrpe->new( # log level (off,error,warn,info,debug)
                                     log        => 'off',
                                     # Set name of check for logging
                                     check_name => $0,
                                     # Print logging to stdout
                                     verbose    => $options->{verbose},
                                   );

    # INSERT YOUR CODE LOGIC HERE.
    # SEE: "perldoc Nagios::Nrpe" FOR MORE INFOMATION

    $nrpe->exit_ok( 'OK' );
};


__END__

INSERT YOUR DOCUMENTATION (POD) HERE.

EOF
};


has ok =>
(
    is      => 'ro',
    isa     => 'Int',
    default => sub { return 0 },
);


has warning =>
(
    is      => 'ro',
    isa     => 'Int',
    default => sub { return 1 },
);


has critical =>
(
    is      => 'ro',
    isa     => 'Int',
    default => sub { return 2 },
);


has unknown =>
(
    is      => 'ro',
    isa     => 'Int',
    default => sub { return 3 },
);


has exit_code =>
(
    is      => 'rw',
    isa     => 'Int',
    default => sub { return 3 },
);


has exit_message =>
(
    is      => 'rw',
    isa     => 'Str',
    default => sub { return 'Unknown' },
);


has exit_stats =>
(
    is      => 'rw',
    isa     => 'HashRef[Str]',
    default => sub { return { } },
);


has logger =>
(
    is      => 'ro',
    lazy    => 1,
    isa     => 'Object',
    default => \&_load_logger,
);


has log =>
(
    is      => 'ro',
    isa     => 'Str',
    default => sub { return 'off' },
);


has verbose =>
(
    is      => 'ro',
    isa     => 'Bool',
    default => sub { return 0 },
);


has check_name =>
(
    is   => 'ro',
    isa  => 'Str',
);


has check_path =>
(
    is      => 'ro',
    lazy    => 1,
    isa     => 'Str',
    default => sub { return getcwd },
);


1;


__END__

=pod

=head1 NAME

Nagios::Nrpe - Small module for creating & using NAGIOS NRPE checks.

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

version 0.006

=head1 SYNOPSIS

    # Example check script for yum package updates.
    use Nagios::Nrpe;

    my $nrpe = Nagios::Nrpe->new( verbose   => 1,
                                  log       => 'off', );

    $nrpe->log_info('Starting yum update notify check.');

    open ( my $fh, '-|', '/usr/bin/yum check-update' )
    || $nrpe->exit_warning('yum command failed');

        my $yum_info = { verbose => do { local $/; <$fh> } };

    close ( $fh );

    $nrpe->log_info('YUM: ' . $yum_info);

    my $exit_code = ( $? >> 8 );

    $nrpe->log_debug("YUM exit code: $exit_code");

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

When enabled will print log messages to stdout.
If log is also enabled, will only print out messages enabled by
the log setting. If log is disabled, will print all log levels to 
stdout.
Disabled by default.

=head2 log

    my $nrpe = Nagios::Nrpe->new( log => 'debug' );

log levels: off, error, warn, info, debug.
When enabled at the appropriate level, will log to syslog.
Disabled by default.

=head2 check_name

    my $nrpe = Nagios::Nrpe->new( check_name => 'example' );

Used for check script generation. See nagios_nrpe.pl
Also, when used within a NAGIOS NRPE check script this option
is used to set the script name for log messages.

=head2 check_path

    my $nrpe = Nagios::Nrpe->new( check_path => '/tmp' );

Used for check script generation. See nagios_nrpe.pl

=head1 SUBROUTINES/METHODS

=head2 exit_ok

    my $nrpe = Nagios::Nrpe->new();
    $nrpe->exit_ok( 'Looks good', \%stats );

Usage: Pass human readable message and then (optionally) nagios stats.
The stats param must be a hashref. If log is enabled, will log the exit call
at the INFO log level.
This call will exit the program with the desired exit code.

Returns: Exits with a nagios "ok" exit code.

=head2 exit_warning

    my $nrpe = Nagios::Nrpe->new();
    $nrpe->exit_warning( 'This landing is gonna get pretty interesting', \%stats );

Usage: Pass human readable message and then (optionally) nagios stats.
The stats param must be a hashref. If log is enabled, will log the exit call
at the WARN log level.
This call will exit the program with the desired exit code.

Returns: Exits with a nagios "warning" exit code.

=head2 exit_critical

    my $nrpe = Nagios::Nrpe->new();
    $nrpe->exit_critical( 'oh god, oh god, we're all going to die', \%stats );

Usage: Pass human readable message and then (optionally) nagios stats.
The stats param must be a hashref. If log is enabled, will log the exit call
at the ERROR log level.
This call will exit the program with the desired exit code.

Returns: Exits with a nagios "critical" exit code.

=head2 exit_unknown

    my $nrpe = Nagios::Nrpe->new();
    $nrpe->exit_unknown( 'I donno lol!' );

Usage: Pass human readable message and then (optionally) nagios stats.
The stats param must be a hashref. If log is enabled, will log the exit call
at the WARN log level.
This call will exit the program with the desired exit code.

Returns: Exits with a nagios "unknown" exit code.

=head2 log_error

    my $nrpe = Nagios::Nrpe->new();
    $nrpe->log_error( 'Insert error message here.' );

Usage: Error logging.
If verbose is on will print to stdout. If log is set to "error" or higher
will log to syslog.

NOTE: This will not exit your program. If you wish to log an error and exit
your program see "exit_critical" or "exit_warning" instead.

Returns: Nothing.

=head2 log_warn

    my $nrpe = Nagios::Nrpe->new();
    $nrpe->log_warn( 'Insert warn message here.' );

Usage: Warn logging.
If verbose is on will print to stdout. If log is set to "warn" or higher
will log to syslog.

TE: This will not exit your program. If you wish to log an error and exit
your program see "exit_critical" or "exit_warning" instead.

Returns: Nothing.

=head2 log_info

    my $nrpe = Nagios::Nrpe->new();
    $nrpe->log_info( 'Insert info message here.' );

Usage: Info logging.
If verbose is on will print to stdout. If log is set to "info" or higher
will log to syslog.

Returns: Nothing.

=head2 log_debug

    my $nrpe = Nagios::Nrpe->new();
    $nrpe->log_debug( 'Insert debug message here.' );

Usage: Debug logging.
If verbose is on will print to stdout. If log is set to "debug" will log to
syslog.

Returns: Nothing.

=head2 generate_check

    my $nrpe    = Nagios::Nrpe->new(  check_name => foo,
                                      check_path => '/tmp',
                                      verbose    => 0,
                                   );
    
    my $check_path = $nrpe->generate_check;

Usage: Generates a new NAGIOS NRPE check.

Returns: Path to newly created file.

=head2 _exit

    INTERNAL USE ONLY.

Usage: Creates a valid exit state for a NAGIOS NRPE check.
If log is enabled, will log exit message.

Returns: Exits the program. Do not pass go, do not collect $200.

=head2 _load_logger

    INTERNAL USE ONLY.

Usage: Inits the log4perl logger.

Returns: blessed ref

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
