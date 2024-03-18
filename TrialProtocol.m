function TrialProtocol   
global BpodSystem

%Initialize HiFi module
H = BpodHiFi('COM6');        %Sets up HiFi module on COM6 as an object
H.push();

S = BpodSystem.ProtocolSettings; % Load settings into current workspace as a struct called S
if isempty(fieldnames(S))  % If settings file was an empty struct, populate struct with default settings
    S.GUI.SoundDuration1 = 2; % (s)
    S.GUI.SoundDuration2 = .5;
    S.GUI.SoundDuration3 = 2;
    S.GUI.SoundDuration4 = .5;
    S.GUI.SoundFreq1 = 1000; % Frequency of cue (Hz)
    S.GUI.SoundFreq2 = 2000;
    S.GUI.SoundFreq3 = 3000;
    S.GUI.SoundFreq4 = 4000;

    S.BNChighthreshold = 1;
end

BpodSystem.SoftCodeHandlerFunction = 'FreeAccess5SoftCodeHandler';

SF = 192000; % Use max supported sampling rate
Sound1 = GenerateSineWave(SF, S.GUI.SoundFreq1, S.GUI.SoundDuration1);
Sound2 = GenerateSineWave(SF, S.GUI.SoundFreq2, S.GUI.SoundDuration2);
Sound3 = GenerateSineWave(SF, S.GUI.SoundFreq3, S.GUI.SoundDuration3);
Sound4 = GenerateSineWave(SF, S.GUI.SoundFreq4, S.GUI.SoundDuration4);
H.load(1, Sound1, loopMode =0);
H.load(2, Sound2, loopMode = 0);
H.load(3, Sound3, loopMode =0);
H.load(4, Sound4, loopMode =0);
H.SamplingRate = SF;
%% Define stimuli and send to HiFi Module
MaxTrials =500;
H.push();

% Tell the user to confirm the suction system is ready 
%box = msgbox('Confirm the suction reservoir is empty and the suction valve is open.'); 
%uiwait(box)​​ 

% Tell the user to start the openMV 

box = msgbox('Please start the openMV machine vision.'); 
uiwait(box)

global a
a=arduino();

%% Main loop (runs once per trial)
for currentTrial = 1:MaxTrials
    H.DigitalAttenuation_dB = -40;
    sma = NewStateMatrix();
  
    sma = SetGlobalCounter(sma, 1, 'BNC1High', S.BNChighthreshold); % Arguments: (sma, CounterNumber, TargetEvent, Threshold)

    sma = AddState(sma, 'Name', 'State 0', ...
        'Timer', 0.001,...
        'StateChangeConditions', {'Tup', 'Sound1'}, ...
        'OutputActions', {});

    sma= AddState(sma,'Name','Sound1',...
        'Timer', 3,...
        'StateChangeConditions', {'Tup', 'PostToneDelay'}, ...
        'OutputActions',{'HiFi1', ['P' 0], 'BNC2',1});
    
    sma = AddState(sma, 'Name', 'PostToneDelay', ...
        'Timer', 1,...
        'StateChangeConditions', {'Tup','PumpOn'}, ...
        'OutputActions',{});

    sma= AddState(sma,'Name','PumpOn',...
        'Timer', 1,...
        'StateChangeConditions', {'Tup', 'PumpOff'}, ...
        'OutputActions',{'SoftCode',1,'BNC2',1});
   
    sma= AddState(sma,'Name','PumpOff',...
        'Timer', 0.001,...
        'StateChangeConditions', {'Tup', 'Consumption Delay'}, ...
        'OutputActions',{'SoftCode',3});

    sma= AddState(sma,'Name','Consumption Delay', ...
        'Timer', 10, ...
        'StateChangeConditions', {'Tup', 'ClearSipper'},...
        'OutputActions', {});

    % sma = AddState(sma, 'Name', 'FaceDetection', ...
    %         'Timer', 10,...
    %         'StateChangeConditions', {'Tup', 'ClearSipper','GlobalCounter1_End', 'Sound3'},...
    %         'OutputActions', {});

    % sma= AddState(sma,'Name','Sound3',...
    %     'Timer', 5, ...
    %     'StateChangeConditions', {'Tup', 'ClearSipper'}, ...
    %     'OutputActions',{'HiFi1', ['P' 2]});

    % - Clear the sipper by suctioning off any fluid
    sma = AddState(sma, 'Name', 'ClearSipper', ...
       'Timer', 3 ,...
       'StateChangeConditions', {'Tup', 'Pause'},...
       'OutputActions', {'Valve1',1});

    sma = AddState(sma, 'Name', 'Pause', ...
       'Timer', 2 ,...
       'StateChangeConditions', {'Tup', 'exit'},...
       'OutputActions', {});  
    
    SendStateMachine(sma); % Send state machine to the Bpod state machine device
    RawEvents = RunStateMachine; % Run the trial and return events
    
    %--- This final block of code is necessary for the Bpod console's pause and stop buttons to work
    HandlePauseCondition; % Checks to see if the protocol is paused. If so, waits until user resumes.
    if BpodSystem.Status.BeingUsed == 0
        return
    end
end
a = [];
