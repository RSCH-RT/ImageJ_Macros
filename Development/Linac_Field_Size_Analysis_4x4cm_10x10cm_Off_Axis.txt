// 	- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -	//
//				LINAC FIELD SIZE by Matt Bolt						//
// 	- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -	//
//													//
//	This is designed to measure from 4cm, 10cm, 20cm and 10cm @125FSD (12.5cm) radiation field sizes		//
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


var intX		//	Global Variables need to be specified outside of the macro
var intY
var a1
var a2
var b1
var b2
var c1
var c2
var d1
var d2

macro "Linac_Field_Size_Analysis"{

// + + + + + + + + + + + + + This whole macro is enclosed in a 'do... while' loop to allow analysis to be restarted if box at end is ticked i.e. if RepeatAnalysis = true + + + + + + + + + + + + + + + +

version = "0.1";
update_date = "23 March 2016 by MB";

///////	0	//////////	Setup ImageJ as required & get image info	/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	do {
	requires("1.47p");
	run("Set Measurements...", "area mean standard min center bounding display redirect=None decimal=3");
	run("Profile Plot Options...", "width=450 height=300 interpolate draw sub-pixel");

	Dialog.create("Macro Opened");
	Dialog.addMessage("---- Linac Field Size Analysis (Off-Axis) ----");
	Dialog.addMessage("Version: " + version);
	Dialog.addMessage("Last Updated: " + update_date);
	if(nImages==0) {
		Dialog.addMessage("");
		Dialog.addMessage("You will be prompted to open the required image after clicking OK");
	}
	Dialog.addMessage("Click OK to start");
	Dialog.show()

//********** Get image details & Tidy up Exisiting Windows
	
   myDirectory = "G:\\Shared\\Oncology\\Physics\\RTPhysics\\EBRT Dosimetry\\Filmless Analysis\\Redhill CAP";
   call("ij.io.OpenDialog.setDefaultDirectory", myDirectory);
   call("ij.plugin.frame.Editor.setDefaultDirectory", myDirectory);

	if (nImages ==0) {
		//showMessageWithCancel("Select Image","Select image to analyse after clicking OK");		//	ensures an image is open before macro runs
		path = File.openDialog("Select a File");
		open(path);
	}

	origImageID = getImageID();

//	if (bitDepth() != 24) {						// 	Will create RGB stack is created if required (RGB is 24bit)
//		run("Stack to RGB");					//	probably not to be used as want to analyse only RED channel
//		selectImage(origImageID);
//		close();
//	}
	
	print("\\Clear");							//	Clears any results in log
	run("Clear Results");
	run("Select None");
	roiManager("reset");
	roiManager("Show All");
	run("Line Width...", "line=1");						//	set line thickness to 1 pixel before starting

	defaultSaveDirectory = "G:\\Shared\\Oncology\\Physics\\RTPhysics\\EBRT Dosimetry\\Monthly QA\\Field Size";
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

	ImageWidthPx = getWidth();				//	returns image width in pixels
	ImageHeightPx = getHeight();

	ImageWidthA4mm = 215.9;				//	known regular scanner image width in mm (from scanner settings)
	ImageHeightA4mm = 297.2;

	ImageWidthA3mm = 309.9;				//	known large scanner image width in mm (from scanner settings)
	ImageHeightA3mm = 436.9;

///////	1	//////////	Tolerance Levels & Standard Figures	///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

     //     Constants used
	roiSize = 5;
	ProfileWidthmm = 4;				//	Sets the width of the measured profile in mm - aim is to average over a wider profile to avoid provlems with any noise/dust/dead pixels in image


     //     Tolerance Levels
	FieldSizeTol = 2;			// tolerance for field size is +/- 2mm


	
	ThresFactorChoices100 = newArray(1.31,1.31,1.31);		//	Edge threshold factors for each beam (6,10,15MV) - measured by taking exposures at 400 & 200MU.
	ThresFactorChoices125 = newArray(1.24,1.24,1.24);		//	This is a multipilication factor for finding 50% pixel value for each energy


///////	2	//////////	Field Details Selected	//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

	LinacChoices = newArray("LA 1 (2008)", "LA 2 (2010)", "LA 3 (2006)", "LA 4 (2007)", "LA 5 (2005)", "LA 6 (2005)");

	EnergyChoices = newArray("6 MV","10 MV","15 MV");
	FieldChoices = newArray("4x4cm","10x10cm");
	FFDChoices = newArray("100cm","125cm");
	CollChoices = newArray("0","90","270");

	FieldSizeHorizChoices = newArray(4,10);				//	relate horiz & vert field size to that selected
	FieldSizeVertChoices = newArray(4,10);				//	rectangular fields by varying these
	FFDChoicesVal = newArray(100,125);					//	FFD used to calculate field size measured

	OffAxisDistanceChoices = newArray("0mm","2.5mm","5mm","7.5mm","10mm","12.5mm","15mm","17.5mm","20mm","25mm");
	OffAxisDistanceChoicesVal = newArray(0,2.5,5,7.5,10,12.5,15,17.5,20,25);

	ScannerChoices = newArray("V750 Pro","11000XL Pro");

	DayChoices = newArray(31);			//	length of array
		for(i=0; i<DayChoices.length; i++)		//	set incremental values in array
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
	Dialog.addChoice("Scanner", ScannerChoices);
	Dialog.addChoice("Linac", LinacChoices);
	Dialog.addChoice("Coll.", CollChoices, "90");
	Dialog.addChoice("Energy", EnergyChoices);
	Dialog.addChoice("Field Size", FieldChoices);
	Dialog.addChoice("FFD", FFDChoices);
	Dialog.addChoice("Off Axis)", OffAxisDistanceChoices, "0mm");
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
	OffAxisDistanceSelected = Dialog.getChoice();

	OffAxisDistancePos = ArrayPos(OffAxisDistanceChoices,OffAxisDistanceSelected);
	OffAxisDistanceSelected = OffAxisDistanceChoicesVal[OffAxisDistancePos];

	FieldSelectedPos = ArrayPos(FieldChoices,FieldSelected);		//	get values from known positoin in array using function
	FFDSelectedPos = ArrayPos(FFDChoices,FFDSelected);

	FieldSizeHorizSelected = FieldSizeHorizChoices[FieldSelectedPos];
	FieldSizeVertSelected = FieldSizeVertChoices[FieldSelectedPos];
	FFDSelected = FFDChoicesVal[FFDSelectedPos];

	EnergySelectedPos = ArrayPos(EnergyChoices,EnergySelected);
	FieldSizeHorizMeasured = FieldSizeHorizSelected*FFDSelected/100;
	FieldSizeVertMeasured = FieldSizeVertSelected*FFDSelected/100;
	
	if(FFDSelected == 100) {						//	Selects threshold factor based on FFD and energy
		ThresFactor = ThresFactorChoices100[EnergySelectedPos];
		} else {
		ThresFactor = ThresFactorChoices125[EnergySelectedPos];
		}


//	ThresFactor = ThresFactorChoices[EnergySelectedPos];		//	Threshold factor for field edges may vary with energy
//	EdgeThresPerc = 100*ThresFactor;
	
	if(ScannerSelected == "11000XL Pro") {
		ImageWidthSelectedmm = ImageWidthA3mm;
		ImageHeightSelectedmm = ImageHeightA3mm;
		ScannerModelSelected = "Epsom Expression 11000 Pro XL";
		run("In [+]");						//	zoom on image
		} else {
		ImageWidthSelectedmm = ImageWidthA4mm;
		ImageHeightSelectedmm = ImageHeightA4mm;
		ScannerModelSelected = "Epsom Perfection V750 Pro";
		}

	EWscale = ImageWidthPx / ImageWidthSelectedmm;		//	gives conversion factor from px to mm from scanner selected
	NSscale = ImageHeightPx / ImageHeightSelectedmm;

	fieldEW = 10*FieldSizeHorizMeasured;				//	Field size in mm for calcs
	fieldNS = 10*FieldSizeVertMeasured;

	OffAxisDistPx = OffAxisDistanceSelected * 0.5* (EWscale+NSscale);	//	convert off axis distance to pixels

	print("------------------------------------------------------------------------");
	print("                    Linac Field Analysis Results");
	print("------------------------------------------------------------------------");
	print("\n");
	print("File Analysed:   \t" +myFileName);
	print("Exposure Date:   \t" + DateSelected);
	print("Analysis Date:   \t" +TimeString);
	print("\n");
	print("Scanner:   \t" + ScannerModelSelected);
	print("Linac:   \t" + LinacSelected);
	print("Coll.:   \t" + CollSelected);
	print("Energy:   \t" + EnergySelected);
	print("Field Size:   \t" + FieldSelected);
	//print("Field Size H:   \t" + FieldSizeHorizSelected);
	//print("Field Size V:   \t" + FieldSizeVertSelected);
	print("FFD:   \t" + FFDSelected + "cm");
		if(OffAxisDistanceSelected != 0){
		print("Off Axis Measurement Distance:   \t" + OffAxisDistanceSelected + "mm");
		} else {
		print("Off Axis Measurement Distance:   \t None");
		}
	//print("Thres Factor: \t" + ThresFactor);
	//print("\n");
	//print("Irradiated Field Size Horiz:   \t" + FieldSizeHorizMeasured);
	//print("Irradiated Field Size Vert:   \t" + FieldSizeHorizMeasured);

//	print("Horizontal Scale (pix/mm):\t" + EWscale);
//	print("Vertical Scale (pix/mm):\t" + NSscale);

///////	3	//////////	Cross Wires Marked	//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

	setTool("multipoint");											//	Set tool to multipoint, for user to select points
	waitForUser("Crosswire Selection", "Select 4 Crosswire Marks Starting at Top and Working Clockwise\n \nEnsure that RED channel is selected using scroll bar at bottom of image\n \nClick OK when complete");

	run("Measure");

	selectWindow("Results");								//	moves results window out of view
	setLocation(screenWidth()*0.95,screenHeight()*0.95);

	while(nResults!=4) {
		run("Clear Results");							//	use to clear results if wrong # pts selected
		setTool("multipoint");							//	4 points only should be selected for analysis
		waitForUser("You must select 4 crosswire points to complete analysis");
		run("Measure");
	}

	arrX = newArray(4);							//	create array with 4 selected points
	arrY = newArray(4);
	for (i=0; i<4;i++) {							//	Get coords of 4 Selected Points and place into Array
		arrX[i] = getResult("X",i);
		arrY[i] = getResult("Y",i);
	}

	NX = arrX[0];							//	Get Coords from array for each point to allow calc of intersection
	NY = arrY[0];							//	NX is the X coord of the North (top) point
	EX = arrX[1];
	EY = arrY[1];
	SX = arrX[2];
	SY = arrY[2];
	WX = arrX[3];
	WY = arrY[3];

		if(OffAxisDistanceSelected != 0){
	offAxisLine(NX,NY,SX,SY,OffAxisDistPx, "LineNS","LineNS-OffAxis", "yellow","green");
	run("Measure");
	angleNS = getResult("Angle", nResults - 1);				//	get angle of line - is in degrees and requires conversion to radians for use in calculations

	NXOffAx1 = a1;		//	These are set using variables from function.
	NYOffAx1 = a2;
	SXOffAx1 = b1;
	SYOffAx1 = b2;
	NXOffAx2 = c1;
	NYOffAx2 = c2;
	SXOffAx2 = d1;
	SYOffAx2 = d2;

	//CXOffAxNS1 = 0.5*(NXOffAx1 + SXOffAx1);				//********* These need to be found from intersection on lines...!
	//CYOffAxNS1 = 0.5*(NYOffAx1 + SYOffAx1);
	//CXOffAxNS2 = 0.5*(NXOffAx2 + SXOffAx2);
	//CYOffAxNS2 = 0.5*(NYOffAx2 + SYOffAx2);

	findIntersection(WX, WY, EX, EY, NXOffAx1, NYOffAx1, SXOffAx1, SYOffAx1);			//	Find Intersection to give coords of off axis intersection
		CXOffAxNS1 = intX;
		CYOffAxNS1 = intY;
	findIntersection(WX, WY, EX, EY, NXOffAx2, NYOffAx2, SXOffAx2, SYOffAx2);
		CXOffAxNS2 = intX;
		CYOffAxNS2 = intY;


	offAxisLine(WX,WY,EX,EY,OffAxisDistPx,"LineEW", "LineEW-OffAxis","yellow","green");
	run("Measure");
	angleEW = getResult("Angle", nResults - 1);

	WXOffAx1 = a1;
	WYOffAx1 = a2;
	EXOffAx1 = b1;
	EYOffAx1 = b2;
	WXOffAx2 = c1;
	WYOffAx2 = c2;
	EXOffAx2 = d1;
	EYOffAx2 = d2;

	//CXOffAxEW1 = 0.5*(WXOffAx1 + EXOffAx1);				//********* These need to be found from intersection on lines...!
	//CYOffAxEW1 = 0.5*(WYOffAx1 + EYOffAx1);
	//CXOffAxEW2 = 0.5*(WXOffAx2 + EXOffAx2);
	//CYOffAxEW2 = 0.5*(WYOffAx2 + EYOffAx2);

	findIntersection(NX, NY, SX, SY, WXOffAx1, WYOffAx1, EXOffAx1, EYOffAx1);
		CXOffAxEW1 = intX;
		CYOffAxEW1 = intY;
	findIntersection(NX, NY, SX, SY, WXOffAx2, WYOffAx2, EXOffAx2, EYOffAx2);
		CXOffAxEW2 = intX;
		CYOffAxEW2 = intY;

	} else {
	
	Line(NX,NY,SX,SY, "LineNS", "yellow");
	run("Measure");
	angleNS = getResult("Angle", nResults - 1);				//	get angle of line - is in degrees and requires conversion to radians for use in calculations

	Line(WX,WY,EX,EY,"LineEW", "yellow");
	run("Measure");
	angleEW = getResult("Angle", nResults - 1);

	}

///////	4	//////////	Central ROI positioned & measured	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

	findIntersection(WX, WY, EX, EY, NX, NY, SX, SY);			//	Find Intersection to give coords of centre of field
		CX = intX;
		CY = intY;

	roiDiamNS = roiSize * NSscale;		 			//	sizes the roi (in pix) based on scale factor and roi size selected
	roiRadNS = 0.5*roiDiamNS;			 			//	gives radius to simplify positioning below
	roiDiamEW = roiSize * EWscale;
	roiRadEW = 0.5*roiDiamEW;

	RectROI(CX-roiRadEW,CY-roiRadNS, roiDiamEW, roiDiamNS,"ROI Centre","red");
	run("Measure");
	RAWmeanROIcentre = getResult("Mean");		


///////	5	//////////	Field Edges Determined	//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

	ThresVal = RAWmeanROIcentre * ThresFactor;	
//	ThresVal = RAWmeanROIcentre - ((1-EdgeThresPerc/100)* (RAWmeanROIcentre - bgROImean));			//	converts factor to pixel value

//	print("Field Edge Threshold (%):\t" + EdgeThresPerc);
//	print("Threshold Val (pix):\t" + ThresVal);

	FindEdges(NX,NY,SX,SY,CX,CY, ProfileWidthmm * EWscale,ThresVal,"Edge North","Edge South",0,0);		//	this is a custom function which finds the 2 edges of the field between the specified points
	FindEdges(WX,WY,EX,EY,CX,CY, ProfileWidthmm * NSscale,ThresVal,"Edge West","Edge East",0,0);

	roiManager("Select", roiManager("count") - 4);			//	measure coords of field edges after any possible movement
	run("Measure");
	roiManager("Select", roiManager("count") - 3);
	run("Measure");
	roiManager("Select", roiManager("count") - 2);
	run("Measure");
	roiManager("Select", roiManager("count") - 1);
	run("Measure");

	edgeNX = getResult("X", nResults - 4);			//	CAX measurements
	edgeNY = getResult("Y", nResults - 4);
	edgeSX = getResult("X", nResults - 3);
	edgeSY = getResult("Y", nResults - 3);
	edgeWX = getResult("X", nResults - 2);
	edgeWY = getResult("Y", nResults - 2);
	edgeEX = getResult("X", nResults - 1);
	edgeEY = getResult("Y", nResults - 1);


		if(OffAxisDistanceSelected != 0){
	FindEdges(NXOffAx1,NYOffAx1,SXOffAx1,SYOffAx1,0,0, ProfileWidthmm * EWscale,ThresVal,"Edge North - Off Axis - 1","Edge South - Off Axis - 1",0,0);
	FindEdges(NXOffAx2,NYOffAx2,SXOffAx2,SYOffAx2,0,0, ProfileWidthmm * EWscale,ThresVal,"Edge North - Off Axis - 2","Edge South - Off Axis - 2",0,0);
	FindEdges(WXOffAx1,WYOffAx1,EXOffAx1,EYOffAx1,0,0, ProfileWidthmm * NSscale,ThresVal,"Edge West - Off Axis - 1","Edge East - Off Axis - 1",0,0);
	FindEdges(WXOffAx2,WYOffAx2,EXOffAx2,EYOffAx2,0,0, ProfileWidthmm * NSscale,ThresVal,"Edge West - Off Axis - 2","Edge East - Off Axis - 2",0,0);
	}
	

	setTool("multipoint");
	selectWindow("ROI Manager");
	setLocation(0.8*screenWidth(),0);
	roiManager("Select", roiManager("count") -1);
	waitForUser("Field Edges", "Have Field Edges Been Located Correctly?\n \nAdjust points manually by selecting with the ROI Manager if Required\nYou may need to Zoom in to precisely position the points\n \nPress OK to continue");
	setTool("Hand");

		if(OffAxisDistanceSelected != 0){
	roiManager("Select", roiManager("count") - 8);			//	measure coords of field edges after any possible movement
	run("Measure");
	roiManager("Select", roiManager("count") - 7);
	run("Measure");
	roiManager("Select", roiManager("count") - 6);
	run("Measure");
	roiManager("Select", roiManager("count") - 5);
	run("Measure");
	}


	roiManager("Select", roiManager("count") - 4);			//	measure coords of field edges after any possible movement
	run("Measure");
	roiManager("Select", roiManager("count") - 3);
	run("Measure");
	roiManager("Select", roiManager("count") - 2);
	run("Measure");
	roiManager("Select", roiManager("count") - 1);
	run("Measure");

		if(OffAxisDistanceSelected != 0){
	edgeNXOffAx1 = getResult("X", nResults - 8);			//	off axis measurements
	edgeNYOffAx1 = getResult("Y", nResults - 8);
	edgeSXOffAx1 = getResult("X", nResults - 7);
	edgeSYOffAx1 = getResult("Y", nResults - 7);
	edgeNXOffAx2 = getResult("X", nResults - 6);
	edgeNYOffAx2 = getResult("Y", nResults - 6);
	edgeSXOffAx2 = getResult("X", nResults - 5);
	edgeSYOffAx2 = getResult("Y", nResults - 5);
	edgeWXOffAx1 = getResult("X", nResults - 4);
	edgeWYOffAx1 = getResult("Y", nResults - 4);
	edgeEXOffAx1 = getResult("X", nResults - 3);
	edgeEYOffAx1 = getResult("Y", nResults - 3);
	edgeWXOffAx2 = getResult("X", nResults - 2);
	edgeWYOffAx2 = getResult("Y", nResults - 2);
	edgeEXOffAx2 = getResult("X", nResults - 1);
	edgeEYOffAx2 = getResult("Y", nResults - 1);
	}

///////	6	//////////	Field Size Calculated from Field Edges	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

	//	Field edge measured relative to central point which should be at crosswire intersection

     //     Whole field
	NSdist = calcDistance(edgeNX,edgeNY,edgeSX,edgeSY);
	NSdistmm = NSdist / NSscale;
	EWdist = calcDistance(edgeEX,edgeEY,edgeWX,edgeWY);
	EWdistmm = EWdist / EWscale;

	NSdifmm = NSdistmm - fieldNS;
	EWdifmm = EWdistmm - fieldEW;

/////	off axis distances		/////
		if(OffAxisDistanceSelected != 0){
	NSOffAx1dist = calcDistance(edgeNXOffAx1,edgeNYOffAx1,edgeSXOffAx1,edgeSYOffAx1);
	NSOffAx1distmm = NSOffAx1dist / NSscale;
	EWOffAx1dist = calcDistance(edgeEXOffAx1,edgeEYOffAx1,edgeWXOffAx1,edgeWYOffAx1);
	EWOffAx1distmm = EWOffAx1dist / EWscale;
	NSOffAx2dist = calcDistance(edgeNXOffAx2,edgeNYOffAx2,edgeSXOffAx2,edgeSYOffAx2);
	NSOffAx2distmm = NSOffAx2dist / NSscale;
	EWOffAx2dist = calcDistance(edgeEXOffAx2,edgeEYOffAx2,edgeWXOffAx2,edgeWYOffAx2);
	EWOffAx2distmm = EWOffAx2dist / EWscale;

	NSOffAxMeandistmm = 0.5*(NSOffAx1distmm + NSOffAx2distmm);		//	Mean off axis field size
	EWOffAxMeandistmm = 0.5*(EWOffAx1distmm + EWOffAx2distmm);

	NSOffAxdifmm = NSOffAxMeandistmm - fieldNS;
	EWOffAxdifmm = EWOffAxMeandistmm - fieldEW;

//	print("NS off axis : " + NSOffAxMeandistmm);
//	print("EW off axis : " + EWOffAxMeandistmm);
	}
/////	off axis distances		/////



	//	With Coll = 90		//
	//	North = Gantry = X2	//
	//	South = Target = X1	//
	//	East = B = Y1		//
	//	West = A = Y2		//

     //     Individual Jaws
	CNdist = calcDistance(CX,CY,edgeNX,edgeNY);
	CNdistmm = CNdist / NSscale;
	CSdist = calcDistance(CX,CY,edgeSX,edgeSY);
	CSdistmm = CSdist / NSscale;
	CEdist = calcDistance(CX,CY,edgeEX,edgeEY);
	CEdistmm = CEdist / EWscale;
	CWdist = calcDistance(CX,CY,edgeWX,edgeWY);
	CWdistmm = CWdist / EWscale;

	CNdifmm = CNdistmm - (fieldNS/2);	//	need half the field size to get half field size for distance measurement.
	CSdifmm = CSdistmm - (fieldNS/2);
	CEdifmm = CEdistmm - (fieldEW/2);
	CWdifmm = CWdistmm - (fieldEW/2);

/////	off axis distances		/////
		if(OffAxisDistanceSelected != 0){
	CNOffAx1dist = calcDistance(CXOffAxNS1,CYOffAxNS1,edgeNXOffAx1,edgeNYOffAx1);
	CNOffAx1distmm = CNOffAx1dist / NSscale;
	CSOffAx1dist = calcDistance(CXOffAxNS1,CYOffAxNS1,edgeSXOffAx1,edgeSYOffAx1);
	CSOffAx1distmm = CSOffAx1dist / NSscale;
	CEOffAx1dist = calcDistance(CXOffAxEW1,CYOffAxEW1,edgeEXOffAx1,edgeEYOffAx1);
	CEOffAx1distmm = CEOffAx1dist / EWscale;
	CWOffAx1dist = calcDistance(CXOffAxEW1,CYOffAxEW1,edgeWXOffAx1,edgeWYOffAx1);
	CWOffAx1distmm = CWOffAx1dist / EWscale;

	CNOffAx2dist = calcDistance(CXOffAxNS2,CYOffAxNS2,edgeNXOffAx2,edgeNYOffAx2);
	CNOffAx2distmm = CNOffAx2dist / NSscale;
	CSOffAx2dist = calcDistance(CXOffAxNS2,CYOffAxNS2,edgeSXOffAx2,edgeSYOffAx2);
	CSOffAx2distmm = CSOffAx2dist / NSscale;
	CEOffAx2dist = calcDistance(CXOffAxEW2,CYOffAxEW2,edgeEXOffAx2,edgeEYOffAx2);
	CEOffAx2distmm = CEOffAx2dist / EWscale;
	CWOffAx2dist = calcDistance(CXOffAxEW2,CYOffAxEW2,edgeWXOffAx2,edgeWYOffAx2);
	CWOffAx2distmm = CWOffAx2dist / EWscale;

	CNOffAxMeandistmm = 0.5*(CNOffAx1distmm + CNOffAx2distmm);
	CSOffAxMeandistmm = 0.5*(CSOffAx1distmm + CSOffAx2distmm);
	CEOffAxMeandistmm = 0.5*(CEOffAx1distmm + CEOffAx2distmm);
	CWOffAxMeandistmm = 0.5*(CWOffAx1distmm + CWOffAx2distmm);

	CNOffAxMeandifmm = CNOffAxMeandistmm - (fieldNS/2);	//	need half the field size to get half field size for distance measurement.
	CSOffAxMeandifmm = CSOffAxMeandistmm - (fieldNS/2);
	CEOffAxMeandifmm = CEOffAxMeandistmm - (fieldEW/2);
	CWOffAxMeandifmm = CWOffAxMeandistmm - (fieldEW/2);

//	print("CN off axis : " + CNOffAxMeandistmm);
//	print("CS off axis : " + CSOffAxMeandistmm);
//	print("CE off axis : " + CEOffAxMeandistmm);
//	print("CW off axis : " + CWOffAxMeandistmm);

//	print("CN off axis dif : " + CNOffAxMeandifmm);
//	print("CS off axis dif : " + CSOffAxMeandifmm);
//	print("CE off axis dif : " + CEOffAxMeandifmm);
//	print("CW off axis dif : " + CWOffAxMeandifmm);
	}
/////	off axis distances		/////



     //   Calc if field size is within tolerance


	//	Full field
	if(abs(NSdifmm) < FieldSizeTol) {
		ResultFieldSizeDiffNS = "OK";
		} else {
		ResultFieldSizeDiffNS = "FAIL";
	}

	if(abs(EWdifmm) < FieldSizeTol) {
		ResultFieldSizeDiffEW = "OK";
		} else {
		ResultFieldSizeDiffEW = "FAIL";
	}


	//	Individual jaws
	if(abs(CNdifmm) < FieldSizeTol) {
		ResultFieldSizeDiffCN = "OK";
		} else {
		ResultFieldSizeDiffCN = "FAIL";
	}

	if(abs(CSdifmm) < FieldSizeTol) {
		ResultFieldSizeDiffCS= "OK";
		} else {
		ResultFieldSizeDiffCS = "FAIL";
	}


	if(abs(CEdifmm) < FieldSizeTol) {
		ResultFieldSizeDiffCE = "OK";
		} else {
		ResultFieldSizeDiffCE = "FAIL";
	}

	if(abs(CWdifmm) < FieldSizeTol) {
		ResultFieldSizeDiffCW = "OK";
		} else {
		ResultFieldSizeDiffCW = "FAIL";
	}



	print("\n");
	print("-----------  Field Size (cm)  (Tol: +/- " + FieldSizeTol + " mm)  ----------");
	print("Length  \t| Std.    \t| Meas.   \t| Result");

//	print("EW  \t| " + d2s(fieldEW/10,1) + "  \t| " + d2s(EWdistmm/10,2) +"  \t| " + ResultFieldSizeDiffEW);
//	print("NS  \t| " + d2s(fieldNS/10,1) + "  \t| " + d2s(NSdistmm/10,2) +"  \t| " + ResultFieldSizeDiffNS);
//	print("\n");


	print("X1 (T)  \t| " + d2s(fieldNS/20,2) + "  \t| " + d2s(CSdistmm/10,2) +"  \t| " + ResultFieldSizeDiffCS);
	print("X2 (G)  \t| " + d2s(fieldNS/20,2) + "  \t| " + d2s(CNdistmm/10,2) +"  \t| " + ResultFieldSizeDiffCN);

	print("Y1 (B)  \t| " + d2s(fieldEW/20,2) + "  \t| " + d2s(CEdistmm/10,2) +"  \t| " + ResultFieldSizeDiffCE);
	print("Y2 (A)  \t| " + d2s(fieldEW/20,2) + "  \t| " + d2s(CWdistmm/10,2) +"  \t| " + ResultFieldSizeDiffCW);


     //   Calc if Off AXIS field size is within tolerance (same as above which is for CAX field size)
			if(OffAxisDistanceSelected != 0){
	//	Full field
	if(abs(NSOffAxdifmm) < FieldSizeTol) {
		ResultFieldSizeDiffNSOffAx = "OK";
		} else {
		ResultFieldSizeDiffNSOffAx = "FAIL";
	}

	if(abs(EWOffAxdifmm) < FieldSizeTol) {
		ResultFieldSizeDiffEWOffAx = "OK";
		} else {
		ResultFieldSizeDiffEWOffAx = "FAIL";
	}


	//	Individual jaws
	if(abs(CNOffAxMeandifmm) < FieldSizeTol) {
		ResultFieldSizeDiffCNOffAxMean = "OK";
		} else {
		ResultFieldSizeDiffCNOffAxMean = "FAIL";
	}

	if(abs(CSOffAxMeandifmm) < FieldSizeTol) {
		ResultFieldSizeDiffCSOffAxMean= "OK";
		} else {
		ResultFieldSizeDiffCSOffAxMean = "FAIL";
	}


	if(abs(CEOffAxMeandifmm) < FieldSizeTol) {
		ResultFieldSizeDiffCEOffAxMean = "OK";
		} else {
		ResultFieldSizeDiffCEOffAxMean = "FAIL";
	}

	if(abs(CWOffAxMeandifmm) < FieldSizeTol) {
		ResultFieldSizeDiffCWOffAxMean = "OK";
		} else {
		ResultFieldSizeDiffCWOffAxMean = "FAIL";
	}



	print("\n");
	print("---------  Off Axis Field Size (cm)  (Tol: +/- " + FieldSizeTol + " mm)  --------");
	print("Length  \t| Std.    \t| Meas.   \t| Result");

//	print("EW Off Axis \t| " + d2s(fieldEW/10,1) + "  \t| " + d2s(EWOffAxMeandistmm/10,2) +"  \t| " + ResultFieldSizeDiffEWOffAx);
//	print("NS Off Axis \t| " + d2s(fieldNS/10,1) + "  \t| " + d2s(NSOffAxMeandistmm/10,2) +"  \t| " + ResultFieldSizeDiffNSOffAx);
//	print("\n");


	print("X1 (T) Off Ax \t| " + d2s(fieldNS/20,2) + "  \t| " + d2s(CSOffAxMeandistmm/10,2) +"  \t| " + ResultFieldSizeDiffCSOffAxMean);
	print("X2 (G) Off Ax \t| " + d2s(fieldNS/20,2) + "  \t| " + d2s(CNOffAxMeandistmm/10,2) +"  \t| " + ResultFieldSizeDiffCNOffAxMean);

	print("Y1 (B) Off Ax \t| " + d2s(fieldEW/20,2) + "  \t| " + d2s(CEOffAxMeandistmm/10,2) +"  \t| " + ResultFieldSizeDiffCEOffAxMean);
	print("Y2 (A) Off Ax \t| " + d2s(fieldEW/20,2) + "  \t| " + d2s(CWOffAxMeandistmm/10,2) +"  \t| " + ResultFieldSizeDiffCWOffAxMean);
	}


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
//
//	Functions below are used within the macro and should be kept in the same file as the above macro
//

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
function Point(x, y, name) {

	makePoint(x,y);						//	plot point with given coord and rename
	roiManager("Add");
	roiManager("Select", roiManager("count")-1);
	roiManager("Rename", name);
}
//----------------------- End of Make Point Function ---------------------------------------------------------------------------------------------


// ----------------------------------- MAKE LINE FUNCTION -------------------------------------------------------------------------
function Line(x1,y1,x2,y2, name, colour) {

	makeLine(x1,y1, x2, y2);					//	Make line between specified poitns with specified name and colour
	roiManager("Add");
	roiManager("Select",roiManager("count")-1);
	roiManager("Rename", name);
	roiManager("Set Color", colour);
}
//----------------------- End of Make Line Function ---------------------------------------------------------------------------------------------


// ----------------------------------- FIND EDGE FUNCTION -------------------------------------------------------------------------
function FindEdges(x1,y1,x2,y2,xC,yC, width,thres,name1,name2, offset1,offset2) {		//	pts 1 & 2 are the ends fo the line, point C is the centre point at which analysis should start
											//	offset allows the i+n'th value to be returned. Set as 0 if none required
											//	width is profile width, thres is edge threshold, name is the name of the edge points 1 & 2 created
	run("Line Width...", "line=" + width);				//	Set profile measurement width

	if(xC == 0 && yC == 0) {					//	If there is no central point defined (Set as zero in function) then it is created to be midway between the 2 points.
		xC = (x1+x2)/2;
		yC = (y1+y2)/2;
	}

	Dist12 = calcDistance(x1,y1,x2,y2);				//	detemines start point in measured profile (i.e. distance centre point is along profile)
	Dist1C = calcDistance(x1,y1,xC,yC);
	ProfStart = Dist1C / Dist12;

	DoubleLine(x1,y1,xC,yC,x2,y2,"Line1");			//	need 3 points along line to run the fit

	run("Fit Spline", "straighten");				//	fit a 'curve' which allows to get profile along this curve and extract coords
	getSelectionCoordinates(x,y);

	profileA = getProfile();					//	get profile values

	endPt = profileA.length;					//	end point of profile (anbd analysis values) is final value in profile
	midPt = endPt * ProfStart;					//	mid point is ratio of total distance
	startPt = 0;						//	start at beginning of profile

     //******* Find Point 1

	i = midPt;
	while (i>startPt && profileA[i] < thres) {			//	start at chosen point (centre) and check all points until one passes thres.
		i = i-1;
	}

	edge1x = x[i+offset1];					//	set the coords of this point as new point
	edge1y = y[i+offset1];

	Point(edge1x, edge1y, name1);				//	use function to create new point
	
     //******* Find Point 2

	i = midPt;
	while (i<endPt && profileA[i] < thres) {
		i = i+1;
	}

	edge2x = x[i+offset2];
	edge2y = y[i+offset2];

	Point(edge2x, edge2y, name2);

	roiManager("Select", roiManager("count")-3);			//	delete line created for profile after its been used
	roiManager("Delete");

	run("Line Width...", "line=1");					//	set line width back to 1 pixel

}
//----------------------- End of Find Edge Function ---------------------------------------------------------------------------------------------


// ----------------------------------- MAKE DOUBLE LINE FUNCTION (This is used when defining the field edges) -------------------------------------------------------------------------
function DoubleLine(x1, y1, x2, y2, x3, y3, name) {

	makeLine(x1, y1, x2, y2, x3, y3);				//	draw line from pt 1, through mid to pt 2 (need 3 points for simple extraction of coords below)
	roiManager("Add");
	roiManager("Select", roiManager("count")-1);
	roiManager("Rename", name);
}
//----------------------- End of Make Line Function ---------------------------------------------------------------------------------------------

// ----------------------------------- MAKE OFF AXIS LINE FUNCTION -------------------------------------------------------------------------
function offAxisLine(x1,y1,x2,y2,d, name,nameNew, colour, colourNew) {		//	d = off axis distance, nameNew = name of off axis line

	makeLine(x1,y1, x2, y2);						//	Make line between specified points with specified name and colour
	roiManager("Add");
	roiManager("Select",roiManager("count")-1);
	roiManager("Rename", name);
	roiManager("Set Color", colour);

	grad = ( y2-y1 ) / (x2 - x1);				//	maybe add if d = 0 then do not draw off axis lines...
	angle = atan(grad);

	dx = 1*d*sin(angle);
	dy = -1*d*cos(angle);

	a1 = x1 +dx;			// these are turned into proper variables after running the function e.g. NXOffAx1
	b1 = x2 + dx;
	a2 = y1 + dy;
	b2 = y2 + dy;

	makeLine(a1,a2,b1,b2);		//	make new line in new position
	roiManager("Add");
	roiManager("Select",roiManager("count")-1);
	roiManager("Rename", nameNew+"-1");
	roiManager("Set Color", colourNew);

	c1 = x1 -dx;
	d1 = x2 - dx;
	c2 = y1 - dy;
	d2 = y2 - dy;

	makeLine(c1,c2,d1,d2);		//	make new line in new position
	roiManager("Add");
	roiManager("Select",roiManager("count")-1);
	roiManager("Rename", nameNew+"-2");
	roiManager("Set Color", colourNew);

	}
//----------------------- End of Make Off Axis Line Function ---------------------------------------------------------------------------------------------

//----------------------- FIND INTERSECTION FUCNTION -------------------------------------------------------------------------------------------------

function findIntersection(xi1, yi1, xi2, yi2, xi3, yi3, xi4, yi4) {

	intX = 0;
	intY = 0;
	
	if(xi4 - xi3!=0 && xi2 - xi1!=0) {				//	If either line registers as vertical, then need to use alternative solving methods
		grad1 = (yi2 - yi1) / (xi2 - xi1);
		grad2 = (yi3 - yi4) / (xi3 - xi4);
		intX = ((yi3 - yi1) + (xi1 * grad1) - (xi3 * grad2)) / (grad1 - grad2);
		intY = grad1 * (intX - xi1) + yi1;
		} else {
	if(xi1 - xi2!=0) {
		intX = xi3;
		grad2 = (yi1 - yi2) / (xi1 - xi2);
		intY = (grad2 * xi3) + (yi1 - (grad2 * xi1));
		} else {
		intX = xi1;
		grad1 = (yi3 - yi4) / (xi3 - xi4);
		intY = (grad1 * xi1) + (yi3 - (grad1 * xi3));
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

// 	- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -	//
//				END OF LINAC FIELD SIZE							//
// 	- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -	//
