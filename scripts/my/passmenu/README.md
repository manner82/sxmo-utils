A modified version of passmenu for my sxmo.
To use it, copy it to the device, eg under /usr/local/bin/

And create some icons to scripts, eg for basic password typing:

    $ ls -lh .config/sxmo/userscripts/passmenu
    [...] .config/sxmo/userscripts/passmenu -> /usr/local/bin/passmenu

This copies the password to the clipboard for 60 seconds:

    $ cat .config/sxmo/userscripts/passmenu-copy
    #! /bin/sh
     
    /usr/local/bin/passmenu --copy

This types in the username (second line of the pass entry):

    $ cat .config/sxmo/userscripts/passmenu-user
    #! /bin/sh
    
    /usr/local/bin/passmenu user
