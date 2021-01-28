/// Dose calibrated RTQA2 field size macro
///
/// NOTES:
/// Image rotation formulas: https://www.siggraph.org/education/materials/HyperGraph/modeling/mod_tran/2drota.htm

version = "v2.1";
update_date = "22/09/20 by JP";

// Renormalisation thresholds for 10FFF
thresh3x3 = 48.4;
thresh10x10 = 41.6;
thresh30x30 = 23.7;
tolerance = 0.2;	

////Ensure that no images are open
if(nImages != 0) exit("Please ensure all images are closed prior to running this macro. Aborting...");

Dialog.create("Macro Opened");
Dialog.addMessage("---- Linac Field Size Analysis using RTQA2 film ----");
Dialog.addMessage("Version: " + version);
Dialog.addMessage("Last Updated: " + update_date);
Dialog.addMessage("Requirements: Film must be scanned (or transformed) with the orientation described in EQC-182");
Dialog.addMessage("                             Film must be scanned at 200 or 96 dpi (preferably 200 dpi)");
Dialog.addMessage("");
Dialog.addMessage("Click OK to start");
Dialog.show();

////Get user to input field details
DayChoices = newArray(31); for(i=0; i<DayChoices.length; i++) DayChoices[i] = d2s(1+i,0);
MonthChoices = newArray("Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec");
YearChoices = newArray(11); for(i=0; i<YearChoices.length; i++) YearChoices[i] = d2s(2018+i,0);
energyChoices = newArray("6X","10X","10FFF","15X");
fieldSizeChoices = newArray("3x3","10x10","30x30");
linacChoices = newArray("Red-A","Red-B","LA2","LA3","LA4","LA5","LA6");
collChoices = newArray("0","90","270");
sadChoices = newArray(100,125);
ScannerChoices = newArray("Guildford - 11000XL Pro ","Redhill - V750 Pro ");
dpiChoices = newArray(200,96);
analysisChoices = newArray("Whole field", "2 strips", "4 strips");

Dialog.create("Please input the following data:");
Dialog.addMessage("--- Date of Exposure ---");
Dialog.addChoice("Day:", DayChoices);
Dialog.addChoice("Month:", MonthChoices);
Dialog.addChoice("Year:", YearChoices);
Dialog.addMessage("--- Exposure Details ---");
Dialog.addChoice("Select Linac: ",linacChoices);
Dialog.addChoice("Select Energy: ",energyChoices);
Dialog.addChoice("Select field size: ",fieldSizeChoices,fieldSizeChoices[1]);
Dialog.addChoice("Collimator angle:",collChoices,collChoices[1]);
Dialog.addChoice("SAD: ",sadChoices,sadChoices[0]);
Dialog.addMessage("--- Scanner Details ---");
Dialog.addChoice("Scanner:", ScannerChoices);
Dialog.addChoice("Scan dpi: ",dpiChoices, dpiChoices[0]);
Dialog.addMessage("--- User ---");
Dialog.addString("User:","",15);
Dialog.show();
irradDay = Dialog.getChoice();
irradMonth = Dialog.getChoice();
irradYear = Dialog.getChoice();
linac = Dialog.getChoice();
energy =  Dialog.getChoice();
fieldSz = Dialog.getChoice();
collAng = Dialog.getChoice();
sad = Dialog.getChoice();
scanner = Dialog.getChoice();
dpi = Dialog.getChoice();
user = Dialog.getString();
mmPerPix = 25.4/dpi;
fieldEdgeProfLength = round(25/mmPerPix);
markAvoidanceLength = round(1.5/mmPerPix);

Dialog.create("Analysis method");
Dialog.addChoice("Please select analysis method:", analysisChoices,analysisChoices[0]);
Dialog.show();
analChoice = Dialog.getChoice();

//// Open and process image
imagePath = File.openDialog("Please select image to analyse");
open(imagePath); run("32-bit");
imName = getTitle();
run("Set Scale...", "distance=0 known=0 pixel=1 unit=pixel");
run("Median...", "radius=1");
waitForUser("Ensure the RED image channel has been selected (red border around the image). If not, please scroll left or right until the red channel has been selected");
ApplyDoseCalToFilm(imName); updateDisplay();

//// Set threshold for field size
if(energy == energyChoices[2] ) {
	pvThresh = SetThreshold(fieldSz,fieldSizeChoices);
} else {
	pvThresh = 50.0;
}

xCentPix = getWidth()/2;
yCentPix = getHeight()/2;
X1=0;X2=0;Y1=0;Y2=0;
jaws = newArray("X1","X2","Y1","Y2");
xOryJaws = newArray("X","Y");

//// Calc field size for 3x3 or 10x10
if(analChoice == analysisChoices[0]) {
	//// Get user to select 4 pen marks
	setTool("zoom");
	showMessageWithCancel("Ensure X2 label is at the top of the image. If not, press Cancel and either rotate or rescan as necessary");
	showMessage("Please select the 4 cross-hair indication points, CLOCKWISE from 12 o'clock. Use zoom function first, \nthen use the multi-point function on the ImageJ tool bar to select the points (the pan function can be \nused inbetween point selections). Begin once you have pressed OK below");
	waitForUser("Press OK when 4 points have been selected");
	getSelectionCoordinates(xpoints, ypoints);
	if(lengthOf(xpoints) != 4 || lengthOf(ypoints) !=4) showMessageWithCancel("ERROR","4 points were not registered. Aborting macro");
	run("Select None");

	//// Transform user selected points using calculated rotation 
	angle = RotateImage(xpoints,ypoints);
	P1_trans = TransformPointsAfterImageRotation(xpoints[0], ypoints[0],angle);
	P2_trans = TransformPointsAfterImageRotation(xpoints[1], ypoints[1],angle);
	P3_trans = TransformPointsAfterImageRotation(xpoints[2], ypoints[2],angle);
	P4_trans = TransformPointsAfterImageRotation(xpoints[3], ypoints[3],angle);	
	fieldCentX = round( (P1_trans[0] + P3_trans[0])/2);
	fieldCentY = round( (P2_trans[1] + P4_trans[1])/2);

	//// Acquire and display profiles for analysis
	makeRectangle(P1_trans[0]-1,P1_trans[1]-fieldEdgeProfLength,3,fieldEdgeProfLength-markAvoidanceLength); setKeyDown("alt"); topProf = getProfile(); setKeyDown("none"); run("Clear");
	makeRectangle(P3_trans[0]-1,P3_trans[1]+markAvoidanceLength,3,fieldEdgeProfLength-markAvoidanceLength);setKeyDown("alt"); bottomProf = getProfile();setKeyDown("none");	run("Clear");
	makeRectangle(P4_trans[0] -fieldEdgeProfLength,P4_trans[1]-1,fieldEdgeProfLength-markAvoidanceLength,3); leftProf= getProfile(); run("Clear");
	makeRectangle(P2_trans[0]+markAvoidanceLength,P2_trans[1]-1,fieldEdgeProfLength-markAvoidanceLength,3); rightProf= getProfile(); run("Clear"); run("Select None");
	
	//// Normalise profiles	
	topProfNorm = NormaliseProfile(fieldCentX, fieldCentY, topProf);
	bottomProfNorm = NormaliseProfile(fieldCentX, fieldCentY, bottomProf);
	leftProfNorm = NormaliseProfile(fieldCentX, fieldCentY, leftProf);
	rightProfNorm = NormaliseProfile(fieldCentX, fieldCentY, rightProf);	

	//// Calcualte CAX to field edge distances
	X2 =ProcessArray(topProfNorm,P1_trans[1]-fieldEdgeProfLength,fieldCentY,pvThresh,"vert");
	X1 =ProcessArray(bottomProfNorm,P3_trans[1]+markAvoidanceLength, fieldCentY,pvThresh,"vert");
	Y2 = ProcessArray(leftProfNorm,P4_trans[0] -fieldEdgeProfLength, fieldCentX, pvThresh,"horz");
	Y1 = ProcessArray(rightProfNorm, P2_trans[0]+markAvoidanceLength, fieldCentX ,pvThresh,"horz");

	makeRectangle(fieldCentX - 1, P1_trans[1]+markAvoidanceLength, 3, (P3_trans[1] - markAvoidanceLength)-(P1_trans[1]+markAvoidanceLength)); run("Clear");
	makeRectangle(P4_trans[0] +markAvoidanceLength, fieldCentY -1, (P2_trans[0] - markAvoidanceLength)-(P4_trans[0]+markAvoidanceLength),3); run("Clear");run("Select None");

} else if(analChoice == analysisChoices[1]) {
	setTool("zoom");
	showMessageWithCancel("Ensure X1 and Y1 jaw labels are at the top of the image. If not, press Cancel and either rotate or rescan as necessary");
	showMessage("Please select the 4 cross-hair indication points, CLOCKWISE from 12 o'clock. Use zoom function first, \nthen use the multi-point function on the ImageJ tool bar to select the points (the pan function can be \nused inbetween point selections). Begin once you have pressed OK below");
	
	for(n=0;n<2;n++) {				
		//// Adjust B/C
		if(n==0) {
			run("Brightness/Contrast...");			
			waitForUser("Adjust image brightness and contrast to aid in resolving jaw labels and pen marks. Then press ok");
		}

		//// Get user to select jaw to process
		Dialog.create("Select jaws to process");
		Dialog.addChoice("Jaws: ",xOryJaws);	
		Dialog.show();
		selectedJaws = Dialog.getChoice();

		//// Get user to select 4 pen marks			
		waitForUser("Press OK when 4 points have been selected");
		getSelectionCoordinates(xpoints, ypoints);
		if(lengthOf(xpoints) != 4 || lengthOf(ypoints) !=4) exit("ERROR","4 points were not registered. Aborting macro");
		run("Select None");
	
		//// Transform user selected points using calculated rotation
		angle = RotateImage(xpoints,ypoints);
		P1_trans = TransformPointsAfterImageRotation(xpoints[0], ypoints[0],angle);
		P2_trans = TransformPointsAfterImageRotation(xpoints[1], ypoints[1],angle);
		P3_trans = TransformPointsAfterImageRotation(xpoints[2], ypoints[2],angle);
		P4_trans = TransformPointsAfterImageRotation(xpoints[3], ypoints[3],angle);	
		fieldCentX = round((P1_trans[0] + P3_trans[0])/2);
		fieldCentY = round((P2_trans[1] + P4_trans[1])/2);

		//// Acquire and display profiles for analysis
		makeRectangle(P1_trans[0]-1,P1_trans[1]-fieldEdgeProfLength,3,fieldEdgeProfLength-markAvoidanceLength); setKeyDown("alt"); topProf = getProfile(); setKeyDown("none"); run("Clear");
		makeRectangle(P3_trans[0]-1,P3_trans[1]+markAvoidanceLength,3,fieldEdgeProfLength-markAvoidanceLength);setKeyDown("alt"); bottomProf = getProfile();setKeyDown("none");	run("Clear");

		//// Normalise profiles	
		topProfNorm = NormaliseProfile(fieldCentX, fieldCentY, topProf);
		bottomProfNorm = NormaliseProfile(fieldCentX, fieldCentY, bottomProf);

		//// Calcualte CAX to field edge distances
		fieldEdgeToCAXtop = ProcessArray(topProfNorm, P1_trans[1]-fieldEdgeProfLength ,fieldCentY,pvThresh,"vert");
		fieldEdgeToCAXbot = ProcessArray(bottomProfNorm,P3_trans[1]+markAvoidanceLength, fieldCentY,pvThresh,"vert");

		if(selectedJaws == xOryJaws[0]) {
			X1 = fieldEdgeToCAXtop;
			X2 = fieldEdgeToCAXbot; 
		}
		if(selectedJaws == xOryJaws[1]) {
			Y1 = fieldEdgeToCAXtop;
			Y2 = fieldEdgeToCAXbot; 
		}
		makeRectangle(fieldCentX - 1, P1_trans[1]+markAvoidanceLength, 3, (P3_trans[1] - markAvoidanceLength)-(P1_trans[1]+markAvoidanceLength)); run("Clear");run("Select None");
		makeRectangle(P4_trans[0]+markAvoidanceLength, fieldCentY-1, (P2_trans[0] - markAvoidanceLength)-(P4_trans[0]+markAvoidanceLength),3);  run("Clear");run("Select None");	
	}	

} else if (analChoice == analysisChoices[2]) {	
	setTool("zoom");
	showMessageWithCancel("Ensure jaw labels are at the top of the image. If not, press Cancel and either rotate or rescan as necessary");
	showMessage("Please select the 4 cross-hair indication points, CLOCKWISE from 12 o'clock. Use zoom function first, \nthen use the multi-point function on the ImageJ tool bar to select the points (the pan function can be \nused inbetween point selections) Begin once you have pressed OK below. ");
	
	for(n=0;n<4;n++) {				
		//// Adjust B/C
		if(n==0) {
			run("Brightness/Contrast...");			
			waitForUser("Adjust image brightness and contrast to aid in resolving jaw labels and pen marks. Then press ok");
		}	

		//// Get user to select jaw to process
		Dialog.create("Select jaw to process");
		Dialog.addChoice("Jaw: ",jaws);	
		Dialog.show();
		selectedJaw = Dialog.getChoice();

		//// Get user to select 4 pen marks			
		waitForUser("Press OK when 4 points have been selected");
		getSelectionCoordinates(xpoints, ypoints);
		if(lengthOf(xpoints) != 4 || lengthOf(ypoints) !=4) exit("ERROR","4 points were not registered. Aborting macro");
		run("Select None");
	
		//// Transform user selected points using calculated rotation
		angle = RotateImage(xpoints,ypoints);
		P1_trans = TransformPointsAfterImageRotation(xpoints[0], ypoints[0],angle);
		P2_trans = TransformPointsAfterImageRotation(xpoints[1], ypoints[1],angle);
		P3_trans = TransformPointsAfterImageRotation(xpoints[2], ypoints[2],angle);
		P4_trans = TransformPointsAfterImageRotation(xpoints[3], ypoints[3],angle);	
		fieldCentX = round((P1_trans[0] + P3_trans[0])/2);
		fieldCentY = round((P2_trans[1] + P4_trans[1])/2);

		//// Acquire and display profiles for analysis
		makeRectangle(P1_trans[0]-1,P1_trans[1]-fieldEdgeProfLength,3,fieldEdgeProfLength-markAvoidanceLength); setKeyDown("alt"); prof = getProfile(); setKeyDown("none"); run("Clear");
		
		//// Normalise profiles	
		profNorm = NormaliseProfile(fieldCentX, fieldCentY, prof);

		//// Calcualte CAX to field edge distances
		fieldEdgeToCAX =ProcessArray(profNorm, P1_trans[1]-fieldEdgeProfLength ,fieldCentY,pvThresh,"vert");		
		if(selectedJaw == "X1") {
			X1 = fieldEdgeToCAX;	
		} else if(selectedJaw == "X2") {
			X2 = fieldEdgeToCAX;	
		} else if(selectedJaw == "Y1") {
			 Y1 = fieldEdgeToCAX;	
		} else if(selectedJaw == "Y2") {
			 Y2 = fieldEdgeToCAX;	
		} else {
			exit("Could not map a film strip to the selected jaw ("+selectedJaw+" for "+fieldSz+". Program aborted");
		}	

		makeRectangle(fieldCentX - 1, P1_trans[1]+markAvoidanceLength, 3, (P3_trans[1] - markAvoidanceLength)-(P1_trans[1]+markAvoidanceLength)); run("Clear");
		makeRectangle(P4_trans[0]+markAvoidanceLength, fieldCentY-1, (P2_trans[0] - markAvoidanceLength)-(P4_trans[0]+markAvoidanceLength),3);  run("Clear");run("Select None");

	} // end of for n jaws	
	
} else {
	exit("ERROR: field size "+fieldSz+" not recognised. Analysis aborted");	
}

if(X1==0 || X2==0 || Y1==0 || Y2==0) exit("ERROR: CAX to field edge distance could not be calculate for all jaws. Program aborted.\nRe-run, ensuring you select the correct jaws during macro execution");

//// Any user comments?
Dialog.create("Comments:");					
Dialog.addString("Comments:", "",40);	
Dialog.show();
comm = Dialog.getString();

//// Close image
//selectWindow(imName); close();

//// Print results
datAndTime = GetDateAndTime();
print("------------------------------------------------------------------------");
print("                    Linac Field Analysis Results");

print("------------------------------------------------------------------------");
print("\n");
print("Analysis by: "+user);
print("File Analysed:   " +imagePath );
print("Exposure Date:   " +irradDay+"-"+irradMonth+"-"+irradYear);
print("Analysis Date:   " +datAndTime[0]);
print("Macro Version:\t "+version);
print("\n");
print("Linac:   \t" + linac);
print("Energy: \t"+energy);
print("Field Size:   \t" + fieldSz);
print("Coll.:   \t" + collAng);
print("SAD:   \t\t" + sad);
print("DPI:   \t\t" + dpi);
print("Scanner:   \t" + scanner);
print("\nField size threshold (%): \t"+pvThresh);
print("\n");
print("------------------ Measured Field Size (cm) -----------------");
print("Field Size Tol (cm): " + tolerance);
print("");
print(fieldSz+" X1:     " + d2s(X1/10,2));
print(fieldSz+" X2:     " + d2s(X2/10,2));
print(fieldSz+" Y1:     " + d2s(Y1/10,2));
print(fieldSz+" Y2:     " + d2s(Y2/10,2));
print("\n");
print("----------------------------  Comments  --------------------------");
print(comm);
print("\n");
print("------------------------------------------------------------------------");
print("                    End of Results");
print("------------------------------------------------------------------------");

//// Save results
resultsSavePath = GetSavePath(imagePath, linac, energy, fieldSz, datAndTime[0]);
if(File.exists(resultsSavePath )) {
	showMessageWithCancel("WARNING: '"+resultsSavePath +"' already exists and will be overwritten. Do you want to continue?");
}
selectWindow("Log");
saveAs("Text",resultsSavePath);

waitForUser("Program Completed and results saved. Check that you are happy with the field edge constructs and results. If not, perform manual analysis");

//////////////////////////////////// FUNCTIONS ////////////////////////////////////////////////
function GetDateAndTime() {
	getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
	dateString = toString(dayOfMonth)+"-"+MonthChoices[month]+"-"+toString(year);
	timeString = toString(hour)+":"+toString(minute);
	dateAndTimeArray = newArray(dateString,timeString);
	return dateAndTimeArray;
}

function GetSavePath(pth, unit, en, fs, date) {
	splitPath = split(pth,"\\");
	len = lengthOf(splitPath );
	saveDir = "";
	for(i=0;i<len-1;i++) saveDir += splitPath [i]+"\\";
	return saveDir+unit+" "+en +" "+ fs+" "+date+" Results.txt";
}

function RotateImage(xpts,ypts) {
	deltaX = xpts[2] - xpts[0];
	deltaY = ypts[2] - ypts[0];
	thetaRad = atan(deltaX/deltaY);	
	thetaDeg = atan(deltaX/deltaY)*180/PI;
	run("Rotate... ", "angle="+thetaDeg+" grid=1 interpolation=Bilinear");
	return thetaRad;
}

function TransformPointsAfterImageRotation(x,y, thetaR) {	
	dx = (x-xCentPix);
	dy = (y-yCentPix);	
	_x = round(xCentPix+dx*cos(thetaR) - dy*sin(thetaR));
	_y = round(yCentPix+ dy*cos(thetaR) + dx*sin(thetaR));
	p = newArray(_x,_y);
	return p;	
}

function ProcessArray(prof,startInd, cax, thresh, profOrient) {	
	if(cax > startInd) {		
		ind = lengthOf(prof)-1;		
		while(prof[ind] > thresh) {
			ind--;
		}
		distPix = cax - (startInd + ind);		
	} else {
		ind=0;
		while(prof[ind] > thresh) {
			ind++;
		}
		distPix = (startInd + ind)-cax;
	}	

	// Display edge
	run("Select None");	
	if(profOrient == "vert") makeLine(fieldCentX-25,startInd+ind ,fieldCentX +25,startInd+ind);
	if(profOrient == "horz") makeLine(startInd+ind,fieldCentY-25,startInd+ind,fieldCentY+25);
	run("Fill"); run("Select None");

	return d2s(distPix*mmPerPix,1);
}

function SetThreshold(fldSz,choices) {
	if(fldSz == choices[0]) {
		thresh = thresh3x3;
	} else if(fldSz == choices[1]) {
		thresh = thresh10x10;
	} else if (fldSz == choices[2]) {
		thresh = thresh30x30;
	} else {
		exit("ERROR: pixel value threshold for field size analysis could not be set. Macro aborted");
	}
	return thresh;
}

function GetStdFig(fldSz,fldSzCh,sadIrr) {

	if(fldSz == fldSzCh[0]) {
		stdFig = 1.5;
	} else if (fldSz == fldSzCh[1]) {
		stdFig = 5.0;
	} else if (fldSz == fldSzCh[2]) {
		stdFig = 15.0;
	} else {
		exit("Could not set standard figure. Aborting macro");
	}	
	return d2s(stdFig*sadIrr/100,2);
}

function ApplyDoseCalToFilm(im) {
	a = 5.675973E-18;
	b = -9.7008866E-13;
	c = 6.349384E-8;
	d= -1.949584E-3;
	e = 2.461955E1;

	selectWindow(im);
	for(j=0; j<getHeight();j++) {
		for(i=0;i<getWidth();i++) {
			pv = getPixel(i,j);
			calPV = a*pow(pv,4) + b*pow(pv,3)+c*pow(pv,2)+d*pv+e;
			setPixel(i,j,calPV);
		}
	showProgress(j/getHeight());
	}
}

function NormaliseProfile(xPix, yPix, arr) {
	normArr = newArray(lengthOf(arr));
	CAXroiMean = GetCAXROImean(xPix,yPix);
	normVal = 100/CAXroiMean;
	for(p=0;p<lengthOf(arr);p++) {
		normArr[p] =normVal*arr[p];
	}
	return normArr;
}

function GetCAXROImean(xP,yP) {
	sum=0;
	c=0;
	for(j=yP-5; j<=yP+5;j++) {
		for(i=xP-5;i<=xP+5;i++) {
			sum+= getPixel(i,j);
			c++;
		}
	}
	roiMean = sum/c;
	if(roiMean > 10) exit("ERROR: Dose calibration couldn't be applied to image for unknown reason. Please close and re-open ImageJ");
	return roiMean;
}


