EPICS-SRSPS365
==============

Here I document a tutorial which uses EPICS to control a power supply (Stanford Research Systems PS365) using a "stream" driver.  This driver sends SCPI commands via serial port to the power supply.  EPICS allows other users to query and set values to control the power supply over a LAN.  This is a simple, but non trivial (to this newbie) example.  In the wiki I document the struggle, from installation of all the EPICS base to implementation of the "driver" from scratch.
