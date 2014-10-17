package Krautfunding_GUI::Qooxdoo;

use strict;
use warnings;
use ADBGUI::BasicVariables;
use ADBGUI::Tools qw(Log);
use POE ;
use CGI;
use Data::Dumper ; # can be used for debug output


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

    $self->{text} = $self->{gui}->{text};

    return $self;
}


sub onAuthenticate {
   my $self = shift;
   my $options = shift;
   my $moreparams = shift;
   unless ((!$moreparams) && $options->{connection} && $options->{curSession}) {
      Log("onAuthenticate: Missing parameters: connection:".$options->{connection}.": !", $ERROR);
      return undef;
   }

   my $return_value = $self->SUPER::onAuthenticate($options) ;
        #tests if we are loged in
   if ( !$options->{curSession}->{"users".$TSEP."id"} ) {
       $self->sendToQXForSession($options->{connection}->{sessionid} || 0, "reset");
       $poe_kernel->yield(sendToQX => "addbutton ".CGI::escape("")." ".CGI::escape("new_account_button")." ".CGI::escape("Neuen Benuter anlegen")." ".CGI::escape("")." ".CGI::escape("job=neweditentry,table=users"));
   }

   return $return_value ;
}    


sub onAuthenticated {
    my $self = shift;
    my $options = shift;
    my $moreparams = shift || 0;

    unless ( ( !$moreparams ) && $options->{curSession} && $options->{connection} )
    {
        Log("In onAuthenticated: Missing parameters: curSession:" . $options->{curSession} .
            "connection:" . $options->{connection} . ": !"
            , $ERROR
        );
        return undef;
    }
    
    my $return = $self->SUPER::onAuthenticated($options);

    # show the projects button, to open table for projects
       # only show this button if user is not admin
    if (defined(my $err =
                    $self->{dbm}->checkRights( $options->{curSession}, $ADMIN )
               )
       )
    {
        $poe_kernel->yield(sendToQX => "addbutton ".CGI::escape("")." ".CGI::escape("richibutton")." ".CGI::escape("Projekte")." ".CGI::escape("")." ".CGI::escape("job=show,table=projects"));
    }


    # display the projects table per default after login
    $self->onShow({table => "projects", curSession => $options->{curSession} , connection => $options->{connection}  }) ;
    
    # return the return value of the corresponding underliying framework method
    return $return;
}
sub onClientData {
   my $self = shift;
   my $options = shift;
   my $moreparams = shift;
   unless ((!$moreparams) && $options->{heap} && $options->{curSession} && $options->{connection}) {
      Log("onClientData: Missing parameters: connection heap=".$options->{heap}.":session=".$options->{curSession}.": !", $ERROR);
      return undef;
   }
        if ($options->{job} eq "doubleclick_on_projects")
        {
            $self->{dbm}->setFilter({ curSession => $options->{curSession}, table => "transactions" , filter => { "transactions".$TSEP."project_id" => $options->{id} } });

            # variable for the project name, filled later
            my $project_name ;
            # get the name of the clicked table (we know only the id) from the Database Backend
            my $db  =  $self->{dbm}->getDBBackend($options->{table});
            my $result_set = $db->getDataSet({
                table => $options->{table},
                session => $options->{curSession},
                id => $options->{id}
            }) ;

            
               # only work with result set if we got correct data
            if ( ref($result_set) eq "ARRAY" ) {
                $project_name = $result_set->[0]->[0]->{$options->{table}.$TSEP.'Name'};
            } else {
                 log("Wanted to get project name from id, got no or corrupted data");
            }
            

            # display the window with the correct title
            $self->onShow({table => "transactions", curSession => $options->{curSession} , connection => $options->{connection} , windowtitle => "Beteiligungen an: $project_name"  });
            return ;
        }
       
    
    if(($options->{job} eq "saveedit") || ($options->{job} eq "newedit"))
    {
        if ($options->{table} eq "transactions")
        {
            my $id = $options->{$UNIQIDCOLUMNNAME} || $options->{connection}->{"q"}->param($self->{dbm}->getIdColumnName($options->{table}));
            my $params = {
               crosslink => $options->{crosslink},
               crossid => $options->{crossid},
               crosstable => $options->{crosstable},
               table => $options->{table},
               $UNIQIDCOLUMNNAME => $id,
               oid => $options->{oid},
               connection => $options->{connection},
               curSession => $options->{curSession},
               "q" => $options->{connection}->{"q"},
               job => $options->{job},
            };
            $params->{columns} = $self->parseFormularData($params);
            $params->{columns}->{$options->{table}.$TSEP.$self->{dbm}->getIdColumnName($options->{table})} = $id;

            # set project for this transaction to current project (gotten from the filter setting)
            $params->{columns}->{"transactions.project_id"} = $params->{curSession}->{filter}->{transactions}->{"transactions.project_id"};
            
            
            # print("\e[1;31m onClient Data: Inhalt von \$params Array\n");
            # print(Dumper($params));
            # print("\e[0m");
            my $returned_value = $self->onSaveEditEntry($params);
            return $returned_value;
            
        }
    }
   


    $self->SUPER::onClientData($options);
   
} 

sub onDelRow
{
    my $self = shift;
    my $options = shift;
    my $moreparams = shift;

    unless ((!$moreparams) && $options->{table} && $options->{curSession}) {
       Log("onDelRow: Missing parameters: connection:".$options->{table}.": !", $ERROR);
       return undef;
    }

    my $return_value = $self->SUPER::onDelRow($options,$moreparams);


    if ( $options->{table} eq 'transactions' )
    {
        ### The following updates the amount_missing value in the footer ###  
          # get the id of the current displayed project
          # needed to get the correct amount_missing
          my $current_filter = $self->{dbm}->getFilter($options, $moreparams);
          my $id_of_current_project = $current_filter->{"transactions".$TSEP."project_id"};
          if ( !($id_of_current_project) ) {
              Log("Project ID for amount missing in footer not found", $WARNING);
              return undef;
          }

          # draw the correct value into the new iframe:
          $self->update_amount_missing_footer( $options->{"curSession"}, $id_of_current_project, 1 );
        
    }
    
    return $return_value;
}


sub onNewEditEntry {
    my $self = shift;
    my $options = shift;
    my $moreparams = shift;
    unless ((!$moreparams) && $options->{curSession} && $options->{table} && $options->{connection}) {
       Log("Qooxdoo: onNewEditEntry: Missing parameters: table:".$options->{table}.":curSession:".$options->{curSession}.": !", $ERROR);
       return undef;
    }

    if ($options->{table} eq 'transactions') {
        # hide the uset_id field in the newEditEntry Window for transactions
        # since it gets set by default
        $options->{dohidden}->{$options->{table}}->{"user_id"}++;

        # don't show the project for the funding, since it gets set automatically 
        $options->{dohidden}->{$options->{table}}->{"project_id"}++;


        
        # print("\e[1;31mContent von \$options in onNewEditEntry:");
        # print(Dumper($options));
        # print("\e[0m");        
    }

    if ($options->{table} eq $USERSTABLENAME ) {

        if (defined(  $self->{dbm}->checkRights( $options->{curSession}, $ADMIN )  )
           )
        {
            # if not admin and we are window of the user list/table
            # don't display the checkbox for admin
            $options->{dohidden}->{$options->{table}}->{"admin"}++;
            # and don't display text filed for "beschreibung" sicne it's unnecessary and confusing for users in our case
            $options->{dohidden}->{$options->{table}}->{"beschreibung"}++;
            # dont display checkbox for modify rights
            $options->{dohidden}->{$options->{table}}->{"modify"}++;

        }
        
    }

    if ( $options->{table} eq 'projects' ) {
        # don't display input field for "amount_missing" since this value gets set automatically
        $options->{dohidden}->{$options->{table}}->{'amount_missing'}++;
        # don't display drop-down menu for "contact_person" since this gets set automatically
        $options->{dohidden}->{$options->{table}}->{'contact_person_id'}++;

    }

    return $self->SUPER::onNewEditEntry($options);
    
}



sub onShow
{
    my $self = shift;
    my $options = shift;
    my $moreparams = shift;

    unless ((!$moreparams) && $options->{curSession} && $options->{table} && $options->{connection}) {
       Log("onShow: Missing parameters: table:".$options->{table}.":curSession:".$options->{curSession}.":connection:".$options->{connection}.": !", $ERROR);
       return undef;
    }

    # call the corresponding framework function
    my $return_value = $self->SUPER::onShow( $options, $moreparams );

    if ( $options->{table} eq "transactions" ) {
       ### The following creates the iframe for displaying the amount missing ###

        # qooxdoo object identifier of the window
        my $window_identifier = $options->{table}."_"."show";
        # the identifier of the comming footer object in qooxdoo
        my $footer_identifier = $window_identifier."_data_"."amount_missing";
        
        # create an new iframe object on the client
        $poe_kernel->yield(sendToQX => "createiframe " . $footer_identifier . " ".CGI::escape("about:blank"));
        # add it to the qooxdoo window
        $poe_kernel->yield(sendToQX => "addobject " . $window_identifier." " . $footer_identifier);

        # get the id of the current displayed project
        # needed to get the correct amount_missing
        my $current_filter = $self->{dbm}->getFilter($options, $moreparams);
        my $id_of_current_project = $current_filter->{"transactions".$TSEP."project_id"};
        if ( !($id_of_current_project) ) {
            Log("Project ID for amount missing in footer not found", $WARNING);
            return undef;
        }

        # draw the correct value into the new iframe:
        $self->update_amount_missing_footer( $options->{"curSession"}, $id_of_current_project );
    }

    return $return_value;
}

sub update_amount_missing_footer
{
    my $self = shift;
    my $session = shift;
    my $project_id = shift;
    my $called_by_save_edit_or_by_delete = shift;
    
    my $footer_identifier = "transactions_show_data_amount_missing";
    

  ### the following fetches the amount missing from the database ###
    my $amount_missing ;
    
    my $db  =  $self->{dbm}->getDBBackend("transactions");
    my $result_set = $db->getDataSet({
        table => "projects",
        session => $session,
        id => $project_id
    }) ;

       # only work with result set if we got correct data
    if ( ref($result_set) eq "ARRAY" ) {
        $amount_missing = $result_set->[0]->[0]->{"projects".$TSEP.'amount_missing'};
    } else {
         log("Wanted to get project name from id, got no or corrupted data");
    }
  ### done ###

    # the footer for the project window
    # a html iframe is needed to set the right bound values in nice formatting in the qooxdoo framework
    my $footer_html =
              "<table width=100%><tr><td>Fehlender Betrag: </td><td align=right> <b><font color=red>$amount_missing &euro; </font></b> </td></tr></table>" ; 

    # only wipe the iframe if we are called by onSaveEditEntry()
    # This is weird but actually needed
    # if it gets called always, the value is not drawn when called from onShow()
    if ( $called_by_save_edit_or_by_delete )
    {
        $poe_kernel->yield(sendToQX => "iframewriteclose " . $footer_identifier );
    }
    # now, write the data into the iframe
    $poe_kernel->yield(sendToQX => "iframewritereset " . $footer_identifier . " " . CGI::escape( $footer_html ));
}    

sub onSaveEditEntry
{
   my $self = shift;
   my $options = shift;
   my $moreparams = shift;

   unless ((!$moreparams) && $options->{curSession} && $options->{table} && $options->{"q"} && $options->{oid} && $options->{connection}) {
      Log("onSaveEditEntry: Missing parameters: table:".$options->{table}.":curSession:".$options->{curSession}.": !", $ERROR);
      return undef;
   }

   # enable autoclosing of the window when save button is preesed
   $options->{close}++;

   my $return_value = $self->SUPER::onSaveEditEntry($options, $moreparams );

   if ( $options->{table} eq 'transactions')
   {
       # get the id of the current showed project from the filter
       my $current_filter = $self->{dbm}->getFilter($options, $moreparams);
       my $id_of_current_project = $current_filter->{"transactions".$TSEP."project_id"};
       if ( !($id_of_current_project) ) {
           Log("Project ID for amount missing in footer not found", $WARNING);
           return undef;
       }

       $self->update_amount_missing_footer( $options->{"curSession"}, $id_of_current_project, 1 );
   }

   return $return_value;
}   


sub getTableButtonsDef {
   my $self = shift;
   my $options = shift;
   my $moreparams = shift;
   
   unless ((!$moreparams) && $options->{table} && $options->{curSession}) {
      Log("onHTMLPreview: Missing parameters: table:".$options->{table}.":curSession:".$options->{curSession}.": !", $ERROR);
      return undef;
   }

   my $curtabledef = $self->{dbm}->getTableDefiniton($options->{table});

   if ( $options->{table} eq "projects" )
   {
       if ($self->{dbm}->{config}->{nojson})
       {
          if ($curtabledef->{readonly} || $options->{nobuttons}) {
             return ["","","",""];
          }
          return [CGI::escape( $self->{text}->{qx}->{new_project} ).",".CGI::escape("Bearbeiten").",".CGI::escape("Löschen").",".CGI::escape("Filter"),
                  CGI::escape("resource/qx/icon/Tango/32/actions/list-add.png").",".CGI::escape("/bilder/edit.png").",".CGI::escape("resource/qx/icon/Tango/32/actions/list-remove.png").",".CGI::escape("resource/qx/icon/Tango/32/actions/system-search.png"),
                  CGI::escape("neweditentry").",".CGI::escape("neweditentry").",".CGI::escape("delrow").",".CGI::escape("filter"),
                  CGI::escape("table").",".CGI::escape("row").",".CGI::escape("row").",".CGI::escape("table")];
       }

       my $return = [];
                        # here comes a hash of hash references
       push( @$return, ({
                name => "new",
                label => $self->{text}->{qx}->{new_project} ,
                image => "resource/qx/icon/Tango/".($options->{smallbuttons} ? "16" : "32")."/actions/list-add.png",
                action => "neweditentry",
                bindto => "table",
           }, {
                name => "edit",
                label => "Bearbeiten",
                image => ($options->{smallbuttons} ? "" : "/bilder/edit.png"),
                action => "neweditentry",
                bindto => "row",
           }, {
                name => "del",
                label => "Loeschen",
                image => "resource/qx/icon/Tango/".($options->{smallbuttons} ? "16" : "32")."/actions/list-remove.png",
                action => "delrow",
                bindto => "row",
       })) unless ($curtabledef->{readonly} || $options->{nobuttons} || $options->{readonly});

       return ["JSON", $return];
   } elsif ( $options->{table} eq "transactions" )
   {
       if ($self->{dbm}->{config}->{nojson})
       {
          if ($curtabledef->{readonly} || $options->{nobuttons}) {
             return ["","","",""];
          }
          return [CGI::escape("Beteiligen").",".CGI::escape("Beteiligung bearbeiten").",".CGI::escape("Löschen").",".CGI::escape("Filter"),
                  CGI::escape("resource/qx/icon/Tango/32/actions/list-add.png").",".CGI::escape("/bilder/edit.png").",".CGI::escape("resource/qx/icon/Tango/32/actions/list-remove.png").",".CGI::escape("resource/qx/icon/Tango/32/actions/system-search.png"),
                  CGI::escape("neweditentry").",".CGI::escape("neweditentry").",".CGI::escape("delrow").",".CGI::escape("filter"),
                  CGI::escape("table").",".CGI::escape("row").",".CGI::escape("row").",".CGI::escape("table")];
       }

       my $return = [];
                        # here comes a hash of hash references
       push( @$return, ({
                name => "new",
                label => "Beteiligen",
                image => "resource/qx/icon/Tango/".($options->{smallbuttons} ? "16" : "32")."/actions/list-add.png",
                action => "neweditentry",
                bindto => "table",
           }, {
                name => "edit",
                label => "Beteiligung_bearbeiten",
                image => ($options->{smallbuttons} ? "" : "/bilder/edit.png"),
                action => "neweditentry",
                bindto => "row",
           }, {
                name => "del",
                label => "Loeschen",
                image => "resource/qx/icon/Tango/".($options->{smallbuttons} ? "16" : "32")."/actions/list-remove.png",
                action => "delrow",
                bindto => "row",
       })) unless ($curtabledef->{readonly} || $options->{nobuttons} || $options->{readonly});

       return ["JSON", $return];
   } else
   {
       return $self->SUPER::getTableButtonsDef($options,$moreparams);
   }

}

1;
