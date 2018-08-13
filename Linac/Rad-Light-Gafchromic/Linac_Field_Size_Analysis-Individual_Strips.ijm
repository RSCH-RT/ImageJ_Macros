// 	- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -	//
//				LINAC FIELD SIZE USING STRIPS by Matt Bolt					//
// 	- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -	//
//													//
//	This is designed to measure radiation field size at 100/125cm FFD using 2 strips of Gafchromic			//
//	One strip will run along the CAX in orthogonal directions							//
//	Each side will be measured and given as a distance from the centre as defined by the crosswire marks		//
//													//
//	Field size determination is based on a pixel threshold determined from measurements				//
//													//
//	0 - Setup ImageJ ready for analysis to start								//
//	1 - Tolerance Levels & Standard Figures								//
//	2 - Field details are selected										//
//	3 - Cross wires marked										//
//	4 - Central ROI positioned										//
//	5 - Field edges determined										//
//	6 - Field Size calculated from field edges								//
//	7 - Option to check results, restart if required then and add comments					//
//	8 - Save results											//


var intx		//	Global Variables need to be specified outside of the macro
var inty
var ext1x
var ext1y
var ext2x
var ext2y
var X1Cx
var X1Cy
var X1edgex
var X1edgey
var X2Cx
var X2Cy
var X2edgex
var X2edgey
var Y1Cx
var Y1Cy
var Y1edgex
var Y1edgey
var Y1Cx
var Y1Cy
var Y1edgex
var Y1edgey
var edgex
var edgey
var outerx		//	these are the points of the extended line which are outside of the filed and are used to determine field edge.
var outery		//	profile analysed from centre to outer to look for field edge
var X1dist
var X2dist
var Y1dist
var Y2dist

macro "Linac_Field_Size_Analysis"{

version = "1.3";
update_date = "23 December 2016 by MB";

// + + + + + + + + + + + + + This whole macro is enclosed in a 'do... while' loop to allow analysis to be restarted if box at end is ticked i.e. if RepeatAnalysis = true + + + + + + + + + + + + + + + +

	myLinac = getArgument() ;  // optional variable passed by MS Access
	if(myLinac == "") {
		myLinac = "Select";
	}

///////	0	//////////	Setup ImageJ as required & get image info	/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	do {
	//requires("1.47p");
	run("Set Measurements...", "area mean standard min center bounding display redirect=None decimal=3");
	run("Profile Plot Options...", "width=450 height=300 interpolate draw sub-pixel");

	Dialog.create("Macro Opened");
	Dialog.addMessage("---- Linac Field Size Analysis using Individual Gafchromic Strips ----");
	Dialog.addMessage("Version: " + version);
	Dialog.addMessage("Last Updated: " + update_date);
	Dialog.addMessage("");
	Dialog.addMessage("Click OK to start");
	Dialog.show()

//********** Get image details & Tidy up Exisiting Windows
	
	if(myLinac=="Select") {
	   myDirectory = "G:\\Shared\\Oncology\\Physics\\Linac Field Analysis\\";
	} else {
   	   myDirectory = "G:\\Shared\\Oncology\\Physics\\Linac Field Analysis\\"+myLinac+"\\";
	}
   call("ij.io.OpenDialog.setDefaultDirectory", myDirectory);
   call("ij.plugin.frame.Editor.setDefaultDirectory", myDirectory);

	if (nImages ==0) {
		path = File.openDialog("Select a File");
		open(path);
	}

	print("\\Clear");							//	Clears any results in log
	run("Clear Results");
	run("Select None");
	roiManager("reset");
	roiManager("Show All");
	run("Line Width...", "line=1");						//	set line thickness to 1 pixel before starting

	myFileName = getInfo("image.filename");				//	gets filename & imageID for referencing in code
	myImageID = getImageID();
	selectImage(myImageID);
	name = getTitle;							//	gets image title and removes file extension for saving purposes
	dotIndex = indexOf(name, ".");
	SaveName = substring(name, 0, dotIndex);
	run("Set Scale...", "distance=0 known=0 pixel=1 unit=pixel");

	MonthNames = newArray("Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec");		//	get current date and display in desired format
	DayNames = newArray("Sun", "Mon","Tue","Wed","Thu","Fri","Sat");
	getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
	TimeString = ""+dayOfMonth+"-"+MonthNames[month]+"-"+year;

	if(dayOfMonth ==1) {
		YesterdayDay = 30;
		} else {
		YesterdayDay = dayOfMonth -1;
		}
	
	if(dayOfMonth ==1) {
		YesterdayMonth = MonthNames[month-1];
		} else {
		YesterdayMonth = MonthNames[month];
		}

	if(dayOfMonth == 1 && month == 0) {
		YesterdayYear = year-1;
		} else {
		YesterdayYear = year;
		}


///////	1	//////////	Tolerance Levels & Standard Figures	///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

     //     Constants used
	roiSize = 5;
	ProfileWidthmm = 5;				//	Sets the width of the measured profile in mm - aim is to average over a wider profile to avoid provlems with any noise/dust/dead pixels in image
	LineExtensionmm = 100;				//	extension of line beyond marked points in mm which must go beyond field edge

     //     Tolerance Levels
	FieldSizeTol = 2;					//	tolerance for field size is +/- 2mm

	ThresFactorChoices100 = newArray(1.31,1.31,1.31);	//	Edge threshold factors for each beam (6,10,15MV) - measured by taking exposures at 400 & 200MU.
	ThresFactorChoices125 = newArray(1.24,1.24,1.24);

	ImageWidthPx = getWidth();				//	returns image width in pixels
	ImageHeightPx = getHeight();

	ImageWidthA4mm = 215.9;				//	known regular scanner image width in mm (from scanner settings)
	ImageHeightA4mm = 297.2;

	ImageWidthA3mm = 309.9;				//	known large scanner image width in mm (from scanner settings)
	ImageHeightA3mm = 436.9;


	//	With Coll = 90 (standard setup)
	//	Gantry = X2		//	X1 and Y1 should be at the top pf the image, with X1 on the left. i.e. X1 is Left-North, Y1 is Left-South
	//	Target = X1
	//	B = Y1			//	X = left, Y = right
	//	A = Y2

///////	2	//////////	Field Details Selected	//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

	LinacChoices = newArray("LA1", "LA2", "LA3", "LA4", "LA5", "LA6","Red-A", "Red-B","Select");

	EnergyChoices = newArray("6 MV","10 MV","15 MV");
	FieldChoices = newArray("4x4cm","10x10cm","25x25cm","30x30cm");		// Setup so can do asym fields
	FFDChoices = newArray("100cm","125cm");
	CollChoices = newArray("0","90","270");

	FieldSizeX1Choices = newArray(20,50,125,150);				//	field size to that selected in FieldChoices
	FieldSizeX2Choices = newArray(20,50,125,150);				//	leaving these seperate leave option to do asym in future.
	FieldSizeY1Choices = newArray(20,50,125,150);				//	These are given in mm for calcs
	FieldSizeY2Choices = newArray(20,50,125,150);

	FFDChoicesVal = newArray(100,125);					//	FFD used to calculate field size measured

	ScannerChoices = newArray("V750 Pro","11000XL Pro");

	DayChoices = newArray(31);			//	length of array
		for(i=0; i<DayChoices.length; i++)	//	set incremental values in array
		DayChoices[i] = d2s(1+i,0);
	MonthChoices = newArray("Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec");
	YearChoices = newArray(11);
		for(i=0; i<YearChoices.length; i++)
		YearChoices[i] = d2s(2010+i,0);

	Dialog.create("Field Details");
	Dialog.addMessage("--- Date of Exposure ---");
	Dialog.addChoice("Day", DayChoices, YesterdayDay);
	Dialog.addChoice("Month", MonthChoices, YesterdayMonth);
	Dialog.addChoice("Year", YearChoices, YesterdayYear);
	Dialog.addMessage("--- Exposure Details ---");

	if(myLinac == "Red-A" || myLinac == "Red-B") {
	Dialog.addChoice("Scanner", ScannerChoices,ScannerChoices[0]);
	} else {
	Dialog.addChoice("Scanner", ScannerChoices,ScannerChoices[1]);
	}

	Dialog.addChoice("Linac", LinacChoices, myLinac);
	Dialog.addChoice("Coll.", CollChoices, "90");
	Dialog.addChoice("Energy", EnergyChoices);
	Dialog.addChoice("Field Size", FieldChoices,FieldChoices[3]);
	Dialog.addChoice("FFD", FFDChoices);
	Dialog.show();

	DaySelected = Dialog.getChoice();
	MonthSelected = Dialog.getChoice();
	YearSelected = Dialog.getChoice();

	DateSelected = DaySelected + "-" + MonthSelected + "-" + YearSelected;

	ScannerSelected = Dialog.getChoice();

	LinacSelected = Dialog.getChoice();
	CollSelected = Dialog.getChoice();
	EnergySelected = Dialog.getChoice();
	FieldSelected = Dialog.getChoice();
	FFDSelected = Dialog.getChoice();

	FieldSelectedPos = ArrayPos(FieldChoices,FieldSelected);		//	get values from known position in array using function
	
	FFDSelectedPos = ArrayPos(FFDChoices,FFDSelected);

	FieldSizeX1Selected = FieldSizeX1Choices[FieldSelectedPos];
	FieldSizeX2Selected = FieldSizeX2Choices[FieldSelectedPos];
	FieldSizeY1Selected = FieldSizeX1Choices[FieldSelectedPos];
	FieldSizeY2Selected = FieldSizeX2Choices[FieldSelectedPos];

	FFDSelected = FFDChoicesVal[FFDSelectedPos];

	EnergySelectedPos = ArrayPos(EnergyChoices,EnergySelected);
	
	if(FFDSelected == 100) {							//	Selects threshold factor based on FFD and energy
		ThresFactor = ThresFactorChoices100[EnergySelectedPos];
		} else {
		ThresFactor = ThresFactorChoices125[EnergySelectedPos];
		}
	
	if(ScannerSelected == "11000XL Pro") {
		ImageWidthSelectedmm = ImageWidthA3mm;
		ImageHeightSelectedmm = ImageHeightA3mm;
		ScannerModelSelected = "Epsom Expression 11000 Pro XL";
		//run("View 100%");						//	zoom on image
		} else {
		ImageWidthSelectedmm = ImageWidthA4mm;
		ImageHeightSelectedmm = ImageHeightA4mm;
		ScannerModelSelected = "Epsom Perfection V750 Pro";
		}

	EWscale = ImageWidthPx / ImageWidthSelectedmm;				//	gives conversion factor from px to mm from scanner selected
	NSscale = ImageHeightPx / ImageHeightSelectedmm;
	AVGscale = 0.5*(EWscale+NSscale);

	LineExtensionpx = LineExtensionmm * NSscale;

	print("------------------------------------------------------------------------");
	print("                    Linac Field Analysis Results");
	print("------------------------------------------------------------------------");
	print("\n");
	print("File Analysed:   \t" +myFileName);
	print("Exposure Date:   \t" + DateSelected);
	print("Analysis Date:   \t" +TimeString);
	print("Macro Version:"+version);
	print("\n");
	print("Scanner:   \t" + ScannerModelSelected);
	print("Linac:   \t" + LinacSelected);
	print("Coll.:   \t" + CollSelected);
	print("Energy:   \t" + EnergySelected);
	print("Field Size:   \t" + FieldSelected);
	print("FFD:   \t" + FFDSelected + "cm");
	print("\n");

	//print("-----------  Field Size (cm)  (Tol: +/- " + FieldSizeTol + " mm)  ----------");
	//print("Length  \t| Std.    \t| Meas.   \t| Result");
	print("----------- Field Size (cm) ----------");
	print("");
	print("Field Size Tol (mm): " + FieldSizeTol);


///////	SELECT JAW & RUN ANALYSIS FUNCTION	//////////////////////////////////////////////////////////////////////////////////////////

	jawChoices = newArray("X1","X2","Y1","Y2","All Jaws Complete");	//	use position in array to move through each time
	jawSelected = jawChoices[0];

	jawSelectedPos = ArrayPos(jawChoices,jawSelected);

	while (jawSelected != jawChoices[jawChoices.length-1]) {		//	Used to loop through each jaw during analysis.

	jawSelected = jawChoices[jawSelectedPos];

	Dialog.create("Jaw Selection");
	Dialog.addMessage("Select Jaw to Analyse");
	Dialog.addChoice("Jaw:", jawChoices,jawSelected);
	Dialog.show();

	jawSelected = Dialog.getChoice;
	jawSelectedPos = ArrayPos(jawChoices,jawSelected);


	if(jawSelected != jawChoices[jawChoices.length-1]) {	//	Do not want to do analysis if "Completed" is selected.
	AnalyseJaw(jawSelected);				//	This will pass the selected jaw name to the function which will contain all the analysis within it.
	}

	if(jawSelectedPos < jawChoices.length-1) {		//	this should happen at the end of the loop so that selected jaw can be referred to during the loop
	jawSelectedPos = ArrayPos(jawChoices,jawSelected)+1;
	}
	}							//	End of While Loop for Each Jaw


///////	7	//////////	Option to Check Results & Restart Analysis	//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

	waitForUser("Analysis Complete", "Check Results Displayed In Log Window.   Press OK to Continue");	//	user can check results prior to adding comments


	Dialog.create("Restart Analysis");
	Dialog.addMessage("Tick to restart analysis. Results will NOT be saved if you do this");
	Dialog.addCheckbox("Restart Analysis",false);
	Dialog.addMessage("Press OK to continue");
	Dialog.show();

	RepeatAnalysis = Dialog.getCheckbox();

	} while (RepeatAnalysis == true);

// + + + + + + + + + + + + + This whole macro above is enclosed in a 'do... while' loop to allow analysis to be restarted if box at end is ticked i.e. if RepeatAnalysis = true;. + + + + + + + + + + + + + + + +


///////	8	//////////	Add Comments & Save Results & Close Windows	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


	Dialog.create("Comments");							//	Allows user to insert comments if required. Default is "Results OK" These are then added to Log
	Dialog.addMessage("Add any Comments in the Box Below");
	Dialog.addString("Comments:", "(None)",40);
	Dialog.addMessage("");
	Dialog.addString("Analysis Performed by:", "",10);
	Dialog.addMessage("Click OK to Continue");
	Dialog.show();

	print("\n");
	print("-----------  Comments  -----------");
	print(Dialog.getString());
	print("\n");
	print("-----------  Analysis Performed by  -----------");
	print(Dialog.getString());
	print("\n");
	print("------------------------------------------------------------------------");
	print("                    End of Results");
	print("------------------------------------------------------------------------");


	selectWindow("Results");							//	close results window and position log window so visible
	setLocation(0,0);
	run("Close");
	selectWindow("Log");
	setLocation(0,0);

	selectImage(myImageID);							//	Brings image ROI Manager & Log into focus
	selectWindow("ROI Manager");
	selectWindow("Log");
	
	Dialog.create("~~ Save Results ~~");						//	Asks user if they want to save results (as a text file). If they select cancel, the macro wil exit, therefore the save will not occur.
	Dialog.addMessage("Save the Results?");
	Dialog.show();

	selectWindow("Log");							//	Get data from log window for transfer to Text window to save
	contents = getInfo();

	FileExt = ".txt";
	title1 = SaveName + "_Results" + FileExt;					//	Title of log window is filename without extension as defined at start.
	title2 = "["+title1+"]";							//	Repeat
	f = title2;
	if (isOpen(title1)) {
		print(f, "\\Update:");
		selectWindow(title1); 						//	clears the window if already one opened with same name
	} else {
		run("Text Window...", "name="+title2+" width=72 height=60");
	}
	setLocation(screenWidth(),screenHeight());					//	Puts window out of sight
	print(f,contents);
	saveAs("Text");
	run("Close");		
	
	Dialog.create("Close Windows");
	Dialog.addMessage("Record Results Displayed in Log Window");
	Dialog.addCheckbox("Close All Open Images?",true);
	Dialog.addCheckbox("Close All Open Windows?",true);
	Dialog.addMessage("Press OK to continue");
	Dialog.show();

	doCloseIm = Dialog.getCheckbox();	//	returns true or false value for function
	doCloseW = Dialog.getCheckbox();	//	returns true or false value for function

	if (doCloseW == true) {
		closeWindows();
	}

	if (doCloseIm == true) {
		closeImages();
	}
	}
// ------------------------------------- End of Field Size & Uniformity Macro ---------------------------------------------------------------------------------------------------------------

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//
//	Functions below are used within the macro and should be kept in the same file as the above macro
//
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// ----------------------------------- MAKE RECTANGLE ROI FUNCTION -------------------------------------------------------------------------
function RectROI(x, y, width, height, name, colour) {
 
	makeRectangle(x, y, width, height);				//	make rectangle ROI at specified location with specified name and colour
	roiManager("Add");
	roiManager("Select",roiManager("count")-1);
	roiManager("Rename", name);
	roiManager("Set Color", colour);
}
//----------------------- End of Make Rect Function ---------------------------------------------------------------------------------------------


// ----------------------------------- MAKE POINT FUNCTION (This is used when defining the field edges) -------------------------------------------------------------------------
function Point(x, y, name, colour) {

	makePoint(x,y);						//	plot point with given coord and rename
	roiManager("Add");
	roiManager("Select", roiManager("count")-1);
	roiManager("Rename", name);
	roiManager("Set Color", colour);
}
//----------------------- End of Make Point Function ---------------------------------------------------------------------------------------------


// ----------------------------------- MAKE EXTENDED LINE FUNCTION -------------------------------------------------------------------------
function LineExt(x1,y1,x2,y2, ext1,ext2,name, colour) {			//	extension is specified in pixels for function (and so may require converting before use)

	grad = ( y2-y1 ) / (x2 - x1);

	angle = atan(grad);

	if(x2-x1<0) {
	ext1x = x1+(ext1*cos(angle));
	ext1y = y1+(ext1*sin(angle));
	ext2x = x2-(ext2*cos(angle));
	ext2y = y2-(ext2*sin(angle));
	} else {
	ext1x = x1-(ext1*cos(angle));
	ext1y = y1-(ext1*sin(angle));
	ext2x = x2+(ext2*cos(angle));
	ext2y = y2+(ext2*sin(angle));
	}

	makeLine(ext1x,ext1y, ext2x, ext2y);					//	Make line between specified points with specified name and colour
	roiManager("Add");
	roiManager("Select",roiManager("count")-1);
	roiManager("Rename", name);
	roiManager("Set Color", colour);

}
//----------------------- End of Make Extended Line Function ---------------------------------------------------------------------------------------------


// ----------------------------------- FIND SINGLE EDGE FUNCTION -------------------------------------------------------------------------

function FindSingleEdge(x1,y1,x2,y2, width,thres,name, offset) {		//	pts 1 & 2 are the ends of the line
								//	offset allows the i+n'th value to be returned. Set as 0 if none required
								//	width is profile width, thres1/2 are the edge thresholds, name is the name of the edge point created
								//	analysis will start from point 1 and work along the profile to point 2.

	run("Line Width...", "line=" + width);				//	Set profile measurement width in pixels

	xC = (x1+x2)/2;						//	create a central point for line fitting function
	yC = (y1+y2)/2;

	DoubleLine(x1,y1,xC,yC,x2,y2,"Line1");			//	need 3 points along line to run the fit

	run("Fit Spline", "straighten");				//	fit a 'curve' which allows to get profile along this curve and extract coords
	getSelectionCoordinates(x,y);

	profileA = getProfile();					//	get profile values

	endPt = profileA.length;					//	end point of profile (and analysis values) is final value in profile
	startPt = 0;						//	start at beginning of profile

     //******* Find Edge Point

	i = startPt;
	while (profileA[i] < thres) {			//	start at chosen point (centre) and check all points until one passes thres.
		i = i+1;
	}

	edgex = x[i+offset];					//	set the coords of this point as new point
	edgey = y[i+offset];					//	offset allows the i+n'th value to be returned instead of that found.

	Point(edgex, edgey, name, "red");					//	use function to create new point on edge located
	
	roiManager("Select", roiManager("count")-2);			//	delete line created for profile after its been used
	roiManager("Delete");

	run("Line Width...", "line=1");					//	set line width back to 1 pixel

}
//----------------------- End of Find Single Edge Function ---------------------------------------------------------------------------------------------


// ----------------------------------- MAKE DOUBLE LINE FUNCTION (This is used when defining the field edges) -------------------------------------------------------------------------
function DoubleLine(x1, y1, x2, y2, x3, y3, name) {

	makeLine(x1, y1, x2, y2, x3, y3);				//	draw line from pt 1, through mid to pt 2 (need 3 points for simple extraction of coords below)
	roiManager("Add");
	roiManager("Select", roiManager("count")-1);
	roiManager("Rename", name);
}
//----------------------- End of Make Line Function ---------------------------------------------------------------------------------------------


//----------------------- FIND INTERSECTION FUCNTION -------------------------------------------------------------------------------------------------

function findIntersection(xi1, yi1, xi2, yi2, xi3, yi3, xi4, yi4) {

	intx = 0;
	inty = 0;
	
	if(xi4 - xi3!=0 && xi2 - xi1!=0) {				//	If either line registers as Leftical, then need to use alternative solving methods
		grad1 = (yi2 - yi1) / (xi2 - xi1);
		grad2 = (yi3 - yi4) / (xi3 - xi4);
		intx = ((yi3 - yi1) + (xi1 * grad1) - (xi3 * grad2)) / (grad1 - grad2);
		inty = grad1 * (intx - xi1) + yi1;
		} else {
	if(xi1 - xi2!=0) {
		intx = xi3;
		grad2 = (yi1 - yi2) / (xi1 - xi2);
		inty = (grad2 * xi3) + (yi1 - (grad2 * xi1));
		} else {
		intx = xi1;
		grad1 = (yi3 - yi4) / (xi3 - xi4);
		inty = (grad1 * xi1) + (yi3 - (grad1 * xi3));
		}
	}
	}

	}
//----------------------- End of Function findIntersection ---------------------------------------------------------------------------------------------


//---------------------- Calculate Distance Between Points -------------------------------------------------------------------------------------------

function calcDistance(a, b, c, d) {

	myDist = sqrt(pow(a-c,2) + pow(b-d,2));			//	calc distance between two coordinates A and B, A = (a,b) B = (c,d)
	return myDist;
       
	}
// ----------------------------------End of Function calcDistance------------------------------------------------------------------------------------------


//---------------------- Determine Position of Selection in Array -------------------------------------------------------------------------------------------

function ArrayPos(a, value) {				//	'a' is the array to be checked, value is the value to be looked up
						//	It is unknown what would happen if there were duplicate values within 'a'.
	for(i=0; i<a.length; i++)			//	This is not an issue in this case
		if(a[i]==value) return i;
	return -1;					//	if the value is not found in the array, '-1' is returned to indicate this.

	}
// ----------------------------------End of Function ArrayPos ------------------------------------------------------------------------------------------

//-------------------------------------- Function closeWindows -----------------------------------------------

function closeWindows() {
// closes all non-image windows except log window

	list = getList("window.titles"); 		//	closes all non-image windows
	    for (i=0; i<list.length; i++) { 

		wName = list[i]; 
		if (wName != "Log") {
		    	selectWindow(wName); 
			run("Close"); 
		}
	    } 

}
//-------------------------------------- End of Function closeWindows -----------------------------------------------

//-------------------------------------- Function closeImages -----------------------------------------------

function closeImages() {

	while (nImages>0) { 			//	closes all open images
	    selectImage(nImages); 
	    close(); 
	}  
}

//-------------------------------------- End of Function closeImages -----------------------------------------------


//*******************************************************************************************************
//*******************************************************************************************************
//*******************************************************************************************************
//*******************************************************************************************************
//*******************************************************************************************************
//*******************************************************************************************************

//-------------------------------------- Function AnalyseJaw -----------------------------------------------

function AnalyseJaw(jaw) {			//	jaw is the name of the jaw passed to the function

	//print(jaw);
	
	NSlineName = jaw + "-Line-NS";
	WElineName = jaw + "-Line-WE";
	ROICentreName = jaw + "-CentreROI";
	edgeName = jaw + "-Edge";

	run("Select None");
	run("View 100%");

	resultscountstart = nResults;		//	used to check 4 points have been selected for the jaw

	setTool("multipoint");								
	waitForUser(jaw + " Crosswire Selection", "Select 4 Crosswire Marks for the " + jaw + " Jaw.\n \nStart at Top and Work Clockwise\n \nEnsure that RED channel is selected using scroll bar at bottom of image\n \nClick OK when complete");

	run("Measure");				//	need to measure to get the point info

	resultscountend = nResults;		//	used to check 4 points have been selected

	selectWindow("Results");								//	moves results window out of view
	setLocation(screenWidth()*0.95,screenHeight()*0.95);




	while(resultscountend - resultscountstart !=4) {
		run("Clear Results");							//	use to clear results if wrong # pts selected
		run("Select None");
		resultscountstart = nResults;
		setTool("multipoint");							//	4 points only should be selected for analysis
		waitForUser("You must select 4 crosswire points to continue");
		run("Measure");
		resultscountend = nResults;
	}


	arrX = newArray(4);							//	create array with 4 selected points
	arrY = newArray(4);
	for (i=0; i<4;i++) {							//	Get coords of 4 Selected Points and place into Array
		arrX[i] = getResult("X",nResults-4+i);
		arrY[i] = getResult("Y",nResults-4+i);


		NX = arrX[0];							//	Get Coords from array for each point to allow calc of intersection
		NY = arrY[0];							//	LNX is the X coord of the North (top) point on the Left side of image (should be X jaw strip)
		EX = arrX[1];
		EY = arrY[1];
		SX = arrX[2];
		SY = arrY[2];
		WX = arrX[3];
		WY = arrY[3];
	}

	LineExt(NX,NY,SX,SY, LineExtensionpx,0,NSlineName, "yellow");		//	extends the line based on the marked points
		outerx = ext1x;
		outery = ext1y;

	LineExt(WX,WY,EX,EY, 0,0,WElineName, "yellow");



///////		//////////	Central ROI positioned & measured	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


	findIntersection(WX, WY, EX, EY, NX, NY, SX, SY);		//	Find Intersection to give coords of centre of field

	roiDiamNS = roiSize * NSscale;		 			//	sizes the roi (in pix) based on scale factor and roi size selected
	roiRadNS = 0.5*roiDiamNS;			 		//	gives radius to simplify positioning below
	roiDiamEW = roiSize * EWscale;					//	NS and EW are kept seperate to allow for different scaling in each direction
	roiRadEW = 0.5*roiDiamEW;

	RectROI(intx-roiRadEW,inty-roiRadNS, roiDiamEW, roiDiamNS,ROICentreName,"red");
	run("Measure");
	RAWmeanROIcentre = getResult("Mean");		


///////		//////////	Field Edges Determined	//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

	ThresVal = RAWmeanROIcentre * ThresFactor;			//	Converts central value to 50% pixel value using multiplication factor

			FindSingleEdge(intx,inty,outerx,outery, ProfileWidthmm * EWscale,ThresVal,edgeName, 0);

	//run("Original Scale");

	setTool("multipoint");
	selectWindow("ROI Manager");
	setLocation(0.8*screenWidth(),0);
	roiManager("Select", roiManager("count") - 1);

		waitForUser("Field Edge Correct?", "Has the " + jaw + " edge been located correctly?\n \nAdjust points manually by selecting with the ROI Manager if Required\nYou may need to Zoom in to precisely position the points\n \nPress OK to continue");

	setTool("Hand");

	roiManager("Select", roiManager("count") - 1);			//	measure coords of field edges after any possible movement
	run("Measure");

	edgex = getResult("X", nResults - 1);
	edgey = getResult("Y", nResults - 1);

	if(jaw == "X1") {			//	these give the coordinates of the centre and edge for each jaw for use in calculations of field size etc
		X1Cx = intx;			//	if a jaw is measured twice, the second measurement will overwrite the first
		X1Cy = inty;
		X1edgex = edgex;
		X1edgey = edgey;
		X1dist = calcDistance(X1Cx,X1Cy,X1edgex,X1edgey);
		X1distmm = X1dist / AVGscale;

		if(X1distmm < FieldSizeX1Selected + FieldSizeTol && X1distmm > FieldSizeX1Selected - FieldSizeTol) {
			ResultFieldSizeDiffX1 = "OK";
			} else {
			ResultFieldSizeDiffX1 = "FAIL";
		}

		//print("X1 (G)  \t| " + d2s(FieldSizeX1Selected/10,1) + "  \t| " + d2s(X1distmm/10,2) + " \t| " + ResultFieldSizeDiffX1);
		print("");
		print("X1 (G) Std: " + d2s(FieldSizeX1Selected/10,1));
		print("X1 (G) Meas: " + d2s(X1distmm/10,2));
		print("X1 (G) Result: " + ResultFieldSizeDiffX1);
	}

	if(jaw == "X2") {
		X2Cx = intx;
		X2Cy = inty;
		X2edgex = edgex;
		X2edgey = edgey;
		X2dist = calcDistance(X2Cx,X2Cy,X2edgex,X2edgey);
		X2distmm = X2dist / AVGscale;

		if(X2distmm < FieldSizeX1Selected + FieldSizeTol && X2distmm > FieldSizeX2Selected - FieldSizeTol) {
			ResultFieldSizeDiffX2 = "OK";
			} else {
			ResultFieldSizeDiffX2 = "FAIL";
		}

		//print("X2 (T)  \t| " + d2s(FieldSizeX2Selected/10,1) + "  \t| " + d2s(X2distmm/10,2) + " \t| " + ResultFieldSizeDiffX2);
		print("");
		print("X2 (T) Std: " + d2s(FieldSizeX2Selected/10,1));
		print("X2 (T) Meas: " + d2s(X2distmm/10,2));
		print("X2 (T) Result: " + ResultFieldSizeDiffX2);
	}

	if(jaw == "Y1") {
		Y1Cx = intx;
		Y1Cy = inty;
		Y1edgex = edgex;
		Y1edgey = edgey;
		Y1dist = calcDistance(Y1Cx,Y1Cy,Y1edgex,Y1edgey);
		Y1distmm = Y1dist / AVGscale;

		if(Y1distmm < FieldSizeY1Selected + FieldSizeTol && Y1distmm > FieldSizeY1Selected - FieldSizeTol) {
			ResultFieldSizeDiffY1 = "OK";
			} else {
			ResultFieldSizeDiffY1 = "FAIL";
		}

		//print("Y1 (B)  \t| " + d2s(FieldSizeY1Selected/10,1) + "  \t| " + d2s(Y1distmm/10,2) + " \t| " + ResultFieldSizeDiffY1);
		print("");
		print("Y1 (B) Std: " + d2s(FieldSizeY1Selected/10,1));
		print("Y1 (B) Meas: " + d2s(Y1distmm/10,2));
		print("Y1 (B) Result: " + ResultFieldSizeDiffY1);
	}

	if(jaw == "Y2") {
		Y2Cx = intx;
		Y2Cy = inty;
		Y2edgex = edgex;
		Y2edgey = edgey;
		Y2dist = calcDistance(Y2Cx,Y2Cy,Y2edgex,Y2edgey);
		Y2distmm = Y2dist / AVGscale;

		if(Y2distmm < FieldSizeY2Selected + FieldSizeTol && Y2distmm > FieldSizeY2Selected - FieldSizeTol) {
			ResultFieldSizeDiffY2 = "OK";
			} else {
			ResultFieldSizeDiffY2 = "FAIL";
		}

		//print("Y2 (A)  \t| " + d2s(FieldSizeY2Selected/10,1) + "  \t| " + d2s(Y2distmm/10,2) + " \t| " + ResultFieldSizeDiffY2);
		print("");
		print("Y2 (A) Std: " + d2s(FieldSizeY2Selected/10,1));
		print("Y2 (A) Meas: " + d2s(Y2distmm/10,2));
		print("Y2 (A) Result: " + ResultFieldSizeDiffY2);

	}
	}
	
//-------------------------------------- Function AnalyseJaw -----------------------------------------------

//*******************************************************************************************************
//*******************************************************************************************************
//*******************************************************************************************************
//*******************************************************************************************************
//*******************************************************************************************************
//*******************************************************************************************************




// 	- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -	//
//				END OF LINAC FIELD SIZE	USING INDIVIDUAL STRIPS					//
// 	- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -	//
