:: This opens and runs an imageJ macro as specified.

ECHO OFF
ECHO Launching ImageJ...
ECHO ...
ECHO This command window will stay open until ImageJ is closed

:: Set path to macro which you would like to run below
:: Note that the macro should be in the same folder as this .bat file or it will not launch.

set macrofile="Papillon_Audit_2015.txt"

java -jar "C:\Program Files\ImageJ\ij.jar" -macro %macrofile%
