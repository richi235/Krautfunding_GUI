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

   $DB->{tables}->{"projects"} = {
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
      }
   };
   $DB->{tables}->{"users"} = {
      idcolumnname => "id",
      columns => {
         "id" => {
            type => $UNIQIDCOLUMNNAME,
         },
         "username" => {
            showInSelect => 1,
            type => "text",
            order => 1,
         },
         "beschreibung" => {
            type => "text",
            order => 2,
         },
         "modify" => {
            type => "boolean",
            order => 3,
         },
         "password" => {
            type => "text",
            order => 4,
         },
         "admin" => {
            type => "boolean",
            order => 5,
         },
         "deleted" => {
            type => "boolean",
            order => 6,
         },
      }
   };
   $DB->{tables}->{"transactions"} = {
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
   $DB->{tables}->{"log"} = {
      idcolumnname => "id",
      columns => {
         "id" => {
            type => $UNIQIDCOLUMNNAME,
         },
         "username" => {
            type => "text",
         },
         "entry" => {
            type => "text",
         },
         "diff" => {
            type => "longtext",
         },
         "mydate" => {
            type => "date",
         },
         "mytable" => {
            type => "text",
         },
         "type" => {
            type => "text",
         },
      }
   };

   return $DB;

}

1;
