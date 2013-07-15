#  You may distribute under the terms of either the GNU General Public License
#  or the Artistic License (the same terms as Perl itself)
#
#  (C) Paul Evans, 2013 -- leonerd@leonerd.org.uk

package Tickit::Widget::SegmentDisplay;

use strict;
use warnings;
use 5.010; # //
use base qw( Tickit::Widget );
use Tickit::Style;

our $VERSION = '0.02';

use Carp;

# The 7 segments are
#  AAA
# F   B
# F   B
#  GGG
# E   C
# E   C
#  DDD
#
# B,C,E,F == 2cols wide
# A,D,G   == 1line tall

=head1 NAME

C<Tickit::Widget::SegmentDisplay> - show a single character like a segmented display

=head1 DESCRIPTION

This class provides a widget that immitates a segmented LED or LCD display. It
shows a single character by lighting or shading fixed rectangular bars.

=head1 STYLE

The default style pen is used as the widget pen, though only the background
colour will actually matter as the widget does not directly display text.

The following style keys are used:

=over 4

=item lit => COLOUR

=item unlit => COLOUR

Colour descriptions (index or name) for the lit and unlight segments of the
display.

=back

=cut

style_definition base =>
   lit => "red",
   unlit => 16+36;

use constant WIDGET_PEN_FROM_STYLE => 1;

=head1 CONSTRUCTOR

=cut

=head2 $segmentdisplay = Tickit::Widget::SegmentDisplay->new( %args )

Constructs a new C<Tickit::Widget::SegmentDisplay> object.

Takes the following named arguments

=over 8

=item value => STR

Sets an initial value.

=item type => STR

The type of display. Supported types are:

=over 4

=item seven

A 7-segment bar display

=item colon

A static C<:>

=back

=back

=cut

my %types = (
   seven => [qw( 7 )],
   colon => [qw( : )],
);

sub new
{
   my $class = shift;
   my %args = @_;
   my $self = $class->SUPER::new( %args );

   my $type = $args{type} // "seven";
   my $method;
   foreach my $typename ( keys %types ) {
      $type eq $typename and $method = $typename, last;
      $type eq $_ and $method = $typename, last for @{ $types{$typename} };
   }
   defined $method or croak "Unrecognised type name '$type'";

   $self->{render_method} = $self->can( "render_${method}_to_rb" );

   $self->{value} = $args{value} // "";

   $self->on_style_changed_values(
      lit   => [ undef, $self->get_style_values( "lit" ) ],
      unlit => [ undef, $self->get_style_values( "unlit" ) ],
   );

   return $self;
}

# ADG + atleast 1 line each for FB and EC
sub lines { 3 + 2 }

# FE, BC + atleast 2 columns for AGD
sub cols  { 4 + 2 }

=head1 ACCESSORS

=cut

=head2 $value = $segmentdisplay->value

=head2 $segmentdisplay->set_value( $value )

Return or set the character on display

=cut

sub value
{
   my $self = shift;
   return $self->{value};
}

sub set_value
{
   my $self = shift;
   ( $self->{value} ) = @_;
   $self->redraw;
}

sub on_style_changed_values
{
   my $self = shift;
   my %values = @_;

   $self->{lit_pen}   = Tickit::Pen::Immutable->new( bg => $values{lit}[1]   ) if $values{lit};
   $self->{unlit_pen} = Tickit::Pen::Immutable->new( bg => $values{unlit}[1] ) if $values{unlit};
}

my %segments = (
   0 => "ABCDEF ",
   1 => " BC    ",
   2 => "AB DE G",
   3 => "ABCD  G",
   4 => " BC  FG",
   5 => "A CD FG",
   6 => "A CDEFG",
   7 => "ABC    ",
   8 => "ABCDEFG",
   9 => "ABCD FG",
);

sub _pen_for_seg
{
   my $self = shift;
   my ( $segment ) = @_;

   my $segments = $segments{$self->value} or return $self->{unlit_pen};

   my $lit = substr( $segments, ord($segment) - ord("A"), 1 ) ne " ";
   return $lit ? $self->{lit_pen} : $self->{unlit_pen};
}

sub reshape
{
   my $self = shift;
   my $win = $self->window or return;

   my $lines = $win->lines;
   my $cols  = $win->cols;
   my ( $top, $left ) = ( 0, 0 );

   $self->{AGD_col}   = $left + 2;
   $self->{AGD_width} = $cols - 4;

   $self->{FE_col} = $left;
   $self->{BC_col} = $left + $cols - 2;

   $self->{A_line} = $top;
   $self->{G_line} = $top + int( ( $lines - 1 + 0.5 ) / 2 );
   $self->{D_line} = $top + $lines - 1;
}

sub render_to_rb
{
   my $self = shift;
   my ( $rb, $rect ) = @_;

   $rb->eraserect( $rect );

   $self->{render_method}->( $self, $rb, $rect );
}

# 7-Segment
sub render_seven_to_rb
{
   my $self = shift;
   my ( $rb ) = @_;

   $rb->erase_at( $self->{A_line}, $self->{AGD_col}, $self->{AGD_width}, $self->_pen_for_seg( "A" ) );
   $rb->erase_at( $self->{G_line}, $self->{AGD_col}, $self->{AGD_width}, $self->_pen_for_seg( "G" ) );
   $rb->erase_at( $self->{D_line}, $self->{AGD_col}, $self->{AGD_width}, $self->_pen_for_seg( "D" ) );

   my ( $F_pen, $B_pen ) = ( $self->_pen_for_seg( "F" ), $self->_pen_for_seg( "B" ) );
   foreach my $line ( $self->{A_line}+1 .. $self->{G_line}-1 ) {
      $rb->erase_at( $line, $self->{FE_col}, 2, $F_pen );
      $rb->erase_at( $line, $self->{BC_col}, 2, $B_pen );
   }

   my ( $E_pen, $C_pen ) = ( $self->_pen_for_seg( "E" ), $self->_pen_for_seg( "C" ) );
   foreach my $line ( $self->{G_line}+1 .. $self->{D_line}-1 ) {
      $rb->erase_at( $line, $self->{FE_col}, 2, $E_pen );
      $rb->erase_at( $line, $self->{BC_col}, 2, $C_pen );
   }
}

# Static double-dot colon
sub render_colon_to_rb
{
   my $self = shift;
   my ( $rb ) = @_;

   my $col = 2 + int( $self->{AGD_width} / 2 );
   $rb->erase_at( int( ($self->{A_line} + $self->{G_line}) / 2 ), $col, 2, $self->{lit_pen} );
   $rb->erase_at( int( ($self->{G_line} + $self->{D_line}) / 2 ), $col, 2, $self->{lit_pen} );
}

=head1 AUTHOR

Paul Evans <leonerd@leonerd.org.uk>

=cut

0x55AA;
