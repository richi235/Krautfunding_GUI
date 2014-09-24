package Krautfunding_GUI::DBDesign;

use strict;
use warnings;
use ADBGUI::BasicVariables;
use ADBGUI::DBDesign(qw/$RIGHTS $DBUSER/);
use ADBGUI::Tools qw(Log);

our @ISA;

BEGIN {
   use Exporter;
   our @ISA = qw(Exporter);
   our @EXPORT = qw//;
}

sub new {
   my $proto = shift;
   my $class = ref($proto) || $proto;
   my $self = shift;
   my $parent = $self ? ref($self) : "";
   @ISA = ($parent) if $parent;
   $self = $self ? $self : {};
   bless ($self, $class);
   return $self;
}

sub getDB {
   my $self = shift;
   my $DB = $self->SUPER::getDB() || {};

   $DB->{tables}->{"projects"} =
   {
      rights => $RIGHTS,
      dbuser => $DBUSER,
      primarykey => ["id"],

      dblclick => "doubleclick_on_projects",
      label => "Projekte",
      order => 1,
      idcolumnname => "id",

      columns => {
         "id" => {
            type => $UNIQIDCOLUMNNAME,
         },
         "Name" => {
            showInSelect => 1,
            type => "text",
            order => 1,
         },
         "cost" => {
            label => "Kosten",
            type => "double",
            order => 3,
         },
         "contact_person_id" => {
            linkto => "users", 
            label => "Zustaendige Kontaktperson",
            type => "longnumber",
            order => 4,
         },
         "amount_missing" => {
            label => "Fehlender Betrag",
            type => "double",
            order => 2,
         },
         "deleted" => {
            type => $DELETEDCOLUMNNAME,
            order => 5,
            # hidden => 1,
         },
      }
   };
   $DB->{tables}->{"transactions"} =
   {
      rights => $RIGHTS,
      dbuser => $DBUSER,
      primarykey => ["id"],

      label => "Spenden", 
      order => 2,
      realdelete => 1,
      idcolumnname => "id",

      columns => {
         "id" => {
            type => $UNIQIDCOLUMNNAME,
         },
         "project_id" => {
            label => "Projekt",
            linkto => "projects",
            type => "number",
            order => 2,
         },
         "user_id" => {
            readonly => 1,
            label => "Spender",
            showInSelect => 1,
            linkto => "users",
            type => "longnumber",
            order => 1,
         },
         "value" => {
            label => "Betrag",
            showInSelect => 1,
            type => "double",
            order => 3,
         },
      }
   };

   return $DB;

}

1;
