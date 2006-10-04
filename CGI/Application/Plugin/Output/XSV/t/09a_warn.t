#!/usr/bin/perl

use strict;
use warnings;

use Test::More;

BEGIN {
  eval "use Test::Warn";
  plan skip_all => "Test::Warn required to test warn" if $@;
  plan tests => 3;
}

BEGIN {
  use_ok( 'CGI::Application::Plugin::Output::XSV', qw(:all) );
  use_ok( 'Text::CSV_XS' );
}

my @vals = qw(one);

warning_like {
  xsv_report({
    iterator   => sub { while ( @vals ) { return [ splice @vals, 0, 1 ] } },
    headers_cb => sub { [ qw(One) ] },
  })
}
  qr/passing empty fields list to headers_cb/i,
  'xsv_report: warning on empty fields list with headers callback';

