#!/usr/bin/perl

use strict;
use warnings;

use Test::More;

BEGIN {
  eval "use Test::Exception";
  plan skip_all => "Test::Exception required to test die" if $@;
  plan tests => 16;
}

my $mock;

BEGIN {
  eval "use Test::MockObject";
  unless( $@ ) {
    $mock= Test::MockObject->new();
    $mock->fake_module( 'Text::CSV_XS' );
    $mock->fake_new( 'Text::CSV_XS' );
    $mock->set_false( 'combine' );
    $mock->mock( error_input => sub { "some csv error" } );
  }

  use_ok( 'CGI::Application::Plugin::Output::XSV', qw(:all) );
  use_ok( 'Text::CSV_XS' );
}

throws_ok { xsv_report() }
          qr/need array reference values to do anything/i,
          'xsv_report: missing values parameter raises exception';

throws_ok { xsv_report( hash => 'value' ) }
          qr/must be a hash reference/i,
          'xsv_report: non-hash reference options parameter raises exception';

throws_ok { xsv_report_web( hash => 'value' ) }
          qr/must be a hash reference/i,
          'xsv_report: non-hash reference options parameter raises exception';

throws_ok { xsv_report({ values => {} }) }
          qr/need array reference values to do anything/i,
          'xsv_report: invalid values list type raises exception';

throws_ok { xsv_report({ values => [ \*_ ] }) }
          qr/unknown list type \[GLOB\]/i,
          'xsv_report: invalid list type raises exception';

throws_ok { xsv_report({ fields => [ 1 ], values => [ \*_ ] }) }
          qr/unknown list type \[GLOB\]/i,
          'xsv_report: invalid list type raises exception';

throws_ok { xsv_report({ fields => [ 1 ], values => [ \*_ ] }) }
          qr/unknown list type \[GLOB\]/i,
          'xsv_report: invalid list type raises exception';

throws_ok { xsv_report({ values => \@_ }) }
          qr/values is an empty list/i,
          'xsv_report: empty values list raises exception';

throws_ok { xsv_report({ values => [[1]], headers_cb => undef }) }
          qr/need headers or headers_cb/i,
          'xsv_report: undef headers and headers_cb raises exception';

throws_ok { xsv_report({ values => [[1]], headers_cb => 1 }) }
          qr/need headers or headers_cb/i,
          'xsv_report: non-coderef headers_cb raises exception';

throws_ok { xsv_report({ values => [[1]], headers_cb => sub { 0 } }) }
          qr/can't generate headers/i,
          'xsv_report: empty return from headers_cb raises exception';

# really a mock object
my $csv= Text::CSV_XS->new();

throws_ok { add_to_xsv( $csv, {} ) }
          qr/must be an array reference/i,
          'add_to_xsv: non-array reference fields param raises exception';

throws_ok { add_to_xsv( $csv ) }
          qr/must be an array reference/i,
          'add_to_xsv: missing fields param raises exception';

SKIP: {
  skip "Need Test::MockObject", 1
    unless $mock;

  throws_ok { add_to_xsv( $csv, [[1]] ) }
            qr/Failed to add \[[^\]]+\] to csv/i,
            'add_to_xsv: invalid list of fields raises exception';
}

