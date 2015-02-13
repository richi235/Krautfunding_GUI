package Krautfunding_GUI::DBManager;

use strict;
use warnings;
use ADBGUI::BasicVariables;
use ADBGUI::Tools qw(Log);
use Data::Dumper;

our @ISA;

sub new
{
    my $proto  = shift;
    my $class  = ref($proto) || $proto;
    my $self   = shift;
    
    my $parent = $self ? ref($self) : "";

    @ISA = ($parent) if $parent;
    $self = $self ? $self : {};

    bless( $self, $class );

    

    
    return $self;
}

sub update_amount_missing
{
    my $self       = shift;
    my $project_id = shift;
    my $options    = shift;

    ### What this function does: ###
    # 1. fetch all fundings for a specific project from database
    # 1.1. calculate sum of them.
    # 2. fetch projects cost from database
    # 3. write cost-sum_of_fundings to database
    ##############################################################


    # this key needs to be overwritten, since it's possible
    # this function is called from another context with another
    # table in $options
    $options->{table} = 'transactions';
    my $db            = $self->getDBBackend( $options->{table} );
    my $db_result_set = undef;
    my $where         = $self->Where_Pre(
        {
            table      => $options->{table},
            curSession => $options->{curSession},
        });
    
    push( @$where,
        "(" . $options->{table} . $TSEP . "project_id = '" . $project_id . "')" );

    # fetch all transactions for this projects from the database
    $db_result_set = $db->getDataSet(
                {
                    table    => $options->{table},
                    simple   => 1,
                    wherePre => $where,
                    session  => $options->{curSession},
                });

    # only process transactions, if we got valid data:    
    if (defined($db_result_set)
        && ( ref($db_result_set) eq "ARRAY" )
      )
    {
        my $sum_of_fundings = 0;

        # process all results, build sum of them
        foreach my $curline ( @{ $db_result_set->[0] } )
        {
            # extract one funding from the result set
            my $funding = $curline->{ $options->{table} . $TSEP . "value" };

            # replaces commas in funding through . for further calculation
            $funding =~ s/\,/\./g;

            # check for correct format
            unless ( $funding =~ m,^\d+(\.\d+)?$, )
            {
                my $err = "Invalid number "
                  . $funding
                  . " in transation with id "
                  . $curline->{ $options->{table} . $TSEP . $UNIQIDCOLUMNNAME };
                Log( $err, $ERROR );
                return $err;
            }

            # build sum of all fundings
            $sum_of_fundings += $funding;
        }

        my $project_cost = undef;

        # fetch the project cost from the database
        $db_result_set = $db->getDataSet(
            {
                table   => "projects",
                simple  => 1,
                id      => $project_id,
                session => $options->{curSession},
            });

        # only db_result_set if it valid
        if ( defined( $db_result_set )
            && ( ref($db_result_set) eq "ARRAY" )
            && ( scalar( @{ $db_result_set->[0] } ) == 1 )
          )
        {
            # extract project_cost from result set
            $project_cost = $db_result_set->[0]->[0]->{ "projects" . $TSEP . "cost" };
            $project_cost =~ s/\,/\./g;

            # abort if wrong format
            unless ( $project_cost =~ m,^\d+(\.\d+)?$, )
            {
                my $err =
                    "Invalid costs '"
                  . $project_cost
                  . "' format for project with id "
                  . $project_id;
                Log( $err, $ERROR );
                return $err;
            }
        }
        else
        {    
            my $err = "No costs format for project with id " . $project_id;
            Log( $err, $ERROR );
            return $err;
        }

        # WRITE new amount_missing to database
        $db->updateDataSet(
            {
                table   => "projects",
                id      => $project_id,
                columns =>
                {
                        "projects"
                      . $TSEP                # the new amount_missing
                      . "amount_missing" => $project_cost - $sum_of_fundings,
                },
                session => $options->{curSession},
            }
        );
    }
    else
    {    
        my $err = "Updating amount_missing failed. No project_id for transaction!";
        Log( $err, $ERROR );
        return $err;
    }
}

sub NewUpdateData {
    my $self       = shift;
    my $options    = shift;
    my $moreparams = shift;

    # check if parameteres are correct
    unless ( ( !$moreparams )
        && $options->{curSession}
        && $options->{table}
        && $options->{cmd}
        && $options->{columns} )
    {
        Log("DBManager: NewUpdateData: Missing parameters: table:"
              . $options->{table}
              . ":curSession:"
              . $options->{curSession} . ": !",
            $ERROR
        );
        return undef;
    }

    if ( $options->{table} eq "transactions" )
    {
        #checkRights returns a undefined, if user and session match and an defined value otherwise
        if ( defined( $self->checkRights( $options->{curSession}, $ADMIN ) ) )
        {
            # if user creates new transaction automatically his user id is set for the transaction
            $options->{columns}->{ $options->{table} . $TSEP . "user_id" } =
                $options->{curSession} ->{ $USERSTABLENAME . $TSEP . $UNIQIDCOLUMNNAME };
        }

        
        # update amount_missing with every new or changed transaction:
        if ( $options->{columns}->{ $options->{table} . $TSEP . "project_id" } )
        {
            # first write the new transaction to database via framework method
            my $ret = $self->SUPER::NewUpdateData($options);

            # than update the amount_missing of the project
            $self->update_amount_missing(
                $options->{columns}->{ $options->{table} . $TSEP . "project_id" },
                $options
            );
            return $ret;
        }
        else {
            my $err = "No transactions found!?";
            Log( $err, $ERROR );
            return $err;
        }
    }

    # makes that: if a new user registers, set the correct admin and deleted flag for this user.
    if ( $options->{table} eq "users" )
    {
        #checkRights returns undefined, if user and session match and an defined value otherwise
        if ( defined( $self->checkRights( $options->{curSession}, $ADMIN ) ) ) {

            # options->{columns}->... contains the new data from the user to be set in the database
            $options->{columns}->{ $options->{table} . $TSEP . "admin" }  = 0;
            $options->{columns}->{ $options->{table} . $TSEP . "modify" } = 0;
        }
    }

    if ( $options->{table} eq "projects" )
    {
        if ( $options->{cmd} eq "NEW" )
        {
            # if creating new project: autmatically set the "amount missing" to the complete cost
            $options->{columns}->{'projects.amount_missing'} =
              $options->{columns}->{'projects.cost'};

            # if creating new project: automatically set contact_person to current user
            $options->{columns}->{'projects.contact_person_id'} =
              $options->{curSession}->{'users.id'};
        }
        elsif ( $options->{cmd} eq "UPDATE" )
        {
            # store the new price, name etc into database using framework method
            my $ret = $self->SUPER::NewUpdateData($options);
            
            # update the corresponding amount_missing of project
            $self->update_amount_missing( $options->{id}, $options );
            return $ret;
        }
    }

    $self->SUPER::NewUpdateData($options);
}

sub toggle_paid_status
{
   my $self           = shift; 
   my $session        = shift;
   my $transaction_id = shift;
   my $moreparams     = shift;
   
   unless( !$moreparams
        && $session
        && $transaction_id)
   {
        Log("DBManager: toggle_paid_status Missing parameters " , $ERROR);
        return undef;
   }
   
   if ( defined( $self->checkRights() ) ) {
       # todo
   } 

   # get paid-attribute from db
   my $paid = $self->get_single_value_from_db(
       {
            curSession => $session,
            table      => "transactions",
            column     => "paid",
            id         => $transaction_id
        });

   # set it
   if ( $paid != 0 ) {
       $paid = 0;
   } else {
       $paid = 1;
   }
   

   # save it back to db
   my $db = $self->getDBBackend("transactions");
   my $ret = $db->updateDataSet(
        {
            table    => "transactions",
            id       => $transaction_id,
            columns  => { "transactions.paid" => $paid },
            session  => $session
        }
    );
   
    unless ( defined($ret) )
    {
        Log("toggle_paid_status: FAILED: SQL Query failed.", $WARNING);
        return undef;
    }

   return $ret;
}    

sub checkRights
{
    my $self    = shift;
    my $session = shift;
    my $rights  = shift;            # what we are asked for, if it's allowed
    my $table   = shift || undef;
    my $id      = shift || undef;

    if ( defined($table) )          #all the following tests are table specific
    { # only test, if we are asked table speciic things and therefore a table is defined in the checkRights Request

        # this enables clients to create new users without beeing logged in
        if (   ( $rights & ( $ACTIVESESSION | $MODIFY ) )
            && ( $table eq 'users' )
            && !$id )
        {
            return undef;
        }

        # if we are asked for the modify right on table projects in an active session
        # this happens if user wants to add new project or change a existing one
        if (   ( $table eq 'projects' )
            && ( $rights & $MODIFY )
            && !defined( $self->SUPER::checkRights( $session, $ACTIVESESSION ) )
          )
        {

            # when there's no defined id we're not working on a existing object but creating a new one
            # this shall be allowed for every user, therefore returning undef
            if ( !defined($id) ) {
                return undef;
            }
            else {
                # Now we are editing an existing project
                # the following lines make sure, the user can only edit his own projects, none of other people

                my $db = $self->getDBBackend($table);

             # get the id of the contact person of the project from the database
                my $result_set = $db->getDataSet(
                    {
                        table   => $table,
                        session => $session,
                        id      => $id
                    }
                );

                my $contact_person_id_of_project;

                # only extract from result set if we got correct data
                if ( ref($result_set) eq "ARRAY" ) {
                    $contact_person_id_of_project =
                      $result_set->[0]->[0]
                      ->{ $table . $TSEP . 'contact_person_id' };
                }
                else {
                    Log( "Wanted to get project name from id, got no or corrupted data");
                }

                # here we check if the user id of the project (gotten from the database) is the one of the current user
                # if not return an error
                if ( $session->{"users.id"} != $contact_person_id_of_project ) {
                    return [
                        "Forbidden: User tried to edit or delete Project of other User",
                        $WARNING
                    ];
                }
                else {
                    return undef;    # all checks passed, therefore return undef
                }

            }

        }

        if (   ( $table eq 'transactions' )
            && ( $rights & $MODIFY )
            && !defined( $self->SUPER::checkRights( $session, $ACTIVESESSION ) )
          )
        {
            # when there's no defined id we're not working on a existing object but creating a new one
            # this shall be allowed for every user, therefore returning undef
            if ( !defined($id) ) {
                return undef;
            }
            else {
                # Now we are editing an existing project
                # the following lines make sure, the user can only edit his own projects, none of other people
                my $user_id_of_transaction = $self->get_single_value_from_db( 
                    {
                        curSession => $session,
                        table      => $table,
                        column     => 'user_id',
                        id         => $id
                    }); # get the user_id of the funding we are editing

                # here we check if the user id of the funder (gotten from the database) is the one of the current user
                # if not return an error
                if ( $session->{"users.id"} != $user_id_of_transaction ) {
                    return [ "Forbidden: User tried to edit or delete funding of other User",
                        $WARNING ];
                }
                else {
                    return undef;    # all checks passed, therefore return undef
                }

            }

        }

    }

    return $self->SUPER::checkRights( $session, $rights, $table, $id );
}


sub deleteUndeleteDataset
{
    my $self    = shift;
    my $options = shift;

    my $ok;
    
       # if a transaction gets deleted or undeleted update the amount missing
    if ( $options->{table} eq 'transactions' )
    {
        # the functions called next look for session as attribute with key curSession
        # in $options so this is needed
        $options->{curSession} = $options->{session};

        # get the project_id for this transaction from the db
        $options->{column} = 'project_id';
        my $project_id = $self->get_single_value_from_db( $options );

        # then delete transaction as usual
        $ok = $self->SUPER::deleteUndeleteDataset($options);


        $self->update_amount_missing( $project_id , $options );
    } else {
        # otherwise just delete as usual
        $ok = $self->SUPER::deleteUndeleteDataset($options);
    }
    return $ok;
}


1;
