EPICS-SRSPS365
==============

Here I document a tutorial which uses EPICS to control a power supply (Stanford Research Systems PS365) using a "stream" driver.  This driver sends SCPI commands via serial port to the power supply.  EPICS allows other users to query and set values to control the power supply over a LAN.  This is a simple, but non trivial (to this newbie) example.  In the wiki I document the struggle, from installation of all the EPICS base to implementation of the "driver" from scratch.

## Installation Instructions:

```
cd <Directory Where you Keep IOC apps>
git clone https://github.com/fullerf/EPICS-SRSPS365.git <desired application name>
./genSCPItemplate.pl
```

You have to hit enter once in that perl script.  I'll fix that later, but otherwise it builds the ioc and should result in a functional ioc.

So far tested to work on the following operating systems:

* OS X Mavericks

### Known Bugs:

* Occasionally while running the ioc a `caput` to modify `$(P)$(R)HVset` results in a segmentation fault (error 11).  Usually this will happen straight away on the first attempt to change the voltage.  Restarting the ioc (sometimes several times) appears to fix the issue.  Would definitely like to solve this.

