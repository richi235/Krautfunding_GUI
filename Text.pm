package Krautfunding_GUI::Text;

use strict;
use warnings;

our @ISA;

sub new {
   my $proto = shift;
   my $class = ref($proto) || $proto;
   my $self = shift;
   my $parent = $self ? ref($self) : "";
   @ISA = ($parent) if $parent;
   $self = $self ? $self : {};
   bless ($self, $class);

   $self->{qx}->{new_project} = "Neues_Projekt";


   return $self;
   
}

1;
