#!/usr/bin/env perl

use 5.010;
use strict;
use warnings;

use Cwd;
use Nagios::Nrpe;
use Getopt::Long;
use Pod::Usage;

## no critic (POD)

our $VERSION = '0.003';


## Setup default options.
my $OPTIONS = { verbose => 1, path => getcwd }; 

# Accept options in from the command line.
GetOptions( $OPTIONS, 
                      'name|n=s', 
                      'path|p=s', 
                      'verbose|v', 
                      'help|h',
                      'man|m', 
          );

# Basic command line options flag switch.
( $OPTIONS->{help} )     ? exit pod2usage( 1 )
: ( $OPTIONS->{man} )    ? exit pod2usage( -exitstatus => 0, -verbose => 2 )
: ( ! $OPTIONS->{name} ) ? exit pod2usage( 1 )
:                          generate_check( $OPTIONS );


sub generate_check
{
    my $options = shift;
    my $nrpe    = Nagios::Nrpe->new(  check_name => $options->{name}, 
                                      check_path => $options->{path},
                                      verbose    => $options->{verbose}, 
                                   );

    my $check_path = $nrpe->generate_check;

    say '+ file: ' . $check_path;

    return;
};


__END__

=pod

=head1 NAME

B<nagios_nrpe.pl> - Create custom NAGIOS NRPE client checks on the fly.

=head1 VERSION

version 0.003

=head1 SYNOPSIS

 nagios_nrpe.pl -n example_check

=head1 DESCRIPTION

This script is used to create new NAGIOS NRPE check scripts using the
Nagios::Nrpe module.

=head1 OPTIONS

=over 8

=item B<-n, --name>
 The name of the NAGIOS NRPE check script to be created.

=item B<-p, --path>
 Creation path. Default is current working directory.

=item B<-v, --verbose>
 Prints the error(s) found.

=item B<-h, --help>
 Prints a brief help message.

=item B<-m, --man>
 Prints the full manual page.

=back

=head1 AUTHOR

Sarah Fuller, C<< <sarah at averna.id.au> >>

=head1 LICENSE AND COPYRIGHT

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

This software is copyright (c) 2012 by Sarah Fuller.

=cut

