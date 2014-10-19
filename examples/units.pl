#!/usr/bin/perl

use strict;
use warnings;
use utf8;

use Tickit;
use Tickit::Widgets qw( SegmentDisplay Box HBox );

my $tickit = Tickit->new(
   root => my $hbox = Tickit::Widget::HBox->new(
      spacing => 1,
   ),
);

# Unit symbols
foreach my $unit (qw( V A W Ω M k m µ )) {
   $hbox->add(
      Tickit::Widget::Box->new(
         child => Tickit::Widget::SegmentDisplay->new(
            type => 'symb',
            value => $unit,
         ),
         child_lines =>  9,
         child_cols  => 10,
      )
   );
}

$tickit->run;
