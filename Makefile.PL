
use strict;
use warnings;

use 5.010;

use ExtUtils::MakeMaker 6.30;



my %WriteMakefileArgs = (
  "ABSTRACT" => "Small module for creating and using custom NAGIOS client side\nNRPE checks on linux hosts.",
  "AUTHOR" => "Sarah Fuller, <sarah at averna.id.au>",
  "BUILD_REQUIRES" => {
    "Test::More" => 0
  },
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => "6.30"
  },
  "DISTNAME" => "Nagios-Nrpe",
  "EXE_FILES" => [
    "bin/nagios_nrpe.pl"
  ],
  "LICENSE" => "perl",
  "NAME" => "Nagios::Nrpe",
  "PREREQ_PM" => {
    "Carp" => 0,
    "Cwd" => 0,
    "English" => 0,
    "Getopt::Long" => 0,
    "Log::Dispatch::Syslog" => 0,
    "Log::Log4perl" => 0,
    "Moo" => 0,
    "Pod::Usage" => 0,
    "autodie" => 0,
    "strict" => 0,
    "warnings" => 0
  },
  "VERSION" => "0.003",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


unless ( eval { ExtUtils::MakeMaker->VERSION(6.56) } ) {
  my $br = delete $WriteMakefileArgs{BUILD_REQUIRES};
  my $pp = $WriteMakefileArgs{PREREQ_PM};
  for my $mod ( keys %$br ) {
    if ( exists $pp->{$mod} ) {
      $pp->{$mod} = $br->{$mod} if $br->{$mod} > $pp->{$mod};
    }
    else {
      $pp->{$mod} = $br->{$mod};
    }
  }
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);



