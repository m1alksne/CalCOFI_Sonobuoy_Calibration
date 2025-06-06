
% Script to estimate calibrated call recieved levels from Sonobuoy
% Need to know which type of Sonobuoy was being used. DIFAR or OMNI? 
% 53G, 53D, or 57A? 
clear all;
close all;
%% define paths:
calibration_specs = load('L:\CalCOFI\CalCOFI_Sonobuoy\Acoustic_density_estimation\CalCOFI_Sonobuoy_Calibration\Sonobuoy_calibration_specs.mat');
detections_dir = 'L:\WhaleMoanDetector_predictions\analysis\predictions_context_filtered\new_context_filter\RL_calculated\CalCOFI_2025_01_raw_detections_context_filtered.txt';
wav_dir = 'O:\CC2501RL\CC2501RL_Sonobuoy_Recordings\OMNI';
%% Define Sonobuoy type:
buoy_type = 'OMNI';   % 'OMNI or 'DIFAR'
model_type = 'i53G';  % 'i53G','i53D', or 'i57A'
%% Plot calibrated RLs?
plot_RL_hist = true;
%% Load detections 
detections = readtable(detections_dir); 
wav_files = dir(fullfile(wav_dir, '**', '*.wav'));
%% extract Sonobuoy type and wav files names with detections
% Access the loaded struct (from Sonobuoy_calibration_specs.mat)
cal = calibration_specs.(buoy_type);
% Pull core calibration constants
volts = cal.volts;
ICOM = cal.ICOM;
S = cal.(model_type).SB_sensitivity;
% Pull frequency response curve
f = cal.(model_type).f;
f_dB = cal.(model_type).response_dB;
% Extract unique wav file names from detections
[~, detected_wav_names, ~] = cellfun(@fileparts, detections.wav_file_path, 'UniformOutput', false);
detected_wav_names = unique(detected_wav_names); % Get unique names
wav_names = erase({wav_files.name}, '.wav'); % Remove .wav extensions
valid_indices = ismember(wav_names, detected_wav_names); % Find matches
filtered_wav_files = wav_files(valid_indices); % Keep only matching files

%% Compute calibrated RL

% loop through unique wav files. inner loop through each detection in a
% given wav file. 

% Loop through each .wav file
for i = 1:length(filtered_wav_files)
    wav_path = fullfile(filtered_wav_files(i).folder, filtered_wav_files(i).name); % Full path to the WAV file
    [~, this_wav_name, ~] = fileparts(wav_path);
    
    % Read in the audio file
    [x, fs] = audioread(wav_path, 'Native');
    x = double(x);
    audio_info = audioinfo(wav_path);
    %disp(audio_info.BitsPerSample)
    %BitDepth = 2^(audio_info.BitsPerSample); 
    BitDepth = 2^32;
    V = 20*log10(volts/BitDepth);
    
    % Find detections corresponding to this wav file
    detection_idx = find(contains(detections.wav_file_path, this_wav_name));
    % Loop through detections in this file
    for j = 1:length(detection_idx)
        idx = detection_idx(j); % Get row index in detection table
        
        % Extract time range for detection
        start_time_sec = detections.start_time_sec(idx);
        end_time_sec = detections.end_time_sec(idx);
        call_duration = end_time_sec - start_time_sec;
        
        if call_duration < 1 % can't compute fft if window less than fft
            % Calculate how much time is needed to reach 1 second
            time_to_add = 1 - call_duration; % Total time that needs to be added
            %Split the time to add evenly between the start and end times
            half_time_to_add = time_to_add / 2;
            % Adjust the start and end times
            start_time_sec = start_time_sec - half_time_to_add;
            end_time_sec = end_time_sec + half_time_to_add;
            
            % Clamp to zero if needed
            if start_time_sec < 0
                end_time_sec = end_time_sec + abs(start_time_sec);  % Shift forward to preserve duration
                start_time_sec = 0;
            end
        end
        
        % Convert time to sample indices
        start_sample = max(1, round(start_time_sec * fs));
        end_sample = min(length(x), round(end_time_sec * fs));
        
        % Extract signal segment
        signal_segment = x(start_sample:end_sample);
 
        [Pxx, F] = pwelch(signal_segment, hamming(fs), round(fs*0.9), fs, fs);
        
        %convert to dB 
        Pxx_dB = 10*log10(Pxx);

        freq_indices = find(F >= detections.min_frequency(idx) & F <= detections.max_frequency(idx));
        
        Pxx_cal_dB = Pxx_dB(freq_indices) - f_dB(freq_indices);  % subtract gain in dB
        % convert back to linear for integration
        Pxx_cal_lin = 10.^(Pxx_cal_dB / 10);  % now in �Pa�/Hz
        
        SPL_lin = trapz(F(freq_indices), Pxx_cal_lin);  % �Pa�
        
        %PSD = Pxx_cal_dB - 10*log10((detections.max_frequency(idx) - detections.min_frequency(idx)));
        
        %SPL_rms = sqrt(SPL_lin); % can do it either way and you get the same thing. so its uPa either way. 
        
        %SPL = 20*log10(SPL_rms);
        % convert back to dB
        SPL = 10*log10(SPL_lin);
        SPL_calibrated = SPL + V + S + ICOM; % apply additional calibrations
        detections.SPL_calibrated_dB(idx) = SPL_calibrated; 
        %detections.PSD_calibrated_dB(idx) = PSD + V + S + ICOM; %calibrated pressure spectral density

    end
    
end 


%save out table with calibrated SPL
writetable(detections, fullfile(detections_dir));

if plot_RL_hist == true
    % Assuming detections is a table or structure with fields as described
    callTypes = {'A', 'B', 'D', '20Hz', '40Hz'}; % Ensure these match your data
    colors = {'#481567', '#5F3C9E', '#8C2981', '#F46D43', '#F9A639'};
    colorMap = containers.Map(callTypes, colors);
    
    % Extracting data
    labels = detections.label; % or detections.label{:} if labels are in a cell array
    SPL_levels = detections.SPL_calibrated_dB;
    
    % Create histograms
    for n = 1:length(callTypes)
        figure; % Create a new figure for each call type
        sgtitle(['Calibrated Sound Pressure Levels for Call Type ', callTypes{n}]); % Title for the whole figure
        
        % Filter data for each call type
        indices = strcmp(labels, callTypes{n});
        
        % Histogram for SPL Received Levels
        histogram(SPL_levels(indices), 'FaceColor', colorMap(callTypes{n}), 'EdgeColor', 'k', 'NumBins', 10, 'FaceAlpha', 0.5);
        xlabel('Received Level (dB re 1 uPa)');
        %xlim([130, 175]);  % Set x-axis limits
        ylabel('Frequency');
       
    end
end


