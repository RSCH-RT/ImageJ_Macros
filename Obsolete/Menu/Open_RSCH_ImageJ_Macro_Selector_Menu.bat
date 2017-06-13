:: This opens and runs an imageJ macro (which will allow user to launch other IJ macros).

:: hide the text in the cmd window on opening
@ECHO OFF

:: specify the path and macro file to run
set filename="ImageJ_Macro_Selector_Menu.txt"
set pathname="G:\Shared\Oncology\Physics\Linac Field Analysis\Menu"

:: combine the path and the filename to get the full address
set macrofile=%pathname%\\%filename%

::launch ImageJ and run the specified macro
start javaw -jar "C:\Program Files\ImageJ\ij.jar" -macro %macrofile%

:: add some text to indicate the things are loading.
echo.
echo This window will close after a short time.
echo.
echo Launching ImageJ...
timeout /t 1 >nul
cls
echo.
echo This window will close after a short time.
echo.
echo Launching ImageJ......
timeout /t 1 >nul
cls
echo.
echo This window will close after a short time.
echo.
echo Launching ImageJ.........
timeout /t 1 >nul
