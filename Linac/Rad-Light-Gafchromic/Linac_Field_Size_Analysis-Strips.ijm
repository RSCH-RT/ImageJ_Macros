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


var intX		//	Global Variables need to be specified outside of the macro
var intY
var ext1x
var ext1y
var ext2x
var ext2y

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
	requires("1.47p");
	run("Set Measurements...", "area mean standard min center bounding display redirect=None decimal=3");
	run("Profile Plot Options...", "width=450 height=300 interpolate draw sub-pixel");

	Dialog.create("Macro Opened");
	Dialog.addMessage("---- Linac Field Size Analysis using Gafchromic Strips ----");
	Dialog.addMessage("Version: " + version);
	Dialog.addMessage("Last Updated: " + update_date);
	if(nImages==0) {
		Dialog.addMessage("");
		Dialog.addMessage("You will be prompted to open the required image after clicking OK");
	}
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
		//showMessageWithCancel("Select Image","Select image to analyse after clicking OK");		//	ensures an image is open before macro runs
		path = File.openDialog("Select a File");
		open(path);
	}

	origImageID = getImageID();

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

	ImageWidthPx = getWidth();				//	returns image width in pixels
	ImageHeightPx = getHeight();

	ImageWidthA4mm = 215.9;				//	known regular scanner image width in mm (from scanner settings)
	ImageHeightA4mm = 297.2;

	ImageWidthA3mm = 309.9;				//	known large scanner image width in mm (from scanner settings)
	ImageHeightA3mm = 436.9;

///////	1	//////////	Tolerance Levels & Standard Figures	///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

     //     Constants used
	roiSize = 5;
	ProfileWidthmm = 6;				//	Sets the width of the measured profile in mm - aim is to average over a wider profile to avoid provlems with any noise/dust/dead pixels in image
	LineExtensionmm = 80;

     //     Tolerance Levels
	FieldSizeTol = 2;			// tolerance for field size is +/- 2mm

	ThresFactorChoices100 = newArray(1.31,1.31,1.31);		//	Edge threshold factors for each beam (6,10,15MV) - measured by taking exposures at 400 & 200MU.
	ThresFactorChoices125 = newArray(1.24,1.24,1.24);

///////	2	//////////	Field Details Selected	//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

	LinacChoices = newArray("LA1", "LA2", "LA3", "LA4", "LA5", "LA6","Red-A","Red-B","Select");

	EnergyChoices = newArray("6 MV","10 MV","15 MV");
	FieldChoices = newArray("4x4cm","10x10cm","25x25cm","30x30cm");
	FFDChoices = newArray("100cm","125cm");
	CollChoices = newArray("0","90","270");

	FieldSizeLeftChoices = newArray(4,10,25,30);				//	relate Right & Left field size to that selected (Leftical 'north-south' should be the X jaw with coll=90)
	FieldSizeRightChoices = newArray(4,10,25,30);				//	rectangular fields by varying these
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
	Dialog.addChoice("Scanner", ScannerChoices,"11000XL Pro");
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

	FieldSizeLeftSelected = FieldSizeLeftChoices[FieldSelectedPos];
	FieldSizeRightSelected = FieldSizeRightChoices[FieldSelectedPos];
	FFDSelected = FFDChoicesVal[FFDSelectedPos];

	EnergySelectedPos = ArrayPos(EnergyChoices,EnergySelected);
	FieldSizeLeftMeasured = FieldSizeLeftSelected*FFDSelected/100;
	FieldSizeRightMeasured = FieldSizeRightSelected*FFDSelected/100;
	
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

	LineExtensionpx = LineExtensionmm * NSscale;

	fieldRight = 10*FieldSizeRightMeasured;					//	Field size in mm for calcs
	fieldLeft = 10*FieldSizeLeftMeasured;

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
	//print("Field Size Right:   \t" + FieldSizeRightSelected);
	//print("Field Size Left:   \t" + FieldSizeLeftSelected);
	print("FFD:   \t" + FFDSelected + "cm");
	//print("Thres Factor: \t" + ThresFactor);
	//print("\n");
	//print("Irradiated Field Size Left:   \t" + FieldSizeLeftMeasured);
	//print("Irradiated Field Size Right:   \t" + FieldSizeRightMeasured);

//	print("Horizontal Scale (pix/mm):\t" + EWscale);
//	print("Verical Scale (pix/mm):\t" + NSscale);

///////	3	//////////	Cross Wires Marked	//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

	Dialog.create("Crosswire Mark Location");
	Dialog.addMessage("Are crosswires marked on inside or outside of field edge?");
	crosswireposition = newArray("Outside", "Inside");
	Dialog.addChoice("Crosswire Mark Location: ",crosswireposition,crosswireposition[1]);
	Dialog.show();

	crosswirepositionselected = Dialog.getChoice;
	print("Crosswire position marked: " + crosswirepositionselected);

	count = 1.0;	//	to repeat below method for each strip

	do {		//	all enclosed in a do...while loop which will run twice (once for each strip).
   	
	run("Select None");
	run("View 100%");

	resultscountstart = nResults;

	setTool("multipoint");											//	Set tool to multipoint, for user to select points
	if(count==1) {
	waitForUser("Crosswire Selection", "Select 4 Crosswire Marks on 'X Strip'.\n \n Start at Top and Work Clockwise\n \nEnsure that RED channel is selected using scroll bar at bottom of image\n \nClick OK when complete");
	} else {
	waitForUser("Crosswire Selection", "Select 4 Crosswire Marks on 'Y'Strip'.\n \n Start at Top and Work Clockwise\n \nEnsure that RED channel is selected using scroll bar at bottom of image\n \nClick OK when complete");
	}

	run("Measure");

	resultscountend = nResults;

	selectWindow("Results");								//	moves results window out of view
	setLocation(screenWidth()*0.95,screenHeight()*0.95);

	while(resultscountend - resultscountstart !=4) {
		run("Clear Results");							//	use to clear results if wrong # pts selected
		resultscountstart = nResults;
		setTool("multipoint");							//	4 points only should be selected for analysis
		waitForUser("You must select 4 crosswire points to complete analysis");
		run("Measure");
		resultscountend = nResults;
	}

	if(count==1) {
	arrLX = newArray(4);							//	create array with 4 selected points
	arrLY = newArray(4);
	for (i=0; i<4;i++) {								//	Get coords of 4 Selected Points and place into Array
		arrLX[i] = getResult("X",nResults-4+i);
		arrLY[i] = getResult("Y",nResults-4+i);
	}
	} else {
	arrRX = newArray(4);							//	create array with 4 selected points
	arrRY = newArray(4);
	for (i=0; i<4;i++) {								//	Get coords of 4 Selected Points and place into Array
		arrRX[i] = getResult("X",nResults-4+i);
		arrRY[i] = getResult("Y",nResults-4+i);
	}
	}

	if(count==1) {
		LNX = arrLX[0];							//	Get Coords from array for each point to allow calc of intersection
		LNY = arrLY[0];							//	LNX is the X coord of the North (top) point on the Left side of image (should be X jaw strip)
		LEX = arrLX[1];
		LEY = arrLY[1];
		LSX = arrLX[2];
		LSY = arrLY[2];
		LWX = arrLX[3];
		LWY = arrLY[3];
	} else {
		RNX = arrRX[0];							//	Get Coords from array for each point to allow calc of intersection
		RNY = arrRY[0];							//	LNX is the X coord of the North (top) point on the Left side of image (should be X jaw strip)
		REX = arrRX[1];
		REY = arrRY[1];
		RSX = arrRX[2];
		RSY = arrRY[2];
		RWX = arrRX[3];
		RWY = arrRY[3];
	}
	
	//******array


	if(count==1) {
	
	if(crosswirepositionselected=="Outside") {
		Line(LNX,LNY,LSX,LSY, "LineX-NS", "yellow");
	} else {
		LineExt(LNX,LNY,LSX,LSY, LineExtensionpx,LineExtensionpx,"LineX-NS", "yellow");
	}

	run("Measure");
	angleLNS = getResult("Angle", nResults - 1);					//	get angle of line - is in degrees and requires conversion to radians for use in calculations

	Line(LWX,LWY,LEX,LEY,"LineX-EW", "yellow");
	run("Measure");
	angleLEW = getResult("Angle", nResults - 1);

	} else {

	if(crosswirepositionselected=="Outside") {
		Line(RNX,RNY,RSX,RSY, "LineY-NS", "yellow");
	} else {
		LineExt(RNX,RNY,RSX,RSY, LineExtensionpx,LineExtensionpx,"LineY-NS", "yellow");
	}
	run("Measure");
	angleRNS = getResult("Angle", nResults - 1);					//	get angle of line - is in degrees and requires conversion to radians for use in calculations

	Line(RWX,RWY,REX,REY,"LineY-EW", "yellow");
	run("Measure");
	angleREW = getResult("Angle", nResults - 1);
	}


///////	4	//////////	Central ROI positioned & measured	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

	if(count==1) {
		findIntersection(LWX, LWY, LEX, LEY, LNX, LNY, LSX, LSY);			//	Find Intersection to give coords of centre of field
		LCX = intX;
		LCY = intY;
	} else {
		findIntersection(RWX, RWY, REX, REY, RNX, RNY, RSX, RSY);			//	Find Intersection to give coords of centre of field
		RCX = intX;
		RCY = intY;
	}

	roiDiamNS = roiSize * NSscale;		 			//	sizes the roi (in pix) based on scale factor and roi size selected
	roiRadNS = 0.5*roiDiamNS;			 			//	gives radius to simplify positioning below
	roiDiamEW = roiSize * EWscale;
	roiRadEW = 0.5*roiDiamEW;


	if(count==1) {
		RectROI(LCX-roiRadEW,LCY-roiRadNS, roiDiamEW, roiDiamNS,"ROI X Centre","red");
		run("Measure");
		RAWmeanROIcentreL = getResult("Mean");		
	} else {
		RectROI(RCX-roiRadEW,RCY-roiRadNS, roiDiamEW, roiDiamNS,"ROI Y Centre","red");
		run("Measure");
		RAWmeanROIcentreR = getResult("Mean");		
	}

///////	5	//////////	Field Edges Determined	//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

	ThresVal = RAWmeanROIcentreL * ThresFactor;			//	ConLefts central value to 50% pixel value

//	print("Field Edge Threshold (%):\t" + EdgeThresPerc);
//	print("Threshold Val (pix):\t" + ThresVal);

	if(count==1) {
		if(crosswirepositionselected=="Outside") {
			FindEdges(LNX,LNY,LSX,LSY,LCX,LCY, ProfileWidthmm * EWscale,ThresVal,"Edge X1","Edge X2",0,0);		//	this is a custom function which finds the 2 edges of the field between the specified points
		} else {
			//FindEdges(ext1x,ext1y,ext2x,ext2y,LCX,LCY, ProfileWidthmm * EWscale,ThresVal,"Edge X1","Edge X2",0,0);
			FindSingleEdge(LNX,LNY,ext1x,ext1y, ProfileWidthmm * EWscale,ThresVal,"Edge X1", 0);
			FindSingleEdge(LSX,LSY,ext2x,ext2y, ProfileWidthmm * EWscale,ThresVal,"Edge X2", 0);
		}

	} else {
		if(crosswirepositionselected=="Outside") {
			FindEdges(RNX,RNY,RSX,RSY,RCX,RCY, ProfileWidthmm * EWscale,ThresVal,"Edge Y1","Edge Y2",0,0);
		} else {
			//FindEdges(ext1x,ext1y,ext2x,ext2y,RCX,RCY, ProfileWidthmm * EWscale,ThresVal,"Edge Y1","Edge Y2",0,0);
			FindSingleEdge(RNX,RNY,ext1x,ext1y, ProfileWidthmm * EWscale,ThresVal,"Edge Y1", 0);
			FindSingleEdge(RSX,RSY,ext2x,ext2y, ProfileWidthmm * EWscale,ThresVal,"Edge Y2", 0);
		}
	}

	run("Original Scale");

	setTool("multipoint");
	selectWindow("ROI Manager");
	setLocation(0.8*screenWidth(),0);
	roiManager("Select", roiManager("count") - 4);

	if(count==1) {
		waitForUser("Field Edges", "Have Field Edges Been Located Correctly for the 'X' Strip?\n \nAdjust points manually by selecting with the ROI Manager if Required\nYou may need to Zoom in to precisely position the points\n \nPress OK to continue");
	} else {
		waitForUser("Field Edges", "Have Field Edges Been Located Correctly for the 'Y' Strip?\n \nAdjust points manually by selecting with the ROI Manager if Required\nYou may need to Zoom in to precisely position the points\n \nPress OK to continue");
	}

	setTool("Hand");

	roiManager("Select", roiManager("count") - 2);			//	measure coords of field edges after any possible movement
	run("Measure");
	roiManager("Select", roiManager("count") - 1);
	run("Measure");

	if(count==1) {
	edgeLNX = getResult("X", nResults - 2);
	edgeLNY = getResult("Y", nResults - 2);
	edgeLSX = getResult("X", nResults - 1);
	edgeLSY = getResult("Y", nResults - 1);
	} else {
	edgeRNX = getResult("X", nResults - 2);
	edgeRNY = getResult("Y", nResults - 2);
	edgeRSX = getResult("X", nResults - 1);
	edgeRSY = getResult("Y", nResults - 1);
	}

///////	6	//////////	Field Size Calculated from Field Edges	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

	//	Field edge measured relative to central point which should be at crosswire intersection

     //     Whole field

	if(count==1) {
	LNSdist = calcDistance(edgeLNX,edgeLNY,edgeLSX,edgeLSY);
	LNSdistmm = LNSdist / NSscale;
	} else {
	RNSdist = calcDistance(edgeRNX,edgeRNY,edgeRSX,edgeRSY);
	RNSdistmm = RNSdist / NSscale;
	}

	//LEWdist = calcDistance(edgeLEX,edgeLEY,edgeLWX,edgeLWY);
	//LEWdistmm = LEWdist / EWscale;

	if(count==1) {
	LNSdifmm = LNSdistmm - fieldLeft;
	} else {
	RNSdifmm = RNSdistmm - fieldRight;
	}

	//	With Coll = 90
	//	Gun = X2		//	X1 and Y1 should be at the top pf the image, with X1 on the left. i.e. X1 is Left-North, Y2 is Right-South
	//	Target = X1
	//	B = Y1			//	X = left, Y = right, 1 = North, 2 = South
	//	A = Y2

     //     Individual Jaws

	if(count==1) {
	LCNdist = calcDistance(LCX,LCY,edgeLNX,edgeLNY);
	LCNdistmm = LCNdist / NSscale;
	LCSdist = calcDistance(LCX,LCY,edgeLSX,edgeLSY);
	LCSdistmm = LCSdist / NSscale;
	} else {
	RCNdist = calcDistance(RCX,RCY,edgeRNX,edgeRNY);
	RCNdistmm = RCNdist / NSscale;
	RCSdist = calcDistance(RCX,RCY,edgeRSX,edgeRSY);
	RCSdistmm = RCSdist / NSscale;
	}

	if(count==1) {
	LCNdifmm = LCNdistmm - (fieldLeft/2);	//	need half the field size to get half field size for distance measurement.
	LCSdifmm = LCSdistmm - (fieldLeft/2);
	} else {
	RCNdifmm = RCNdistmm - (fieldRight/2);	//	need half the field size to get half field size for distance measurement.
	RCSdifmm = RCSdistmm - (fieldRight/2);
	}

     //   Calc if field size is within tolerance

	if(count==1) {

	//Full field
	if(abs(LNSdifmm) < FieldSizeTol) {
		ResultFieldSizeDiffLNS = "OK";
		} else {
		ResultFieldSizeDiffLNS = "FAIL";
	}

	//Individual jaws
	if(abs(LCNdifmm) < FieldSizeTol) {
		ResultFieldSizeDiffLCN = "OK";
		} else {
		ResultFieldSizeDiffLCN = "FAIL";
	}

	if(abs(LCSdifmm) < FieldSizeTol) {
		ResultFieldSizeDiffLCS= "OK";
		} else {
		ResultFieldSizeDiffLCS = "FAIL";
	}
	} else {

	//Full field
	if(abs(RNSdifmm) < FieldSizeTol) {
		ResultFieldSizeDiffRNS = "OK";
		} else {
		ResultFieldSizeDiffRNS = "FAIL";
	}

	//Individual jaws
	if(abs(RCNdifmm) < FieldSizeTol) {
		ResultFieldSizeDiffRCN = "OK";
		} else {
		ResultFieldSizeDiffRCN = "FAIL";
	}

	if(abs(LCSdifmm) < FieldSizeTol) {
		ResultFieldSizeDiffRCS= "OK";
		} else {
		ResultFieldSizeDiffRCS = "FAIL";
	}
	}

	if(count==1) {
	print("\n");
	//print("-----------  Field Size (cm)  (Tol: +/- " + FieldSizeTol + " mm)  ----------");
	print("----------- Field Size (cm) ------------");
	//print("Length  \t| Std.    \t| Meas.   \t| Result");
	print("");
	print("Field Size Tol (mm): " + FieldSizeTol);
	}

	if(count==1) {
	//print("X1 (G)  \t| " + d2s(fieldLeft/20,2) + "  \t| " + d2s(LCNdistmm/10,2) +"  \t| " + ResultFieldSizeDiffLCN);
	//print("X2 (T)  \t| " + d2s(fieldLeft/20,2) + "  \t| " + d2s(LCSdistmm/10,2) +"  \t| " + ResultFieldSizeDiffLCS);
	print("");
	print("X1 (G) Std: " + d2s(fieldLeft/20,2));
	print("X1 (G) Meas: " + d2s(LCNdistmm/10,2));
	print("X1 (G) Result: " + ResultFieldSizeDiffLCN);
	print("");
	print("X2 (T) Std: " + d2s(fieldLeft/20,2));
	print("X2 (T) Meas: " + d2s(LCSdistmm/10,2));
	print("X2 (T) Result: " + ResultFieldSizeDiffLCS);
	} else {
	//print("Y1 (B)  \t| " + d2s(fieldRight/20,2) + "  \t| " + d2s(RCNdistmm/10,2) +"  \t| " + ResultFieldSizeDiffRCN);
	//print("Y2 (A)  \t| " + d2s(fieldRight/20,2) + "  \t| " + d2s(RCSdistmm/10,2) +"  \t| " + ResultFieldSizeDiffRCS);
	print("");
	print("Y1 (B) Std: " + d2s(fieldRight/20,2));
	print("Y1 (B) Meas: " + d2s(RCNdistmm/10,2));
	print("Y1 (B) Result: " + ResultFieldSizeDiffRCN);
	print("");
	print("Y2 (A) Std: " + d2s(fieldRight/20,2));
	print("Y2 (A) Meas: " + d2s(RCSdistmm/10,2));
	print("Y2 (A) Result: " + ResultFieldSizeDiffRCS);
	}

	count = count+1;

	} while (count<=2);

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

// ----------------------------------- MAKE EXTENDED LINE FUNCTION -------------------------------------------------------------------------
function LineExt(x1,y1,x2,y2, ext1,ext2,name, colour) {			//	extension is specified in pixels for function (and so may require converting before use)

//	print(name);

	grad = ( y2-y1 ) / (x2 - x1);
//	print("grad: " +grad);

	angle = atan(grad);
//	print("angle: " + angle);

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

	//makePoint(ext1x,ext1y);						//	plot point with given coord and rename (points are at end of extended line = useful for calcs)
	//roiManager("Add");
	//roiManager("Select", roiManager("count")-1);
	//roiManager("Rename", name+"ext1");
	//makePoint(ext2x,ext2y);						//	plot point with given coord and rename (points are at end of extended line = useful for calcs)
	//roiManager("Add");
	//roiManager("Select", roiManager("count")-1);
	//roiManager("Rename", name+"ext2");
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

	Point(edgex, edgey, name);					//	use function to create new point on edge located
	
	roiManager("Select", roiManager("count")-2);			//	delete line created for profile after its been used
	roiManager("Delete");

	run("Line Width...", "line=1");					//	set line width back to 1 pixel

}
//----------------------- End of Find Single Edge Function ---------------------------------------------------------------------------------------------


// ----------------------------------- FIND 2 EDGES FUNCTION -------------------------------------------------------------------------
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
//----------------------- End of Find 2 Edge Function ---------------------------------------------------------------------------------------------


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

	intX = 0;
	intY = 0;
	
	if(xi4 - xi3!=0 && xi2 - xi1!=0) {				//	If either line registers as Leftical, then need to use alternative solving methods
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
//				END OF LINAC FIELD SIZE	USING STRIPS					//
// 	- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -	//
