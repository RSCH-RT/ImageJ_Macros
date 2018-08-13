// 	- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -	//
//				GULMAY FIELD SIZE & UNIFORMITY by Matt Bolt				//
// 	- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -	//
//	Macro will measure field size as defined by threshold set by user						//
//	Option is given to measure uniformity based on peripheral regions (NSEW)					//
//													//
//	* Will be performed only if uniformity analysis required (App C & J)						//
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

macro "Gulmay_Field_Analysis"{

// + + + + + + + + + + + + + This whole macro is enclosed in a 'do... while' loop to allow analysis to be restarted if box at end is ticked i.e. if RepeatAnalysis = true + + + + + + + + + + + + + + + +

version = "1.3";
update_date = "23 December 2016 by MB";

///////	0	//////////	Setup ImageJ as required & get image info	/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	do {
	requires("1.47p");
	run("Profile Plot Options...", "width=450 height=300 interpolate draw sub-pixel");

	Dialog.create("Macro Opened");
	Dialog.addMessage("---- Gulmay Field Analysis ----");
	Dialog.addMessage("Version: " + version);
	Dialog.addMessage("Last Updated: " + update_date);
	if(nImages==0) {
		Dialog.addMessage("");
		Dialog.addMessage("You will be prompted to open the required image after clicking OK");
	}
	Dialog.addMessage("Click OK to start");
	Dialog.show()

   myDirectory = "G:\\Shared\\Oncology\\Physics\\RTPhysics\\EBRT Dosimetry\\XstrahlGulmay Commissioning 2011 to 12\\Field Analysis QC";
   call("ij.io.OpenDialog.setDefaultDirectory", myDirectory);
   call("ij.plugin.frame.Editor.setDefaultDirectory", myDirectory);

//********** Get image details & Tidy up Exisiting Windows

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

	//defaultSaveDirectory = "G:\\Shared\\Oncology\\Physics\\RTPhysics\\EBRT Dosimetry\\XstrahlGulmay\\Field Analysis QC\\Results\\";
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


	ThresFactorChoices = newArray("1.28","1.32","1.35","1.34");		//	Edge threshold factors for each beam - measured by taking exposures at 200 & 100MU.
									//	This is a multip;lication factor for finding 50% pixel value for each energy


     //     Uniformity Std Figs

	//	North = Sink
	//	South = Intercom
	//	East = Anode
	//	West = Cathode

//	----- Correct as of 01/08/13 (Values given to 2 d.p.) -----


//	if(dayOfMonth == 1 && month == 0) {
//		YesterdayYear = year-1;
//		} else {
//		YesterdayYear = year;
//		}

	UniAppCMeasDist = 3;		// distance of uniformity ROIs from centre should be 3cm for 8cm circle (app C)
	UniAppJMeasDist = 8;		// distance of uniformity ROIs from centre should be 8cm for 20x20 (app J)

     //     Tolerance Levels
	FieldSizeTol = 2;			// tolerance for field size is +/- 2mm
	//FieldEdgeTol = 1;			// tolerance for distance from pinned crosswire to field edge is +/- 1mm (should be 3mm for 30cm FSD, and 4mm for 50cm FSD)
	RatioTol = 3;			// tolerance on uniformity ratios is +/- 3% (Equivalent to +/-5% in dose as on previous films)
	

///////	2	//////////	Field Details Selected	//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

	BeamChoices = newArray("80kV - 30cm FSD","140kV - 30cm FSD","140kV - 50cm FSD","250kV - 50cm FSD");
	AppChoices = newArray("4cm Circle","6cm Circle","8cm Circle","6x6cm","6x10cm","8x8cm","8x12cm","10x10cm","15x15cm","20x20cm");

	EnergyChoices = newArray("80kV","140kV","140kV","250kV");		//	1:1 relationship to FilterChoices array
	FSDChoices = newArray("30cm","30cm","50cm","50cm");
	FilterChoices = newArray("2","4","6","9");

	AppIDChoices = newArray("A","B","C","D","E","F","G","H","I","J");
	FieldSizeHorizChoices = newArray("4","6","8","6","6","8","12","10","15","20");		//	relate horiz & vert field size to app selected
	FieldSizeVertChoices = newArray("4","6","8","6","10","8","8","10","15","20");
	FieldShapeChoices = newArray("Circle","Circle","Circle","Rectangle","Rectangle","Rectangle","Rectangle","Rectangle","Rectangle","Rectangle");
	
	ScannerChoices = newArray("V750 Pro","11000XL Pro");

	DayChoices = newArray(31);			//	length of array
		for(i=0; i<DayChoices.length; i++)	//	set incremental values in array
		DayChoices[i] = d2s(1+i,0);
	MonthChoices = newArray("Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec");
	YearChoices = newArray(11);
		for(i=0; i<YearChoices.length; i++)
		YearChoices[i] = d2s(2010+i,0);

	Dialog.create("Analysis Type");
	Dialog.addCheckbox("Advanced Analysis Required",false);
	Dialog.show();
	
	advanced = Dialog.getCheckbox();	// true or false to advanced use.


	if(advanced == false) {
	Dialog.create("Field Details");
	Dialog.addMessage("--- Date of Exposure ---");
	Dialog.addChoice("Day", DayChoices, YesterdayDay);
	Dialog.addChoice("Month", MonthChoices, YesterdayMonth);
	Dialog.addChoice("Year", YearChoices, YesterdayYear);
	Dialog.addMessage("--- Exposure Details ---");
	Dialog.addChoice("Scanner", ScannerChoices,ScannerChoices[1]);
	Dialog.addChoice("Beam", BeamChoices);
	Dialog.addChoice("Applicator", AppChoices);
	Dialog.show();
	}

	if(advanced == true) {
	Dialog.create("Field Details");
	Dialog.addMessage("--- Date of Exposure ---");
	Dialog.addChoice("Day", DayChoices, YesterdayDay);
	Dialog.addChoice("Month", MonthChoices, YesterdayMonth);
	Dialog.addChoice("Year", YearChoices, YesterdayYear);
	Dialog.addMessage("--- Exposure Details ---");
	Dialog.addChoice("Scanner", ScannerChoices);
	Dialog.addChoice("Beam", BeamChoices);
	Dialog.addChoice("Applicator", AppChoices);
	Dialog.addMessage("--- Analysis Parameters ---");
	Dialog.addNumber("ROI Size (mm)",roiSize);
	Dialog.addNumber("ROI dist from centre (cm)", 3);
	Dialog.show();
	}

	DaySelected = Dialog.getChoice();
	MonthSelected = Dialog.getChoice();
	YearSelected = Dialog.getChoice();

	ScannerSelected = Dialog.getChoice();

	EnergyFSD = Dialog.getChoice();
	AppSelected = Dialog.getChoice();

	if(advanced == true) {
	roiSize = Dialog.getNumber();
	roiEWdistcm = Dialog.getNumber();
	roiNSdistcm = roiEWdistcm;
	}

	DateSelected = DaySelected + "-" + MonthSelected + "-" + YearSelected;

	BeamSelectedPos = ArrayPos(BeamChoices,EnergyFSD);
	AppSelectedPos = ArrayPos(AppChoices,AppSelected);

	EnergySelected = EnergyChoices[BeamSelectedPos];		//	Get field details from known array position for use during macro
	FSDSelected = FSDChoices[BeamSelectedPos];
	FilterSelected = FilterChoices[BeamSelectedPos];

	ThresFactor = ThresFactorChoices[BeamSelectedPos];		//	Threshold factor for field edges may vary with energy
//	EdgeThresPerc = 100*ThresFactor;
	
	AppIDSelected = AppIDChoices[AppSelectedPos];
	FieldSizeHorizSelected = FieldSizeHorizChoices[AppSelectedPos];	//	Field size in cm
	FieldSizeVertSelected = FieldSizeVertChoices[AppSelectedPos];
	appShape = FieldShapeChoices[AppSelectedPos];

	if(ScannerSelected == "11000XL Pro") {

		run("In [+]");		//	Zoom into image

		ImageWidthSelectedmm = ImageWidthA3mm;
		ImageHeightSelectedmm = ImageHeightA3mm;
		ScannerModelSelected = "Epson Expression 11000XL Pro";

		RatioN80kV8circle = 0.97;		//	these are the standard background corrected uniformity ratios and should be kept up-to-date
		RatioS80kV8circle = 0.97;		//	the correct ones are selected based on the energy/applicator selected and named RatioNStdSelected etc
		RatioE80kV8circle = 0.98;
		RatioW80kV8circle = 0.96;

		RatioN140kV8circle = 0.97;		//	there are no film std figs for these
		RatioS140kV8circle = 0.97;
		RatioE140kV8circle = 0.98;
		RatioW140kV8circle = 0.97;

		RatioN140kV20x20 = 0.96;		//	Note that ratios depend upon the scanner selected due to the film not laying flat for large fields on the V750
		RatioS140kV20x20 = 0.96;
		RatioE140kV20x20 = 1.00; 		//0.97; These are the previous V750 values
		RatioW140kV20x20 = 0.98;		//0.95;

		RatioN250kV20x20 = 0.93;
		RatioS250kV20x20 = 0.92;
		RatioE250kV20x20 = 1.01;		//0.97;
		RatioW250kV20x20 = 0.94;		//0.90;

		} else {

		ImageWidthSelectedmm = ImageWidthA4mm;
		ImageHeightSelectedmm = ImageHeightA4mm;
		ScannerModelSelected = "Epsom Perfection V750 Pro";

		RatioN80kV8circle = 0.97;		//	these are the standard background corrected uniformity ratios and should be kept up-to-date
		RatioS80kV8circle = 0.97;		//	the correct ones are selected based on the energy/applicator selected and named RatioNStdSelected etc
		RatioE80kV8circle = 0.98;
		RatioW80kV8circle = 0.96;

		RatioN140kV8circle = 0.97;		//	there are no film std figs for these
		RatioS140kV8circle = 0.97;
		RatioE140kV8circle = 0.98;
		RatioW140kV8circle = 0.97;

		RatioN140kV20x20 = 0.96;
		RatioS140kV20x20 = 0.96;
		RatioE140kV20x20 = 0.97;
		RatioW140kV20x20 = 0.95;

		RatioN250kV20x20 = 0.93;
		RatioS250kV20x20 = 0.92;
		RatioE250kV20x20 = 0.97;
		RatioW250kV20x20 = 0.90;

		}

	EWscale = ImageWidthPx / ImageWidthSelectedmm;		//	gives conversion factor from px to mm from scanner selected
	NSscale = ImageHeightPx / ImageHeightSelectedmm;

	fieldEW = 10*FieldSizeHorizSelected;				//	Field size in mm for calcs
	fieldNS = 10*FieldSizeVertSelected;

	if(advanced == true) {
	roiEWdist = 10 * roiEWdistcm * EWscale;
	roiNSdist = 10 * roiNSdistcm * NSscale;
	}


	if (appShape == "Circle") {					//	Display size dependant on circular or rectangular app.
		FieldDetailsSelected = FieldSizeHorizSelected + " cm Diameter";
		appThick = 3;
		} else {
		FieldDetailsSelected = FieldSizeHorizSelected + " x " + FieldSizeVertSelected + " cm";
		appThick = 4;
		}
	
	if (AppIDSelected == "C" || AppIDSelected == "J") {			//	If app A or J then perform uniformity test
		UniformityAnalysis = true;
		UniformityPerformed = "Yes";
		} else {
		UniformityAnalysis = false;
		UniformityPerformed = "No";
		}


if (advanced == false) {
	if (AppIDSelected == "C" && FilterSelected == 2) {			//	Set standard uniformity ratios to use based on app/filter
		RatioNStdSelected = RatioN80kV8circle;
		RatioSStdSelected = RatioS80kV8circle;
		RatioEStdSelected = RatioE80kV8circle;
		RatioWStdSelected = RatioW80kV8circle;
		}

	if (AppIDSelected == "C" && FilterSelected == 4) {
		RatioNStdSelected = RatioN140kV8circle;
		RatioSStdSelected = RatioS140kV8circle;
		RatioEStdSelected = RatioE140kV8circle;
		RatioWStdSelected = RatioW140kV8circle;
		}

	if (AppIDSelected == "J" && FilterSelected == 6) {
		RatioNStdSelected = RatioN140kV20x20;
		RatioSStdSelected = RatioS140kV20x20;
		RatioEStdSelected = RatioE140kV20x20;
		RatioWStdSelected = RatioW140kV20x20;
		}
	if (AppIDSelected == "J" && FilterSelected == 9) {
		RatioNStdSelected = RatioN250kV20x20;
		RatioSStdSelected = RatioS250kV20x20;
		RatioEStdSelected = RatioE250kV20x20;
		RatioWStdSelected = RatioW250kV20x20;
		}
}

	print("------------------------------------------------------------------------");
	print("                    Gulmay Field Analysis Results");
	print("------------------------------------------------------------------------");
	print("\n");
	print("File Analysed:  " +myFileName);
	print("Exposure Date:  " + DateSelected);
	print("Analysis Date:  " +TimeString);
	print("Macro Version:"+version);
	print("\n");
	print("Scanner:  " + ScannerModelSelected);
	print("Energy: " + EnergySelected);
	print("Filter: " + FilterSelected);
	print("App:   \t" + AppSelected);
	print("FSD: " + FSDSelected);
	print("App. :  " + AppIDSelected);
	print("Uniformity Analysed:  " + UniformityPerformed);
	

//	print("Horizontal Scale (pix/mm): " + EWscale);
//	print("Vertical Scale (pix/mm): " + NSscale);

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

	ThresVal = RAWmeanROIcentre * ThresFactor;	
//	ThresVal = RAWmeanROIcentre - ((1-EdgeThresPerc/100)* (RAWmeanROIcentre - bgROImean));			//	converts factor to pixel value

//	print("Field Edge Threshold (%): " + EdgeThresPerc);
//	print("Threshold Val (pix): " + ThresVal);

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

	edgeNX = getResult("X", nResults - 4);
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

	//   Calc if field size is within tolerance


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

	print("\n");
	//print("-----------  Field Size  (Tol: +/- " + FieldSizeTol + " mm)  ----------");
	print("----------- Filed Size (cm) ----------");
	print("");
	print("Field Size Tol (mm): " + FieldSizeTol);
	//print("Length  \t| Std.    \t| Meas.   \t| Result");
	//print("EW  \t| " + d2s(fieldEW,1) + "  \t| " + d2s(EWdistmm,1) +"  \t| " + ResultFieldSizeDiffEW);
	//print("NS  \t| " + d2s(fieldNS,1) + "  \t| " + d2s(NSdistmm,1) +"  \t| " + ResultFieldSizeDiffNS);
	print("EW Std: " + d2s(fieldEW,1));
	print("EW Meas: " + d2s(EWdistmm,1));
	print("");
	print("NS Std: " + d2s(fieldNS,1));
	print("NS Meas: " + d2s(NSdistmm,1));


///////	7*	//////////	Peripheral ROIs & BG ROIs Positioned for Uniformity Analysis	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// $$$$$

	if(advanced == true) {
	UniformityAnalysis = true;
	UniformityPerformed = "Yes";
	RatioNStdSelected = 1;
	RatioSStdSelected = 1;
	RatioEStdSelected = 1;
	RatioWStdSelected = 1;
	}

	if (UniformityAnalysis == true) {		//	points 7 and 8 only run if true is slected and are contained within an IF statement marked with $$$$$

if (advanced == false) {
	if(AppIDSelected == "C") {						//	position of peripheral ROIs based on applicator selected
		roiEWdistcm = 3;
		roiNSdistcm = 3;
		roiEWdist = 10 * roiEWdistcm * EWscale;
		roiNSdist = 10 * roiNSdistcm * NSscale;
	}
	if(AppIDSelected == "J") {
		roiEWdistcm = 8;
		roiNSdistcm = 8;
		roiEWdist = 10 * roiEWdistcm * EWscale;
		roiNSdist = 10 * roiNSdistcm * NSscale;
	}
}

	bgROIposNS = 10 * NSscale;					//	Distance of bg ROIs from marker points (10mm is set but user can then adjust positions)
	bgROIposEW = 10 * EWscale;

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

	NSXcorr = roiNSdist * cos(angleNS * PI / 180);				//	convert measured distances to X & Y distances using trig
	NSYcorr = roiNSdist * sin(angleNS * PI / 180);
	EWXcorr = roiEWdist * cos(angleEW * PI / 180);
	EWYcorr = roiEWdist * sin(angleEW * PI / 180);

	RectROI(CX-roiRadEW-NSXcorr, CY-roiRadNS+NSYcorr, roiDiamEW, roiDiamNS,"ROI North","red");		//	Make peripheral ROIs along lines
	RectROI(CX-roiRadEW+NSXcorr, CY-roiRadNS-NSYcorr, roiDiamEW, roiDiamNS,"ROI South","red");
	RectROI(CX-roiRadEW-EWXcorr, CY-roiRadNS+EWYcorr, roiDiamEW, roiDiamNS,"ROI West","red");
	RectROI(CX-roiRadEW+EWXcorr, CY-roiRadNS-EWYcorr, roiDiamEW, roiDiamNS,"ROI East","red");


if (advanced == true) {
	setTool("Rectangle");				//	allow adjustment of uniformity ROIs
	selectWindow("ROI Manager");
	setLocation(0.8*screenWidth(),0);
	roiManager("Select", roiManager("count") - 4);
	waitForUser("Uniformity ROI Position", "Check position of Uniformity ROIs\n \nTo move: Select using the ROI Manager Window & Click and Drag\n \nPress OK  when ROIs are correctly positioned");
	setTool("Hand");	
}

	roiManager("Select", roiManager("count") - 4);					//	Measures Peripheral ROIs
	run("Measure");
	roiManager("Select", roiManager("count") - 3);
	run("Measure");
	roiManager("Select", roiManager("count") - 2);
	run("Measure");
	roiManager("Select", roiManager("count") - 1);
	run("Measure");

	RAWmeanROInorth = getResult("Mean", nResults - 4);			//	extracts mean of peripheral ROIs
	RAWmeanROIsouth = getResult("Mean", nResults - 3);
	RAWmeanROIwest = getResult("Mean", nResults - 2);
	RAWmeanROIeast = getResult("Mean", nResults - 1);

	CORRmeanROIcentre = abs(RAWmeanROIcentre - bgROImean);
	CORRmeanROInorth = abs(RAWmeanROInorth - bgROImean);
	CORRmeanROIsouth = abs(RAWmeanROIsouth - bgROImean);
	CORRmeanROIwest = abs(RAWmeanROIwest - bgROImean);
	CORRmeanROIeast = abs(RAWmeanROIeast - bgROImean);


///////	8*	//////////	Ratio of Peripheral ROIs to Centre calcualted for Uniformity Analysis	//////////////////////////////////////////////////////////////////////////////////////////////////////////////


	RATIOnorth = CORRmeanROInorth / CORRmeanROIcentre;		//	take ratio of peripheral ROIs to central
	RATIOsouth = CORRmeanROIsouth / CORRmeanROIcentre;
	RATIOwest = CORRmeanROIwest / CORRmeanROIcentre;
	RATIOeast = CORRmeanROIeast / CORRmeanROIcentre;
	RATIOcentre = CORRmeanROIcentre / CORRmeanROIcentre;

	RATIOnorthDifPerc = ((RATIOnorth / RatioNStdSelected) - 1)*100;		//	calculate percentage difference of ratios from standards
	RATIOsouthDifPerc = ((RATIOsouth / RatioSStdSelected) - 1)*100;
	RATIOwestDifPerc = ((RATIOwest / RatioWStdSelected) - 1)*100;
	RATIOeastDifPerc = ((RATIOeast / RatioEStdSelected) - 1)*100;

	if(abs(RATIOnorthDifPerc) < RatioTol) {					//	Check ratios are within tolerance
		ResultRatioN = "OK";
		} else {
		ResultRatioN = "FAIL";
	}
	if(abs(RATIOsouthDifPerc) < RatioTol) {
		ResultRatioS = "OK";
		} else {
		ResultRatioS = "FAIL";
	}
	if(abs(RATIOwestDifPerc) < RatioTol) {
		ResultRatioW = "OK";
		} else {
		ResultRatioW = "FAIL";
	}
	if(abs(RATIOeastDifPerc) < RatioTol) {
		ResultRatioE = "OK";
		} else {
		ResultRatioE = "FAIL";
	}


	print("\n");
	//print("---------  Uniformity Ratios  (Tol: +/- " + RatioTol + " %)  ---------");
	//print("Posn.  \t| Std.   \t| Meas.  \t| Result");
//	print("C  \t" + RATIOcentre);
//	print("Sink  \t" + "| " + d2s(RatioNStdSelected,3) + "\t| " + d2s(RATIOnorth,3) + "\t| " + d2s(RATIOnorthDifPerc,1) + "%\t| " + ResultRatioN);
//	print("Int.  \t" + "| " + d2s(RatioSStdSelected,3) + "\t| " + d2s(RATIOsouth,3) + "\t| " + d2s(RATIOsouthDifPerc,1) + "%\t| " + ResultRatioS);
//	print("A+  \t" + "| " + d2s(RatioEStdSelected,3) + "\t| " + d2s(RATIOeast,3) + "\t| " + d2s(RATIOeastDifPerc,1) + "%\t| " + ResultRatioE);
//	print("C-  \t" + "| " + d2s(RatioWStdSelected,3) + "\t| " + d2s(RATIOwest,3) + "\t| " + d2s(RATIOwestDifPerc,1) + "%\t| " + ResultRatioW);
	print("--------- Uniformity Ratios ---------");
	print("Ratio Tol (%): " + RatioTol);
	print("");
	print("Sink Std: " + d2s(RatioNStdSelected,3));
	print("Sink Meas: " + d2s(RATIOnorth,3));
	print("Sink Dif (%): " + d2s(RATIOnorthDifPerc,1));
	print("Sink Result: " + ResultRatioN);
	print("");
	print("Int. Std: " + d2s(RatioSStdSelected,3));
	print("Int. Meas: " + d2s(RATIOsouth,3));
	print("Int. Dif (%): " + d2s(RATIOsouthDifPerc,1));
	print("Int. Result: " + ResultRatioS);
	print("");
	print("A+ Std: " + d2s(RatioEStdSelected,3));
	print("A+ Meas: " + d2s(RATIOeast,3));
	print("A+ Dif (%): " + d2s(RATIOeastDifPerc,1));
	print("A+ Result: " + ResultRatioE);
	print("");
	print("C- Std: " + d2s(RatioWStdSelected,3));
	print("C- Meas: " + d2s(RATIOwest,3));
	print("C- Dif (%): " + d2s(RATIOwestDifPerc,1));
	print("C- Result: " + ResultRatioW);
	print("");
	

//	print("Distance of Peripheral ROIs form Centre (mm)");
//	print("North & South:\t" + 10*roiNSdistcm);
//	print("East & West:\t" + 10*roiEWdistcm);

	} else {
	
	print("\n");
	print("---------  Uniformity  ---------");
	print("Not Measured");
	print("\n");
	print("\n");
	print("\n");
	print("\n");

	}	//	end of IF statement for performing Uniformity analysis
// $$$$$

///////	9	//////////	Option to Check Results & Restart Analysis	//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

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
	Dialog.addString("Comments:", "None",40);
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
//				END OF GULMAY FIELD SIZE & UNIFORMITY					//
// 	- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -	//
