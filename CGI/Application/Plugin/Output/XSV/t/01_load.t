#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 1;

BEGIN {
  use_ok( 'CGI::Application::Plugin::Output::XSV' );
}
