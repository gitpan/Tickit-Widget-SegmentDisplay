#  You may distribute under the terms of either the GNU General Public License
#  or the Artistic License (the same terms as Perl itself)
#
#  (C) Paul Evans, 2013-2014 -- leonerd@leonerd.org.uk

package Tickit::Widget::SegmentDisplay;

use strict;
use warnings;
use 5.010; # //
use base qw( Tickit::Widget );
use Tickit::Style;

use utf8;

our $VERSION = '0.03';

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

=encoding UTF-8

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

=item seven_dp

A 7-segment bar display with decimal-point. To light the decimal point, append
the value with ".".

=item colon

A static C<:>

=item symb

A unit or prefix symbol character. The following characters are recognised

  V A W Ω
  M k m µ

Each will be drawn in a style approximately to fit the general LED shape
display, by drawing lines of erased cells. Note however that some more
intricate shapes may not be very visible on smaller scales.

=back

=back

=cut

my %types = (
   seven    => [qw( 7 )],
   seven_dp => [qw( 7. )],
   colon    => [qw( : )],
   symb     => [],
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

   $self->{reshape_method} = $self->can( "reshape_${method}" );
   $self->{render_method}  = $self->can( "render_${method}_to_rb" );

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

sub reshape
{
   my $self = shift;
   my $win = $self->window or return;

   $self->{reshape_method}->( $self, $win->lines, $win->cols, 0, 0 );
}

sub render_to_rb
{
   my $self = shift;
   my ( $rb, $rect ) = @_;

   $rb->eraserect( $rect );

   $self->{render_method}->( $self, $rb, $rect );
}

# 7-Segment
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

sub reshape_seven
{
   my $self = shift;
   my ( $lines, $cols, $top, $left ) = @_;

   $self->{AGD_col}   = $left + 2;
   $self->{AGD_width} = $cols - 4;

   $self->{FE_col} = $left;
   $self->{BC_col} = $left + $cols - 2;

   $self->{A_line} = $top;
   $self->{G_line} = $top + int( ( $lines - 1 + 0.5 ) / 2 );
   $self->{D_line} = $top + $lines - 1;
}

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

# 7-Segment with DP
sub reshape_seven_dp
{
   my $self = shift;
   my ( $lines, $cols, $top, $left ) = @_;

   $self->reshape_seven( $lines, $cols - 2, $top, $left );

   $self->{DP_line} = $top  + $lines - 1;
   $self->{DP_col}  = $left + $cols  - 2;
}

sub render_seven_dp_to_rb
{
   my $self = shift;
   my ( $rb ) = @_;

   my $value = $self->{value};
   my $dp;
   local $self->{value};

   if( $value =~ m/^(\d?)(\.?)/ ) {
      $self->{value} = $1;
      $dp = length $2;
   }
   else {
      $self->{value} = $value;
   }

   $self->render_seven_to_rb( $rb );

   my $dp_pen = $dp ? $self->{lit_pen} : $self->{unlit_pen};
   $rb->erase_at( $self->{DP_line}, $self->{DP_col}, 2, $dp_pen );
}

# Static double-dot colon
sub reshape_colon
{
   my $self = shift;
   my ( $lines, $cols, $top, $left ) = @_;
   my $bottom = $top + $lines - 1;

   $self->{colon_col} = 2 + int( ( $cols - 4 ) / 2 );

   my $ofs = int( ( $lines - 1 + 0.5 ) / 4 );

   $self->{A_line} = $top    + $ofs;
   $self->{B_line} = $bottom - $ofs;
}

sub render_colon_to_rb
{
   my $self = shift;
   my ( $rb ) = @_;

   my $col = $self->{colon_col};
   $rb->erase_at( $self->{A_line}, $col, 2, $self->{lit_pen} );
   $rb->erase_at( $self->{B_line}, $col, 2, $self->{lit_pen} );
}

# Symbol drawing
#
# Each symbol is drawn as a series of erase calls on the RB to draw 'lines'.

my %symbol_strokes = do {
   no warnings 'qw'; # Quiet the 'Possible attempt to separate words with commas' warning

   # Letters likely to be used for units
   V => [ [qw( 0,0 50,100 100,0 )] ],
   A => [ [qw( 0,100 50,0 100,100 )], [qw( 20,70 80,70)] ],
   W => [ [qw( 0,0 25,100 50,50 75,100 100,0)] ],
   Ω => [ [qw( 0,100 25,100 25,75 10,60 0,50 0,20 20,0 80,0 100,20 100,50 90,60 75,75 75,100 100,100 ) ] ],

   # Symbols likely to be used as SI prefixes
   M => [ [qw( 0,100 0,0 50,50 100,0 100,100 )] ],
   k => [ [qw( 10,0 10,100 )], [qw( 90,40 10,70 90,100 )] ],
   m => [ [qw( 0,100 0,50 )], [qw( 10,40 40,40 )], [qw( 50,50 50,100 )], [qw( 60,40 90,40 )], [qw( 90,50 100,100 )] ],
   µ => [ [qw( 0,100 0,40 )], [qw( 0,80 70,80 80,75 90,60 100,40 )] ],
};

sub reshape_symb
{
   my $self = shift;
   my ( $lines, $cols, $top, $left ) = @_;

   $self->{mid_line} = int( ( $lines - 1 ) / 2 );
   $self->{mid_col}  = int( ( $cols  - 2 ) / 2 );

   $self->{Y_to_line} = ( $lines - 1 ) / 100;
   $self->{X_to_col}  = ( $cols  - 2 ) / 100;
}

sub _roundpos
{
   my $self = shift;
   my ( $l, $c ) = @_;

   # Round away from the centre of the widget
   return
      int($l) + ( $l > int($l) && $l > $self->{mid_line} ),
      int($c) + ( $c > int($c) && $c > $self->{mid_col}  );
}

sub render_symb_to_rb
{
   my $self = shift;
   my ( $rb ) = @_;

   my $strokes = $symbol_strokes{$self->value} or return;

   $rb->setpen( $self->{lit_pen} );

   my $Y_to_line = $self->{Y_to_line};
   my $X_to_col  = $self->{X_to_col};

   foreach my $stroke ( @$strokes ) {
      my ( $start, @points ) = @$stroke;
      $start =~ m/^(\d+),(\d+)$/;
      my ( $atL, $atC ) = $self->_roundpos( $2 * $Y_to_line, $1 * $X_to_col );

      foreach ( @points ) {
         m/^(\d+),(\d+)$/;
         my ( $toL, $toC ) = $self->_roundpos( $2 * $Y_to_line, $1 * $X_to_col );

         if( $toL == $atL ) {
            my ( $c, $limC ) = $toC > $atC ? ( $atC, $toC ) : ( $toC, $atC );
            $rb->erase_at( $atL, $c, $limC - $c + 2 );
         }
         elsif( $toC == $atC ) {
            my ( $l, $limL ) = $toL > $atL ? ( $atL, $toL ) : ( $toL, $atL );
            $rb->erase_at( $_, $atC, 2 ) for $l .. $limL;
         }
         else {
            my ( $sL, $eL, $sC, $eC ) = $toL > $atL ? ( $atL, $toL, $atC, $toC )
                                                    : ( $toL, $atL, $toC, $atC );
            # Maths is all easier if we use exclusive coords.
            $eL++;
            $eC > $sC ? $eC++ : $eC--;

            my $dL = $eL - $sL;
            my $dC = $eC - $sC;

            if( $dL >= abs $dC ) {
               my $c = $sC;
               my $err = 0;

               for( my $l = $sL; $l != $eL; $l++ ) {
                  $c++, $err -= $dL if  $err > $dL;
                  $c--, $err += $dL if -$err > $dL;

                  $rb->erase_at( $l, $c, 2 );

                  $err += $dC;
               }
            }
            else {
               my $l = $sL;
               my $err = 0;
               my $adC = abs $dC;

               for( my $c = $sC; $c != $eC; $c += ( $eC > $sC ) ? 1 : -1 ) {
                  $l++, $err -= $adC if  $err > $adC;
                  $l--, $err += $adC if -$err > $adC;

                  $rb->erase_at( $l, $c, 2 );

                  $err += $dL;
               }
            }
         }

         $atL = $toL;
         $atC = $toC;
      }
   }
}

=head1 AUTHOR

Paul Evans <leonerd@leonerd.org.uk>

=cut

0x55AA;
