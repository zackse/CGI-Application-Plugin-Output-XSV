# $Id$

package CGI::Application::Plugin::Output::XSV;

use strict;
use warnings;

use Carp;
require Text::CSV_XS;
require Exporter;

our @ISA= qw(Exporter);

our @EXPORT= qw(
  xsv_report_web
);

our @EXPORT_OK= qw(
  add_to_xsv
  clean_field_names
  xsv_report
);

our %EXPORT_TAGS= (
  all => [ @EXPORT, @EXPORT_OK ],
);

our $VERSION= '0.02';

##

sub xsv_report {
  my $args= shift || {};

  croak "argument to xsv_report must be a hash reference"
    if ref( $args ) ne 'HASH';

  my %defaults= (
    headers         => undef,
    headers_cb      => \&clean_field_names,
    include_headers => 1,
    fields          => undef,
    values          => undef,
    get_row_cb      => undef,
    line_ending     => "\n",
    csv_opts        => {},
  );

  my %opts= ( %defaults, %$args );

  croak "need array reference values to do anything"
    unless $opts{values} && ref( $opts{values} ) eq 'ARRAY';

  # list of fields to include in report
  my $fields= [];

  if( $opts{fields} ) {
    $fields= $opts{fields};
  }
  elsif( @{ $opts{values} } ) {
    my $list_type= ref( $opts{values}[0] );

    # field list from first entry in value list
    if( $list_type eq 'HASH' ) {
      $fields= [ keys %{ $opts{values}[0] } ];
    }
    # or simply array indices
    elsif( $list_type eq 'ARRAY' ) {
      $fields= [ 0..$#{$opts{values}[0]} ];
    }
    else {
      croak "unknown list type [$list_type]";
    }
  }
  else {
    croak "values is an empty list, aborting";
  }

  # function to retrieve each row of data from $opts{values}
  my $get_row;

  if( $opts{get_row_cb} ) {
    $get_row= $opts{get_row_cb};
  }
  else {
    my $list_type= ref( $opts{values}[0] );

    if( $list_type eq 'HASH' ) {
      $get_row= sub { my( $row, $fields )= @_; return [ @$row{@$fields} ] };
    }
    elsif( $list_type eq 'ARRAY' ) {
      $get_row= sub { my( $row, $fields )= @_; return [ @$row[@$fields] ] };
    }
    else {
      croak "unknown list type [$list_type]";
    }
  }

  my $csv= Text::CSV_XS->new( $opts{csv_opts} );
  my $output;

  if( $opts{include_headers} ) {
    if( ! $opts{headers} &&
        !($opts{headers_cb} && ref( $opts{headers_cb} ) eq 'CODE')
    )
    {
      croak "need headers or headers_cb to include headers";
    }

    # formatted column headers
    my $readable_headers= $opts{headers} || $opts{headers_cb}->( $fields )
      or croak "can't generate headers";

    $output .= add_to_xsv( $csv, $readable_headers, $opts{line_ending} );
  }

  foreach( @{ $opts{values} } ) {
    $output .= add_to_xsv( $csv, $get_row->($_, $fields), $opts{line_ending} );
  }

  return $output;
}

# send xsv output directly to browser for download
# same params as xsv_report, plus
#   filename => 'download.csv',
sub xsv_report_web {
  my( $self, $args )= @_;
  $args ||= {};

  croak "argument to xsv_report_web must be a hash reference"
    if ref( $args ) ne 'HASH';

  my %defaults= (
    filename => 'download.csv',
  );

  my %opts= ( %defaults, %$args );

  $self->header_props(
    -type                  => 'application/x-csv',
    '-content-disposition' => "attachment; filename=$opts{filename}",
  );

  # consider use of magic goto in case of croak() inside xsv_report
  return xsv_report( \%opts );
}

sub clean_field_names {
  my $fields= shift;

  # using temp var to avoid modifying $fields
  return [
    map {
      my $f= $_; $f =~ tr/_/ /; $f =~ s/\b(\w+)/\u$1/g; $f
    } @$fields
  ];
}

sub add_to_xsv {
  my( $csv, $fields, $line_ending )= @_;
  croak "fields argument (required) must be an array reference"
    unless $fields && ref( $fields ) eq 'ARRAY';

  # XXX redundant for empty string (or 0)
  $line_ending ||= '';

  return $line_ending unless @$fields;

  $csv->combine( @$fields )
    or croak "Failed to add [@$fields] to csv: " . $csv->error_input();

  return $csv->string() . $line_ending;
}

1;

__END__

=head1 NAME

CGI::Application::Plugin::Output::XSV - generate csv output from a CGI::Application runmode

=head1 SYNOPSIS

  use CGI::Application::Plugin::Output::XSV;
  ...

  # in some runmode...

  # $sth is a prepared DBI statement handle
  my $members= $sth->fetchall_arrayref( {} );

  my @headers= qw( member_id first_name last_name ... );

  return $self->xsv_report_web({
    fields     => \@headers,
    values     => $members,
    csv_opts   => { sep_char => "\t" },
    filename   => 'members.csv',
  });

=head1 DESCRIPTION

C<CGI::Application::Plugin::Output::XSV> provides csv-related routines
useful for web applications (via L<Text::CSV_XS|Text::CSV_XS>).

A method, C<xsv_report_web> is exported by default. Three other
functions, C<xsv_report>, C<clean_field_names>, and C<add_to_xsv>
are available for optional export.

You may export all four routines by specifying the export tag C<:all>:

  use CGI::Application::Plugin::Output::XSV qw(:all);

=head1 PURPOSE

On many websites, I had code to retrieve a list of data items for use
in an L<HTML::Template|HTML::Template(3)> TMPL_LOOP. Usually this code
would use the L<DBI|DBI(3)> routine C<fetchall_arrayref( {} )> to get a
list of hash references, one for each data item.

  my $users= $sth->fetchall_arrayref( {} );

  my $template= $self->load_tmpl( ... );

  $template->param( users => $users );

  return $template->output;

Inevitably, the client would ask for a data format they could load
in Excel, so I'd add another runmode for a csv export. This runmode
almost always looked the same:

    my @fields= qw(keys to each data item);

    my $csv= Text::CSV_XS->new();

    foreach( @$users ) {
      $csv->combine( [ @$_{ @fields } ] );
      $output .= $csv->string() . "\n";
    }

    $self->header_props(
      -type                  => 'application/x-csv',
      '-content-disposition' => "attachment; filename=export.csv",
    );
    
    return $output;

The purpose of this module is to provide a simple method, C<xsv_report_web>,
that wraps the above code while offering enough programmer flexibility.

For example, the programmer may control the naming of header columns,
filter each line of output before it is passed to L<Text::CSV_XS|Text::CSV_XS(3)>,
and set the filename that is supplied to the user's browser.

Please see the documentation below for C<xsv_report_web> for a list of
available options.

=head1 METHODS

=over 4

=item B<xsv_report_web>

  # in a runmode

  my @members= (
    { member_id  => 1,
      first_name => 'Chuck',
      last_name  => 'Barry', },
    ...
  );

  my @headers= ("Member ID", "First Name", "Last Name");

  my @fields = qw(member_id first_name last_name);

  return $self->xsv_report_web({
    fields     => \@fields,
    headers    => \@headers,
    values     => \@members,
    csv_opts   => { sep_char => "\t" },
    filename   => 'members.csv',
  });

This method generates a csv file that is sent directly to the user's
web browser. It sets the content-type header to 'application/x-csv' and sets
the content-disposition header to 'attachment'.

It should be invoked through a
L<CGI::Application|CGI::Application(3)> subclass object.

It takes a reference to a hash of named parameters. All except for
C<values> are optional:

=over 8

=item fields

A reference to an array of field names or array indices. This parameter
specifies the order of fields in each row of output.

If C<fields> is not supplied, a list will be generated using the first
entry in the C<values> list. Note, however, that in this case, if the
C<values> parameter is a list of hashes, the field
order will be random because the field names are extracted from a hash.
If the C<values> parameter is a list of lists, the field order will be
the same as the data provided.

=item filename

The name of the file which will be sent in the HTTP content-disposition
header. The default is "download.csv".

=item headers

A reference to an array of column headers to be used as the first row
of the csv report.

If C<headers> is not supplied (and C<include_headers> is not set
to a false value), C<headers_cb> will be called with C<fields>
as a parameter to generate column headers.

=item headers_cb

A reference to a subroutine used to generate column
headers from the field names.

A default routine is provided in C<clean_field_names>. This
function is passed the list of fields (C<fields>) as a parameter
and should return a reference to an array of column headers.

=item include_headers

A true or false value indicating whether to include C<headers>
(or automatically generated headers) as the first row of output.

The default is true.

=item values

A reference to an array of hash references (such as
that returned by the L<DBI|DBI(3)> C<fetchall_arrayref( {} )> routine, or
a reference to an array of list references.

This argument is required.

=item get_row_cb

A reference to a subroutine used to generate each row of output
(other than the header row). Default routines are provided that
return each row of C<values> in the order specified by C<headers>.

This subroutine is passed two parameters for each row:

=over 12

=item *

the current row (reference to an array)

=item *

the field list (C<fields> - reference to an array)

=back

=back

=back

=head1 FUNCTIONS

=over 4

=item B<add_to_xsv>

   # $sth is a prepared DBI statement handle
   my $values= $sth->fetchall_arrayref( {} );
   my @headers= qw/foo bar baz/;
   my $output;

   # $csv is a Text::CSV_XS object
   foreach( @$values ) {
      $output .= add_to_xsv( $csv, [ @$_{@headers} ], "\r\n" );
   }

This function, used internally by C<xsv_report>/C<xsv_report_web>,
formats a list of values for inclusion a csv file. The return value is
from C<< $csv->string() >>, where C<$csv> is a L<Text::CSV_XS|Text::CSV_XS(3)> object.

It takes three parameters:

=over 8

=item *

A L<Text::CSV_XS|Text::CSV_XS(3)> object

=item *

A reference to a list of values

=item *

The line ending

=back

On an error from L<Text::CSV_XS|Text::CSV_XS(3)>, the function raises an exception.

On receiving an empty list of values, the function returns the
line ending only.

XXX should this return a formatted list of empty fields?

=item B<clean_field_names>

  my $fields= [ qw/first_name foo bar baz/ ];
  my $headers= clean_field_names( $fields );

  # $headers is now [ 'First Name', 'Foo', 'Bar', 'Baz' ]

This function takes a reference to a list of strings and returns
a reference to a new list in which the strings are reformatted
as such:

  1. Underscores ('_') are changed to spaces
  2. The first letter of each word is capitalized

This function is used by C<xsv_report> and C<xsv_report_web>
if the C<headers_cb> parameter is not supplied.

=item B<xsv_report>

  # $sth is a prepared DBI statement handle
  my $members= $sth->fetchall_arrayref( {} );

  my @headers= qw( member_id first_name last_name ... );

  my $output= $self->xsv_report({
    fields     => \@headers,
    values     => $members,
    csv_opts   => { sep_char => "\t" },
  });

  # do something with $output

This function generates a string containing csv data and returns it.

This may be useful
when you want to do some manipulation of the data before sending it to
the user's browser or elsewhere. It takes the same named parameters
(via a reference to a hash) as C<xsv_report_web> except for C<filename>,
which is not applicable to this function.

=back

=head1 EXAMPLES

=over 4

=item Specify (almost) everything

  return $self->xsv_report_web({
    values          => [
      { first_name => 'Jack',
        last_name  => 'Tors',
        phone      => '555-1212' },
      { first_name => 'Frank',
        last_name  => 'Rizzo',
        phone      => '555-1515' },
    ],
    headers         => [ "First Name", "Last Name", "Phone" ],
    fields          => [ qw(first_name last_name phone) ],
    include_headers => 1,
    line_ending     => "\n",
    csv_opts        => { sep_char => "\t" },
    filename        => 'download.csv',
  });

  __END__
  "First Name"  "Last Name"     Phone
  Jack  Tors    555-1212
  Frank Rizzo   555-1515

=item Use defaults

  # ends up with same options and output as above

  return $self->xsv_report_web({
    values          => [
      { first_name => 'Jack',
        last_name  => 'Tors',
        phone      => '555-1212' },
      { first_name => 'Frank',
        last_name  => 'Rizzo',
        phone      => '555-1515' },
    ],
    headers         => [ "First Name", "Last Name", "Phone" ],
    fields          => [ qw(first_name last_name phone) ],
  });

=item Use header generation provided by module

  # headers generated will be [ "First Name", "Last Name", "Phone" ]

  # same output as above

  return $self->xsv_report_web({
    values          => [
      { first_name => 'Jack',
        last_name  => 'Tors',
        phone      => '555-1212' },
      { first_name => 'Frank',
        last_name  => 'Rizzo',
        phone      => '555-1515' },
    ],
    fields          => [ qw(first_name last_name phone) ],
  });

=item Use custom header generation

  # headers generated will be [ "first", "last", "phone" ]

  return $self->xsv_report_web({
    values          => [
      { first_name => 'Jack',
        last_name  => 'Tors',
        phone      => '555-1212' },
      { first_name => 'Frank',
        last_name  => 'Rizzo',
        phone      => '555-1515' },
    ],
    fields          => [ qw(first_name last_name phone) ],
    headers_cb      => sub {
      my @h= @{ +shift };
      s/_name$// foreach @h;
      return \@h;
    },
  });

  __END__
  first,last,phone
  Jack,Tors,555-1212
  Frank,Rizzo,555-1515

=item If order of fields doesn't matter

  # headers and fields will be in random order (but consistent
  # throughout data processing) due to extraction from hash

  # (headers will be generated automatically)

  return $self->xsv_report_web({
    values          => [
      { first_name => 'Jack',
        last_name  => 'Tors',
        phone      => '555-1212' },
      { first_name => 'Frank',
        last_name  => 'Rizzo',
        phone      => '555-1515' },
    ],
  });

  __END__
  Phone,"Last Name","First Name"
  555-1212,Tors,Jack
  555-1515,Rizzo,Frank

=item No header row

  return $self->xsv_report_web({
    values          => [
      { first_name => 'Jack',
        last_name  => 'Tors',
        phone      => '555-1212' },
      { first_name => 'Frank',
        last_name  => 'Rizzo',
        phone      => '555-1515' },
    ],
    fields          => [ qw(first_name last_name phone) ],
    include_headers => 0,
  });

  __END__
  Jack,Tors,555-1212
  Frank,Rizzo,555-1515

=item Filter data as it is processed

  sub plus_one {
    my( $row, $fields )= @_;

    return [ map { $_ + 1 } @$row{@$fields} ];
  }

  # each row (other than header row) will be
  # passed through plus_one()
  return  $self->xsv_report_web({
    fields     => [ qw(foo bar baz) ],
    values     => [ { foo => 1, bar => 2, baz => 3 }, ],
    get_row_cb => \&plus_one,
  });

  __END__
  Foo,Bar,Baz
  2,3,4

=item Pass list of lists (instead of hashes)

  # each row will be processed in order
  # since fields parameter is omitted

  $self->xsv_report_web({
    include_headers => 0,
    values          => [
      [ 1, 2, 3 ],
      [ 4, 5, 6 ],
    ],
  });

  __END__
  1,2,3
  4,5,6

=back

=head1 ERROR HANDLING

=over 4

The function C<add_to_xsv> will raise an exception when
C<< Text::CSV_XS->combine >> fails. Please see the L<Text::CSV_XS|Text::CSV_XS(3)>
documentation for details about what type of input causes a failure.

=back

=head1 AUTHOR

Evan A. Zacks C<< <zackse@cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to
C<bug-cgi-application-plugin-output-xsv@rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=CGI-Application-Plugin-Output-XSV>.
I will be notified, and then you'll automatically be notified of progress on
your bug as I make changes.

=head1 SEE ALSO

L<Text::CSV_XS>, L<CGI::Application>

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2005 CommonMind, LLC. All rights reserved.

This program is free software; you can redistribute it
and/or modify it under the same terms as Perl itself.

=head1 REVISION

$Id$

=cut
