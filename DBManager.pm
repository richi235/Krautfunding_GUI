package Krautfunding_GUI::DBManager;

use strict;
use warnings;
use ADBGUI::BasicVariables;
use ADBGUI::Tools qw(Log);

our @ISA;

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

sub NewUpdateData
{
    my $self = shift;
    my $options = shift;
    my $moreparams = shift;

    # check if parameteres are correct
    # unless ((!$moreparams) && $options->{curSession} && $options->{table} && $options->{cmd} && $options->{columns} && $options->{onDone}) {
    #    Log("DBManager: NewUpdateData: Missing parameters: table:".$options->{table}.":curSession:".$options->{curSession}.": !", $ERROR);
    #    return &$onDone("ACCESS DENIED", $options, $self);
    # }

    # make that: if user creates new transaction automatically his user id is set for the transaction
    if ($options->{table} eq "transactions" )
    {                                #checkRights returns undefined, if User and session match and an undifend value otherwise
        if (defined(my $err = $self->checkRights($options->{curSession},$ADMIN) ))
        {
            $options->{columns}->{$options->{table}.$TSEP."user"."_".$UNIQIDCOLUMNNAME} = $options->{curSession}->{$USERSTABLENAME.$TSEP.$UNIQIDCOLUMNNAME};
        }
    }


    # makes thet: if a new user registers, set the correct admin or deleted flag for this user.
    if ($options->{table} eq "users" )
    {                                #checkRights returns undefined, if User and session match and an undifend value otherwise
        if (defined(my $err = $self->checkRights($options->{curSession},$ADMIN) ))
        {
            # options->{columns}->... contains the new data from the user to be set in the database
            $options->{columns}->{$options->{table}.$TSEP."admin"} = 0;
            $options->{columns}->{$options->{table}.$TSEP."modify"} = 0;
        }
    }
    

    $self->SUPER::NewUpdateData($options);
}



sub checkRights {
   my $self = shift;
   my $session = shift;
   my $rights  = shift;
   my $table   = shift || undef;
   my $id      = shift || undef;

   if (($rights & ( $ACTIVESESSION | $MODIFY ) ) && ( $table eq 'users' ) && !$id ) {
       return undef ;
       
   }

   if ( !defined( $self->SUPER::checkRights( $session,$ACTIVESESSION )) &&  ($rights & ( $ACTIVESESSION | $MODIFY ) ) && ( $table eq 'projects' )  ) {
       return undef ;
   }
   
   return $self->SUPER::checkRights( $session,$rights,$table,$id ) ;
   
}   


1;
