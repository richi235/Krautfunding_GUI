package Krautfunding_GUI::Qooxdoo;

use strict;
use warnings;
use ADBGUI::BasicVariables;
use ADBGUI::Tools qw(Log);
use POE ;


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

    
    $self->onShow({table => "projects", curSession => $options->{curSession} , connection => $options->{connection}  }) ;
    

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
            $self->onShow({table => "transactions", curSession => $options->{curSession} , connection => $options->{connection}  });
            return ;
        }
       
  $self->SUPER::onClientData($options);
   
} 
1;
