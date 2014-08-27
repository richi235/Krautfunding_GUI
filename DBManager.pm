package Krautfunding_GUI::DBManager;

use strict;
use warnings;
use ADBGUI::BasicVariables;
use ADBGUI::Tools qw(Log);
use Data::Dumper;



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
    {                                #checkRights returns a undefined, if user and session match and an defined value otherwise
        if (defined($self->checkRights($options->{curSession},$ADMIN) ))
        {
            $options->{columns}->{$options->{table}.$TSEP."user_id"} = $options->{curSession}->{$USERSTABLENAME.$TSEP.$UNIQIDCOLUMNNAME};
        }
    }

    
    # makes that: if a new user registers, set the correct admin and deleted flag for this user.
    if ($options->{table} eq "users" )
    {                                #checkRights returns undefined, if user and session match and an defined value otherwise
        if (defined($self->checkRights($options->{curSession},$ADMIN) ))
        {
            # options->{columns}->... contains the new data from the user to be set in the database
            $options->{columns}->{$options->{table}.$TSEP."admin"} = 0;
            $options->{columns}->{$options->{table}.$TSEP."modify"} = 0;
        }
    }


    if ( $options->{table} eq "projects" ) {
        if ( $options->{cmd} eq "NEW" ) {

            # if creating new project: autmatically set the "amount missing" to the complete cost
            $options->{columns}->{'projects.amount_missing'} = $options->{columns}->{'projects.cost'};
            
        }
    }

    $self->SUPER::NewUpdateData($options);
}


sub deleteUndeleteDataset {
    my $self = shift;
    my $options = shift;
    my $db = $self->getDBBackend($options->{table});
    my $ok = undef;

    if ( $options->{table} eq "projects") {

        # get the id of the contact person of the project to be deleted:

          # get the whole row from the table
        my $result_set = $db->getDataSet({
            table => $options->{table},
            session => $options->{session},
            id => $options->{id}
        }) ;
           # extract the contact_person_id
        my $contact_person_id_of_project ;
            # only work with result set if we got correct data
         if ( ref($result_set) eq "ARRAY" ) {
             $contact_person_id_of_project = $result_set->[0]->[0]->{$options->{table}.$TSEP.'contact_person_id'};
         } else {
              log("Wanted to get project name from id, got no or corrupted data");
         }

        # test if it's the user who wants to delete
        if ( $options->{session}->{"users.id"} != $contact_person_id_of_project ){
            return 0 ; # do nothing
        }
        
    }

    # print (Dumper($options));
    # die ;
    
    if (uc($options->{cmd}) eq "UNDEL") {
       $ok = $db->undeleteDataSet($options);
    } else {
       $ok = $db->deleteDataSet($options);
    }
    return $ok ? 0 : "(un)deleteDataSet reported error";
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
