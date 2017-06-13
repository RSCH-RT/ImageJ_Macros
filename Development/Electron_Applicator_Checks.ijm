// 	- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -	//
//				ELECTRON APPLICATOR CHECKS by Matt Bolt				//
// 	- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -	//
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
var ptX1
var ptY1
var ptX2
var ptY2

macro "Electron_Insert_Checks"{

version = "0.1";
update_date = "23 March 2016 by MB";

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
	Dialog.addMessage("---- Electron Insert Checks ----");
	Dialog.addMessage("Version: " + version);
	Dialog.addMessage("Last Updated: " + update_date);
	if(nImages==0) {
		Dialog.addMessage("");
		Dialog.addMessage("You will be prompted to open the required image after clicking OK");
	}
	Dialog.addMessage("Click OK to start");
	Dialog.show()

//********** Get image details & Tidy up Exisiting Windows
	
   myDirectory = "G:\\Shared\\Oncology\\Physics\\RTPhysics\\EBRT Dosimetry\\Electron Applicator Checks";
   call("ij.io.OpenDialog.setDefaultDirectory", myDirectory);
   call("ij.plugin.frame.Editor.setDefaultDirectory", myDirectory);

	if (nImages ==0) {
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
	setLocation(10,50);
	name = getTitle;							//	gets image title and removes file extension for saving purposes
	run("Enhance Contrast", "saturated=0.35"); //makes the image visible
	run("Set Scale...", "distance=0 known=0 pixel=1 unit=pixel");

	MonthNames = newArray("Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec");		//	get current date and display in desired format
	DayNames = newArray("Sun", "Mon","Tue","Wed","Thu","Fri","Sat");
	getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
	TimeString = ""+dayOfMonth+"-"+MonthNames[month]+"-"+year;

	ImageWidthPx = getWidth();				//	returns image width in pixels
	ImageHeightPx = getHeight();

	ImagerSSD = parseInt(getInfo("3002,0026")) / 10;	//	image distance in cm from DICOM info

	DICOMDateString = getInfo("0008,0012")	;		//	get image date from DICOM info
//	print("date string" + DICOMDateString);	

	DICOMyear = parseFloat(substring(DICOMDateString,0,5));		//	construct date in desired format
	DICOMmonth = MonthNames[substring(DICOMDateString,5,7)-1];
	DICOMday = parseFloat(substring(DICOMDateString,7,9));
	DICOMdate = ""+DICOMday + "-" + DICOMmonth + "-" + DICOMyear;

//	print("Date:  \t" + DICOMdate);

	Scale = parseFloat(substring(getInfo("3002,0011"),0,5));		//	gives scale in mm/10 pixels

	Enlarged = "False";

	if(ImageWidthPx == 512) {
		run("Size...", "width=1024 height=768 constrain average interpolation=Bilinear");
		Scale = Scale/2;
		Enlarged = "True";
		}


///////	1	//////////	Tolerance Levels & Standard Figures	///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


     //     Constants used
	roiSize = 2;
	ProfileWidthmm = 3;				//	Sets the width of the measured profile in mm - aim is to average over a wider profile to avoid provlems with any noise/dust/dead pixels in image

     //     Tolerance Levels
	FieldSizeTol = 2;			// tolerance for applicator size is +/- 2mm

///////	2	//////////	Field Details Selected	//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

	LinacChoices = newArray("LA1", "LA2", "LA3", "LA4", "LA5", "LA6","Red A", "Red B", "Select");

	DayChoices = newArray(31);			//	length of array
		for(i=0; i<DayChoices.length; i++)	//	set incremental values in array
		DayChoices[i] = d2s(1+i,0);
	MonthChoices = newArray("Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec");
	YearChoices = newArray(11);
		for(i=0; i<YearChoices.length; i++)
		YearChoices[i] = d2s(2010+i,0);

	Dialog.create("Details");
	Dialog.addMessage("Date of Test:  " + DICOMdate);
	//Dialog.addChoice("Day", DayChoices, dayOfMonth);
	//Dialog.addChoice("Month", MonthChoices, MonthNames[month]);
	//Dialog.addChoice("Year", YearChoices, year);
	Dialog.addMessage("--- Applicator Details ---");
	Dialog.addChoice("Linac", LinacChoices, myLinac);
	Dialog.addMessage("Imager Location: " + ImagerSSD + " cm");
	Dialog.addNumber("End Plate Location:", 95,1,4,"cm");
	Dialog.addNumber("Horizontal Length:", 10,1,4,"cm");
	Dialog.addNumber("Vertical Length:", 10,1,4,"cm");
	Dialog.show();

	//DaySelected = Dialog.getChoice();
	//MonthSelected = Dialog.getChoice();
	//YearSelected = Dialog.getChoice();

	//DateSelected = DaySelected + "-" + MonthSelected + "-" + YearSelected;

	LinacSelected = Dialog.getChoice();

	EndPlateLocationSelectedcm = Dialog.getNumber();
	HorizLengthSelectedcm = Dialog.getNumber();
	VertLengthSelectedcm = Dialog.getNumber();
	

	fieldEW = 10*HorizLengthSelectedcm;				//	Field size in mm for calcs
	fieldNS = 10*VertLengthSelectedcm;

	DistCorr = 100/ImagerSSD;		//	used to scale measurements back to 100cm FSD

	print("------------------------------------------------------------------------");
	print("                    Electron Applicator Analysis Results");
	print("------------------------------------------------------------------------");
	print("\n");
	print("File Analysed:   \t" +myFileName);
	print("Exposure Date:   \t" + DICOMdate);
	print("Analysis Date:   \t" +TimeString);
	print("\n");
	print("Linac:   \t" + LinacSelected);
	print("End Plate Location (cm):  \t" + d2s(EndPlateLocationSelectedcm,1));
	print("Imager Location (cm):   \t" + d2s(ImagerSSD,1));
	print("Horizontal Field (cm):   \t" + d2s(HorizLengthSelectedcm,1));
	print("Vertical Field (cm):   \t" + d2s(VertLengthSelectedcm,1));
	print("Scale (mm/px):   \t" + Scale/10);
	print("Distance Correction:   \t" + DistCorr);
	print("Image Enlarged?:  \t" + Enlarged);


///////	3	//////////	Cross Wires Marked	//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

	setTool("multipoint");											//	Set tool to multipoint, for user to select points
	waitForUser("Crosswire Selection", "Select 4 inner corners of the insert, Starting in the Top Right and Working Clockwise\n \nClick OK when complete");

	run("Measure");

	selectWindow("Results");								//	moves results window out of view
	setLocation(screenWidth()*0.95,screenHeight()*0.95);

	while(nResults!=4) {
		run("Clear Results");							//	use to clear results if wrong # pts selected
		setTool("multipoint");							//	4 points only should be selected for analysis
		waitForUser("You must select 4 points to continue analysis");
		run("Measure");
	}

	arrX = newArray(4);							//	create array with 4 selected points
	arrY = newArray(4);
	for (i=0; i<4;i++) {							//	Get coords of 4 Selected Points and place into Array
		arrX[i] = getResult("X",i);
		arrY[i] = getResult("Y",i);
	}

	NEX = arrX[0];		//	Use corner coordinates to get central positions to mark on vertical/horizontal lines.
	NEY = arrY[0];
	SEX = arrX[1];
	SEY = arrY[1];
	SWX = arrX[2];
	SWY = arrY[2];
	NWX = arrX[3];
	NWY = arrY[3];

	NX = (NEX+NWX)/2;					//	Get Coords from array for each point to allow calc of intersection
	NY = (NEY+NWY)/2;					//	NX is the X coord of the North (top) point
	EX = (NEX+SEX)/2;
	EY = (NEY+SEY)/2;
	SX = (SWX+SEX)/2;
	SY = (SWY+SEY)/2;
	WX = (NWX+SWX)/2;
	WY = (NWY+SWY)/2;

	LineExtensionmm = 3;
	LineExtensionPx = LineExtensionmm * Scale;		//	Line extension in pixels

	Line(NEX,NEY,SWX,SWY,"LineNESW","cyan");
	Line(NWX,NWY,SEX,SEY,"LineNWSE","cyan");

	LineExt(NX,NY,SX,SY,LineExtensionPx, LineExtensionPx, "LineNS", "yellow");
	run("Measure");
	angleNS = getResult("Angle", nResults - 1);				//	get angle of line - is in degrees and requires conversion to radians for use in calculations

	NextX = ptX1;
	NextY = ptY1;
	SextX = ptX2;
	SextY = ptY2;

	LineExt(WX,WY,EX,EY,LineExtensionPx,LineExtensionPx,"LineEW", "yellow");
	run("Measure");
	angleEW = getResult("Angle", nResults - 1);

	WextX = ptX1;
	WextY = ptY1;
	EextX = ptX2;
	EextY = ptY2;

//	roiManager("Select",roiManager("count") - 6);		//	Select extended line ROIs and measure to get end points for creating periphery ROIs
//	run("Measure");
//	roiManager("Select",roiManager("count")-3);
//	run("Measure");

//	NextX = getResult("BX", nResults - 2);
//	NextY = getResult("BY", nResults -2);
//	extXdif = getResult("Width", nResults - 2);
//	extYdif = getResult("Height", nResults -2);
//	SextX = NextX + extXdif;
//	SextY = NextY + extYdif;
//
//	WextX = getResult("BX", nResults - 1);
//	WextY = getResult("BY", nResults -1);
//	extXdif = getResult("Width", nResults - 1);
//	extYdif = getResult("Height", nResults -1);
//	EextX = WextX + extXdif;
//	EextY = WextY + extYdif;


///////	4	//////////	ROIs positioned & measured	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

	findIntersection(WX, WY, EX, EY, NX, NY, SX, SY);			//	Find Intersection to give coords of centre of field
		CX = intX;
		CY = intY;

	roiDiamNS = roiSize * Scale;		 			//	sizes the roi (in pix) based on scale factor and roi size selected
	roiRadNS = 0.5*roiDiamNS;			 			//	gives radius to simplify positioning below
	roiDiamEW = roiSize * Scale;
	roiRadEW = 0.5*roiDiamEW;

	RectROI(CX-roiRadEW,CY-roiRadNS, roiDiamEW, roiDiamNS,"ROI Centre","red");
	run("Measure");
	RAWmeanROIcentre = getResult("Mean");

	RectROI(NextX-roiRadEW,NextY-roiRadNS,roiDiamEW,roiDiamNS,"ROI North","red");
	RectROI(EextX-roiRadEW,EextY-roiRadNS,roiDiamEW,roiDiamNS,"ROI East","red");
	RectROI(SextX-roiRadEW,SextY-roiRadNS,roiDiamEW,roiDiamNS,"ROI South","red");
	RectROI(WextX-roiRadEW,WextY-roiRadNS,roiDiamEW,roiDiamNS,"ROI West","red");
	run("Measure");
	RAWmeanROInorth = getResult("Mean",nResults-4);
	RAWmeanROIeast = getResult("Mean",nResults-3);
	RAWmeanROIsouth = getResult("Mean",nResults-2);
	RAWmeanROIwest = getResult("Mean",nResults-1);

	RAWmeanROIperiph = (RAWmeanROInorth + RAWmeanROIeast + RAWmeanROIsouth + RAWmeanROIwest)/4;


///////	5	//////////	Field Edges Determined	//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

	ThresVal = (RAWmeanROIcentre + RAWmeanROIperiph)/2;

	FindEdges(NextX,NextY,SextX,SextY,CX,CY, ProfileWidthmm * Scale,ThresVal,"Edge North","Edge South",0,0);		//	this is a custom function which finds the 2 edges of the field between the specified points
	FindEdges(WextX,WextY,EextX,EextY,CX,CY, ProfileWidthmm * Scale,ThresVal,"Edge West","Edge East",0,0);

	setTool("multipoint");
	selectWindow("ROI Manager");
	setLocation(0.8*screenWidth(),0);
	roiManager("Select", roiManager("count") - 4);
	waitForUser("Field Edges", "Have Field Edges Been Located Correctly?\n \nAdjust points manually by selecting with the ROI Manager if Required\nYou may need to Zoom in to precisely position the points\n \nPress OK to continue");
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

	//	Field edge measured relative to central point which should be at crosswire intersection

     //     Whole field
	NSdist = calcDistance(edgeNX,edgeNY,edgeSX,edgeSY);
	NSdistmm = NSdist * Scale/10 * DistCorr;
	EWdist = calcDistance(edgeEX,edgeEY,edgeWX,edgeWY);
	EWdistmm = EWdist * Scale/10 * DistCorr;

//	print("NSdist:" + NSdist);
//	print("NSdist*Scale:" + NSdistmm);

	NSdifmm = NSdistmm - fieldNS;
	EWdifmm = EWdistmm - fieldEW;

	//	With Coll = 90
	//	North = Gantry = X2
	//	South = Target = X1
	//	East = B = Y1
	//	West = A = Y2

     //     Individual Jaws
	CNdist = calcDistance(CX,CY,edgeNX,edgeNY);
	CNdistmm = CNdist * Scale/10 * DistCorr;
	CSdist = calcDistance(CX,CY,edgeSX,edgeSY);
	CSdistmm = CSdist * Scale/10 * DistCorr;
	CEdist = calcDistance(CX,CY,edgeEX,edgeEY);
	CEdistmm = CEdist * Scale/10 * DistCorr;
	CWdist = calcDistance(CX,CY,edgeWX,edgeWY);
	CWdistmm = CWdist * Scale/10 * DistCorr;

	CNdifmm = CNdistmm - (fieldNS/2);	//	need half the field size to get half field size for distance measurement.
	CSdifmm = CSdistmm - (fieldNS/2);
	CEdifmm = CEdistmm - (fieldEW/2);
	CWdifmm = CWdistmm - (fieldEW/2);


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

	print("GT  \t| " + d2s(fieldNS/10,2) + "  \t| " + d2s(NSdistmm/10,2) +"  \t| " + ResultFieldSizeDiffNS);
	print("AB  \t| " + d2s(fieldEW/10,2) + "  \t| " + d2s(EWdistmm/10,2) +"  \t| " + ResultFieldSizeDiffEW);
	print("\n");

	print("G  \t| " + d2s(fieldNS/20,2) + "  \t| " + d2s(CNdistmm/10,2) +"  \t| " + ResultFieldSizeDiffCN);
	print("T  \t| " + d2s(fieldNS/20,2) + "  \t| " + d2s(CSdistmm/10,2) +"  \t| " + ResultFieldSizeDiffCS);
	print("A  \t| " + d2s(fieldEW/20,2) + "  \t| " + d2s(CWdistmm/10,2) +"  \t| " + ResultFieldSizeDiffCW);
	print("B  \t| " + d2s(fieldEW/20,2) + "  \t| " + d2s(CEdistmm/10,2) +"  \t| " + ResultFieldSizeDiffCE);

	ImageScale = Scale*DistCorr;	//	For adding a scale to the image corrected to 100cm.

	run("Set Scale...", "distance=10 known=ImageScale pixel=1 unit=cm");	//put at end of analysis

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
	title1 = name + "_Results" + FileExt;					//	Title of log window is filename without extension as defined at start.
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

	ptX1 = 0;
	ptY1 = 0;
	ptX2 = 0;
	ptY2 = 0;

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

	makeLine(ext1x,ext1y, ext2x, ext2y);					//	Make line between specified poitns with specified name and colour
	roiManager("Add");
	roiManager("Select",roiManager("count")-1);
	roiManager("Rename", name);
	roiManager("Set Color", colour);

	makePoint(ext1x,ext1y);						//	plot point with given coord and rename (points are at end of extended line = useful for calcs)
	roiManager("Add");
	roiManager("Select", roiManager("count")-1);
	roiManager("Rename", name+"in");
	run("Measure");
	ptX1 = getResult("X", nResults -1);
	ptY1 = getResult("Y", nResults -1);

	makePoint(ext2x,ext2y);						//	plot point with given coord and rename (points are at end of extended line = useful for calcs)
	roiManager("Add");
	roiManager("Select", roiManager("count")-1);
	roiManager("Rename", name+"out");
	run("Measure");
	ptX2 = getResult("X", nResults -1);
	ptY2 = getResult("Y", nResults -1);
	
}
//----------------------- End of Make Extended Line Function ---------------------------------------------------------------------------------------------


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
