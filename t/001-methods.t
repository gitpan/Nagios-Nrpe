use Test::More tests => 15;

BEGIN { use_ok( 'Nagios::Nrpe' ); }

my $object = Nagios::Nrpe->new ();
isa_ok ($object, 'Nagios::Nrpe');

$stdout=qx{ perl -Ilib -e "use Nagios::Nrpe;
Nagios::Nrpe->new()->exit_ok('good');" };
$exit=$? >> 8;
is ($exit, '0', "Ok exit");

$stdout=qx{ perl -Ilib -e "use Nagios::Nrpe;
Nagios::Nrpe->new()->exit_warning('not so good');" };
$exit=$? >> 8;
is ($exit, '1', "Warning exit");

$stdout=qx{ perl -Ilib -e "use Nagios::Nrpe;
Nagios::Nrpe->new()->exit_critical('opps');" };
$exit=$? >> 8;
is ($exit, '2', "Critical exit");

$stdout=qx{ perl -Ilib -e "use Nagios::Nrpe;
Nagios::Nrpe->new()->exit_unknown('I donno lol');" };
$exit=$? >> 8;
is ($exit, '3', "Unknown exit");

$stdout=qx{ perl -Ilib -e "use Nagios::Nrpe; Nagios::Nrpe->new()->_exit;" };
$exit=$? >> 8;
is ($exit, '3', "Default exit");

$stdout=qx{  perl -Ilib -e "use Nagios::Nrpe; print Nagios::Nrpe->new( 
)->verbose;" };
is ($stdout, '0', "Default verbose");

$stdout=qx{  perl -Ilib -e "use Nagios::Nrpe; print Nagios::Nrpe->new( 
 verbose => 1 )->verbose;" };
is ($stdout, '1', "Enable verbose");

$stdout=qx{  perl -Ilib -e "use Nagios::Nrpe; print Nagios::Nrpe->new( 
log => 'error' )->log_error('test');" };
$exit=$? >> 8;
is ($exit, '0', "Error log");

$stdout=qx{  perl -Ilib -e "use Nagios::Nrpe; print Nagios::Nrpe->new( 
log => 'warn' )->log_warn('test');" };
$exit=$? >> 8;
is ($exit, '0', "Warn log");

$stdout=qx{  perl -Ilib -e "use Nagios::Nrpe; print Nagios::Nrpe->new( 
 log => 'info' )->log_info('test');" };
$exit=$? >> 8;
is ($exit, '0', "Info log");

$stdout=qx{  perl -Ilib -e "use Nagios::Nrpe; print Nagios::Nrpe->new( 
 log => 'debug' )->log_debug('test');" };
$exit=$? >> 8;
is ($exit, '0', "Debug log");

$stdout=qx{ perl -Ilib -e "use Nagios::Nrpe; print Nagios::Nrpe->new(
 check_name => (int( rand(12151)) + 12151) . '_001_methods_test_nagios_nrpe' 
 )->generate_check();" };
$exit=$? >> 8;
is ($exit, '0', "Generate script");

$stdout=qx{ perl -Ilib -e "use Nagios::Nrpe; print Nagios::Nrpe->new(
 check_name => (int( rand(12151)) + 12151) . '_001_methods_test_nagios_nrpe', 
 check_path => '/tmp' )->generate_check();" };
$exit=$? >> 8;
is ($exit, '0', "Generate script - custom path")
