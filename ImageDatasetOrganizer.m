% dataSetOrganizer
%
%   This script organizes images that have been categorized and prepares
%   them to be packaged into the TFrecord data format for network training
%   in tensor flow.

%% Settings

% List the data path prefix for all the data files
dataPathPrefix = 'C:\Users\Bpod\Documents\MATLABCODE\Video Processing\Videos\';

% List the files that contain the training images
filenames = {'DBH23052KTClassify1815to2546.mat', 'DBH23052First500frames.mat',};

% Set the proportion of images to mark as outliers
pOut = 0.20;

% Set the proportion of data for training and testing
trainingProp = 0.8;

% Set the number of each type of image to generate from each animal
nImPerAnim = 200;

% Set the name of the directory where we should store the images
imgDir = [pwd,filesep,'imageVer3'];

% Set the standard deviation for cropping jitter in pixels
cropJitSD = 5;

% Set the final crop size (x pixels, y pixels)
cropSize = [100,80];


%% Load all the images and their categories, and also segregate outliers

nImages = 0;
allRawImages = cell([length(filenames),2,2]);
allRefImages = cell([length(filenames),1]);
allCropCoords = zeros([length(filenames),2]);
for iFile = 1:length(filenames)
    
    load([dataPathPrefix,filenames{iFile}])
    imgCats(imgCats == 0) = [];
    for iCat = 1:2
        imgTemp = frames(:,:,imgCats == iCat);
        difScore = squeeze(sum(sum(abs(double(imgTemp) - repmat(mean(imgTemp,3),[1,1,size(imgTemp,3)])),1),2));
        [~,iSort] = sort(difScore,'descend');
        iSortOut = iSort(1:round(pOut*length(iSort)));
        iSortReg = iSort((round(pOut*length(iSort)) + 1):end);
        allRawImages{iFile,iCat,1} = imgTemp(:,:,iSortOut);
        allRawImages{iFile,iCat,2} = imgTemp(:,:,iSortReg);
    end
    allRefImages{iFile,1} = refFrames;
    allCropCoords(iFile,:) = cropCoords;
    
end

%% Perform image subtraction and select images for the data set

allSubImages = cell([length(filenames),2]);
for iFile = 1:length(filenames)
    nRefImages = size(allRefImages{iFile,1},3);
    for iCat = 1:2
        nImgs = [size(allRawImages{iFile,iCat,1},3),size(allRawImages{iFile,iCat,2},3)];
        imgTemp = zeros([cropSize(2),cropSize(1),nImPerAnim],'uint8');
        for iImg = 1:nImPerAnim
            xJit = round(cropJitSD*randn);
            xJit = max([xJit,-allCropCoords(iFile,1) + 1]);
            xJit = min([xJit,320 - cropSize(1) - allCropCoords(iFile,1) + 1]);
            yJit = round(cropJitSD*randn);
            yJit = max([yJit,-allCropCoords(iFile,2) + 1]);
            yJit = min([yJit,240 - cropSize(2) - allCropCoords(iFile,2) + 1]);
            iOut = randi(2);
            tempCoords = [allCropCoords(iFile,2) + yJit,allCropCoords(iFile,2) + yJit + cropSize(2) - 1,allCropCoords(iFile,1) + xJit,allCropCoords(iFile,1) + xJit + cropSize(1) - 1];
            tempRef = double(allRefImages{iFile,1}(tempCoords(1):tempCoords(2),tempCoords(3):tempCoords(4),randi(nRefImages)));
            tempNew = double(allRawImages{iFile,iCat,iOut}(tempCoords(1):tempCoords(2),tempCoords(3):tempCoords(4),randi(nImgs(iOut))));
            imgTemp(:,:,iImg) = uint8(abs(tempRef - tempNew));
        end
        allSubImages{iFile,iCat} = imgTemp;
    end
end

%% Save images

% Make the directories, if necessary
mkdir(imgDir)
mkdir([imgDir,filesep,'training_set',filesep,'lick'])
mkdir([imgDir,filesep,'training_set',filesep,'no_lick'])
mkdir([imgDir,filesep,'test_set',filesep,'lick'])
mkdir([imgDir,filesep,'test_set',filesep,'no_lick'])

imgCount = ones([2,2]);
for iFile = 1:length(filenames)
    for iCat = 1:2
        for iImg = 1:nImPerAnim
            if (iImg/nImPerAnim) <= trainingProp
                if iCat == 1
                    imwrite(uint8(repmat(allSubImages{iFile,iCat}(:,:,iImg),[1,1,3])),[imgDir,filesep,'training_set',filesep,'no_lick',filesep,'img',num2str(imgCount(iCat,1),'%05d'),'.png'])
                elseif iCat == 2
                    imwrite(uint8(repmat(allSubImages{iFile,iCat}(:,:,iImg),[1,1,3])),[imgDir,filesep,'training_set',filesep,'lick',filesep,'img',num2str(imgCount(iCat,1),'%05d'),'.png'])
                end
                imgCount(iCat,1) = imgCount(iCat,1) + 1;
            else
                if iCat == 1
                    imwrite(uint8(repmat(allSubImages{iFile,iCat}(:,:,iImg),[1,1,3])),[imgDir,filesep,'test_set',filesep,'no_lick',filesep,'img',num2str(imgCount(iCat,2),'%05d'),'.png'])
                elseif iCat == 2
                    imwrite(uint8(repmat(allSubImages{iFile,iCat}(:,:,iImg),[1,1,3])),[imgDir,filesep,'test_set',filesep,'lick',filesep,'img',num2str(imgCount(iCat,2),'%05d'),'.png'])
                end
                imgCount(iCat,2) = imgCount(iCat,2) + 1;
            end
        end
    end
end


