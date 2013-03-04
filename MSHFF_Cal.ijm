//Multiscale Hessian fracture filtering: Cosine calibration
//Maarten Voorn, December 2012

requires("1.47b");
usedialog=1;				//1 to use the GUI dialog, 0 to use parameters defined below!!

if (usedialog==0) {
root='D:\\Rootfolder\\';
mincal=0;
maxcal=1;
usemaxg=5;			//Maximum used Gaussian for analysis previously!! Used to calculate reduced ROI size.
dothresh=1;			//1 = Apply conservative threshold. 0 = Don't.
fracthresh=0;
teston=0;			//Amount of slices to test the calibration on. Fill in 0 for all slices.
starton=0;			//Offset in dataset for a testing series. If teston is 0, this value is ignored.
} else {	

Dialog.create("Cosine Calibration - Settings");
Dialog.addMessage("Set the following parameters.\nThe starred (*) numbers should correspond to the Hessian analysis performed earlier (especially [uses-max])!");
Dialog.addString("Path to root folder. Use \\ for subfolders and at end!", "D:\\Rootfolder\\", 50);
Dialog.addMessage("Set the following parameters for calibration");
Dialog.addNumber("mincal = ", 0, 5, 7, "Lower asymptote");
Dialog.addNumber("maxcal = ", 1, 5, 7, "Upper asymptote");
Dialog.addMessage("");
Dialog.addNumber("Used combined maximum Gaussian [uses-max]", 6, 0, 4, "voxels *. As used in combining the files!");
Dialog.addCheckbox("Add a convervative threshold?", true);
Dialog.addNumber("Conservative threshold greyscale value", 0, 0, 5, "(Best: As chosen previously [consthresh] *). Uncheck and ignore number when no conservative threshold is needed.");
Dialog.addMessage(" ");
Dialog.addNumber("Number of slices to test the combination on", 0, 0, 4, "Set 0 for ALL slices (full dataset)");
Dialog.addNumber("Starting file number of test range", 0, 0, 4, "Ignored when number of slices set to 0/All");
Dialog.show();

root=Dialog.getString();
mincal=Dialog.getNumber();
maxcal=Dialog.getNumber();
usemaxg=Dialog.getNumber();
dothresh=Dialog.getCheckbox();
fracthresh=Dialog.getNumber();
teston=Dialog.getNumber();
starton=Dialog.getNumber();
}


IJ.log("\\Close");			
if (endsWith(root, "\\")==0) {exit("Root folder filename is not correct! Does it end with \\ ? Macro aborted")}	
if (dothresh==true) {
	threshinputfolder=root+"InputHess\\";
}
outputfolder=root+"Output\\";
coscalfolder=root+"CosineCal\\";
checkempty=getFileList(coscalfolder);
if (checkempty.length>0) {
	Dialog.create("Folder not empty");
	Dialog.addMessage("The CosineCal-folder is not empty. Press OK to delete files. Press Cancel to abort macro.");
	Dialog.show();
	for (i=0; i<checkempty.length; i++) {ok=File.delete(coscalfolder+checkempty[i]);}		
}	
File.makeDirectory(coscalfolder);
ROImacro=root+"ROI.ijm";
if (File.exists(ROImacro)==false) {exit("No ROI-file (ROI.ijm) found. Macro aborted.");}

print("Calibration by cosine");
//_____________________________________________________________________________________________________________________
getDateAndTime(year1,month1,dayofweek1,dayofmonth1,hour1,minute1,second1,msec1);
month1=month1+1;
if (month1<10) {month1b="0"+month1; } else {month1b=month1;}
if (dayofmonth1<10) {dayofmonth1b="0"+dayofmonth1; } else {dayofmonth1b=dayofmonth1; }
if (hour1<10) {hour1b="0"+hour1; } else {hour1b=hour1; }
if (minute1<10) {minute1b="0"+minute1; } else {minute1b=minute1; }
if (second1<10) {second1b="0"+second1; } else {second1b=second1; }		
timestart="Macro started: "+year1+"-"+month1b+"-"+dayofmonth1b+" "+hour1b+":"+minute1b+":"+second1b;
print(timestart);
//_____________________________________________________________________________________________________________________

outputfiles=getFileList(outputfolder);
if (teston==0) {
	print("Calibrating full dataset.");
	numfilesout=outputfiles.length;
	starton=0;
} else {
	print("Calibrating chosen test-dataset only (", starton, "files, starting from file number", teston, ")");
	numfilesout=starton+teston;
}

pi=d2s(PI,9);
setdivide=(maxcal-mincal)/pi;
mincalname=d2s(mincal,8);
maxcalname=d2s(maxcal,8);

print("___________________________________");
print(">Used settings<");
print("Minimum="+mincalname);
print("Maximum="+maxcalname);
print("Largest combined Gaussian kernel:", usemaxg, "- used to remove edge effects of Hessian analysis.");
print("___________________________________");
if (dothresh==true) {
	print("A conservative threshold with greyvalue", fracthresh, "will be added to the calibrated output");
} else print("No conservative threshold will be added to the calibrated output");

setBatchMode(true);
testfile=outputfolder+outputfiles[0];
open(testfile);
runMacro(ROImacro);					// Opens ROI, in first run only
getSelectionBounds(x, y, r1, r2);			// Gets bounds of ROI
ROItype=selectionType();				// Allows rectangular (0) or oval (1) selection in a later stage
close();
smallx=x+4*usemaxg;					// Shifts x
smally=y+4*usemaxg;					// Shifts y
smallr1=r1-8*usemaxg;					// Shrinks radius by overlap
smallr2=r2-8*usemaxg;					// Shrinks radius by overlap
print("Smaller ROI Bounds set (edge effect removal):  x coordinates =", smallx, ", y coordinates =", smally, ", width =", smallr1, ", height =", smallr2);
setBatchMode(false);
print("___________________________________");

//Main loop
print("Applying functions... ");
setBatchMode(true);
for (i=starton; i<numfilesout; i++) {	
	showStatus("Applying functions...");
	showProgress((i-starton)/(numfilesout-starton));
	outputfile = outputfolder+outputfiles[i];
	open(outputfile);
	rename("Calibration");

	run("Max...", "value=&maxcal");
	run("Subtract...", "value=&mincal");
	run("Min...", "value=0");
	run("Divide...", "value=&setdivide");
	run("Add...", "value=&pi");
	run("Macro...", "code=v=0.5*(1+cos(v))");

	setMinAndMax(0, 2.55); //Scales from 0 to 100
	run("8-bit");
	run("Max...", "value=100");
	if (dothresh==true) {
		threshinputfilename=replace(outputfiles[i],"Hessian_","");
		threshinputfile=threshinputfolder+threshinputfilename;
		if (i==starton) {
			print("Check if correct: file", threshinputfile, "used for applying conservative threshold; combined with calibration in", outputfile);
		}
		open(threshinputfile);
		rename("ConsThresh");
		setThreshold(0,fracthresh);
		run("Convert to Mask", "  black");
		run("Divide...", "value=2.55");
		imageCalculator("Max", "Calibration", "ConsThresh");
		selectImage("ConsThresh");
		close();
	}
	selectImage("Calibration");
	if (ROItype==0) {
		makeRectangle(smallx, smally, smallr1, smallr2);
	} else if (ROItype==1) {
		makeOval(smallx, smally, smallr1, smallr2);
	}
	run("Make Inverse");
	run("Set...", "value=0");
	coscalfile = coscalfolder+outputfiles[i];	
	save(coscalfile);
	close();
}
setBatchMode(false);

print("Calibration finished!");
print("___________________________________");
//____________________________________________________________________________________________________________________________________
getDateAndTime(year2,month2,dayofweek2,dayofmonth2,hour2,minute2,second2,msec2);
month2=month2+1;
if (month2<10) {month2b="0"+month2; } else {month2b=month2;}
if (dayofmonth2<10) {dayofmonth2b="0"+dayofmonth2; } else {dayofmonth2b=dayofmonth2; }
if (hour2<10) {hour2b="0"+hour2; } else {hour2b=hour2; }
if (minute2<10) {minute2b="0"+minute2; } else {minute2b=minute2; }
if (second2<10) {second2b="0"+second2; } else {second2b=second2; }
timeend="Macro finished: "+year2+"-"+month2b+"-"+dayofmonth2b+" "+hour2b+":"+minute2b+":"+second2b;
print(timeend);
if (dayofmonth2<dayofmonth1) {
	hours=((dayofmonth1+dayofmonth2*24)+hour2)-(dayofmonth1*24+hour1);
} else {hours=(dayofmonth2*24+hour2)-(dayofmonth1*24+hour1);}
minutes=minute2-minute1;
if (minutes<0) {
hours=hours-1;
minutes=minutes+60;
}
timetaken="Duration of analysis: "+hours+" Hours and "+minutes+" Minutes";
print(timetaken);
usedmemory=(IJ.currentMemory())/1048576;
maxmemory=(IJ.maxMemory())/1048576;
percmemory=(usedmemory/maxmemory)*100;
percmemorydisp="("+percmemory+" %)";
print("End memory usage:",usedmemory,"MB of",maxmemory,"MB",percmemorydisp, "NOTE: Differs from Windows Task Manager memory usage!");
//____________________________________________________________________________________________________________________________________
savelogcalname="CosineCalLog";
savelogcalfile=root+"\\"+savelogcalname+".txt";
i=1;
while (File.exists(savelogcalfile)==true) {				//Prevents overwriting of log-files
	savelogcalnamealt=savelogcalname+i;
	savelogcalfile=root+"\\"+savelogcalnamealt+".txt";
	i=i+1;	
}
print("Logfile saved to", savelogcalfile);
selectWindow("Log");
run("Text...", "save=savelogcalfile");

if (teston>0) {
	run("Image Sequence...", "open=&coscalfolder number=&teston starting=1 increment=1 scale=100 file=[] or=[] sort use");
	setMinAndMax(0, 100);
	showMessage("Calibration of the test sequence shown. Restart the macro to test other settings, or to perform on the whole stack.\nUsed settings are recorded in the log-file. End of macro.");
}
