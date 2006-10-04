#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 3;

BEGIN {
  use_ok( 'CGI::Application::Plugin::Output::XSV', qw(xsv_report) );
}

my $report;

my @vals = qw(one two three four five six);

# using iterator to generate values list
$report= xsv_report({
  fields    => [ qw(foo bar baz) ],
  iterator  => sub { while ( @vals ) { return [ splice @vals, 0, 3 ] } },
});

is( $report, "Foo,Bar,Baz\none,two,three\nfour,five,six\n",
             "report output (iterator) matches" );


@vals = qw(one two three);

$report= xsv_report({
  include_headers => 0,
  iterator        => sub { while ( @vals ) { return [ splice @vals, 0, 3 ] } },
});

is( $report, "one,two,three\n",
             "report output (iterator) matches" );

=for later
use DBI;
my $dbh= DBI->connect(
  "dbi:mysql:test",
  "test",
  "test",
  { RaiseError => 1 }
)
  or croak $DBI::errstr;

my $sql = q{
  SELECT dealer_id, company_name, address1, city, state, zipcode
  FROM   dealer
  ORDER BY company_name
};

my $sth = $dbh->prepare($sql);
$sth->execute();

#sub get_vals {
#  my $fields_ref = shift;
#
#  while ( my $dealer_href = $sth->fetchrow_hashref ) {
#    return [ @{$dealer_href}{@{$fields_ref}} ];
#  }
#}
#
#$report= xsv_report({
#  fields   => [ qw(dealer_id company_name address1 city state zipcode) ],
#  iterator => \&get_vals,
#});
#
#is( $report, "one,two,three\n",
#             "report output (iterator) matches" );

sub get_vals {
  my $fields_ref = shift;

  while ( my $vals = $sth->fetchrow_arrayref() ) {
    return $vals;
  }
}

$report= xsv_report({
  iterator => \&get_vals,
});

is( $report, "one,two,three\n",
             "report output (iterator) matches" );
=cut
