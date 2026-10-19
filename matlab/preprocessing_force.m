%% Preprocessing 
clear; clc; close all;


% Selection of the folder
fprintf('Select the folder of you data (LC_...)\n');
input_folder = uigetdir('', 'Select M1 or M2');

if input_folder == 0
    error('error: ');
end

% Define the destination folder
output_folder = fullfile(input_folder, 'Normalized_Force_for_LabVIEW');
if ~exist(output_folder, 'dir')
    mkdir(output_folder);
end

% Finde all the file in the folder
file_list = dir(fullfile(input_folder, 'LC_*.txt'));
num_files = length(file_list);

if num_files == 0
    error('No LC_*.txt file in the selected folder! Try again');
end

fprintf('%d file.Phase 1: Calculate Global Max/Min...\n', num_files);

% Parameters
fs = 1000;
fc = 5; 
Wn = fc / (fs/2); 
[b, a] = butter(2, Wn, 'low'); 

% Variables for the global normalization
F_min_globale = inf;
F_max_globale = -inf;

% Cell Array to memorize the data 
stored_Fz_filtered = cell(num_files, 1);
stored_X = cell(num_files, 1);
stored_Y = cell(num_files, 1);

%% Phase 1: Filter and research of global min and max
for i = 1:num_files
    filename = file_list(i).name;
    % Carica il file usando il percorso completo
    full_input_path = fullfile(input_folder, filename);
    data = load(full_input_path);
    
    Fz_raw = data(:, 4); 
    stored_X{i} = data(:, 8); 
    stored_Y{i} = data(:, 9); 
    
    num_samples = length(Fz_raw);
    
    % A. Zeroing 
    num_baseline_samples = 50;
    if num_samples < num_baseline_samples
        num_baseline_samples = floor(num_samples/10);
    end
    baseline_mean = mean(Fz_raw(1:num_baseline_samples));
    Fz_zeroed = Fz_raw - baseline_mean;
    
    % B. Absolute value
    Fz_abs = abs(Fz_zeroed);
    
    % C. Low-pass filter
    Fz_filtered = filtfilt(b, a, Fz_abs); 
    
   
    stored_Fz_filtered{i} = Fz_filtered;
    
    % Max and min of the specific file
    current_min = min(Fz_filtered);
    current_max = max(Fz_filtered);
    
    % Update the global max and min if necessary
    if current_min < F_min_globale
        F_min_globale = current_min;
    end
    if current_max > F_max_globale
        F_max_globale = current_max;
    end
end

fprintf('Phase 1 completed.\n');
fprintf('  -> Minimum global force: %.4f N\n', F_min_globale);
fprintf('  -> Maximum global force: %.4f N\n\n', F_max_globale);

if F_max_globale == F_min_globale 
    F_max_globale = F_min_globale + 1e-6; 
end

%% Phase 2: Global normalization
fprintf('Phase 2: Normalization and export...\n');
for i = 1:num_files
    filename = file_list(i).name;
    
    Fz_filtered = stored_Fz_filtered{i};
    X_pos = stored_X{i};
    Y_pos = stored_Y{i};
    
    % D. Global normalization(0 - 1)
    Fz_norm = (Fz_filtered - F_min_globale) / (F_max_globale - F_min_globale);
    
    % Matrix: [ Norm. Force, X, Y]
    output_data = [Fz_norm, X_pos, Y_pos];
    
    % Save in the subfolder of the phantom
    new_filename = fullfile(output_folder, ['Norm_', filename]);
    
    writematrix(output_data, new_filename, 'Delimiter', ',');
end
fprintf('Finish! %d The normalized file are in:\n "%s"\n', num_files, output_folder);