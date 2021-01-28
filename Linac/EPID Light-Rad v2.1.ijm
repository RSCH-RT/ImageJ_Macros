//// EPID 10x10 Rad analysis
/////
//// STEPS
//// 1. Initialisation - select image and set exposure details
//// 2. Apply CU calibration58

//// 3. Locate ball bearings (thresholds are machine dependent?)
//// 4. Find image centre
//// 5. Acquire profiles 
//// 6. Normalise profiles (using FFF CAX attenutation factor)
//// 7. Process profiles for 50% point

version = "v2.1";
update_date = "22/09/20 by JP";

//// Variables
tolerance = 2.0;
energyChoices = newArray("6X","10X","10FFF");
linacChoices = newArray("LA3","LA4","LA5","LA6", "Red-A","Red-B");
testChoices = newArray("10x10 Only", "10x10 and 3x3","30x30 Only");
imageMag = 1.25;
initialFieldSize = "";
pixelSizeCm = "";


//// Check that there are no open images
if(nImages != 0) exit("Please ensure all images are closed prior to runnung macro. Macro aborted");

//// Program initialisation
Dialog.create("Macro Opened");
Dialog.addMessage("EPID radiation field size analysis macro");
Dialog.addMessage("Version: " + version);
Dialog.addMessage("Last Updated: " + update_date);
Dialog.addMessage("Requirements: ");
Dialog.addMessage("   1. Image must be acquired in machine QA mode with CA90 and GA0");
Dialog.addMessage("   2. The image acquired must be an integrated image (i.e. of type 'CU')");
Dialog.addMessage("   3. The PIPS field size phantom must be used (NOT the in-house perspex phantom)");
Dialog.addMessage("   4. The MV imager vert position must be125cm.");
Dialog.addMessage("   5. If both 10x10 and 3x3 images are to be analysed they must be acquired using the same energy and without shifting the panel between imaging.");
Dialog.addMessage("");
Dialog.addMessage("Click OK to start");
Dialog.show();

Dialog.create("Please input the following data:");
Dialog.addMessage("--- Irradiation details ---");
Dialog.addChoice("Select Linac: ",linacChoices);
Dialog.addChoice("Select energy: ",energyChoices);
Dialog.addMessage("--- Irradiation details ---");
Dialog.addChoice("Select test: ",testChoices);
Dialog.addMessage("--- Test User Inputs? ---");
Dialog.addCheckbox("Test user inputs against DICOM header",true)
Dialog.addMessage("--- User ---");
Dialog.addString("User:","",15);
Dialog.show();
linac = Dialog.getChoice();
energy =  Dialog.getChoice();
test = Dialog.getChoice();
checkUserInput = Dialog.getCheckbox();
user = Dialog.getString();

// Test for Redhill EPID constraints
if(linac == linacChoices[4] && test == testChoices[2]) exit("ERROR: "+linac +" imager not large enough to image 30x30 field. Aborting macro");
if(linac == linacChoices[5] && test == testChoices[2]) exit("ERROR: "+linac +" imager not large enough to image 30x30 field. Aborting macro");
if(energy == energyChoices[2] && linac == linacChoices[4]) exit("ERROR: "+linac +" imager not capable of imaging "+energy+". Aborting macro");
if(energy == energyChoices[2] && linac == linacChoices[5]) exit("ERROR: "+linac +" imager not capable of imaging "+energy+". Aborting macro");

// Determine initial field size
if(test == testChoices[0] || test == testChoices[1]) initialFieldSize = "10x10";
if(test == testChoices[2]) initialFieldSize = "30x30";

// set threshold 
fieldEdgeThresh = 50;
if(energy == energyChoices[2] && test != testChoices[2])  fieldEdgeThresh =41.3;
if(energy == energyChoices[2] && test == testChoices[2])  fieldEdgeThresh =25.3;


//// Set pixel size
if(linac == linacChoices[0] || linac == linacChoices[1] || linac == linacChoices[2] || linac == linacChoices[3] ) {
	pixelSizeCm=0.0336/imageMag;
} else if (linac == linacChoices[4] || linac == linacChoices[5]) {
	pixelSizeCm=0.0392/imageMag;
} else {
	exit("ERROR: pixel scale could not be determined. Aborting macro");
}
 
//// Set offsets to avoid MLC leakage
mlcVertOffset = 0;
mlcHorzOffset = 0;
if(initialFieldSize == "10x10") {
	if(linac == linacChoices[0] || linac == linacChoices[1]) {
		mlcVertOffset = 30;
		mlcHorzOffset = 13;
	} else if( linac == linacChoices[2] || linac == linacChoices[3]) {
		mlcVertOffset = 30;
		mlcHorzOffset = 7;
	} else if(linac == linacChoices[4] || linac == linacChoices[5] ) {
		mlcVertOffset = 25;
		mlcHorzOffset = 6;
	} else {
		exit("ERROR: mlc offsets for leakage avoidance could not be determined. Aborting analysis");
	}
}
	 
//// STEP 1: Open and process image
imagePath = File.openDialog("Please select the "+ energy+" "+initialFieldSize +" EPID image for analysis");
open(imagePath); imName = getTitle(); run("32-bit");
if(checkUserInput) TestUserInputAgainstDICOMHeaderData(linac, energy);
if(round(getInfo("300A,0120")) != 90) print("***WARNING: CA not 90 degress. Results will require transforming");
if(getInfo("0028,1054") != " CU") exit("ERROR: Image selected is not an integrated image (i.e. not CU mode). Analysis aborted"); 
acquisitionDate = getInfo("0008,0023");
run("Set Scale...", "distance=0 known=0 pixel=1 unit=pixel");
run("Median...", "radius=1");
xDim = getWidth();
yDim = getHeight();

/// Duplicate image for CAX identification purporses
dupImageName = "dupImage";
run("Duplicate...", dupImageName);
rename(dupImageName);

//// STEP 2: Find phantom centre using ball bearings
phantCent = DeterminePhantomCentre(linac,initialFieldSize,dupImageName);
phantCentHorz = phantCent[0]; 
phantCentVert = phantCent[1];


//// STEP 3: Apply CU calibration
ApplyCUCalibrationToImage(imName); run("Enhance Contrast", "saturated=0.35");

////// Perform 10x10 analysis

//// STEP 4: Acquire profiles
horzProf = newArray(xDim);
vertProf  = newArray(yDim);
makeRectangle(0,phantCentVert-1-mlcVertOffset ,xDim,3); horzProf = getProfile(); 
makeRectangle(phantCentHorz-1+mlcHorzOffset ,0,3,yDim);setKeyDown("alt"); vertProf = getProfile(); setKeyDown("none"); run("Select None");


//// STEP 5: Normalise profiles,
normHorzProf = newArray(xDim);
normVertProf = newArray(yDim);
normFactor = GetNormalisationFactor(phantCentHorz, phantCentVert);


//// Correct for CAX phantom attenuation for 30x30 fields
if(test == testChoices[2]) {
	if(energy == energyChoices[0]) {
		normFactor *= 1.037;
	} else if (energy == energyChoices[1]) {
		normFactor *= 1.006;
	} else if(energy == energyChoices[2]) {
		normFactor *= 1.028;
	} else {
		exit("Phantom attentuation factor could not determined. Analysis aborted");
	}
}

normHorzProf = NormaliseProfile(horzProf,normFactor);
normVertProf = NormaliseProfile(vertProf,normFactor);

//// STEP 6: Calulate field edges and display
horzResultsPix = CalcFieldEdge(normHorzProf,phantCentHorz,fieldEdgeThresh); 
vertResultsPix = CalcFieldEdge(normVertProf,phantCentVert,fieldEdgeThresh); 
fieldSizeX1 = 0; fieldSizeX2 = 0; fieldSizeY1 = 0; fieldSizeY2 = 0;

//// Display field edges
if(isOpen("ROI Manager")) {
     selectWindow("ROI Manager");
     run("Close");
}

// Display CAX
//tmp = GetRoiMean(phantCentHorz, phantCentVert,2,1);
//print("ROI mean: "+tmp);
//updateDisplay();

run("Select None");
run("ROI Manager...");
run("Point Tool...", "type=Crosshair color=Magenta size=Large label show counter=0");
makePoint(round(phantCentHorz)+mlcHorzOffset, round(vertResultsPix[0])); roiManager("Add"); 
makePoint(round(horzResultsPix[1]), round(phantCentVert)-mlcVertOffset); roiManager("Add");
makePoint(round(phantCentHorz)+mlcHorzOffset, round(vertResultsPix[1])); roiManager("Add");
makePoint(round(horzResultsPix[0]), round(phantCentVert)-mlcVertOffset); roiManager("Add");
makePoint(phantCentHorz+mlcHorzOffset, phantCentVert-mlcVertOffset); roiManager("Add");
roiManager("Show All"); 
selectWindow("ROI Manager"); run("Close");



showMessageWithCancel("Are all field edges marked correctly (note that they will be offset from phantom centre for MLC defined fields)? If not, press Cancel. Manual analysis required");

//// STEP 7: Cal results
fieldSizeX1 = Round( (vertResultsPix[1] - phantCentVert)*pixelSizeCm, 2);
fieldSizeX2 = Round( (phantCentVert - vertResultsPix[0])*pixelSizeCm, 2);
fieldSizeY1 = Round( (horzResultsPix[1] - phantCentHorz)*pixelSizeCm, 2);
fieldSizeY2 = Round( (phantCentHorz -horzResultsPix[0])*pixelSizeCm, 2);

//selectWindow(imName);close();


if(test == testChoices[1]) {
	//// Open 3x3 image
	imagePath_3x3 = File.openDialog("Please select the "+energy+" 3x3 EPID image for analysis");
	open(imagePath_3x3); imName_3x3 = getTitle(); run("32-bit");
	if(checkUserInput) TestUserInputAgainstDICOMHeaderData(linac, energy);
	if(round(getInfo("300A,0120")) != 90) print("***WARNING: CA not 90 degress. Results will require transforming");
	if(getInfo("0028,1054") != " CU") exit("ERROR: Image selected is not an integrated image (i.e. not CU mode). Analysis aborted"); 
	acquisitionDate_3x3 = getInfo("0008,0023");
	if(acquisitionDate_3x3 != acquisitionDate) exit("3x3 and 10x10 images acquired on different days. Analysis aborted");
	run("Set Scale...", "distance=0 known=0 pixel=1 unit=pixel"); run("Median...", "radius=1");
	xDim_3x3 = getWidth();
	yDim_3x3 = getHeight();

	if(energy != energyChoices[2]) fieldEdgeThresh_3x3 = 50; 
	if(energy == energyChoices[2]) fieldEdgeThresh_3x3 =49;
	
	//// STEP 3: Apply CU calibration
	ApplyCUCalibrationToImage(imName_3x3); run("Enhance Contrast", "saturated=0.35");

	////// Perform 3x3 analysis
	//// STEP 4: Acquire profiles
	horzProf_3x3 = newArray(xDim_3x3);
	vertProf_3x3 = newArray(yDim_3x3);
	makeRectangle(0,phantCentVert-1 ,xDim_3x3,3); horzProf_3x3 = getProfile(); ;
	makeRectangle(phantCentHorz-1,0,3,yDim_3x3); setKeyDown("alt"); vertProf_3x3 = getProfile(); setKeyDown("none"); run("Select None");

	//// STEP 5: Normalise profiles,
	normHorzProf_3x3 = newArray(xDim_3x3);
	normVertProf_3x3 = newArray(yDim_3x3);
	normFactor_3x3 = GetNormalisationFactor(phantCentHorz, phantCentVert);
	normHorzProf_3x3 = NormaliseProfile(horzProf_3x3,normFactor_3x3);
	normVertProf_3x3 = NormaliseProfile(vertProf_3x3,normFactor_3x3);

	//// STEP 6: Calulate field edges and display
	horzResultsPix_3x3 = CalcFieldEdge(normHorzProf_3x3,phantCentHorz,fieldEdgeThresh_3x3); 
	vertResultsPix_3x3 = CalcFieldEdge(normVertProf_3x3,phantCentVert,fieldEdgeThresh_3x3); 
	fieldSizeX1_3x3 = 0; fieldSizeX2_3x3 = 0; fieldSizeY1_3x3 = 0; fieldSizeY2_3x3 = 0;

	//// Display field edges
	if(isOpen("ROI Manager")) {
 	    selectWindow("ROI Manager");
    	 run("Close");
	}

	run("Select None");
	run("ROI Manager...");
	run("Point Tool...", "type=Crosshair color=Magenta size=Large label show counter=0");
	makePoint(round(phantCentHorz), round(vertResultsPix_3x3[0])); roiManager("Add"); 
	makePoint(round(horzResultsPix_3x3[1]), round(phantCentVert)); roiManager("Add");
	makePoint(round(phantCentHorz), round(vertResultsPix_3x3[1])); roiManager("Add");
	makePoint(round(horzResultsPix_3x3[0]), round(phantCentVert)); roiManager("Add");
	makePoint(phantCentHorz, phantCentVert); roiManager("Add");
	roiManager("Show All");
	selectWindow("ROI Manager"); run("Close");

	showMessageWithCancel("Are all field edges and phantom centre marked correctly? If not, press Cancel. Manual analysis required");

	//// STEP 7: Cal results
	fieldSizeX1_3x3 = Round( (vertResultsPix_3x3[1] - phantCentVert)*pixelSizeCm, 2);
	fieldSizeX2_3x3 = Round( (phantCentVert - vertResultsPix_3x3[0])*pixelSizeCm, 2);
	fieldSizeY1_3x3 = Round( (horzResultsPix_3x3[1] - phantCentHorz)*pixelSizeCm, 2);
	fieldSizeY2_3x3 = Round( (phantCentHorz -horzResultsPix_3x3[0])*pixelSizeCm, 2);

	//// Close 3x3 image
	//selectWindow(imName_3x3);close();
}

//// Any user comments?
Dialog.create("Comments:");					
Dialog.addString("Comments:", "",50);	
Dialog.show();
comm = Dialog.getString();

datAndTime = GetDateAndTime();
print("------------------------------------------------------------------------");
print("                    Linac Field Analysis Results");

print("------------------------------------------------------------------------");
print("\n");
print("Analysis by: "+user);
print("Acquisition Date:   " +acquisitionDate);
print("Analysis Date:   " +datAndTime[0]);
print("Macro Version:\t "+version);
print("\n");
print("Linac:   \t" + linac);
print("Energy: \t"+energy);
print("\n");
print("------------------ Measured Field Size "+ initialFieldSize+" (cm) -----------------");
print("File Analysed:   " +imagePath );
print("CAX dose (CU): \t"+d2s(normFactor,3));
print("Field size threshold (%): \t"+fieldEdgeThresh);
print("Field Size Tol (mm): " + tolerance);
print("");
print(initialFieldSize + " X1:     "+d2s(fieldSizeX1,2));
print(initialFieldSize + " X2:     "+d2s(fieldSizeX2,2));
print(initialFieldSize + " Y1:     "+d2s(fieldSizeY1,2));
print(initialFieldSize + " Y2:     "+d2s(fieldSizeY2,2));
print("\n");
if(test == testChoices[1]) {
	print("------------------ Measured Field Size 3x3 (cm) -----------------");
	print("File Analysed:   " +imagePath_3x3);
	print("CAX dose (CU): \t"+d2s(normFactor_3x3,3));
	print("Field size threshold (%): \t"+fieldEdgeThresh_3x3);
	print("Field Size Tol (mm): " + tolerance);
	print("");
	print("3x3 X1:     "+d2s(fieldSizeX1_3x3,2));
	print("3x3 X2:     "+d2s(fieldSizeX2_3x3,2));
	print("3x3 Y1:     "+d2s(fieldSizeY1_3x3,2));
	print("3x3 Y2:     "+d2s(fieldSizeY2_3x3,2));
	print("\n");
}
print("----------------------------  Comments  --------------------------");
print(comm);
print("\n");
print("------------------------------------------------------------------------");
print("                    Results saved automatically");
print("------------------------------------------------------------------------");

//// Save results
resultsSavePath = GetSavePath(imagePath, linac, energy, datAndTime[0], test);
if(File.exists(resultsSavePath )) {
	showMessageWithCancel("WARNING: '"+resultsSavePath +"' already exists and will be overwritten. Do you want to continue?");
}
selectWindow("Log");
saveAs("Text",resultsSavePath);

///////////////////////////////////// FUNCTIONS///////////////////////////////////
function GetDateAndTime() {
	getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
	dateString = toString(year)+"-"+(month+1)+"-"+toString(dayOfMonth);
	timeString = toString(hour)+":"+toString(minute);
	dateAndTimeArray = newArray(dateString,timeString);
	return dateAndTimeArray;
}

function GetSavePath(pth, unit, en, date, test) {
	splitPath = split(pth,"\\");
	len = lengthOf(splitPath );
	saveDir = "";
	for(i=0;i<len-1;i++) saveDir += splitPath [i]+"\\";
	return saveDir+unit+"_"+en +"_"+test+"_"+date+"_Results.txt";
}

//// Function applies pixel calibration as defined in the DICOM header 
function ApplyCUCalibrationToImage(imName) {
	selectWindow(imName);
	intercept = getInfo("0028,1052"); // get the slope and intercept values from the DICOM file.
	slope = getInfo("0028,1053");
	run("Multiply...", "value=&slope"); // apply the slope and intercept to the pixel values.
	run("Add...", "value=&intercept"); // slope should be applied first to ensure correctly applying linear scaling	
}

//// Function to locate ball bearings and calculate phantom centre
function DeterminePhantomCentre(linac,fs,im) {
	selectWindow(im);
	setLocation(0,0); 
	if(linac == linacChoices[0] || linac == linacChoices[1] || linac == linacChoices[2] || linac == linacChoices[3] ) run("In [+]");

	noBallBearings = 0;
	if(fs == "10x10") noBallBearings = 4;	
	if(fs == "30x30") noBallBearings = 8;
	if(noBallBearings == 0) exit("ERROR: Expected number of ball bearing in the image unknowm. Terminating macro");
	
	//// Invert image so that ball bearing can be found
	if(linac != "LA2") run("Invert"); 	 
	if(fs == "10x10") {
		setMinAndMax(0, 23000);
	} else {
		setMinAndMax(16152, 36600);
	}	
	
	////Find ballbearings	
	allBallBearingsFound = false;
	maximaThreshold = 0;	
	while (allBallBearingsFound == false) {
   		run("Find Maxima...", "noise="+maximaThreshold +" output=[Point Selection] exclude");
		getSelectionCoordinates(xCoordinates, yCoordinates); 
		if (lengthOf(xCoordinates) == noBallBearings) allBallBearingsFound = true;
		maximaThreshold += 25;		
		if (maximaThreshold > 1000) allBallBearingsFound = true; 			
	 } // end While

	setTool("multipoint"); 		// select pointer
	waitForUser("Image QC", "There should be "+noBallBearings+" points on the image, correlating to each of the phantom's ball bearings. To edit point positions select 'Multi-point' tool, \nhover over the point, left click and drag. Points can be added by left clicking or deleted by hoving over the point, pressing Ctrl and left clicking.  \nIf the ball bearings are not visible, open the Brightness/Contrast dialog (Ctrl+Shift+c) and adjust. Press OK when all points are accurately marked");
	getSelectionCoordinates(xCoordinates, yCoordinates); 
	
	selectWindow(im); close();
	
	//// Calc phantom centre
	phantomCentreX = 0;
	phantomCentreY = 0;
	for(i=0; i<noBallBearings;i++) {
		phantomCentreX += xCoordinates[i];
		phantomCentreY += yCoordinates[i];	
	}
	if(phantomCentreX ==0 || phantomCentreY == 0) exit("Phantom centre could not be determined. Macro aborted");
	phantomCentre = newArray(2);
	
	phantomCentre[0] = phantomCentreX/noBallBearings;
	phantomCentre [1] = phantomCentreY/noBallBearings;		
	return phantomCentre;
}

function GetNormalisationFactor(xCent, yCent) {
	norm = 0;
	norm = GetRoiMean(xCent,yCent,2,0);	
	if(norm == 0) exit("Image normalisation factor could not be calculated. Macro aborted");	
	return norm;
}

function NormaliseProfile(profile, normFactor) {
	normProf = newArray(lengthOf(profile));	
	for(p=0;p<lengthOf(profile);p++) {
		normProf[p] = 100*profile[p]/normFactor;
	}
	return normProf;
}

function CalcFieldEdge(prof,cax,threshold) {
	indLow = round(cax);
	while(prof[indLow ] > threshold) {
		indLow--;
	}
	
	indHigh = round(cax);
	while(prof[indHigh] > threshold) {
		indHigh++;
	}
	
	interpLow = Interpolate(prof[indLow], prof[indLow+1],indLow, indLow+1,threshold);	
	interpHigh = Interpolate(prof[indHigh-1], prof[indHigh],indHigh-1, indHigh,threshold);	
	
	resArray = newArray(2);
	//resArray[0] = indLow+1;
	//resArray[1] = indHigh;
	resArray[0] = interpLow;
	resArray[1] = interpHigh;
	return resArray;
}

function Interpolate(_x1,_x2,_y1,_y2,_x) {
	y = _y1+(_y2-_y1)*((_x-_x1)/(_x2-_x1));
	return Round(y,2);
}

function GetRoiMean(x,y,r,_fill) {
	sum=0;
	c=0;
	for(j=y-r; j<=y+r;j++) {
		for(i=x-r; i<=x+r;i++) {
			sum += getPixel(i,j);
			c++;
			if(_fill == 1) setPixel(i,j,0);
		}
	}
	return sum/c;
}

function Round(n,dp) {
	return round(n*pow(10,dp))/pow(10,dp);
}


//// Function to test user inputs against DICOM header info
function TestUserInputAgainstDICOMHeaderData(lin, en) {
	//// Test user selection feasibility
	if(en == "15X" && lin == "LA2" || lin == "LA3" || lin == "LA4" || lin == "LA5" || lin == "LA6"  ) exit("WARNING::MAIN::TestUserInputAgainstDICOMHeaderData():: "+lin+" does not deliver "+en+" beams. Terminating program");
	if(en == "10FFF" && lin == "LA2" || lin == "Red-A" || lin == "Red-B" ) exit("WARNING::MAIN::TestUserInputAgainstDICOMHeaderData():: "+lin+" can not image "+en+" beams. Terminating program");
	
	//// Test Machine - not possible for LA2
	linacDICOM = getInfo("0008,1010");		
	if(lin == "LA2" && linacDICOM == "") {
		 showMessageWithCancel("WARNING::The linac can not be read from the DICOM header for LA2 images. Was an LA2 image definitely selected by the user?");
	} else if (lin == "LA2" && linacDICOM != "") {
		exit("ERROR::Linac in DICOM header ("+linacDICOM+") is not consistent with an LA2 image. Program aborted");
	} else if (lin != "LA2" && linacDICOM == "" ) {
		exit("ERROR::Linac in DICOM header is not consistent with a "+lin+" image. Program aborted");
	} else {
		if(lin == "LA6" && linacDICOM  != " LA6_2015") exit("ERROR::TestUserInputAgainstDICOMHeaderData():: User selected linac "+lin+" does not match the machine given in the DICOM header("+getInfo("0008,1010")+"). Terminating program");
		if(lin == "LA5" && linacDICOM  != " LA5_2017") exit("ERROR::TestUserInputAgainstDICOMHeaderData():: User selected linac "+lin+" does not match the machine given in the DICOM header("+getInfo("0008,1010")+"). Terminating program");
		if(lin == "LA4" && linacDICOM  != " LA4_2018") exit("ERROR::TestUserInputAgainstDICOMHeaderData():: User selected linac "+lin+" does not match the machine given in the DICOM header("+getInfo("0008,1010")+"). Terminating program");
		if(lin == "LA3" && getInfo("0008,1010")  != " LA3_2018") exit("ERROR::TestUserInputAgainstDICOMHeaderData():: User selected linac "+lin+" does not match the machine given in the DICOM header("+getInfo("0008,1010")+"). Terminating program");		
		if(lin == "Red-A" && linacDICOM  != " RED_A_2013") exit("ERROR::TestUserInputAgainstDICOMHeaderData():: User selected linac "+lin+" does not match the machine given in the DICOM header("+getInfo("0008,1010")+"). Terminating program");
		if(lin == "Red-B" && linacDICOM  != " RED_B_2013") exit("ERROR::TestUserInputAgainstDICOMHeaderData():: User selected linac "+lin+" does not match the machine given in the DICOM header("+getInfo("0008,1010")+"). Terminating program");
	}
	
	//// Test Energy		
	energyMod = GetEnergyModality(getInfo("3002,0004"),lin);
	if(en == "6X" && energyMod != "6x") exit("ERROR::TestUserInputAgainstDICOMHeaderData():: User selected energy "+en+" does not match that in the DICOM header ("+energyMod+"). Terminating program");
	if(en== "10X" && energyMod != "10x") exit("ERROR::TestUserInputAgainstDICOMHeaderData():: User selected energy "+en+" does not match that in the DICOM header ("+energyMod+"). Terminating program");
	if(en== "10FFF" && energyMod != "10xFFF") exit("ERROR::TestUserInputAgainstDICOMHeaderData():: User selected energy "+en+" does not match that in the DICOM header ("+energyMod+"). Terminating program");
	if(en== "15X" && energyMod != "15x") exit("ERROR::TestUserInputAgainstDICOMHeaderData():: User selected energy "+en+" does not match that in the DICOM header ("+energyMod+"). Terminating program");
}

//// Function to read energy modality from DICOM header
function GetEnergyModality(mod,lin) {
	sp1 = split(mod,",");
	if(lengthOf(sp1) != 2) exit("ERROR::GetEnergyModality():: Format of energy modilty ("+mod+") read from DICOM file is not recognised. Program aborted");
	sp2 = split(sp1[0]," ");	
	if(lengthOf(sp2) != 2) exit("ERROR::GetEnergyModality():: Format of energy modilty ("+sp1[0]+") read from DICOM file not recognised. Program aborted");	
	if(lin == "LA2") sp2[0] = sp2[0]+"x";			
	return sp2[0];
}
