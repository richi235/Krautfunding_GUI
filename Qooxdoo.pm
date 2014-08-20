package Krautfunding_GUI::Qooxdoo;

use strict;
use warnings;
use ADBGUI::BasicVariables;
use ADBGUI::Tools qw(Log);
use POE ;
# use Data::Dumper ; # can be used for debug output


our @ISA;

sub new {
    my $proto  = shift;
    my $class  = ref($proto) || $proto;
    my $self   = shift;
    my $parent = $self ? ref($self) : "";
    @ISA = ($parent) if $parent;
    $self = $self ? $self : {};
    bless( $self, $class );
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

            # use Dumper for debugging output
            # print (Dumper($result_set));
            # die ;
            
            
               # only work with result set if we got correct data
            if ( ref($result_set) eq "ARRAY" ) {
                $project_name = $result_set->[0]->[0]->{$options->{table}.$TSEP.'Name'};
            } else {
                 log("Wanted to get project name from id, got no or corrupted data");
            }
            

            # display the window with the correct title
            $self->onShow({table => "transactions", curSession => $options->{curSession} , connection => $options->{connection} , windowtitle => "Spenden fuer: $project_name"  });
            return ;
        }
       
  $self->SUPER::onClientData($options);
   
} 
1;
