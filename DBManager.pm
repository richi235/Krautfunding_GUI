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

sub updateProjectVal
{
    my $self    = shift;
    my $projid  = shift;
    my $options = shift;

    ### What this function does: ###
    # 1. fetch all fundings for a specific project from database
    # 1.1. calculate sum of them.
    # 2. fetch projects cost from database
    # 3. write cost-sum_of_fundings to database
    ##############################################################

    my $db            = $self->getDBBackend( $options->{table} );
    my $db_result_set = undef;
    my $where         = $self->Where_Pre(
        {
            table      => $options->{table},
            curSession => $options->{curSession},
        });
    
    push( @$where,
        "(" . $options->{table} . $TSEP . "project_id = '" . $projid . "')" );

    # fetch all transactions for this projects from the database
    my $db_result_set = $db->getDataSet(
                {
                    table    => $options->{table},
                    simple   => 1,
                    wherePre => $where,
                    session  => $options->{curSession},
                })

    # only process transactions, if we got valid data:    
    if (defined($db_result_set)
        && ( ref($db_result_set) eq "ARRAY" )
        && ( scalar( @{ $db_result_set->[0] } ) )
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
        my $db_result_set = $db->getDataSet(
            {
                table   => "projects",
                simple  => 1,
                id      => $projid,
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
                  . $projid;
                Log( $err, $ERROR );
                return $err;
            }
        }
        else
        {    
            my $err = "No costs format for project with id " . $projid;
            Log( $err, $ERROR );
            return $err;
        }

        # WRITE new amount_missing to database
        $db->updateDataSet(
            {
                table   => "projects",
                id      => $projid,
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
        my $err = "Writing new amount missing failed. No project id in transaction!";
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
        Log(
            "DBManager: NewUpdateData: Missing parameters: table:"
              . $options->{table}
              . ":curSession:"
              . $options->{curSession} . ": !",
            $ERROR
        );
        return undef;
    }

# make that: if user creates new transaction automatically his user id is set for the transaction
    if ( $options->{table} eq "transactions" )
    {    #checkRights returns a undefined, if user and session match and an defined value otherwise
        if ( defined( $self->checkRights( $options->{curSession}, $ADMIN ) ) )
        {
            $options->{columns}->{ $options->{table} . $TSEP . "user_id" } =
              $options->{curSession}
              ->{ $USERSTABLENAME . $TSEP . $UNIQIDCOLUMNNAME };
        }
        if ( $options->{columns}->{ $options->{table} . $TSEP . "project_id" } )
        {
            my $ret = $self->SUPER::NewUpdateData($options);
            $self->updateProjectVal(
                $options->{columns}
                  ->{ $options->{table} . $TSEP . "project_id" },
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
    {    #checkRights returns undefined, if user and session match and an defined value otherwise
        if ( defined( $self->checkRights( $options->{curSession}, $ADMIN ) ) ) {

            # options->{columns}->... contains the new data from the user to be set in the database
            $options->{columns}->{ $options->{table} . $TSEP . "admin" }  = 0;
            $options->{columns}->{ $options->{table} . $TSEP . "modify" } = 0;
        }
    }

    if ( $options->{table} eq "projects" ) {
        if ( $options->{cmd} eq "NEW" ) {

            # if creating new project: autmatically set the "amount missing" to the complete cost
            $options->{columns}->{'projects.amount_missing'} =
              $options->{columns}->{'projects.cost'};

            # if creating new project: automatically set contact_person to current user
            $options->{columns}->{'projects.contact_person_id'} =
              $options->{curSession}->{'users.id'};
        }

        if ( $options->{cmd} eq
            "UPDATE" )    # a attribute of an existing project is changed
        {
            # fetch the old value of "cost" from the Database:
            my $db         = $self->getDBBackend( $options->{table} );
            my $result_set = $db->getDataSet(
                {
                    table   => $options->{table},
                    session => $options->{curSession},
                    id      => $options->{id}
                }
            );

            my $old_project_cost;

            # only extract from result set if we got correct data
            if ( ref($result_set) eq "ARRAY" ) {
                $old_project_cost =
                  $result_set->[0]->[0]->{ $options->{table} . $TSEP . 'cost' };
            }
            else {
                log(
                    "Wanted to get project name from id, got no or corrupted data"
                );
            }

            # done fetching old value of "cost"

            my $new_price =
              $options->{columns}
              ->{'projects.cost'};    # new price we get from user request

            if ( $old_project_cost !=
                $new_price )          # if project cost has been changed
            {
                my $price_increasing_amount =
                  $new_price -
                  $old_project_cost
                  ; # can also be a negative value, calculations will still be correct
                $options->{columns}->{'projects.amount_missing'} +=
                  $price_increasing_amount;
            }

        }
        if ( $options->{id} ) {
            my $ret = $self->SUPER::NewUpdateData($options);
            $self->updateProjectVal( $options->{id}, $options );
            return $ret;
        }
    }

    $self->SUPER::NewUpdateData($options);
}

sub checkRights {
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
                    log(
                        "Wanted to get project name from id, got no or corrupted data"
                    );
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

                my $db = $self->getDBBackend($table);

                # the next ~10 lines get the id of the funder from the database
                my $result_set = $db->getDataSet(
                    {
                        table   => $table,
                        session => $session,
                        id      => $id
                    }
                );

                my $user_id_of_funder;

                # only extract from result set if we got correct data
                if ( ref($result_set) eq "ARRAY" ) {
                    $user_id_of_funder =
                      $result_set->[0]->[0]->{ $table . $TSEP . 'user_id' };
                }
                else {
                    log(
                        "Wanted to get project name from id, got no or corrupted data"
                    );
                }

                # here we check if the user id of the funder (gotten from the database) is the one of the current user
                # if not return an error
                if ( $session->{"users.id"} != $user_id_of_funder ) {
                    return [
                        "Forbidden: User tried to edit or delete funding of other User",
                        $WARNING
                    ];
                }
                else {
                    return undef;    # all checks passed, therefore return undef
                }

            }

        }

    }

    return $self->SUPER::checkRights( $session, $rights, $table, $id );
}

1;
