//Multiscale Hessian fracture filtering: Main code
//Maarten Voorn, December 2012

requires("1.47b");
usedialog=1;				//1 to use the GUI dialog, 0 to use parameters defined below!!

if (usedialog==0) {
root='D:\\Rootfolder\\';		// Root folder with files. Note double backslash, also at end!
avgmat=65535;				// Average material greyscale. Defaults (not specified): 65535 for 16bit, 255 for 8bit.
fracthresh=0;				// Conservative threshold for clear fractures. Default (not specified): 0.
maxmat=65535;				// Maximum material greyscale to delete bright spots. Defaults (not specified): 65535 for 16bit, 255 for 8bit.
padding=0;				// Amount of padding at start and end of stack to reduce deletion. 0-100% (over overlap). Recommended: 0 (no padding)!!
blocksize=100;				// Size (number of slices) for blocks in 3D Hessian analysis.
ming=2;					// Minimum Gaussian kernel to calculate. 
maxg=6;					// Maximum Gaussian kernel to calculate. Also controls overlap!!!
stepg=1;				// Stepsize between consecutive Gaussian kernels to calculate. 
useming=2;				// Eventually used min Gaussian kernel. 
usemaxg=6;				// Eventually used max Gaussian kernel. 
usestepg=1;				// Eventually used stepsize between consecutive Gaussian kernels. 
doprep=1;				// Create preparation files (1=yes, 0=no)
dohess=1;				// Perform Hessian calculation (1=yes, 0=no)
docombi=1;				// Combine multiple scales outputted by Hessian calculation (1=yes, 0=no)
}
else {					

Dialog.create("Multiscale Hessian Fracture Filtering settings");
Dialog.addMessage("Set the following parameters. Under every choice, several numbers need to be entered.\nFull analyses (i.e. all steps taken at once) are recommended to prevent conflicts, and to keep a single log with all information\nIf a choice is however unchecked, make sure the starred (*) numbers DO still correspond to previous analysis parts. Also note comments to padding!\nPerforming steps later in the hierarchy is usually only possible if the previous steps have been taken too!\n(e.g. the Hessian analysis is not possible without preparing input files first).");
Dialog.addString("Path to root folder. Use \\ for subfolders and at end!", "D:\\Rootfolder\\", 50);
Dialog.addCheckbox("Input files preparation", true);
Dialog.addNumber("Average material greyscale [avgmat]", 65535, 0, 5, "Default=not specified: 65535 for 16bit, 255 for 8bit.");
Dialog.addNumber("Conservative threshold for clear fractures (greyscale value) [consthresh]", 0, 0, 5, "Default=not specified: 0.");
Dialog.addNumber("Maximum material greyscale (to delete bright spots and patches) [maxmat]", 65535, 0, 5, "Default=not specified: 65535 for 16bit, 255 for 8bit.");
Dialog.addMessage("");
Dialog.addMessage("Padding (performed in the folder with Hessian input files).\nWhen Hessian input files have been prepared previously WITH padding ('Padding.txt' exists), set this to 0!!\nSeveral dialog boxes preventing conflicts will appear in this case.\nNote that the overlap is related to the maximum Gaussian kernel to calculate, so set that value in accordance!");
Dialog.addNumber("Padding of start and end of stack by percentage of overlap (0-100%)", 0,0,3, "%. Recommended: 0% (no padding)");
Dialog.addMessage("");
Dialog.addCheckbox("Hessian calculations", true);
Dialog.addNumber("Blocksize: size (number of slices) per block of 3D analysis", 100, 0, 4, "Slices (optimum/best choice can be calculated seperately)");
Dialog.addNumber("Minimum Gaussian Kernel to calculate [s-min]", 2, 0, 2, "voxels *");
Dialog.addNumber("Maximum Gaussian Kernel to calculate [s-max]", 6, 0, 2, "voxels *");
Dialog.addNumber("Stepsize between Gaussian Kernel to calculate [s-step]", 1, 0, 2, "voxels *");
Dialog.addMessage("");
Dialog.addCheckbox("Combination of outputted scales", true);
Dialog.addNumber("Minimum Gaussian Kernel to use in output [uses-min]", 2, 0, 2, "voxels");
Dialog.addNumber("Maximum Gaussian Kernel to use in output [uses-max]", 6, 0, 2, "voxels");
Dialog.addNumber("Stepsize between Gaussian Kernel to use in output [uses-step]", 1, 0, 2, "voxels");
Dialog.show();

root=Dialog.getString();
doprep=Dialog.getCheckbox();
avgmat=Dialog.getNumber();				
fracthresh=Dialog.getNumber();				
maxmat=Dialog.getNumber();
padding=Dialog.getNumber();
dohess=Dialog.getCheckbox();
blocksize=Dialog.getNumber();
ming=Dialog.getNumber();	
maxg=Dialog.getNumber();	
stepg=Dialog.getNumber();
docombi=Dialog.getCheckbox();			
useming=Dialog.getNumber();				
usemaxg=Dialog.getNumber();				
usestepg=Dialog.getNumber();
}					

//____________________________________________________________________________________________________________
//Testing settings. Defining locations and number of files. Starting logfile.
IJ.log("\\Close");			//Closes the log-window (if open)
if (endsWith(root, "\\")==0) {exit("Root folder filename is not correct! Does it exist, and does it end with \\ ? Macro aborted")}
run("FeatureJ Options", "  progress");			//Setting FeatureJ to work properly with macro
if (docombi==1) {					//Tests required for combining.
	if (useming==usemaxg) {										//Allows but warns for single Gaussian kernel.
		Dialog.create("Warning on selected Gaussian kernels");
		Dialog.addMessage("Only 1 Gaussian kernel to combine selected. The analysis is hence not 'multiscale'.\nPress OK to continue anyway. Press Cancel to abort macro.");
		Dialog.show();
	}
	if (useming<ming||useming>maxg) {exit("Gaussian kernels to combine [uses-min, uses-max] are outside of range of calculated Gaussian kernels [s-min, s-max]. Macro aborted.");}
	if (usemaxg>maxg||usemaxg<ming) {exit("Gaussian kernels to combine [uses-min, uses-max] are outside of range of calculated Gaussian kernels [s-min, s-max]. Macro aborted.");}

	selnum=((usemaxg-useming)/usestepg)+1;								
	if (selnum/round(selnum)!=1) {									//Check for integer
		exit("Range of Gaussian kernels to combine does not correspond to an integer amount of scales. Revise!\nExample:\nSteps 2 to 5 with a stepsize of 2 is wrong; gives [2,4] but leaves 'half a scale'.\nSteps 2 to 4 with a stepsize of 2 is correct, and gives [2,4].\nMacro aborted.");
	}
	teststepg=usestepg/stepg;
	if (teststepg/round(teststepg)!=1) {
		exit("The stepsize in Gaussian kernels to combine [uses-step] is not a multiple of the stepsize of Gaussian kernels to calculate [s-step]! Macro aborted");
	}
}

if ((blocksize-4*maxg)<1) {exit("Blocksize is set too small with current maximum Gaussian scale (required overlap is larger than blocksize). Macro aborted.");} //Take overlap = 2*maxg
inputfolder=root+"Input\\";
inputfiles=getFileList(inputfolder);
numfiles=inputfiles.length;
if (blocksize>numfiles) {exit("Blocksize is larger than total number of files. Only blocksize <= Number of files is supported. Macro aborted.");}
inputhessfolder=root+"InputHess\\";
checkempty=getFileList(inputhessfolder);
if (doprep==0 && dohess==0 && docombi==0) {
	exit("No analyses selected! Macro aborted.");
}
if (doprep==1) {
	if (checkempty.length>0) {
		Dialog.create("Folder not empty");
		Dialog.addMessage("The InputHess-folder is not empty. Press OK to delete files. Press Cancel to abort macro.");
		Dialog.show();
		for (i=0; i<checkempty.length; i++) {ok=File.delete(inputhessfolder+checkempty[i]);}		
	}
} else if (doprep==0&&dohess==1) {
	if (checkempty.length==0) {
		exit("There are no Hessian input files (InputHess-folder is empty)\nand the generation of input files is turned off! Macro aborted.");
	}
}	
File.makeDirectory(inputhessfolder);
calcfolder=root+"Calc\\";
checkempty=getFileList(calcfolder);
if (dohess==1) {
	if (checkempty.length>0) {
		Dialog.create("Folder not empty");
		Dialog.addMessage("The Calc-folder is not empty. Press OK to delete files. Press Cancel to abort macro.");
		Dialog.show();
		for (i=0; i<checkempty.length; i++) {ok=File.delete(calcfolder+checkempty[i]);}
	}
} else if (dohess==0&&docombi==1) {
	if (checkempty.length==0) {
		exit("There are no files outputted by the Hessian analysis (Calc-folder is empty)\nand the generation of these files is turned off! Macro aborted.");
	}
}
File.makeDirectory(calcfolder);
outputfolder=root+"Output\\";
checkempty=getFileList(outputfolder);
if (docombi==1) {
	if (checkempty.length>0) {
		Dialog.create("Folder not empty");
		Dialog.addMessage("The Output-folder is not empty. Press OK to delete files. Press Cancel to abort macro.");
		Dialog.show();
		for (i=0; i<checkempty.length; i++) {ok=File.delete(outputfolder+checkempty[i]);}
	}
}
File.makeDirectory(outputfolder);

//Check padding file etc.
if (doprep==1) {
	ok=File.delete(root+"Padding.txt");	// When new Hessian input files are generated, any previous padding file is deleted. ok= added to suppress output in log
}
paddone=File.exists(root+"Padding.txt");
if (paddone==1) {
	padsettingprear=split(File.openAsString(root+"Padding.txt"),"\t\n");
	padsettingpre=padsettingprear[3];
	paddialogtext="Previously used padding of "+padsettingpre+" slices at both start and end of stack detected in 'Padding.txt'.";
}
if (padding>0 && paddone==1) {
	exit("Padding conflict. Padding is turned on, but it has already been performed previously ('Padding.txt' exists)!\nApply one of the following options:\n1) To use the padding selected in a previous analysis, set the padding to 0.\n2) Delete 'Padding.txt' and the padded slices manually to perform the padding with new settings.\n3) Restart the analysis with the generation of Hessian input files turned ON (recommended, slowest but safest choice).\nMacro aborted.");
} else if (padding==0 && paddone==1) {
	Dialog.create("Previous padding detected");
	Dialog.addMessage("Possible padding conflict. Padding is turned off, but has been applied in a previous stage ('Padding.txt' exists)!");
	Dialog.addMessage(paddialogtext);
	Dialog.addMessage("In current setup, the previous padding WILL affect the end results.\nIf this is not desired, abort the macro and apply one of the following options:\n1) Delete 'Padding.txt' and the padded slices manually to perform the padding with new settings.\n2) Restart the analysis with the generation of Hessian input files turned ON (recommended, slowest but safest choice).\nPress OK to continue. Press Cancel to abort macro.");
	Dialog.show();
}
//End of padding checking

ROImacro=root+"ROI.ijm";
if (File.exists(ROImacro)==false) {exit("No ROI-file [ROI.ijm] found. Macro aborted.");}
linesmacro=root+"Lines.ijm";
if (File.exists(linesmacro)==false) {exit("No lines-file [Lines.ijm] found. Macro aborted.");}

getDateAndTime(year1,month1,dayofweek1,dayofmonth1,hour1,minute1,second1,msec1);
month1=month1+1;
if (month1<10) {month1b="0"+month1; } else {month1b=month1;}
if (dayofmonth1<10) {dayofmonth1b="0"+dayofmonth1; } else {dayofmonth1b=dayofmonth1; }
if (hour1<10) {hour1b="0"+hour1; } else {hour1b=hour1; }
if (minute1<10) {minute1b="0"+minute1; } else {minute1b=minute1; }
if (second1<10) {second1b="0"+second1; } else {second1b=second1; }		
timestart="Macro started: "+year1+"-"+month1b+"-"+dayofmonth1b+" "+hour1b+":"+minute1b+":"+second1b;
print("3D Multiscale Hessian Fracture Filtering");  
print(timestart);
print("___________________________________");
print(">Used settings<");
print("Input folder:", inputfolder);
print("Folder for input for Hessian calculation:", inputhessfolder);
print("Folder for Hessian calculation:", calcfolder);
print("Folder for final output:", outputfolder);
print("Number of files to be analysed:", numfiles);
if (doprep==1) {
	print("Input files for Hessian calculation will be created");
	print("**Average material greyscale (used for calibration of the Hessian output) [avgmat]:", avgmat);
	print("**Conservative threshold for clear fractures [consthresh]:", fracthresh);
	print("**Maximum material greyscale; to exclude bright spots [maxmat]:", maxmat);
} else {
	print("Input files for Hessian calculation have already been created earlier");
}

if (padding>0) {
	print("Padding turned on with",padding,"% overlap");
} else if (padding==0 && paddone==1) {
	print("Padding turned off but done in a previous stage."); 
	print("**",paddialogtext, "For more details, check earlier logs.");
} else {
	print("Padding turned off");
}

if (dohess==1) {
	print("The Hessian calculations will be performed");
	print("**Hessian calculations for Gaussian kernels from", ming, "to", maxg, ", with stepsize", stepg);
	print("**Size of analysis blocks (Hessian):", blocksize); 
} else if (dohess==0 && docombi==1) {
	print("The Hessian calculations have already been performed earlier");
	print("**Hessian calculations were for Gaussian kernels from", ming, "to", maxg, ", with stepsize", stepg, "Make sure this is correct!");
} else {
	print("The Hessian calculations will not be performed");	
}
if (docombi==1) {
	print("The results of the Hessian calculations on various Gaussian kernels will be combined");
	print("**Hessian calculations to be included in final output: Gaussian kernels from", useming, "to", usemaxg, ", with stepsize", usestepg);
} else {
	print("The results of the Hessian calculations on various Gaussian kernels will not be combined");
}
print("___________________________________");
//____________________________________________________________________________________________________________________________________
//Converting avgmat & fracthresh to proper text strings for passing to other macros (must have 5 positions)
if (avgmat<10) {avgmatstr="0000"+avgmat;} else if (avgmat<100) {avgmatstr="000"+avgmat;} else if (avgmat<1000) {avgmatstr="00"+avgmat;} else if (avgmat<10000) {avgmatstr="0"+avgmat;} else {avgmatstr=toString(avgmat);};
if (fracthresh<10) {fracthreshstr="0000"+fracthresh;} else if (fracthresh<100) {fracthreshstr="000"+fracthresh;} else if (fracthresh<1000) {fracthreshstr="00"+fracthresh;} else if (fracthresh<10000) {fracthreshstr="0"+fracthresh;} else {fracthreshstr=toString(fracthresh);};
//____________________________________________________________________________________________________________________________________
//Checking the ROI and adding control lines for the Hessian analysis, checking conservative threshold
print("Check the ROI and control lines: Awaiting input...");
numtestfile=round(numfiles/2);				//Take a slice halfway the stack
testfile=inputfolder+inputfiles[numtestfile];
open(testfile);
rename("TestROIandLines");
linearguments=avgmatstr+fracthreshstr;
runMacro(linesmacro, linearguments);
getSelectionBounds(lineboxx, lineboxy, lineboxw, lineboxh);		
run("Select None");			
runMacro(ROImacro);
Dialog.create("Check ROI and control lines position");
Dialog.addMessage("ROI and control lines OK?\nPress OK to continue running the macro.\nPress Cancel to terminate (change the ROI and control lines macros and restart).");
Dialog.show();
selectImage("TestROIandLines");
getSelectionBounds(x, y, r1, r2);
print("**ROI Bounds set:  x coordinates =", x, ", y coordinates =", y, ", width =", r1, ", height =", r2);
print("**ROI and lines OK'd by user!");
print("Continuing analysis!");
print("___________________________________");

if (doprep==1) {							
print("Check the set conservative threshold / fracture greyscale and bright spot removal: Awaiting input...");
rename("TestConsThresh");
run("Max...", "value=maxmat");
wait(100);				// Without the wait statement, the threshold does not work correctly
setThreshold(0,fracthresh);
Dialog.create("Check conservative threshold / fracture greyscale and bright spot removal");
Dialog.addMessage("Conservative threshold / fracture greyscale OK (in ROI)?\nBright spots correctly eliminated?\nPress OK to continue running the macro.\nPress Cancel to terminate (change threshold setting in macro).");
Dialog.show();

print("**Conservative threshold / fracture greyscale of", fracthresh, "OK'd by user!");
print("**Removal of greyscales above", maxmat, "(bright spots removal) OK'd by user!");
print("Continuing analysis!");
print("___________________________________");
}									// End of IF for checking greyscales.
close();								// Required to close open image 							
//____________________________________________________________________________________________________________________________________
//Generating input files for Hessian analysis: applying the bright spot removal, the ROI, and the addition of control lines

if (doprep==0) 								
	{print("Input files for Hessian analysis already created earlier. Continuing.");
} else {
print("Generating input files for Hessian analysis: applying the bright spot removal, the ROI, and the addition of control lines...");

setBatchMode(true);
for (i=0; i<numfiles; i++) {				//File counting starts at 0
	showStatus("Generating input files...");
	showProgress(i/numfiles);
	inputfile = inputfolder+inputfiles[i];
	open(inputfile);
	run("Max...", "value=maxmat");
	run("32-bit");
	runMacro(ROImacro);
	run("Make Inverse");
	run("Set...", "value=NaN");
	runMacro(linesmacro, linearguments);
	run("Select None");				
	inputhessfile=inputhessfolder+inputfiles[i];
	saveAs("tiff", inputhessfile);
	close();
}
setBatchMode(false);
print("Generating input files for Hessian analysis finished!");
}
print("___________________________________");
//____________________________________________________________________________________________________________________________________

overlap=2*maxg;							

setBatchMode(true);
if (padding>0) {
	print("Padding files by",padding,"% overlap");
	padoverlap=floor((padding/100)*overlap);			
	print("**Selected percentage corresponds to",padoverlap,"x copying of the first and last slices");
	inputpadfiles=getFileList(inputhessfolder);				
	numpadfiles=inputpadfiles.length;					

	testfile=inputhessfolder+inputpadfiles[numpadfiles-1];			// Last file is numpadfiles-1
	open(testfile);
	padfilename=inputpadfiles[numpadfiles-1];

	for (i=1; i<=padoverlap; i++) {
		padfilename="Z"+padfilename;
		padfile=inputhessfolder+padfilename;

		save(padfile);
	}
	close();
	testfile=inputhessfolder+inputpadfiles[0];
	open(testfile);
	padfilename=inputpadfiles[0];

	for (i=1; i<=padoverlap; i++) {
		padfilename="0"+padfilename;
		padfile=inputhessfolder+padfilename;

		save(padfile);
	}
	close();
	print("Padding finished!");
	setResult("Padding (no. of slices of overlap)",0,padoverlap);
	updateResults();
	selectWindow("Results");
	save(root+"Padding.txt");
	run("Close");
} else if (padding==0 && paddone==1) {
	print("Padding turned off here but done in a previous stage."); 
} else {
	print("Padding turned off");
}
setBatchMode(false);
print("___________________________________");
//End of padding

//____________________________________________________________________________________________________________________________________
//Hessian analysis

//overlap=2*maxg;								//Removed here since already present higher up
inputhessfiles=getFileList(inputhessfolder);
numhessfiles=inputhessfiles.length;					
if (dohess==0) 								
	{print("Hessian analysis and normalising turned off or already performed earlier. Continuing.");
} else {
print("Applying Hessian analysis...");
blockstep=blocksize-2*overlap;
delstart=overlap;			//Slice number "delstart" is deleted itself as well
delend=blocksize-overlap+1;		//Slice number "delend" is deleted itself as well
laststart=numhessfiles-blocksize+1;	//Defines last block to be analysed. May overlap severely with previous.

countblocktot=-floor(-(numhessfiles-(2*overlap))/blockstep);	//Total number of analysed blocks [ -floor(-A)=ceil(A) ]
countblock=1;							//Start of counting.

setBatchMode(true);
for (i=1; i<laststart; i+=blockstep) {	//Image sequence counting starts at 1.
	namestart=i+delstart;
	nameend=namestart+blockstep-1;
	print("**Analysing block", countblock, "of", countblocktot, ". Non-overlapping part of slices:", namestart, "-", nameend);
	run("Image Sequence...", "open=&inputhessfolder number=&blocksize starting=&i increment=1 scale=100 file=tif or=[] sort");
	rename("Input");
	for (j=ming; j<=maxg; j+=stepg) {
		print("****Analysing Gaussian Kernel:", j);
		run("FeatureJ Hessian", "largest middle smallest smoothing=&j");
		selectImage("Input largest Hessian eigenvalues");
		run("Slice Remover", "first=&delend last=&blocksize increment=1");
		run("Slice Remover", "first=1 last=&delstart increment=1");
		selectImage("Input middle Hessian eigenvalues");
		run("Slice Remover", "first=&delend last=&blocksize increment=1");
		run("Slice Remover", "first=1 last=&delstart increment=1");
		run("Abs", "stack");		
		selectImage("Input smallest Hessian eigenvalues");
		run("Slice Remover", "first=&delend last=&blocksize increment=1");
		run("Slice Remover", "first=1 last=&delstart increment=1");
		run("Abs", "stack");
		imageCalculator("Subtract stack", "Input largest Hessian eigenvalues","Input middle Hessian eigenvalues");
		imageCalculator("Subtract stack", "Input largest Hessian eigenvalues","Input smallest Hessian eigenvalues");
		selectImage("Input middle Hessian eigenvalues");
		close();
		selectImage("Input smallest Hessian eigenvalues");
		close();
		selectImage("Input largest Hessian eigenvalues");
		run("Min...", "value=0 stack");
		nameprefix=d2s(j,1)+"_";
		run("Image Sequence... ", "format=TIFF name=&nameprefix start=&namestart digits=5 save=&calcfolder");
		close();
	}
	selectImage("Input");
	close();
	countblock=countblock+1;
}
setBatchMode(false);

//Last block:
setBatchMode(true);
	i=laststart;
	namestart=i+delstart;
	nameend=namestart+blockstep-1;
	print("**Analysing block", countblock, "of", countblocktot, "(LAST block). Non-overlapping part of slices:", namestart, "-", nameend);
	run("Image Sequence...", "open=&inputhessfolder number=&blocksize starting=&i increment=1 scale=100 file=tif or=[] sort");
	rename("Input");
	for (j=ming; j<=maxg; j+=stepg) {
		print("****Analysing Gaussian Kernel:", j);
		run("FeatureJ Hessian", "largest middle smallest smoothing=&j");
		selectImage("Input largest Hessian eigenvalues");
		run("Slice Remover", "first=&delend last=&blocksize increment=1");
		run("Slice Remover", "first=1 last=&delstart increment=1");
		selectImage("Input middle Hessian eigenvalues");
		run("Slice Remover", "first=&delend last=&blocksize increment=1");
		run("Slice Remover", "first=1 last=&delstart increment=1");
		run("Abs", "stack");		
		selectImage("Input smallest Hessian eigenvalues");
		run("Slice Remover", "first=&delend last=&blocksize increment=1");
		run("Slice Remover", "first=1 last=&delstart increment=1");
		run("Abs", "stack");
		imageCalculator("Subtract stack", "Input largest Hessian eigenvalues","Input middle Hessian eigenvalues");
		imageCalculator("Subtract stack", "Input largest Hessian eigenvalues","Input smallest Hessian eigenvalues");
		selectImage("Input middle Hessian eigenvalues");
		close();
		selectImage("Input smallest Hessian eigenvalues");
		close();
		selectImage("Input largest Hessian eigenvalues");
		run("Min...", "value=0 stack");
		nameprefix=d2s(j,1)+"_";
		run("Image Sequence... ", "format=TIFF name=&nameprefix start=&namestart digits=5 save=&calcfolder");
		close();
	}
	selectImage("Input");
	close();
setBatchMode(false);

print("Hessian analysis finished!");
print("___________________________________");
//____________________________________________________________________________________________________________________________________
//Normalising the slices using the control lines
print("Normalising the slices using the control lines...");
normfiles = getFileList(calcfolder);
setBatchMode(true);
for (i=0; i<normfiles.length; i++) {			//File counting starts at 0
	showStatus("Normalising...");
	showProgress(i/normfiles);	
	normfile = calcfolder+normfiles[i];
	open(normfile);
	makeRectangle(lineboxx, lineboxy, lineboxw, lineboxh);
	getStatistics(a,b,c,max);
	run("Select None");
	run("Divide...", "value=&max");			//Normalises stack by dividing by maximum value of control lines
	run("Max...", "value=1");			//Sets maximum saturation to 1
	save(normfile);
	close();
}
setBatchMode(false);

print("Normalising finished!");
}
print("___________________________________");
//____________________________________________________________________________________________________________________________________
//Combining the selected range of normalised Hessian scales
if (docombi==0) {
	print("The results of the Hessian calculations on various Gaussian kernels will not be combined. Continuing.");
} else {
print("Combining the selected range of normalised Hessian scales...");
print("**Gaussian kernel sizes combined:", useming, "to", usemaxg, ", with stepsize", usestepg);

selnum=((usemaxg-useming)/usestepg)+1;			//"Sel" for "Select" NOTE COUNTING STARTS AT 1
selstart=((useming-ming)/stepg)+1;
selstep=(usestepg/stepg);

hessfilestart=1+overlap;				//First name of files to address. Based on NAMES (namestart) series. Differs from original series. Explains taken numbers.
hessfileend=numhessfiles-overlap;			//Last name of files to address

setBatchMode(true);					//Loop to make names correspond to earlier output.
for (i=hessfilestart; i<=hessfileend; i++) {
	showStatus("Combining Hessian outputs...");
	showProgress(i/hessfileend);
	if (i<10) {
	name="_0000"+i; 
	}else if (i<100) {
	name="_000"+i; 
	}else if (i<1000) {
	name="_00"+i; 
	}else if (i<10000) {
	name="_0"+i;
	}else if (i<100000) {
	name="_"+i; }
	
	run("Image Sequence...", "open=&calcfolder number=&selnum starting=&selstart increment=&selstep scale=100 file=&name or=[] sort");
	rename("Hessscales");
	if (selnum>1) {										//IF required to also allow 1 Hessian scale to be renamed only
		run("Z Project...", "start=1 stop=100 projection=[Max Intensity]");		//100 is fine, there will never this amount of different Gaussian kernels at the same time.
		selectImage("Hessscales");
		close();
	} else {
		rename("MAX_Hessscales");							//One scale only
	}											//End of IF for one scale only.

	selectImage("MAX_Hessscales");
	j=i-1;							//Hessian files start counting at 1. Filenames can be everything but internally start counting at 0
	outputfile=outputfolder+"Hessian_"+inputhessfiles[j];
	if (i==hessfilestart) {
		print("**First combined: Hessian analysis slice", i, "to file", outputfile, "(Overlap is", overlap, ", Check if correct)");  
	}
	saveAs("Tiff", outputfile);
	close();
}
setBatchMode(false);
	
print("Combining finished!");
} 									
print("___________________________________");
print("Selected analysis finished!");
print("___________________________________");

//____________________________________________________________________________________________________________________________________
//Displaying final time, duration, and memory usage (note: bytes / 1024^2 to get MBs). Saving logfile.
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

savelogname="HessianFilteringLog";
savelogfile=root+"\\"+savelogname+".txt";
i=1;
while (File.exists(savelogfile)==true) {				//Prevents overwriting of log-files
	savelognamealt=savelogname+i;
	savelogfile=root+"\\"+savelognamealt+".txt";
	i=i+1;	
}
print("Logfile saved to", savelogfile);
selectWindow("Log");
run("Text...", "save=savelogfile");