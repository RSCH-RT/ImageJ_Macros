// -------------------------------------------------------------------------------------------------------------------------------------------
//  Program to analyse junction doses for 4 quadrant fields
//  Written by JP 12/11/18
// -------------------------------------------------------------------------------------------------------------------------------------------

version = "v2.1";
update_date = "22/09/20 by JP";
requires("1.47p");	
if (nImages != 0) exit("Please close all images before running this macro");

Dialog.create("Macro Opened");
Dialog.addMessage("EPID QC ASYM Image Analysis");
Dialog.addMessage("Version: " + version);
Dialog.addMessage("Last Updated: " + update_date);
Dialog.addMessage("");
Dialog.addMessage("Requirements:")
Dialog.addMessage("     1. Images should be acquired at Coll 90. If not, the results will need to be transformed by user");
Dialog.addMessage("     2. The couch should be retracted so that it does not obscure imager");
Dialog.addMessage("");
Dialog.show();

energyChoices = newArray("6X","10X","15X");
linacChoices = newArray("LA2","LA3","LA4","LA5","LA6","Red-A","Red-B");

Dialog.create("Please input the following data:");
Dialog.addMessage("--- Irradiation details ---");
Dialog.addChoice("Select Linac: ",linacChoices);
Dialog.addChoice("Select energy: ",energyChoices);
Dialog.addMessage("--- User ---");
Dialog.addString("User:","",15);
Dialog.show();
linac = Dialog.getChoice();
energy =  Dialog.getChoice();
user = Dialog.getString();

//// Select image directory
imageDir = getDirectory("Choose Image File Directory ");
fileList = getFileList(imageDir);
if(lengthOf(fileList) != 4) exit("Please ensure only 4 images are present in the selected directory. Macro aborted");

//// Open images, convert to 32-bit, and apply CU calibration
open(imageDir+fileList[0]); run("32-bit"); rename("A");ApplyCUcal("A"); run("Enhance Contrast", "saturated=0.35"); if(getInfo("0028,1054") != " CU") exit("Image type not CU. Aborting macro"); TestUserInputAgainstDICOMHeaderData(linac, energy); if(round(getInfo("300A,0120")) != 90) exit("ERROR:  CA not at 90 degrees. Analysis aborted");
open(imageDir+fileList[1]); run("32-bit"); rename("B");ApplyCUcal("B"); run("Enhance Contrast", "saturated=0.35"); if(getInfo("0028,1054") != " CU") exit("Image type not CU. Aborting macro"); TestUserInputAgainstDICOMHeaderData(linac, energy); if(round(getInfo("300A,0120")) != 90) exit("ERROR:  CA not at 90 degrees. Analysis aborted");
open(imageDir+fileList[2]); run("32-bit"); rename("C");ApplyCUcal("C"); run("Enhance Contrast", "saturated=0.35"); if(getInfo("0028,1054") != " CU") exit("Image type not CU. Aborting macro"); TestUserInputAgainstDICOMHeaderData(linac, energy); if(round(getInfo("300A,0120")) != 90) exit("ERROR:  CA not at 90 degrees. Analysis aborted");
open(imageDir+fileList[3]); run("32-bit"); rename("D");ApplyCUcal("D"); run("Enhance Contrast", "saturated=0.35"); if(getInfo("0028,1054") != " CU") exit("Image type not CU. Aborting macro"); TestUserInputAgainstDICOMHeaderData(linac, energy); if(round(getInfo("300A,0120")) != 90) exit("ERROR:  CA not at 90 degrees. Analysis aborted");
acquisitionDate = getInfo("0008,0023");
analysisDate = GetAnalysisDate(); 

//// Create composite image and filter
imageCalculator("Add create 32-bit", "A","B"); rename("A+B");
imageCalculator("Add create 32-bit", "C","D"); rename("C+D");
imageCalculator("Add create 32-bit", "A+B","C+D"); rename("Composite image");
selectWindow("Composite image");run("Median...", "radius=1");

//// Close unwanted images
selectWindow("A"); close();
selectWindow("B"); close();
selectWindow("C"); close();
selectWindow("D"); close();
selectWindow("A+B"); close();
selectWindow("C+D"); close();

//// Normalise image
NormaliseImage("Composite image", linac, linacChoices);

// Acquire profiles
if(linac == linacChoices[0] || linac == linacChoices[5] || linac == linacChoices[6]) {
	//// LA2/Red-A/Red-B
	makeRectangle(470, 260, 80, 3); topProf = getProfile(); run("Clear", "slice"); run("Select None");
	makeRectangle(470, 505, 80, 3); bottomProf = getProfile(); run("Clear", "slice"); run("Select None");		 
	makeRectangle(383, 350, 3, 80); setKeyDown("alt"); leftProf = getProfile(); run("Clear", "slice"); run("Select None");
	makeRectangle(635, 350, 3, 80); setKeyDown("alt"); rightProf = getProfile();run("Clear", "slice"); run("Select None");	
	setKeyDown("none"); 
} else if(linac == linacChoices[1] || linac == linacChoices[2] || linac == linacChoices[3] || linac == linacChoices[4]) {
	//// LA3/LA4/LA5/LA6
	makeRectangle(543, 450, 100, 3); topProf = getProfile(); run("Clear", "slice"); run("Select None"); 
	makeRectangle(543, 735, 100, 3); bottomProf = getProfile(); run("Clear", "slice"); run("Select None");		 
	makeRectangle(450, 550, 3, 90); setKeyDown("alt"); leftProf = getProfile(); run("Clear", "slice"); run("Select None");
	makeRectangle(740, 550, 3, 90); setKeyDown("alt"); rightProf = getProfile(); run("Clear", "slice"); run("Select None");	
	setKeyDown("none"); 
} else {
	exit("ERROR - treatment unit could not be identified");
}

//// Update image with ROIs
selectWindow("Composite image"); updateDisplay(); run("Enhance Contrast", "saturated=0.35");

//// Calculate min/max junction dose
resTop = DetermineProfMinOrMax(topProf); 
resBottom = DetermineProfMinOrMax(bottomProf); 
resLeft = DetermineProfMinOrMax(leftProf); 
resRight = DetermineProfMinOrMax(rightProf); 

maxJuncX = DetermineMax(resLeft,resRight); 
maxJuncY = DetermineMax(resTop,resBottom); 

//// User comments
Dialog.create("Comments");					
Dialog.addString("Comments:", "None",40);
Dialog.show();
comm = Dialog.getString();

//// Print Results
print ("\\Clear");
print("-------------------------------------------------------------");
print("      Asymmetric Image Analysis using EPID");
print("-------------------------------------------------------------");
print("Images Analysed:");
print("   "+imageDir);
print("   Image Date: "+acquisitionDate); 
print("   Analysis Date: "+analysisDate);
print("   Macro Version:"+version);
print("   User: "+user);
print("   Linac: "+linac);
print("   Energy: "+energy);
print("-------------------------------------------------------------");
print("Maximum junction deviation from 100%: ");	
print("     X jaws:  "+ d2s(maxJuncX,1));
print("     Y jaws:  "+ d2s(maxJuncY,1));
print("\n");
print("-------------------------------------------------------------");
print("Comments: ");
print("   "+comm);
print("-------------------------------------------------------------");

//// Save results
resultsSavePath = GetSavePath(imageDir, linac, energy, acquisitionDate);
if(File.exists(resultsSavePath )) {
	showMessageWithCancel("WARNING: '"+resultsSavePath +"' already exists and will be overwritten. Do you want to continue?");
}
selectWindow("Log");
saveAs("Text",resultsSavePath);

waitForUser("Program Completed and results saved. \nThe image should have a black square in the centre of each quadrant (normalisation ROIs) and a black line drawn across each junction (profiles). \n If this is not the case, disregard the analysis results and perform manual analysis");
//selectWindow("Composite image");close();

/////////////////////////////////////////////////////////// FUNCTIONS ////////////////////////////////////////

function ApplyCUcal(id) {
	selectImage(id);
	intercept = getInfo("0028,1052"); // get the slope and intercept values from the DICOM file.
	slope = getInfo("0028,1053");
	run("Multiply...", "value=&slope"); // apply the slope and intercept to the pixel values.
	run("Add...", "value=&intercept"); // slope should be applied first to ensure correctly applying linear scaling
}

function NormaliseImage(im,lin,linChoices) {
	selectWindow(im);
	mean=0;
	if(lin== linChoices[0] || lin== linChoices[5] || lin== linChoices[6]) {
		//// LA2/Red-A/Red-B
		roi1mean = GetRoiMean(382,260,10);
		roi2mean = GetRoiMean(637,260,10);	
		roi3mean = GetRoiMean(382,507,10);
		roi4mean = GetRoiMean(640,507,10);
	} else if(lin== linChoices[1] || lin== linChoices[2] || lin== linChoices[3] || lin== linChoices[4]) {
		////LA3/LA4/LA5/LA6
		roi1mean = GetRoiMean(450,450,10);
		roi2mean = GetRoiMean(740,450,10);	
		roi3mean = GetRoiMean(450,734,10);
		roi4mean = GetRoiMean(740,734,10);
	} else {
		exit("NormaliseImage()::Could not identify acquistion linac. Aborting macro");
	}
	mean = (roi1mean + roi2mean + roi3mean + roi4mean)/4;
	normFactor = 100/mean;	
	run("Multiply...", "value="+normFactor);
}

function GetRoiMean(x,y,r) {
	sum = 0;
	count =0;
	for(j=y-r;j<y+r;j++) {
		for(i=x-r;i<x+r;i++) {
			sum += getPixel(i,j);
			count++;
			setPixel(i,j,0);
		}
	}
	return sum/count;
}

function DetermineProfMinOrMax(prof) {
	maxDiff = 0.0;
	for(p=0;p<lengthOf(prof);p++) {
		diff = prof[p] - 100;
		if(abs(diff) > abs(maxDiff)) maxDiff = diff;
		//print(p+"    "+prof[p]+"    "+diff+"    "+maxDiff);
	}
	return 100+maxDiff;
}

function DetermineMax(a,b) {	
	if(abs(a-100) >= abs(b-100)) {
		return a;
	} else {
		return b;
	}
}

function GetAnalysisDate() {
	getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
	date = d2s(year,0)+"-"+d2s(month+1,0)+"-"+d2s(dayOfMonth,0);	
	return date;
}

function GetSavePath(pth, unit, en, date) {
	splitPath = split(pth,"\\");
	len = lengthOf(splitPath );
	saveDir = "";
	for(i=0;i<len;i++) saveDir += splitPath [i]+"\\";
	return saveDir+unit+" "+en +" "+date+" Results.txt";
}

//// Function to test user inputs against DICOM header info
function TestUserInputAgainstDICOMHeaderData(lin, en) {
	//// Test user selection feasibility
	if(en == "15X" && lin == "LA2" || lin == "LA3" || lin == "LA4" || lin == "LA5" || lin == "LA6"  ) exit("WARNING::MAIN::TestUserInputAgainstDICOMHeaderData():: "+lin+" does not deliver "+en+" beams. Terminating program");
	
	//// Test Machine - not possible for LA2
	linacDICOM = getInfo("0008,1010");		
	if(lin == "LA2" && linacDICOM == "") {
		
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
