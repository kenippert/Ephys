function FreeAccess5
% FreeAccess1 is a new task protocol. The task is very simple.
% Periodically, a droplet of fluid is dispensed onto the tip of sipper. If
% it is licked off, a new droplet is added. If, after a certain amount of
% time, the droplet hasn't been licked, it is suctioned off and a new
% droplet is added. The wheel will be locked and wheel turns will not be
% recorded. There will be no visual stimuli. 
% New to version 2, there is an auditory CS that plays right before the
% droplet is dispensed. The valves have been moved out of the rig to
% control for valve sounds.
% New to version 4 relative to version 2 is that the IR lickometery has
% been replaced with machine vision. Also, fluid is now delivered with a
% syringe pump.
% New to version 5 relative to version 4 is switching from drop detection
% to lick detection via machine vision.
global BpodSystem

%% Setup (runs once before the first trial)

%--- Define parameters and trial structure
global S
S = BpodSystem.ProtocolSettings; % Loads settings file chosen in launch manager into current workspace as a struct called 'S'
if isempty(fieldnames(S))  % If chosen settings file was an empty struct, populate struct with default settings
    % Define default settings here as fields of S (i.e S.InitialDelay = 3.2)
    % Note: Any parameters in S.GUI will be shown in UI edit boxes. 
    % See ParameterGUI plugin documentation to show parameters as other UI types (listboxes, checkboxes, buttons, text)
    
    
    % Set the name of the softcode handler function
    S.SoftCodeHandlerFunctionName = 'FreeAccess5SoftCodeHandler';
    
    % Load the rig parameter files
    load('C:\SanworksBPod\Bpod Local\rigParams.mat','rigParams')
    
    % COM Ports
    S.COM_Rot = rigParams.COM_Rot; % Rotary Encoder
    S.COM_F2TTL = rigParams.COM_F2TTL; % Frame2TTL sensor 
    
    % The microphone device ID
    S.MicID = rigParams.MicID;
    
    % The camera device ID
    S.VideoID = rigParams.VideoID;
    
    % Speaker device ID
    S.SpeakerID = rigParams.SpeakerID;
    
    % Screen device ID
    S.ScreenID = rigParams.ScreenID;
    
    % Set the number of licks within consumption window to count as a drink
    % trial
    S.LickThreshold = 3;
    
    % Set the pretrial delay period in seconds.
    S.PretrialDelayTime = 0.5;
    
    % Set the delay in seconds after reward delivery to accept reward
    % consumptions. Note, this should be at least the length of the CS,
    % which is 4 seconds.
    S.PostRewardDelay = 15;
    
    % Set the post-consumption delay in seconds. This is the time after licking that
    % will be allowed for further licking before suction is applied to
    % remove any unconsumed drop.
    S.PostConsumptionDelay = 4;
    
    % Set the sipper clear time in seconds. This is the amount of time that suction
    % will be applied to remove any excess drops.
    S.SipperClearTime = 1;
    
    % Audio stimulus parameters
        % First column: Sound ID (1: white noise, 2: pure tone, 3: tone ramp)
        % Second column: parameters
            % White Noise: [Duration (sec), Sampling Frequency (Hz), Volume]
            % Pure Tone: [Duration (sec), Sampling Frequency (Hz), Volume, Tone
                % Frequency (Hz)]
            % Tone Ramp: [Duration (sec), Sampling Frequency (Hz), Volume, Starting
                % Tone Frequency (Hz), Ending Tone Frequency (Hz)]
        % Each row is a unique audio stimulus.
        % Volume is on the range of 0 (no sound) to 1 (maximum).
    S.AudioParams = {1,[1,192000,0.1];
        2,[1,48000,0.1,1000];...
        3,[1,48000,0.1,500,1500];...
        2,[1,48000,0.02,5000];...
        3,[1,48000,0.1,9000,11000]};
    
    % Select the audio stimuli to use for the CSs
    S.AudioSelections = 4; % Currently just the CS
    
    
end

%--- Initialize plots and start USB connections to any modules
% BpodParameterGUI('init', S); % Initialize parameter GUI plugin

% Identify the soft code handler function for the Bpod
BpodSystem.SoftCodeHandlerFunction = S.SoftCodeHandlerFunctionName; % Provide the name of the soft code handler function

% Make a directory to hold non-state machine data files
mkdir([BpodSystem.Path.CurrentDataFile(1:(end - 4)),'AdditionalData']);
mkdir([BpodSystem.Path.CurrentDataFile(1:(end - 4)),'Video']);
dataDir = [BpodSystem.Path.CurrentDataFile(1:(end - 4)),'AdditionalData',filesep];
videoDir = [BpodSystem.Path.CurrentDataFile(1:(end - 4)),'Video'];

% Obtain information from the user
prompt = {'Time Limit (Minutes):','Alcohol Concentration (Percent):','Drop Volume (uL):',...
    'Pump Volume Setting (uL):','Animal Weight (Grams):','Liquid Density (g/mL):','Estimate of Fluid Left in Tube (g):'};
dlgtitle = 'Set Calibration Parameters';
definput = {'30','20','4','','','0.97','0'};
dims = [1 60];
answer = inputdlg(prompt,dlgtitle,dims,definput);
timeLimit = str2double(answer{1});
alcCon = str2double(answer{2});
S.alcCon = alcCon;
dropVol = str2double(answer{3});
S.dropVol = dropVol;
S.pumpVolSetting = str2double(answer{4});
animWeight = str2double(answer{5});
S.animWeight = animWeight;
doseConv = (dropVol/1000)*0.789*(alcCon/100)/(animWeight/1000);
S.liqDensity = str2double(answer{6});
S.lossWeight = str2double(answer{7});

% Tell the user to confirm the suction system is ready
f = msgbox('Confirm the suction reservoir is empty and the suction valve is open.');
uiwait(f)

% Perform sipper alignment
sipperAlignmentTool
save([dataDir,'SipperAlignmentImages.mat'],'targetSipAlignIm','actualSipAlignIm')
imwrite(targetSipAlignIm,[dataDir,'targetSipperAlignmentImage.png'])
imwrite(actualSipAlignIm,[dataDir,'actualSipperAlignmentImage.png'])
close gcf

% Tell the user to start the openMV
f = msgbox(['Please start the openMV machine vision.',newline,newline,...
    'Follow these steps:',newline,...
    'Open OpenMV IDE.',newline,...
    'The necessary script should already be loaded (alignmentTool.py and lickClassVer1.py).',newline,...
    'Connect to the camera with the button in the lower left corner.',newline,...
    'With alignmentTool up, press the green play arrow. Make sure the mouse'' jaw is centered in the image.',newline,...
    'If necessary, stop the script and adjust the frame bounds on line 17.',newline,...
    'NOTE: ONLY CHANGE THE FIRST TWO NUMBERS (x-coord, y-coord).',newline,...
    'Stop alignmentTool, copy and changed frame coordinates to lickClassVer1 line 15, and press play.']);
uiwait(f)

% Tell the user to start the video recording.
f = msgbox(['Please start the video recording in FlyCapture2.',newline,newline,...
    'Follow these steps to start video recording.',newline,...
    'Open FlyCapture2.',newline,...
    'Click OK.',newline,...
    'Click File -> Capture Image or Video Sequence.',newline,...
    'The video filename should be ',videoDir,'\video.',newline,...
    'Recording mode should be set to Buffered.',newline,...
    'Click the videos tab, video recording type should be M-JPEG.',newline,...
    'Click use camera frame rate.',newline,...
    'Set AVI split size to 100.',newline,...
    'Set JPEG compression quality to 50%.']);
uiwait(f)

% Create sounds
InitializePsychSound % Initialize port audio
MyWaveforms = cell([size(S.AudioParams,1),1]);
for iSound = 1:size(S.AudioParams,1)
    if S.AudioParams{iSound,1} == 1
        % White Noise
        MyWaveforms{iSound} = S.AudioParams{iSound,2}(3)*[(2*rand([1,S.AudioParams{iSound,2}(1)*S.AudioParams{iSound,2}(2)])) - 1;zeros([1,S.AudioParams{iSound,2}(1)*S.AudioParams{iSound,2}(2)])]; % Create waveform
        MyWaveforms{iSound}(2,1:round(S.AudioParams{iSound,2}(2)/1000)) = 1; % For sync signal
    elseif S.AudioParams{iSound,1} == 2
        % Pure Tone
        MyWaveforms{iSound} = S.AudioParams{iSound,2}(3)*[sin((2*pi*S.AudioParams{iSound,2}(4))*((1/S.AudioParams{iSound,2}(2)):(1/S.AudioParams{iSound,2}(2)):S.AudioParams{iSound,2}(1)));zeros([1,S.AudioParams{iSound,2}(1)*S.AudioParams{iSound,2}(2)])]; % Create waveform
        MyWaveforms{iSound}(2,1:round(S.AudioParams{iSound,2}(2)/1000)) = 1; % For sync signal
    elseif S.AudioParams{iSound,1} == 3
        % Tone Ramp
        MyWaveforms{iSound} = S.AudioParams{iSound,2}(3)*[sin((2*pi*linspace(S.AudioParams{iSound,2}(4),S.AudioParams{iSound,2}(5),S.AudioParams{iSound,2}(1)*S.AudioParams{iSound,2}(2))).*((1/S.AudioParams{iSound,2}(2)):(1/S.AudioParams{iSound,2}(2)):S.AudioParams{iSound,2}(1)));zeros([1,S.AudioParams{iSound,2}(1)*S.AudioParams{iSound,2}(2)])]; % Create waveform
        MyWaveforms{iSound}(2,1:round(S.AudioParams{iSound,2}(2)/1000)) = 1; % For sync signal
    end
end
pahandleMaster = PsychPortAudio('Open',S.SpeakerID,9,1,48000,2); % Open the master sound device
PsychPortAudio('Start', pahandleMaster, 0, 0, 1); % Start the master sound device
for iSound = 1:length(S.AudioSelections)
    eval(['global pahandleS',num2str(iSound)]);
    eval(['pahandleS',num2str(iSound),' = PsychPortAudio(''OpenSlave'', pahandleMaster,1,2,[1,2]);']); % Open slave sound device for this sound
    eval(['PsychPortAudio(''FillBuffer'', pahandleS',num2str(iSound),', MyWaveforms{S.AudioSelections(iSound)});']); % Put sound in the slave device
end

%Initialize pump on COM port
global pump
pump = serial(['COM',num2str(rigParams.COM_Pump)]);
%Set all values in order to read values correctly
set(pump, 'Timeout', 60);
set(pump,'BaudRate', 9600);
set(pump, 'Parity', 'none');
set(pump, 'DataBits', 8);
set(pump, 'StopBits', 1);
set(pump, 'RequestToSend', 'off');
%Open pump data stream
fopen(pump);


%% Prompt the user to proceed

disp(' ')
disp(' ')
input('The protocol is ready to run. Press any key when you are ready to start the protocol.','s');
tOverall = tic;

%% Prepare figures

f = figure;
f.Position = [0,60,490,545];

% Prepare plot of trial performance (drink (1) or skip (0))
subplot(3,1,1)
h1Axes = gca; 
ylim(h1Axes,[-0.1,1.1]); 
xlim(h1Axes,[0,1]);
xlabel(h1Axes,'Trials'); ylabel(h1Axes,'1: Drink, 0: Skip'); title(h1Axes,'Trial Performance')
trialPerformance = NaN([1,2000]);

% Prepare plot of number of drops consumed
subplot(3,1,2) 
h2Axes = gca; 
ylim(h2Axes,[-0.1,1.1]); 
xlim(h2Axes,[0,1]);
xlabel(h2Axes,'Trials'); ylabel(h2Axes,'Number of Drops'); title(h2Axes,['Number of Drops Consumed (',num2str(dropVol),' uL)'])
nDropsCons = NaN([1,2000]);

% Prepare plot of dose consumed
subplot(3,1,3)
h3Axes = gca; 
ylim(h3Axes,[-0.1,1.1]); 
xlim(h3Axes,[0,1]);
xlabel(h3Axes,'Time (min)'); ylabel(h3Axes,'Dose (g/kg)'); title(h3Axes,'Dose Consumed')
dose = NaN([2,2000]);

%% Main loop (runs once per trial)
currentTrial = 1;
while ((toc(tOverall)/60) < timeLimit)
    
    %--- Typically, a block of code here will compute variables for assembling this trial's state machine
    
    disp(['Starting trial ',num2str(currentTrial),'.'])
    disp(['There are about ',num2str(timeLimit - (toc(tOverall)/60),3),' minutes left in this session.'])
    disp('Starting pre-trial dead time.')
    
    tLocal = tic;
    
    %--- Assemble state machine    
    sma = NewStateMachine();
    
    % Set lick counter
    sma = SetGlobalCounter(sma, 1, 'BNC1High', S.LickThreshold); % Arguments: (sma, CounterNumber, TargetEvent, Threshold)
    
    % State 1
    % - Impose a brief pretrial delay, turn on IR LED to sync video
    sma = AddState(sma, 'Name', 'PretrialDelay', ...
        'Timer', S.PretrialDelayTime,...
        'StateChangeConditions', {'Tup', 'PlayCS'},...
        'OutputActions', {'PWM2',255});
    
    % State 2
    % - Play CS
    sma = AddState(sma, 'Name', 'PlayCS', ...
        'Timer', S.AudioParams{S.AudioSelections(1),2}(1),...
        'StateChangeConditions', {'Tup', 'OpenFluidValve'},...
        'OutputActions', {'SoftCode', 1});
    
    % State 3
    % - Open the valve to deliver fluid
    sma = AddState(sma, 'Name', 'OpenFluidValve', ...
        'Timer', 0.1,...
        'StateChangeConditions', {'Tup', 'PostRewardDelay'},...
        'OutputActions', {'SoftCode', 2});
    
    % State 4
        % - Impose a delay to allow for consumption
        sma = AddState(sma, 'Name', 'PostRewardDelay', ...
            'Timer', S.PostRewardDelay,...
            'StateChangeConditions', {'Tup', 'ClearSipper', 'GlobalCounter1_End', 'PostConsumptionDelay'},...
            'OutputActions', {});
    
    % State 5
        % - Impose a post-consumption delay
        sma = AddState(sma, 'Name', 'PostConsumptionDelay', ...
            'Timer', S.PostConsumptionDelay,...
            'StateChangeConditions', {'Tup', 'ClearSipper'},...
            'OutputActions', {});
    
    % State 6
        % - Clear the sipper by suctioning off any fluid
        sma = AddState(sma, 'Name', 'ClearSipper', ...
            'Timer', S.SipperClearTime,...
            'StateChangeConditions', {'Tup', 'exit'},...
            'OutputActions', {'Valve2',1});
    
    
    SendStateMatrix(sma); % Send state machine to the Bpod state machine device
    
    disp(['Finished pre-trial dead time. It took ',num2str(toc(tLocal)),' seconds. Starting trial now.'])
    
    RawEvents = RunStateMatrix; % Run the trial and return events
    RawEvents
    
    
    %--- Package and save the trial's data, update plots
    if ~isempty(fieldnames(RawEvents)) % If you didn't stop the session manually mid-trial
        
        disp('Starting post-trial dead time.')
        
        tLocal = tic;
        BpodSystem.Data = AddTrialEvents(BpodSystem.Data,RawEvents); % Adds raw events to a human-readable data struct
        BpodSystem.Data.TrialSettings(currentTrial) = S; % Adds the settings used for the current trial to the Data struct (to be saved after the trial ends)
        SaveBpodSessionData; % Saves the field BpodSystem.Data to the current data file
        toc(tLocal)
        
        %--- Typically a block of code here will update online plots using the newly updated BpodSystem.Data
        
        % Update graph of trial performance (drink or skip)
        tLocal = tic;
        if ismember(5,RawEvents.States)
            trialPerformance(currentTrial) = 1;
        else
            trialPerformance(currentTrial) = 0;
        end
        plot(h1Axes,1:currentTrial,trialPerformance(1:currentTrial),'r-o');
        xlim(h1Axes,[0,currentTrial+1]);
        xlabel(h1Axes,'Trials'); ylabel(h1Axes,'1: Drink, 0: Skip'); title(h1Axes,'Trial Performance')
        toc(tLocal)
        
        % Update graph of number of drops consumed and graph
        tLocal = tic;
        if ismember(5,RawEvents.States)
            if currentTrial == 1
                nDropsCons(currentTrial) = 1;
            else
                nDropsCons(currentTrial) = nDropsCons(currentTrial - 1) + 1;
            end
        else
            if currentTrial == 1
                nDropsCons(currentTrial) = 0;
            else
                nDropsCons(currentTrial) = nDropsCons(currentTrial - 1);
            end
        end
        plot(h2Axes,1:currentTrial,nDropsCons(1:currentTrial),'r-o');
        xlim(h2Axes,[0,currentTrial+1]);
        ylim(h2Axes,[0,1.1*max([nDropsCons(currentTrial),1])]);
        xlabel(h2Axes,'Trials'); ylabel(h2Axes,'Number of Drops'); title(h2Axes,['Number of Drops Consumed (',num2str(dropVol),' uL)'])
        toc(tLocal)
        
        % Update graph of dose consumed
        tLocal = tic;
        dose(1,currentTrial) = toc(tOverall)/60;
        dose(2,currentTrial) = doseConv*nDropsCons(currentTrial);
        plot(h3Axes,dose(1,1:currentTrial),dose(2,1:currentTrial),'r-o');
        xlim(h3Axes,[0,1.1*dose(1,currentTrial)]);
        ylim(h3Axes,[0,1.1*max([dose(2,currentTrial),1])]);
        xlabel(h3Axes,'Time (min)'); ylabel(h3Axes,'Dose (g/kg)'); title(h3Axes,'Dose Consumed')
        toc(tLocal)
        
        disp('Finished post-trial dead time.')
        
    end
    
    %--- This final block of code is necessary for the Bpod console's pause and stop buttons to work
    HandlePauseCondition; % Checks to see if the protocol is paused. If so, waits until user resumes.
    if BpodSystem.Status.BeingUsed == 0
        return
    end
    
    % Advance the trial count
    currentTrial = currentTrial + 1;
    
end

% Save plot data
nTrialsCompleted = currentTrial - 1;
save([dataDir,'plotData.mat'],'nTrialsCompleted','trialPerformance','nDropsCons','dose')

% Tell the user to stop the video recording
f = msgbox('Stop the video recording and close FlyCapture2!');
uiwait(f)

% Tell the user to stop the openMV
f = msgbox('Stop the openMV script!');
uiwait(f)

% Ask the user if they want to retake the sipper alignment image
answer = questdlg('Do you want to retake the sipper alignment image?','Sipper Alignment','Yes','No','No');
if strcmp(answer,'Yes')
    try
        sipperAlignmentTool
        
        % Tell the user to remove the animal from the rig.
        f = msgbox('Remove the animal from the rig.');
        uiwait(f)
    catch
        f = msgbox('There was a problem with the sipper alignment tool. Skipping for now. Execute sipperAlignmentTool after the protocol ends.');
        uiwait(f)
    end
else
    % Tell the user to remove the animal from the rig.
    f = msgbox('Remove the animal from the rig.');
    uiwait(f)
end

% Ask the user to input the paper towel weights
prompt = {'Dry Paper Towel Weight (g):','Wet Paper Towel Weight (g):','Weight of Misc. Lost Fluid (g):'};
dlgtitle = 'Suction Reservoir Paper Towel Weights';
definput = {'','','0'};
dims = [1 60];
answer = inputdlg(prompt,dlgtitle,dims,definput);
dryWeight = str2double(answer{1});
wetWeight = str2double(answer{2});
miscLostWeight = str2double(answer{3});

% Calculate various measurements of consumption and loss
volDispensed = nTrialsCompleted*dropVol/1000; % Volume in mL dispensed assuming each drop was dropVol microliters
volConsumed = max(nDropsCons)*dropVol/1000; % Volume in mL consumed assuming each drop was dropVol microliters and all licked drops were totally consumed
volCollected = (wetWeight - dryWeight + S.lossWeight - miscLostWeight)/S.liqDensity; % Volume in mL dispensed, but not consumed
save([dataDir,'fluidMeasurements.mat'],'volDispensed','volConsumed','volCollected')

% Display the estimates of the amount consumed
msgbox(['Consumption (Lick Method): ',num2str(doseConv*max(nDropsCons),4),' g/kg',newline,...
    'Consumption (Fluid Lost Method): ',num2str((volDispensed - volCollected)*0.789*(alcCon/100)/(animWeight/1000),4),' g/kg']);

%Close pump I/O stream
fclose(pump);

% Stop the master sound device
PsychPortAudio('Stop', pahandleMaster);

% Close all audio devices (speakers and recordings)
PsychPortAudio('Close')


disp('Protocol has ended. Please press stop in the Bpod GUI.')





    


