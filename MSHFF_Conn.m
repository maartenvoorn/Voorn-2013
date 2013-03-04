clear;
tic;

%Provide the following two parameters:
rootfolder='D:/Rootfolder/';
threshold = 1;


%----------------------------------
%----------------------------------
pathDATA = 'CosineCal/';
typeDATA = '*.tif';
pathOUTPUT = 'Connected/';
nrcol = 255; % 255 for 8 bit images
%----------------------------------
cd(rootfolder);
fileDATA = dir([pathDATA typeDATA]);
mkdir(pathOUTPUT);
nrfiles=numel(fileDATA);

disp(['Loading ', num2str(nrfiles), ' input files...']);

h = waitbar(0,'Loading input files...');
for i=1:nrfiles
    perc=(i/nrfiles)*100;
    waitbar(i/nrfiles,h,sprintf('Loading input files %2.0f%%',perc));
    I(:,:,i) = uint8(imread([pathDATA fileDATA(i).name]));
end
pause(1);
delete(h);

disp(['Saving temporary MAT file with original data...']);
save('tempI.mat', 'I', '-v7.3'); % Save temp MAT file with original data

disp(['Setting a threshold of: ', num2str(threshold), ' for connectivity analysis...']);
J=I.*0;                          %Preallocation
h = waitbar(0,'Setting threshold...');
for i=1:nrfiles
    perc=(i/nrfiles)*100;
    waitbar(i/nrfiles,h,sprintf('Setting threshold %2.0f%%',perc));
    J(:,:,i) = im2bw(I(:,:,i), (threshold/nrcol));
end
pause(1);
delete(h);

clear I;

disp(['Labeling connected voxels...']);
CC = bwconncomp(J, 26);

% CC.PixelIdxList is a list of clusternumbers, where for every number, an
% array of positions where this cluster occurs is saved.

imvolume=CC.ImageSize;
maxind=length(CC.PixelIdxList);         % Number of indices (=number of clusters)
maxvoxel=imvolume(1)*imvolume(2)*imvolume(3);
firstslice=imvolume(1)*imvolume(2);     % Max. value of first slice
lastslice=maxvoxel-firstslice+1;        % Min. value of last slice 

disp('Checking for matching indices in first and last slice...');

% Adapted from http://www.mathworks.com.au/matlabcentral/answers/43833 :
indexok=false(1,maxind);                % Allocates an array of zeroes
for j=1:maxind;
    if length(CC.PixelIdxList{j})<imvolume(3)
        indexok(j)=true;                % Sets index number to 1 if it's not throughconnected
    elseif any(CC.PixelIdxList{j}<=firstslice)==0 || any(CC.PixelIdxList{j}>=lastslice)==0;
        indexok(j)=true;                % Sets index number to 1 if it's not throughconnected
    end
end
CC.PixelIdxList(indexok)=[];            % Deletes non-connected parts!!! 

pause(1);

disp('Extracting all connected image locations...');
A=vertcat(CC.PixelIdxList{1:end});      % Combines ALL elements (=pixel locations) left in CC.PixelIdxList into 1 array A.

clear CC;
pause(1);

%Copying original dataset
J=J.*0;

pause(1);
disp(['Loading original dataset...']);
load('TempI.mat');

pause(1);

disp(['Filtering original data by connected components...']);
A=sort(A);                              % Sort A (not sure if really necessary)
%h = waitbar(0,'Filtering data...');    % Waitbar just doesn't work here...
nrA=numel(A);
for j=1:nrA;
    J(A(j))=I(A(j));
end
pause(1);
%delete(h);

pause(1);
disp(['Writing output files...']);
h = waitbar(0,'Writing output files...');
for i=1:nrfiles
    [useless, filename, useless]=fileparts(fileDATA(i).name);
    clear useless;
    perc=(i/nrfiles)*100;
    waitbar(i/nrfiles,h,sprintf('Writing output files %2.0f%%',perc));
    imwrite(J(:,:,i),[pathOUTPUT, 'Conn_', filename, '.tif']);
end
pause(1);
delete(h);
pause(1);
disp(['Finished!']);
elapsedtime=toc;
disp(['Ellapsed time: ', num2str(elapsedtime)]);

delete('tempI.mat');