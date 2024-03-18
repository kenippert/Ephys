% rigParamsGen
%
%   rigParamsGen generates a file that contains parameters for the various
%   devices connected to a given rig.

% Set the rig number
rig = 1;

rigParams = struct;

%% Rig 1

if rig == 1
 
    % The camera device ID
    rigParams.VideoID = 4;
   
    % Pump COM port
    rigParams.COM_Pump = 3;

    %HiFi module COM port
    rigParams.COM_HiFi1 = 6;
 
end

save('C:\Users\Bpod\Documents\Bpod Local\rigParams.mat','rigParams')