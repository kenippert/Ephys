% sipperAlignmentTool
%
%   sipperAlignmentTool allows the user to save an alignment image and
%   align the sipper on each individual day.

%% Load rig parameter file

load('C:\Users\Bpod\Documents\Bpod Local\rigParams.mat','rigParams')

%% Get info from the user

% Generate list of animals with available alignment images
fileList = dir('C:\Users\Bpod\Documents\Bpod Local\Data');
animList = cell([length(fileList),1]);
for iFile = 3:length(fileList)
    if exist(['C:\Users\Bpod\Documents\Bpod Local\Data\',fileList(iFile).name,'\sipperAlignmentImage.mat'],'file') == 2
        animList{iFile - 2} = fileList(iFile).name;
    end
end
animList{end - 1} = 'Recreate an Alignment Image for an Existing Animal';
animList{end} = 'Create an Alignment Image for a New Animal';
animList = animList(~cellfun('isempty',animList));

% Ask user which animal to align or to create a new image
[indx,tf] = listdlg('PromptString',{'Select an animal for sipper alignment.',...
    'Only one animal can be selected at a time.',''},...
    'SelectionMode','single','ListString',animList,'ListSize',[400,350]);

% Organize results
if isempty(indx)
    warning('Sipper alignment has been skipped.')
    alignMode = 'None';
elseif indx == length(animList)
    alignMode = 'NewAnimImage';
elseif indx == (length(animList) - 1)
    alignMode = 'RecreateImage';
else
    alignMode = 'AlignImage';
    anim = animList{indx};
end

%% Capture a new alignment image for a new animal

if strcmp(alignMode,'NewAnimImage')
    
    % Request animal name from user
    animName = inputdlg({'Name'},...
        'Input Animal Name');
    
    % Error check input
    if isempty(animName{1})
        error('No animal name given!')
    end
    
    % Capture image
    vidObj = videoinput('mwspinnakerimaq', rigParams.VideoID);
    vidObj.FramesPerTrigger = 1;
    start(vidObj)
    sipperAlignmentImageWaste = getdata(vidObj); % For some reason, the first image has the wrong size
    vidObj = videoinput('mwspinnakerimaq', rigParams.VideoID);
    vidObj.FramesPerTrigger = 1;
    start(vidObj)
    sipperAlignmentImage = getdata(vidObj);
    
    % Display image
    figure
    imagesc(sipperAlignmentImage)
    
    % Save the image
    save(['C:\Users\Bpod\Documents\Bpod Local\Data\',animName{1},'\sipperAlignmentImage.mat'],'sipperAlignmentImage')
    imwrite(sipperAlignmentImage,['C:\Users\Bpod\Documents\Bpod Local\Data\',animName{1},'\sipperAlignmentImage.png'])
    
    % Label the images for saving in the main protocol
    targetSipAlignIm = sipperAlignmentImage;
    actualSipAlignIm = sipperAlignmentImage;
    
    % Clear the video object
    delete(vidObj)
    clear vidObj
    
end

%% Capture a new alignment image for an existing animal

if strcmp(alignMode,'RecreateImage')
    
    % Ask user which animal we are creating an image for
    [indx,tf] = listdlg('PromptString',{'Select an animal for new image.',...
        'Only one animal can be selected at a time.',''},...
        'SelectionMode','single','ListString',animList(1:(end - 2)),'ListSize',[400,350]);
    
    if isempty(indx)
        error('No animal selected.')
    else
        anim = animList{indx};
    end
    
    % Capture image
    vidObj = videoinput('mwspinnakerimaq', rigParams.VideoID);
    vidObj.FramesPerTrigger = 1;
    start(vidObj)
    sipperAlignmentImageWaste = getdata(vidObj); % For some reason, the first image has the wrong size
    vidObj = videoinput('mwspinnakerimaq', rigParams.VideoID);
    vidObj.FramesPerTrigger = 1;
    start(vidObj)
    sipperAlignmentImage = getdata(vidObj);
    
    % Display image
    figure
    imagesc(sipperAlignmentImage)
    
    % Save the image
    save(['C:\SanworksBPod\Bpod Local\Data\',anim,'\sipperAlignmentImage.mat'],'sipperAlignmentImage')
    imwrite(sipperAlignmentImage,['C:\SanworksBPod\Bpod Local\Data\',anim,'\sipperAlignmentImage.png'])
    
    % Label the images for saving in the main protocol
    targetSipAlignIm = sipperAlignmentImage;
    actualSipAlignIm = sipperAlignmentImage;
    
    % Clear the video object
    delete(vidObj)
    clear vidObj
    
end

%% Align Sipper

if strcmp(alignMode,'AlignImage')
    
    % Load image file
    load(['C:\SanworksBPod\Bpod Local\Data\',anim,'\sipperAlignmentImage.mat'],'sipperAlignmentImage')
    maxInt = max(sipperAlignmentImage(:));
    
    % Make the figure
    figure; 
    hAxes = gca;
    global stopFlag
    stopFlag = 0;
    set(gcf, 'KeyPressFcn', @myKeyPressFcn)
    
    % Display images to allow user to align the sipper
    vidObj = videoinput('mwspinnakerimaq', rigParams.VideoID);
    vidObj.FramesPerTrigger = 1;
    start(vidObj)
    sipperAlignmentImageWaste = getdata(vidObj); % For some reason, the first image has the wrong size
    vidObj = videoinput('mwspinnakerimaq', rigParams.VideoID);
    vidObj.FramesPerTrigger = 1;
    
    hWaitbar = waitbar(0,'Hit Cancel to Stop Image Display','CreateCancelBtn','delete(gcbf)');
    
    % Loop until user stops
    while stopFlag == 0
        start(vidObj)
        newImage = getdata(vidObj);
        colormap parula
        imagesc(hAxes,newImage,[0,maxInt])
        drawnow
        pause(0.2)
        colormap gray
        imagesc(hAxes,0.7*sipperAlignmentImage + 0.3*newImage,[0,maxInt])
%         imagesc(hAxes,sipperAlignmentImage,[0,255])
        drawnow
        pause(0.3)
        if ~ishandle(hWaitbar)
            stopFlag = 1;
        end
    end
    
    % Label the images for saving in the main protocol
    targetSipAlignIm = sipperAlignmentImage;
    actualSipAlignIm = newImage;
    
    % Clear the video object
    delete(vidObj)
    clear vidObj
    
end




function myKeyPressFcn(hObject, event)
global stopFlag
stopFlag  = 1;
end