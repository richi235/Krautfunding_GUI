Krautfunding GUI
================
Krautfunding GUI is designed for the tracking of crowdfunding projects in Hackerspaces and communities.  
It lets you:
 * Create user accounts.
 * Create and configure projects
 * Create, manipulate and delete fundings for a project
   * by double-clicking on that project


## Installation on Debian GNU+Linux or Ubuntu (12.04-14.10)
```bash
# set the name used by the installer
export PROJECTNAME=Krautfunding_GUI

# Download and rename the Framework 
git clone https://github.com/pRiVi/ADBGUI.git
mv ADBGUI $PROJECTNAME
cd $PROJECTNAME

# Download the Krautfunding_GUI slice pack
git clone https://github.com/richi235/Krautfunding_GUI/

# call the installer
install/installscript qx noap
```
## Usage
Start your Crowdfunding managment with:   
``` perl dbm.pl ```   
Per default Krautfunding GUI listens on port: **8181**.   
(This can be changed in the file ```dbm.cfg``` in the ADBGUI root folder, key: ```QooxdooListenPort```)



