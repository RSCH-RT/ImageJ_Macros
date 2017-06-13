// ------------------------------------------------------------------------------------------------------
//  Sarah Bailey 17 Dec 2013 - Edited by Matt Bolt 29 Aug 2014 for use at Redhill with different phantom - Some of the code may now be redundant but it works
// ------------------------------------------------------------------------------------------------------
//   STEP 1 = Dialog & initialise images
//   STEP 2 = Find the ball bearings & their quadrant 
//   STEP 3 =  Profile Analysis
//   STEP 4 =  Calc distances
//   STEP 5 = Tidy interface - closing windows not required
//   STEP 6 = Output results & prompt to save file
//
//   MODIFICATION HISTORY:
//	only scale images that are 512 x 368 pixels
//	Previously named "EpidAnalysisFinal"
// 	Removed ImageJ calibration which  can affect some IJ installs
//	Results X,Y display rather than North South
//	At Coll 90, North (G) = X2, South (T) = X1, East (B) = Y1, West (A) = Y2
//	N,S,E,W to show X and Y correctly
//	dEastX and dWestX swapped around 23/04/14 due to Y1 & Y2 being incorrectly orientated in results. Line 161/162
// ------------------------------------------------------------------------------------------------------

// ---------------------------- global variables ------------------------------------------------
var pos1;   	//  can be seen (edited) by all functions in this macro
var pos2;  
var intX;
var intY;
var xNorth;
var yNorth;
var xSouth; 
var ySouth;
var xEast;
var yEast;
var xWest;
var yWest;
var xCentre;
var yCentre;
var myImageID;  // the scaled image
var myOriginalID;  
var myLinac;
var intEnergy;
var intSSD;
var strDateImage;
var CentreX;
var CentreY;
var Pt0X;
var Pt0Y;

// ------------------------------------------------------------------------------------------------------
//		MAIN MACRO
// ------------------------------------------------------------------------------------------------------

macro "Find Points" {

version = "1.2";
update_date = "23 December 2016 by MB";

//*************Update Log**************
// v1.1 - 22/Jul/16 - formatted results for import into QATrack (added colons as separators on jaws)

// *************** STEP 1 ***************
// Show a dialog to user so that they know the macro is running, initialise images

	requires("1.47p");
	myLinac = getArgument() ;
	if(myLinac == "") {
		myLinac = "Select";
	}

	if (nImages != 0) {
	   exit("Oops, please close all images before running this macro! ");
	} 

	lstLinac = newArray("LA1","LA2","LA3","LA4","LA5", "LA6", "Red-A", "Red-B", "Select");		

	Dialog.create("Macro Opened");
	Dialog.addMessage("EPID QC Image Analysis");
	Dialog.addMessage("Version: " + version);
	Dialog.addMessage("Last Updated: " + update_date);
	Dialog.addMessage("");
	Dialog.addMessage("This is an automated process as folows:");
	Dialog.addMessage(" - the macro finds the 4 ball bearings.");
	Dialog.addMessage(" - these can be adjusted manually when prompted.");
	Dialog.addMessage(" - results appear in the Log window");
	Dialog.addMessage("");	
	//Dialog.addMessage("Linac: "+myLinac);	
	//Dialog.addMessage("Select linac where images were obtained:");
	Dialog.addChoice("             Linac:", lstLinac,myLinac);

	Dialog.addMessage("                                    ***** Click OK to start ******");
	Dialog.show();

	myLinac = Dialog.getChoice();

   myDirectory = "G:\\Shared\\Oncology\\Physics\\Linac Field Analysis\\"+myLinac+"\\";
   call("ij.io.OpenDialog.setDefaultDirectory", myDirectory);
   call("ij.plugin.frame.Editor.setDefaultDirectory", myDirectory);

	print(myDirectory);

	strFile = File.openDialog("Select an Image");
	
	if (File.exists(strFile) != 1) {
	        exit("Oops, no file selected! ");
	}
	
	open(strFile);
	run("Enhance Contrast", "saturated=0.35"); //makes the image visible

	// removes any previous calibration - affects the X-ray field results
	run("Calibrate...", "function=None unit=[Gray Value] text1=[ ] text2= global show"); 

	myOriginalID = getImageID();
	myImageID = myOriginalID;
	setLocation(10, 80);

	strName=getTitle; 			// original image name, not the scaled image
	// extract DICOM Image data:
	intEnergy = parseInt(getInfo("0018,0060")) / 1000;
	strDateImage = getInfo("0008,0023");
	intSSD = parseInt(getInfo("3002,0022")) / 10;

	// rescale the original image if it is from old imager with only 512 x 384 pixels i.e. LA5/6, but don't over-write original
	pWidth = getWidth();
	pHeight = getHeight();

	    run("Remove Outliers...", "radius=1 threshold=100 which=Bright");	//	Removes dead pixels from image
	
	if (pWidth == 512) {
		run("Scale...", "x=2 y=2 width="+2*pWidth+" height="+2*pHeight+" interpolation=Bilinear average create title=ScaledImage.dcm");
		selectWindow("ScaledImage.dcm");
		myImageID = getImageID(); 	   
		setLocation(15, 100);
	}

	// Initialise the results table, and ROI Manager	
	selectImage(myImageID);  		// make sure its selected
	run("Set Measurements...", "area mean min bounding display redirect=None decimal=3");
	run("Clear Results");
	roiManager("reset");
	roiManager("Show All");
	print ("\\Clear");
	getStatistics(area,mean,min,max,std);

// *************** STEP 2 ***************
// 2. Find the ball bearings (BB) and identify which quadrant they are in so can draw lines between them

	findBB();		// find 4 BBs and then finds the centre

// *************** STEP 3 ***************
// 3. Find Edges

	//Horizontal & Vertical lines through centre, add a few pixels to line so that make sure it covers entire profile

	pxAdd = 300; 		// this is wide enough to ensure get true FWHM
	LineWidth = 5;
	Threshold = (max-min)/2;	// set threshold as midway between the max and min values within the image. Note that outliers have been removed prior to this.
	print("Thres: " + Threshold);

	FindSingleEdge(CentreX,CentreY,CentreX,CentreY-300, LineWidth,Threshold,"EdgeN", 0);
	FindSingleEdge(CentreX,CentreY,CentreX,CentreY+300, LineWidth,Threshold,"EdgeS", 0);
	FindSingleEdge(CentreX,CentreY,CentreX-300,CentreY, LineWidth,Threshold,"EdgeW", 0);
	FindSingleEdge(CentreX,CentreY,CentreX+300,CentreY, LineWidth,Threshold,"EdgeE", 0);

	roiManager("Select", roiManager("count") - 4);			//	measure coords of field edges after any possible movement so can do measurements
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
	edgeWX = getResult("X", nResults - 2);
	edgeWY = getResult("Y", nResults - 2);
	edgeEX = getResult("X", nResults - 1);
	edgeEY = getResult("Y", nResults - 1);

// *************** STEP 4 ***************
// 4. Calc distance between central position and XRay field

	// the Xray field edge is the point along straight or veritcal line running through the central point
	// it does not correct for a phantom set up skewed - this will give wrong results

	myCF = 0.0392;	// conversion in cm/px based on examining the DICOM data which gives the scale. This corresponds to the numvber of pixels in the image and the image size.

	dNorth = myCF * calcDistance(CentreX, CentreY, edgeNX, edgeNY);
	dSouth = myCF * calcDistance(CentreX, CentreY, edgeSX, edgeSY);
	dWest = myCF * calcDistance(CentreX, CentreY, edgeWX, edgeWY);
	dEast = myCF * calcDistance(CentreX, CentreY, edgeEX, edgeEY);

// *************** STEP 5 ***************
// 5. Tidy the user interface by closing windows not needed

	// close the scaled image - know its scaled if working image ID is not the original image ID
	if (myImageID != myOriginalID){
		selectImage(myImageID);  
		run("Close"); 
	}

	//selectWindow("ROI Manager"); 
	//run("Close"); 

	selectWindow("Results");							//	close results window and position log window so visible
	setLocation(0,0);
	run("Close");

	selectWindow("Log"); 
	setLocation(600, 50);


// *************** STEP 6 ***************
// 6. Output the results, prompt to save

	// At Coll 90, North (G) = X2, South (T) = X1, East (B) = Y1, West (A) = Y2

	printHeader();
	print("For Col 90");
            print("   X1 : "+d2s(dSouth, 2)+"cm");
            print("   X2 : "+d2s(dNorth, 2)+"cm");
            print("   Y1 : "+d2s(dEast, 2)+"cm");
            print("   Y2 : "+d2s(dWest, 2)+"cm");

	saveResults();

} // End Macro
// ------------------------------------------------------------------------------------------------------
//		END OF MAIN MACRO
// ------------------------------------------------------------------------------------------------------


// ------------------------------------------------------------------------------------------------------
//		FUNCTIONS USED IN THIS MACRO
// ------------------------------------------------------------------------------------------------------

//*************** findBB ************************************
function findBB() {

	selectImage(myImageID);  

	refAx = 0; 
	refAy = 0; 
	refBx = getWidth();
	refBy = 0;
	refCx = getWidth();
	refCy = getHeight();
	refDx = 0;
	refDy = getHeight();

            isFound = false;
	myThreshold = 25;

	while (isFound == false) {

   	    run("Find Maxima...", "noise="+myThreshold+" output=[Point Selection] exclude");

	    getSelectionCoordinates(xCoordinates, yCoordinates); 

	    if (lengthOf(xCoordinates)== 4) {
	        isFound = true;
	    } // end if

	    myThreshold = myThreshold + 50;
	    if (myThreshold > 5000) {
	        isFound = true; 		// should never get this far, but this is needed to stop a never ending loop!!		
	    }
	} // End While

	selectImage(myImageID);  		// make sure its selected, and on top

	setTool("multipoint");
	waitForUser("Image QC", "Adjust positions of BB if required. \nthen Click OK");
	getSelectionCoordinates(xCoordinates, yCoordinates); 

	if (lengthOf(xCoordinates)> 4) {  	// this stops if the user has added a point by mistake (easily done)
	     exit("More than 4 points were detected, \n Please start the analysis again");
	}

	Pt0X = xCoordinates[0];
	Pt0Y = yCoordinates[0];

	CentreX = 0.25*(xCoordinates[0]+xCoordinates[1]+xCoordinates[2]+xCoordinates[3]);
	CentreY = 0.25*(yCoordinates[0]+yCoordinates[1]+yCoordinates[2]+yCoordinates[3]);

	Point(xCoordinates[0], yCoordinates[0], "Pt0", "Yellow");
	Point(xCoordinates[1], yCoordinates[1], "Pt1", "Yellow");
	Point(xCoordinates[2], yCoordinates[2], "Pt2", "Yellow");
	Point(xCoordinates[3], yCoordinates[3], "Pt3", "Yellow");
	Point(CentreX, CentreY, "Centre", "Red");

} // End of Function findBB





// ***************************** FUNCTION PRINT HEADER ************************************
function printHeader(){

	strDate = getMyDate();

	print ("\\Clear");
	print("--------------------------------------------------------");
	print("  Congruence Image Analysis using EPID");
	print("--------------------------------------------------------");
	print("Macro Version:"+version);
            	print("Image Analysed: "+strName);
	print("Image Date: "+strDateImage);
	print("Analysis Date: "+strDate);
	print("Linac: "+myLinac);
	print("Energy: "+intEnergy+"MV");
	print("SSD: "+intSSD+"cm");
	print("\n");	

}  // End Function

// ************************ FUNCTION SAVE RESULTS *******************************************
function saveResults(){

	// Add Comments & Save Results	

	Dialog.create("Comments");							// Allows user to insert comments if required. Default is "Results OK" These are then added to Log
	Dialog.addMessage("Add any Comments in the Box Below");
	Dialog.addString("Comments:", "None",40);
	Dialog.addMessage("");
	Dialog.addString("Analysis Performed by:", "",10);
	Dialog.addMessage("Click OK to Continue");
	Dialog.show();

	print("\n");
	print("Comments:"+Dialog.getString());
	print("Analysis Performed by:" + Dialog.getString());
	print("\n");
	print("--------------------------------------------------------");
	
	Dialog.create("~~ Save Results ~~");		// Asks user if they want to save results (as a text file). If they select cancel, the macro wil exit, therefore the save will not occur.
	Dialog.addMessage("  Save the Results?      ");
	Dialog.show();
	setLocation(100, 200);

	selectWindow("Log");				// Get data from log window for transfer to Text window to save
	contents = getInfo();

	FileExt = ".txt";
	title1 = strDateImage+"-"+myLinac+"-"+intEnergy+"-CongResults" + FileExt;	//	Title of log window is filename without extension as defined at start.
	title2 = "["+title1+"]";				
	f = title2;
	if (isOpen(title1)) {
		print(f, "\\Update:");
		selectWindow(title1); 			// clears the window if already one opened with same name
	} else {
		run("Text Window...", "name="+title2+" width=72 height=60");
	}
	setLocation(screenWidth() -100,screenHeight()-100);	// Puts window out of sight
	print(f,contents);
	saveAs("Text");
	run("Close");	

} // End of Function


//************************* FUNCTION getMyDate **************************************************
function getMyDate() {

	arrMonth = newArray("Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec");
	getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
	strDate = ""+dayOfMonth+"-"+arrMonth[month]+"-"+year;
	return strDate;

// ----------------------------------- MAKE POINT FUNCTION (This is used when defining the field edges) -------------------------------------------------------------------------
function Point(x, y, name, colour) {

	makePoint(x,y);						//	plot point with given coord and rename
	roiManager("Add");
	roiManager("Select", roiManager("count")-1);
	roiManager("Rename", name);
	roiManager("Set Color", colour);
}
//----------------------- End of Make Point Function ---------------------------------------------------------------------------------------------

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
	while (profileA[i] > thres) {			//	start at chosen point (centre) and check all points until one passes thres.
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

//---------------------- Calculate Distance Between Points -------------------------------------------------------------------------------------------

function calcDistance(a, b, c, d) {

	myDist = sqrt(pow(a-c,2) + pow(b-d,2));			//	calc distance between two coordinates A and B, A = (a,b) B = (c,d)
	return myDist;
       
	}
// ----------------------------------End of Function calcDistance------------------------------------------------------------------------------------------

  } // End Function
