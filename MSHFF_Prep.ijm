//Multiscale Hessian fracture filtering: Preparation
//Maarten Voorn, December 2012

requires("1.47b");
usedialog=1;	//1 is use dialog, 0 is use settings below.

if (usedialog==0) {
	root='D:\\Rootfolder\\';
	doroifile=1;
	dolinesfile=1;
	ming=1;
	maxg=8;
	stepg=1;
} else {
	Dialog.create("Preparation settings");
	Dialog.addMessage("Set the following. Both ROI and lines file need to be present before starting the Multiscale Hessian Filtering.");
	Dialog.addString("Path to root folder. Use \\ for subfolders and at end!", "D:\\Rootfolder\\",50);
	Dialog.addCheckbox("Prepare ROI.ijm file?", true);
	Dialog.addCheckbox("Prepare lines.ijm file?", true);
	Dialog.addMessage("The following settings are required when a lines.ijm file needs to be created.\nThe scales to be added need to correspond or represent a wider range than intended in the analysis!");
	Dialog.addNumber("Minimum Gaussian Kernel to include for control lines [<=s-min]", 1, 0, 2, "voxels");
	Dialog.addNumber("Maximum Gaussian Kernel to include for control lines [>=s-max]", 8, 0, 2, "voxels");
	Dialog.addNumber("Stepsize between Gaussian Kernels for control lines [<=s-step]", 1, 0, 2, "voxels");
	Dialog.show;
	root=Dialog.getString();
	doroifile=Dialog.getCheckbox();
	dolinesfile=Dialog.getCheckbox();
	ming=Dialog.getNumber();
	maxg=Dialog.getNumber();
	stepg=Dialog.getNumber();
}

if (endsWith(root, "\\")==0) {exit("Root folder filename is not correct! Does it end with \\ ? Macro aborted")}
saveroifile=root+"ROI.ijm";
savelinesfile=root+"Lines.ijm";
inputfolder=root+"Input\\";
inputfiles=getFileList(inputfolder);
numfiles=inputfiles.length;


numtestfile=round(numfiles/2);				//Take a slice halfway the stack
testfile=inputfolder+inputfiles[numtestfile];

//ROI file generation
if (doroifile==true) {
run("Image Sequence...", "open=&inputfolder number=&numfiles starting=1 increment=1 scale=100 file=[] or=[] sort use");

setTool(1);
waitForUser("Create a circular/oval or rectangular ROI. Regard the complete stack! Press OK when finished.");
getSelectionBounds(xroi,yroi,widthroi,heightroi);
seltype=selectionType();

if (widthroi==getWidth && heightroi==getHeight) {
	close();
	IJ.log("\\Close");
	exit("A rectangular selection of the WHOLE image was made. Macro aborted.\nConflict with the main code, since the control lines must lie outside the ROI.");	
}

IJ.log("\\Close");
print('//Automatically generated file for ROI for multiscale Hessian fracture filtering');

if (seltype==0) {
	print("makeRectangle(",xroi,",",yroi,",",widthroi,",",heightroi,")");
} else if (seltype==1) {
	print("makeOval(",xroi,",",yroi,",",widthroi,",",heightroi,")");
} else {
	close();
	IJ.log("\\Close");
	exit("No selection, or no rectangular or oval selection made! Macro aborted.");
}

close();
selectWindow("Log");
run("Text...", "save=saveroifile");
}						

//Control lines file generation
if (dolinesfile==false) {
	IJ.log("\\Close");
	if (doroifile==true) {
		exit("ROI file generated. Control lines file creation turned off.");
	} else exit("No files generated since all options are turned off!");
} else {
endok=false;

while (endok==false) {
linespacey=ming;					//Varies later
linewidth=ming*2;
linelength=0;
open(testfile);
if (File.exists(saveroifile)==false) {
	close();
	exit("No ROI file found! Generate this file first. Macro aborted!");
}
runMacro(saveroifile);
run("Divide...", "value=2");
setTool(0);

waitForUser("Create a rectangular selection for the position of the control lines, outside of the ROI. Press OK when finished.\nThe chosen ROI is displayed for comparison (darker area).");
getSelectionBounds(x1,y1,width1,height1);

//Starting file creation
IJ.log("\\Close");									
print('//Automatically generated file for control lines for multiscale Hessian analysis');
//Do NOT change the following first lines
print('arguments=getArgument();');
print('avgmat=substring(arguments,0,5);');					//Substring positions are correct like this	
print('fracthresh=substring(arguments,5,10);');					//Counting starts at zero. Start: index1, End: index2-1
print('//____________________________________');
print("makeRectangle(", x1,",", y1,",",width1,",",height1,");");
print('run("Set...", "value=avgmat");');

//Generates control lines
for (i=(y1+4*linespacey); i<(y1+height1-linelength); i+=linespacey) {
	for (j=(x1+3*linewidth); j<(x1+width1-2*linewidth); j+=2*linewidth) {
		linelength=5*linewidth;							//5:1 linelength:linewidth
		print("makeRectangle(", j,",", i,",",linewidth,",",linelength,");");
		print('run("Set...", "value=fracthresh");');				//Single ' for printing text WITH " 
		linewidth=linewidth+(2*stepg);						//Max response at 2*Gaussian scale
											
		if (linewidth>(2*maxg)) {						//Breaks out of loops when condition forfilled. Max response at 2*Gaussian scale
			j=1e99;							
			i=1e99;
		}
	}
	linespacey=2*linewidth+linelength;
}

print("makeRectangle(", x1,",", y1,",",width1,",",height1,");		//Repetition required to pass box to main code");		//Repetition required for main code

selectWindow("Log");
run("Text...", "save=savelinesfile");



linearguments="65535"+"00000";
runMacro(savelinesfile, linearguments);

numlines=floor((maxg-ming)/stepg)+1;
numlinestext="Control lines OK? There should be "+numlines+" lines present";
Dialog.create("Control lines OK?");
Dialog.addMessage(numlinestext);
Dialog.addMessage("Press OK to finish.");
Dialog.addMessage("Uncheck and press OK to repeat procedure.");
Dialog.addCheckbox("Control lines OK?", true);
Dialog.show();

if (Dialog.getCheckbox()==true) {
	close();
	endok=true;
	IJ.log("\\Close");
} else { 
	close();
}
}			
}			