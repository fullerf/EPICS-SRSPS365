#!../../bin/$[EPICS_HOST_ARCH]/$[APP_NAME]


##########################################
# Setup Environment
< envPaths
epicsEnvSet "STREAM_PROTOCOL_PATH" "$(TOP)/db"

##########################################
# Allow PV prefixes and serial port name to be set from the environment
epicsEnvSet "P" "$(P=$[P])"
epicsEnvSet "R" "$(R=$[R])"
epicsEnvSet "TTY" "$(TTY=$[TTY])"

##########################################
# Register all support components
cd ${TOP}
dbLoadDatabase(dbd/$[APP_NAME].dbd)
$[APP_NAME]_registerRecordDeviceDriver(pdbbase)

##########################################
# Set up ASYN ports
drvAsynSerialPortConfigure("L0","$(TTY)",0,0,0) #sets up a port L0 at $(TTY) (see above)
#now we fill in the details of the port connection
#9600/8/N/1 is the most typical serial port configuration
asynSetOption("L0",0,"baud","$[BAUD]")
asynSetOption("L0",0,"bits","$[BITS]")
asynSetOption("L0",0,"parity","$[PARITY]")
asynSetOption("L0",0,"stop","$[STOP]")

##########################################
## Load record instances
dbLoadRecords("db/dev$[APP_NAME].db","P=$(P),R=$(R),PORT=L0,A=0")

##########################################
# Start EPICS
cd ${TOP}/iocBoot/${IOC}
iocInit
