// 	- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -	//
//				PAPILLON FIELD SIZE & UNIFORMITY by Matt Bolt				//
// 	- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -	//
//	Macro will measure field size as defined by threshold set by user						//
//	Option is given to measure uniformity based on peripheral regions (NSEW)					//
//													//
//	* Will be performed only if uniformity analysis required (as selected using checkbox)				//
//													//
//	0 - Setup ImageJ ready for analysis to start								//
//	1 - Tolerance Levels & Standard Figures								//
//	2 - Field details are selected										//
//	3 - Cross wires marked										//
//	4 - Central ROI positioned										//
//	5 - Field edges determined										//
//	6 - Field Size calculated from field edges								//
//	*7 - Peripheral & BG ROIs positioned at set distance from central point					//
//	*8 - Ratio of peripheral to central ROI determined to assess uniformity					//
//	9 - Option to check results, restart if required then and add comments					//
//	10 - Save results											//


var intX		//	Global Variables need to be specified outside of the macro
var intY
var centreX
var centreY
var mean

macro "Papillon_Field_Analysis"{

// + + + + + + + + + + This whole macro is enclosed in a 'do... while' loop to allow analysis to be restarted if box at end is ticked i.e. if RepeatAnalysis = true + + + + + + + + + + + + +

// Last updated 18 Nov 15 after replacement of flattening filter. New threshold ratios added as well as uniformity and field size std figs
// Updated March 2016 to include display of version numbers and allow management through GitHub.
// Updated November 2022 for teh Papillon+ machine (different applicators than P50 - V1.3 should continue to be used with the P50 if required).

//// *** Version number and date last updated. To be used within the code *** /////

version = "1.4";
update_date = "30 November 2022 by Matt Bolt";

/// V1.1 Updated to find applicator centre using fitted circle ROI. Altered display of results for simple extraction in QATrack. Profile plots inverted by setting y limits.
/// V1.2 Updated version to coincide with relase of other macros.
/// V1.3 Updated to include Applicator ID selection and to address error on 'restart of macro' (closes open plot windows on restart).
/// V1.4 updated to function with the P+ which has different applicators. New standard figures added, and selectable date range altered. Will no longer work with the P50.


///////	0	//////////	Setup ImageJ as required & get image info	/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	do {
		
	close("*Plot"); // closes any open window which has a title which ends with "Plot".
		
	requires("1.47p");
	run("Profile Plot Options...", "width=450 height=300 interpolate draw sub-pixel");
	run("Set Measurements...", "area mean standard min centroid center bounding display redirect=None decimal=3");

	Dialog.create("Macro Opened");
	Dialog.addMessage("---- Papillon+ Field Analysis ----");
	Dialog.addMessage("Version: " + version);
	Dialog.addMessage("Last Updated: " + update_date);
	if(nImages==0) {
		Dialog.addMessage("");
		Dialog.addMessage("You will be prompted to open the required image after clicking OK");
	}
	Dialog.addMessage("Click OK to start");
	Dialog.show()

   myDirectory = "G:\\Shared\\Oncology\\Physics\\RTPhysics\\Brachy\\Papillon\\P+\\Papillon QA\\Field Analysis";
   call("ij.io.OpenDialog.setDefaultDirectory", myDirectory);
   call("ij.plugin.frame.Editor.setDefaultDirectory", myDirectory);

//********** Get image details & Tidy up Exisiting Windows
	
	if (nImages ==0) {
		path = File.openDialog("Select a File");
		open(path);
	}

	origImageID = getImageID();

	print("\\Clear");									//	Clears any results in log
	run("Clear Results");
	run("Select None");
	roiManager("reset");
	roiManager("Show All");
	run("Line Width...", "line=1");								//	set line thickness to 1 pixel before starting

	//defaultSaveDirectory = "G:\\Shared\\Oncology\\Physics\\RTPhysics\\EBRT Dosimetry\\";
	myFileName = getInfo("image.filename");						//	gets filename & imageID for referencing in code
	myImageID = getImageID();
	selectImage(myImageID);
	name = getTitle;									//	gets image title and removes file extension for saving purposes
	dotIndex = indexOf(name, ".");
	SaveName = substring(name, 0, dotIndex);
	run("Set Scale...", "distance=0 known=0 pixel=1 unit=pixel");

	MonthNames = newArray("Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec");		//	get current date and display in desired format
	DayNames = newArray("Sun", "Mon","Tue","Wed","Thu","Fri","Sat");
	getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
	TimeString = ""+dayOfMonth+"-"+MonthNames[month]+"-"+year;

	ImageWidthPx = getWidth();				//	returns image width in pixels
	ImageHeightPx = getHeight();

// added to automate rotation if scanner settings not correct.
	
	// 	to check if image has portrait orientation as required
	if (ImageWidthPx > ImageHeightPx) {
		//waitForUser("Rotate?", "Image will rotate 90 degrees clockwise when you click OK");	//let user know about rotation
		run("Rotate 90 Degrees Left");
		ImageWidthPx = getWidth();			//returns new image width/height in pixels after rotation for calcs
		ImageHeightPx = getHeight();
	}

	ImageWidthA4mm = 215.9;				//	known regular scanner image width in mm (from scanner settings)
	ImageHeightA4mm = 297.2;

	ImageWidthA3mm = 309.9;				//	known large scanner image width in mm (from scanner settings)
	ImageHeightA3mm = 436.9;

///////	1	//////////	Tolerance Levels & Standard Figures	///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

     //     Constants used
	LineDistFromCentremm = 30;							//	distance of lines drawn. Must be long enough to cross field edge
	roiSize = 2;
	ProfileWidthmm = 2;					//	Sets the width of the measured profile in mm - aim is to average over a wider profile to avoid problems with any noise/dust/dead pixels in image
	UniMeasDist = newArray("7","8","9","8");				//	Distance of unifomrity ROIs from centre in mm for each applicator (22mm, 25mm, 30mm, physics)

//***** Measured for P+ 25/11/22 by MB ****
	ThresFactorChoices = newArray("1.26","1.20","1.22","1.21");	//	Edge threshold factors for each beam - measured by taking exposures at 200 & 100MU.
								//	This is a multiplication factor for finding 50% pixel value for each energy


     //     Uniformity Std Figs

	// See relevant work instructions to understand what the four cardinal points refer to.		
	
// **** Updated for P+ based on films taken on 18/11/22 and 23/11/22 by MB and HC/SGO respectively.

	UniformityNRatio = newArray("0.995","0.991","0.993","1.006");		//	Uniformity values for each applicator (20mm, 25mm, 30mm, physics)
	UniformitySRatio = newArray("0.982","0.976","0.982","0.987");		//	N etc is specified within the protocol, and may depend on the applicator/unit orientation.
	UniformityERatio = newArray("0.981","0.978","0.983","0.985");
	UniformityWRatio = newArray("0.988","0.994","0.994","1.011");

     //     Tolerance Levels		************ THESE NEED RE-DEFINING IF NECESSARY - MONITOR ************
	FieldSizeTol = 0.5;			// tolerance for field size is +/- 0.5mm (+/- 1mm suspension)
	FieldSizeTolSusp = 1;
	RatioTol = 3;			// tolerance on uniformity ratios is +/- 3% (+/-5% suspension) (Equivalent to +/-5%  (or +/-7%) in dose)
	RatioTolSusp = 5;
	

///////	2	//////////	Field Details Selected	//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

	AppChoices = newArray("20mm","25mm","30mm","Physics (25mm)","Select...");		//	These can be given names as this array is only used for selection purposes
									//	Physics applicator should be identical to 30mm applicator
	AppIDs = newArray("Select...",
			"2102-AR-20-0003",
			"2102-AR-20-0005",
			"2102-AR-20-0011",
			"2102-AR-25-0002",
			"2102-AR-25-0005",
			"2102-AR-25-0014",
			"2102-AR-25-0020",
			"2102-AR-30-0019",
			"2102-AR-30-0020",
			"Physics (25mm)",
			"Other");			//	SNs added for P+ use

	FieldSizeChoices = newArray("20.4","25.3","30.5","25.5");		//	relate horiz & vert field size to app selected - these are the standard figures

	ScannerChoices = newArray("11000XL Pro","V750 Pro");

	DayChoices = newArray(31);					//	length of array
		for(i=0; i<DayChoices.length; i++)			//	set incremental values in array
		DayChoices[i] = d2s(1+i,0);
	MonthChoices = newArray("Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec");
	YearChoices = newArray(11);
		for(i=0; i<YearChoices.length; i++)
		YearChoices[i] = d2s(2022+i,0);

	Dialog.create("Field Details");
	Dialog.addMessage("--- Date of Exposure ---");
	Dialog.addChoice("Day", DayChoices, dayOfMonth);
	Dialog.addChoice("Month", MonthChoices, MonthChoices[month]);
	Dialog.addChoice("Year", YearChoices, year);
	Dialog.addMessage("--- Exposure Details ---");
	Dialog.addChoice("Scanner", ScannerChoices,ScannerChoices[0]);
	Dialog.addChoice("Applicator size", AppChoices,"Select...");
	Dialog.addChoice("Applicator ID", AppIDs,"Select...");
	Dialog.addCheckbox("Uniformity Analysis", true);
	Dialog.show();

	DaySelected = Dialog.getChoice();
	MonthSelected = Dialog.getChoice();
	YearSelected = Dialog.getChoice();

	ScannerSelected = Dialog.getChoice();
	AppSelected = Dialog.getChoice();
	AppIDSelected = Dialog.getChoice();
	UniformitySelected = Dialog.getCheckbox();				//	returns true or false to allow uniformity to me measured or not

	DateSelected = DaySelected + "-" + MonthSelected + "-" + YearSelected;

	AppSelectedPos = ArrayPos(AppChoices,AppSelected);

	ThresFactor = ThresFactorChoices[AppSelectedPos];			//	Threshold factor for field edges may vary with energy
	FieldSizeSelected = FieldSizeChoices[AppSelectedPos];			//	Field size in mm
	UniMeasDistSelected = UniMeasDist[AppSelectedPos];			//	Uniformity ROI positions

	UniformityNRatioSelected = UniformityNRatio[AppSelectedPos];		//	Uniformity Ratio North
	UniformitySRatioSelected = UniformitySRatio[AppSelectedPos];		//	Uniformity Ratio South
	UniformityERatioSelected = UniformityERatio[AppSelectedPos];		//	Uniformity Ratio East
	UniformityWRatioSelected = UniformityWRatio[AppSelectedPos];		//	Uniformity Ratio West

	if(ScannerSelected == "11000XL Pro") {
		ImageWidthSelectedmm = ImageWidthA3mm;
		ImageHeightSelectedmm = ImageHeightA3mm;
		ScannerModelSelected = "Epson Expression 11000XL Pro";
		run("In [+]");						//	Zoom into image
		} else {
		ImageWidthSelectedmm = ImageWidthA4mm;
		ImageHeightSelectedmm = ImageHeightA4mm;
		ScannerModelSelected = "Epsom Perfection V750 Pro";
		}

	EWscale = ImageWidthPx / ImageWidthSelectedmm;		//	gives conversion factor from px to mm from scanner selected
	NSscale = ImageHeightPx / ImageHeightSelectedmm;

	fieldEW = FieldSizeSelected;				//	Field size in mm for calcs
	fieldNS = FieldSizeSelected;

	FieldDetailsSelected = FieldSizeSelected + " mm Diameter";

	if (UniformitySelected == true) {
		UniformityPerformed = "Yes";
		} else {
		UniformityPerformed = "No";
		}


	print("------------------------------------------------------------------------");
	print("                    Papillon Field Analysis Results");
	print("------------------------------------------------------------------------");
	print("Macro Version:"+version);
	print("\n");
	print("File Analysed:   \t" +myFileName);
	print("Exposure Date:   \t" + DateSelected);
	print("Analysis Date:   \t" +TimeString);
	print("\n");
	print("Scanner:   \t" + ScannerModelSelected);
	print("Applicator Size:   \t" + AppSelected);
	print("Applicator ID:   \t" + AppIDSelected);
	print("Uniformity Analysed:   \t" + UniformityPerformed);
	

//	print("Horizontal Scale (pix/mm):\t" + EWscale);
//	print("Vertical Scale (pix/mm):\t" + NSscale);

///////	3	//////////	Cross Wires Marked	//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

	setTool("zoom");									//	Set tool to magnify, for user to zoom in before starting
	waitForUser("Zoom", "Click on image to magnify\n \nClick OK when complete");

//*********** find centre of irradiation by fitting circles to 3 points placed by user


	//CircleCentreROI(roiSizePx,roiSizePx,"Centre ROI 50%","Red","Select 3 points around 50% exposure edge.\n \nEnsure that RED channel is selected using scroll bar at bottom of image\n \nClick OK when complete");
	CircleCentreROI(roiSize*EWscale,roiSize*NSscale,"Centre ROI 50%","Red","Select 3 points around 50% exposure edge. (Use 'alt' to delete a point)\n \nEnsure that RED channel is selected using scroll bar at bottom of image\n \nClick OK when complete");	
		circlemean = mean;
		centrex = centreX;
		centrey = centreY;
		
	NX = centrex;									// set positions of extended line points
	NY = centrey - (LineDistFromCentremm * NSscale);
	EX = centrex + (LineDistFromCentremm * EWscale);
	EY = centrey;
	SX = centrex;
	SY = centrey + (LineDistFromCentremm * NSscale);
	WX = centrex - (LineDistFromCentremm * EWscale);
	WY = centrey;
	
//********** Create lines to use for getting profiles/ROIs etc
	
	
	Line(NX,NY,SX,SY, "LineNS", "yellow");
	run("Measure");
	angleNS = getResult("Angle", nResults - 1);				//	get angle of line - is in degrees and requires conversion to radians for use in calculations

	Line(WX,WY,EX,EY,"LineEW", "yellow");
	run("Measure");
	angleEW = getResult("Angle", nResults - 1);


	
	
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

	ThresVal = RAWmeanROIcentre * ThresFactor;			//	find 50% threshold value in pixels by multiplying central value by threshold factor

//	print("Threshold Val (pix):\t" + ThresVal);

	FindEdges(NX,NY,SX,SY,CX,CY, ProfileWidthmm * EWscale,ThresVal,"Edge North","Edge South",0,0);		//	this is a custom function which finds the 2 edges of the field between the specified points
	FindEdges(WX,WY,EX,EY,CX,CY, ProfileWidthmm * NSscale,ThresVal,"Edge West","Edge East",0,0);

	setTool("multipoint");
	selectWindow("ROI Manager");
	setLocation(0.8*screenWidth(),0);
	roiManager("Select", roiManager("count") - 4);
	waitForUser("Field Edges", "Have Field Edges Been Located Correctly?\n \nAdjust points manually by sleecting with the ROI Manager if Required\nYou may need to Zoom in to precisely position the points\n \nPress OK to continue");
	setTool("Hand");

	roiManager("Select", roiManager("count") - 4);			//	measure coords of field edges after any possible movement
	run("Measure");
	roiManager("Select", roiManager("count") - 3);
	run("Measure");
	roiManager("Select", roiManager("count") - 2);
	run("Measure");
	roiManager("Select", roiManager("count") - 1);
	run("Measure");

	edgeNX = getResult("X", nResults - 4);				//	get coords of each edge point from the results window
	edgeNY = getResult("Y", nResults - 4);
	edgeSX = getResult("X", nResults - 3);
	edgeSY = getResult("Y", nResults - 3);
	edgeEX = getResult("X", nResults - 2);
	edgeEY = getResult("Y", nResults - 2);
	edgeWX = getResult("X", nResults - 1);
	edgeWY = getResult("Y", nResults - 1);

///////	6	//////////	Field Size Calculated from Field Edges	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

	NSdist = calcDistance(edgeNX,edgeNY,edgeSX,edgeSY);
	NSdistmm = NSdist / NSscale;
	EWdist = calcDistance(edgeEX,edgeEY,edgeWX,edgeWY);
	EWdistmm = EWdist / EWscale;

	NSdifmm = NSdistmm - fieldNS;
	EWdifmm = EWdistmm - fieldEW;

       //  Calc if field size is within tolerance

	if (abs(NSdifmm) < FieldSizeTol) {
		ResultFieldSizeDiffNS = "OK";
	} else if (abs(NSdifmm) < FieldSizeTolSusp) {
			ResultFieldSizeDiffNS = "ACTION";
	} else {
		ResultFieldSizeDiffNS = "SUSPENSION";
	}

	if (abs(EWdifmm) < FieldSizeTol) {
		ResultFieldSizeDiffEW = "OK";
	} else if (abs(EWdifmm) < FieldSizeTolSusp) {
			ResultFieldSizeDiffEW = "ACTION";
	} else {
		ResultFieldSizeDiffEW = "SUSPENSION";
	}

	print("\n");
	print("-----------  Field Size Results  ----------");
	print("Expected EW: " + d2s(fieldEW,1));
	print("Expected NS: " + d2s(fieldNS,1));
	print("Action Tolerance (mm): " + FieldSizeTol);
	print("Suspension Tolerance (mm): " + FieldSizeTolSusp);
	print("Measured EW: " + d2s(EWdistmm,1));
	print("Measured NS: " + d2s(NSdistmm,1));
	print("Result EW: " + ResultFieldSizeDiffEW);
	print("Result NS: " + ResultFieldSizeDiffNS);


///////	7*	//////////	Peripheral ROIs & BG ROIs Positioned for Uniformity Analysis	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// $$$$$
	if (UniformitySelected == true) {			//	points 7 and 8 only run if true is slected and are contained within an IF statement marked with $$$$$

	roiEWdistmm = UniMeasDistSelected;		//	position of peripheral ROIs based on applicator selected
	roiNSdistmm = UniMeasDistSelected;			//	EW and NW are dealt with seperately in case of different scales.
	roiEWdist = 1 * roiEWdistmm * EWscale;
	roiNSdist = 1 * roiNSdistmm * NSscale;

	bgROIposNS = 3 * NSscale;						//	Distance of bg ROIs from marker points (3mm is set but user can then adjust positions)
	bgROIposEW = 3 * EWscale;

	if(NY-roiRadNS-bgROIposNS<0) {					//	if statement used to ensure ROI is positioned within image area
		RectROI(NX-roiRadEW, NY+roiRadNS+bgROIposNS, roiDiamEW, roiDiamNS,"BG ROI North","blue");
		} else {
		RectROI(NX-roiRadEW, NY-roiRadNS-bgROIposNS, roiDiamEW, roiDiamNS,"BG ROI North","blue");
		}

	if(SY-roiRadNS+bgROIposNS>ImageHeightPx) {
		RectROI(SX-roiRadEW, SY+roiRadNS-bgROIposNS, roiDiamEW, roiDiamNS,"BG ROI South","blue");
		} else {
		RectROI(SX-roiRadEW, SY-roiRadNS+bgROIposNS, roiDiamEW, roiDiamNS,"BG ROI South","blue");
		}

	if(WX-roiRadEW-bgROIposEW<0) {
		RectROI(WX+roiRadEW+bgROIposEW, WY-roiRadEW, roiDiamEW, roiDiamNS,"BG ROI West","blue");
		} else {
		RectROI(WX-roiRadEW-bgROIposEW, WY-roiRadEW, roiDiamEW, roiDiamNS,"BG ROI West","blue");
		}

	if(EX-roiRadEW+bgROIposEW>ImageWidthPx) {
		RectROI(EX-roiRadEW-bgROIposEW, EY-roiRadEW, roiDiamEW, roiDiamNS,"BG ROI East","blue");
		} else {
		RectROI(EX-roiRadEW+bgROIposEW, EY-roiRadEW, roiDiamEW, roiDiamNS,"BG ROI East","blue");
		}


	setTool("Rectangle");
	selectWindow("ROI Manager");
	setLocation(0.8*screenWidth(),0);
	roiManager("Select", roiManager("count") - 4);
	waitForUser("Background ROI Position", "Check position of Background ROIs\n \nTo move: Select using the ROI Manager Window & Click and Drag\n \nPress OK  when ROIs are correctly positioned");
	setTool("Hand");								//	Ensure User does not easily adjust anything by a rogue click on screen
	
	roiManager("Select", roiManager("count") - 4);					//	Measures BG ROIs following any movement by user
	run("Measure");
	roiManager("Select", roiManager("count") - 3);
	run("Measure");
	roiManager("Select", roiManager("count") - 2);
	run("Measure");
	roiManager("Select", roiManager("count") - 1);
	run("Measure");

	RAWmeanROInorthBG = getResult("Mean", nResults - 4);			//	extracts mean of BG ROI
	RAWmeanROIsouthBG = getResult("Mean", nResults - 3);
	RAWmeanROIwestBG = getResult("Mean", nResults - 2);
	RAWmeanROIeastBG = getResult("Mean", nResults - 1);

	bgROImean = 0.25*(RAWmeanROInorthBG + RAWmeanROIsouthBG + RAWmeanROIeastBG + RAWmeanROIwestBG);		//	mean of all BG ROIs

	NSXcorr = roiNSdist * cos(angleNS * PI / 180);					//	convert measured distances to X & Y distances using trig
	NSYcorr = roiNSdist * sin(angleNS * PI / 180);					//	angles in degrees are converted to radians for calculation
	EWXcorr = roiEWdist * cos(angleEW * PI / 180);
	EWYcorr = roiEWdist * sin(angleEW * PI / 180);

	RectROI(CX-roiRadEW-NSXcorr, CY-roiRadNS+NSYcorr, roiDiamEW, roiDiamNS,"ROI North","red");				//	Make peripheral ROIs along lines
	RectROI(CX-roiRadEW+NSXcorr, CY-roiRadNS-NSYcorr, roiDiamEW, roiDiamNS,"ROI South","red");
	RectROI(CX-roiRadEW-EWXcorr, CY-roiRadNS+EWYcorr, roiDiamEW, roiDiamNS,"ROI West","red");
	RectROI(CX-roiRadEW+EWXcorr, CY-roiRadNS-EWYcorr, roiDiamEW, roiDiamNS,"ROI East","red");

	roiManager("Select", roiManager("count") - 4);					//	Measures Peripheral ROIs
	run("Measure");
	roiManager("Select", roiManager("count") - 3);
	run("Measure");
	roiManager("Select", roiManager("count") - 2);
	run("Measure");
	roiManager("Select", roiManager("count") - 1);
	run("Measure");

	RAWmeanROInorth = getResult("Mean", nResults - 4);				//	extracts mean of peripheral ROIs
	RAWmeanROIsouth = getResult("Mean", nResults - 3);
	RAWmeanROIwest = getResult("Mean", nResults - 2);
	RAWmeanROIeast = getResult("Mean", nResults - 1);

	CORRmeanROIcentre = abs(RAWmeanROIcentre - bgROImean);
	CORRmeanROInorth = abs(RAWmeanROInorth - bgROImean);
	CORRmeanROIsouth = abs(RAWmeanROIsouth - bgROImean);
	CORRmeanROIwest = abs(RAWmeanROIwest - bgROImean);
	CORRmeanROIeast = abs(RAWmeanROIeast - bgROImean);


///////	8*	//////////	Ratio of Peripheral ROIs to Centre calcualted for Uniformity Analysis	//////////////////////////////////////////////////////////////////////////////////////////////////////////////


	RATIOnorth = CORRmeanROInorth / CORRmeanROIcentre;			//	take ratio of peripheral ROIs to central
	RATIOsouth = CORRmeanROIsouth / CORRmeanROIcentre;
	RATIOwest = CORRmeanROIwest / CORRmeanROIcentre;
	RATIOeast = CORRmeanROIeast / CORRmeanROIcentre;
	//RATIOcentre = CORRmeanROIcentre / CORRmeanROIcentre;

	RATIOnorthDifPerc = ((RATIOnorth / UniformityNRatioSelected) - 1)*100;		//	calculate percentage difference of ratios from standards
	RATIOsouthDifPerc = ((RATIOsouth / UniformitySRatioSelected) - 1)*100;
	RATIOwestDifPerc = ((RATIOwest / UniformityWRatioSelected) - 1)*100;
	RATIOeastDifPerc = ((RATIOeast / UniformityERatioSelected) - 1)*100;

	if (abs(RATIOnorthDifPerc) < RatioTol) {						//	Check ratios are within tolerance
		ResultRatioN = "OK";
	} else if (abs(RATIOnorthDifPerc) < RatioTolSusp) {
		ResultRatioN = "ACTION";
	} else {
		ResultRatioN = "SUSPENSION";
	}

	if (abs(RATIOsouthDifPerc) < RatioTol) {
		ResultRatioS = "OK";
	} else if (abs(RATIOsouthDifPerc) < RatioTolSusp) {
		ResultRatioS = "ACTION";
	} else {
		ResultRatioS = "SUSPENSION";
	}

	if (abs(RATIOwestDifPerc) < RatioTol) {
		ResultRatioW = "OK";
	} else if (abs(RATIOwestDifPerc) < RatioTolSusp) {
			ResultRatioW = "ACTION";
	} else {
		ResultRatioW = "SUSPENSION";
	}

	if (abs(RATIOeastDifPerc) < RatioTol) {
		ResultRatioE = "OK";
	} else if (abs(RATIOeastDifPerc) < RatioTolSusp) {
		ResultRatioE = "ACTION";
	} else {
		ResultRatioE = "SUSPENSION";
	}

	print("\n");
	print("---------  Uniformity Results  ---------");

	print("Uniformity Std-N: " + d2s(UniformityNRatioSelected,3));
	print("Uniformity Std-S: " + d2s(UniformitySRatioSelected,3));
	print("Uniformity Std-E: " + d2s(UniformityERatioSelected,3));
	print("Uniformity Std-W: " + d2s(UniformityWRatioSelected,3));
	print("Action Tolerance (%): " + RatioTol);
	print("Suspension Tolerance (%): " + RatioTolSusp);
	print("Measured Ratio-N: " + d2s(RATIOnorth,3));
	print("Measured Ratio-S: " + d2s(RATIOsouth,3));
	print("Measured Ratio-E: " + d2s(RATIOeast,3));
	print("Measured Ratio-W: " + d2s(RATIOwest,3));
	print("Difference (%)-N: " + d2s(RATIOnorthDifPerc,1));
	print("Difference (%)-S: " + d2s(RATIOsouthDifPerc,1));
	print("Difference (%)-E: " + d2s(RATIOeastDifPerc,1));
	print("Difference (%)-W: " + d2s(RATIOwestDifPerc,1));
	print("Result-N : " +ResultRatioN);
	print("Result-S : " +ResultRatioS);
	print("Result-E : " +ResultRatioE);
	print("Result-W : " +ResultRatioW);
	

	} else {
	
	print("\n");
	print("---------  Uniformity  ---------");
	print("Not Measured");
	print("\n");
	print("\n");
	print("\n");
	print("\n");

	}		//	end of IF statement for performing Uniformity analysis
// $$$$$

////////// Display profile plots ////////////////

	// North South Profile Plot
	selectImage(origImageID);
	roiManager("select",1);
	profileNS = getProfile();
	Plot.create("North - South Plot", "Position", "Pixel Value", profileNS);
	Plot.setFrameSize(350,250);
	Plot.setLimits(NaN, NaN, 70000, 15000);
	Plot.show();
	setLocation(0,500);

	// West East Profile Plot
	selectImage(origImageID);
	roiManager("select",2);
	profileWE = getProfile();
	Plot.create("West - East Plot", "Position", "Pixel Value", profileWE);
	Plot.setFrameSize(350,250);
	Plot.setLimits(NaN, NaN, 70000, 15000);
	Plot.show();
	setLocation(500,500);
	selectWindow("North - South Plot");
	selectWindow("West - East Plot");

///////	9	//////////	Option to Check Results & Restart Analysis	//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

	selectWindow("Log");
	setLocation(0,100);
	waitForUser("Analysis Complete", "Check Results Displayed In Log Window.   Press OK to Continue");	//	user can check results prior to adding comments

	Dialog.create("Restart Analysis");
	Dialog.addMessage("Tick to restart analysis. Results will NOT be saved if you do this");
	Dialog.addCheckbox("Restart Analysis",false);
	Dialog.addMessage("Press OK to continue");
	Dialog.show();

	RepeatAnalysis = Dialog.getCheckbox();

	} while (RepeatAnalysis == true);

// + + + + + + + + + + + + + This whole macro above is enclosed in a 'do... while' loop to allow analysis to be restarted if box at end is ticked i.e. if RepeatAnalysis = true;. + + + + + + + + + + + + + + + +


///////	10	//////////	Add Comments & Save Results	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


	Dialog.create("Comments");							//	Allows user to insert comments if required. Default is "Results OK" These are then added to Log
	Dialog.addMessage("Add any Comments in the Box Below");
	Dialog.addString("Comments:", "(None)",40);
	Dialog.addMessage("");
	Dialog.addString("Analysis Performed by:", "",10);
	Dialog.addMessage("Click OK to Continue");
	Dialog.show();

	print("\n");
	print("Comments: " + Dialog.getString());
	print("\n");
	print("Performed by: " + Dialog.getString());
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


// ----------------------------------- MAKE CIRCLE CENTRE ROI FUNCTION -------------------------------------------------------------------------
function CircleCentreROI(width, height, name, colour,message) {

	resultsstart = nResults;							//	used to count the number of resutls so that can check if 3 points have been selected for circle fitting.

	setTool("multipoint");
	waitForUser("Mark Circle Edge", message);						//	user selects (3) points around the circle edge

	run("Measure");
		selectWindow("Results");							//	moves results window out of view
		setLocation(screenWidth()*0.95,screenHeight()*0.95);

	resultsend = nResults;

	while(resultsend-resultsstart != 3) {
		resultsstart = nResults;
			setTool("multipoint");						//	3 points only should be selected to fit circle
			waitForUser(message);
			run("Measure");
		resultsend = nResults;
		}

	run("Fit Circle");
	//waitForUser("Circular field marked correctly? Adjust position if necessary.");		//	could remove this as centre of 50% is not critical.

	run("Measure");								//	get circle centre coordinates
	//waitForUser("measure done");
		centreX = getResult("XM",nResults - 1);
		centreY = getResult("YM",nResults - 1);

	RectROI(centreX-(width/2),centreY-(height/2),width,height, name, colour);		//	plot central ROI

	run("Measure");								//	get 50% mean from ROI
		mean = getResult("Mean",nResults - 1);
}
// --------------------- End of MakeCircleRoi Funciton ------------------------------------------------------------

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



// 	- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -	//
//				END OF Papillon FIELD SIZE & UNIFORMITY					//
// 	- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -	//
