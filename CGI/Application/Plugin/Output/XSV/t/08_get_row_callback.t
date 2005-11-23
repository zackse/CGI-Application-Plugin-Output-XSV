#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 4;

BEGIN {
  use_ok( 'CGI::Application::Plugin::Output::XSV', qw(xsv_report) );
}

sub plus_one {
  my( $row, $fields )= @_;

  return [ map { $_ + 1 } @$row{@$fields} ];
}

my $report;

# test creating header list from values
# passing list of hashes
$report= xsv_report({
  fields     => [ qw(foo bar baz) ],
  values     => [ { foo => 1, bar => 2, baz => 3 }, ],
  get_row_cb => \&plus_one,
});

is( $report, "Foo,Bar,Baz\n2,3,4\n", "rows are retrieved using user callback" );

sub some_other_data {
  return [ "Jolly",42 ];
}

$report= xsv_report({
  values          => [ [ 1, 2, 3 ], ],
  get_row_cb      => \&some_other_data,
  include_headers => 0,
});

is( $report, "Jolly,42\n", "rows are retrieved using user callback" );

sub uppercase {
  my( $row, $fields )= @_;

  return [ map { uc } @$row{@$fields} ];
};

$report= xsv_report({
  fields          => [ qw(first second third) ],
  values          => [ { first => 'foo', second => 'bar', third => 'baz' }, ],
  get_row_cb      => \&uppercase,
  include_headers => 0,
});

is( $report, "FOO,BAR,BAZ\n", "rows are retrieved using user callback" );

