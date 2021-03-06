function [results] = do_registration(input_dir, output_dir, varargin)


% Parse input arguments
p = inputParser;
p.addParamValue('ModelMode',     'global', @(x)strcmpi(x,'global') || strcmpi(x,'previous'));
p.addParamValue('MaxCloudSize',  1e4, @(x)isnumeric(x));
p.addParamValue('MaxFrames',  inf, @(x)isnumeric(x));
p.addParamValue('StartPosition', [0 0 0], @(x)isnumeric(x) && numel(x) == 3);
p.addParamValue('StartOrientation', [1 0 0 0], @(x)isnumeric(x) && numel(x) == 4);
p.addParamValue('FrameSkip', 1, @(x)isnumeric(x));
p.addParamValue('GICPArgs', {});
p.parse(varargin{:});

modelmode = p.Results.ModelMode;
cloudsize = p.Results.MaxCloudSize;
gicpargs = p.Results.GICPArgs;
maxframes = p.Results.MaxFrames;
frameskip = p.Results.FrameSkip;

mkdir(output_dir);
mkdir(fullfile(output_dir,'frames'));

pcs = PointCloudSet(input_dir);

%Write the first frame with the initial pose.
qt = [p.Results.StartOrientation p.Results.StartPosition];
T = eye(4);

model = pcs{1};
model.subsample(cloudsize);
model.apply_qt(qt); 
model.write(fullfile(output_dir,'frames','frame1.ply'));

results.avg_mse = 0.0;
results.mse_profile{1} = [];
results.num_iter(1) = 0;
results.transformations{1} = qt;
results.pose{1} = qt;
results.timestamp{1} = model.timestamp;

ii = 2:frameskip:min(pcs.num_frames, maxframes);
for j = 1:numel(ii)
    i = ii(j);
    fprintf('\n=== ALIGNING FRAME %i ===\n\n', i);
        
    % Load up a new frame
    frame = pcs.cloud{i};
    frame.subsample(cloudsize);
    frame.apply_matrix(T);
    
    % Call the ICP method and save the results.
    [dqt mse_profile] = gicp(frame, model, gicpargs{:});
    qt = rigid_multiply(dqt, qt);
    dT = [quat2dcm(dqt(1:4))' dqt(5:7)'; 0 0 0 1];
    T = dT * T;
    
    % Write the new frame
    frame.apply_matrix(dT);
    frame.write(fullfile(output_dir, 'frames', sprintf('frame%d.ply',i)));
    
    results.avg_mse = results.avg_mse + mse_profile(end);
    results.mse_profile{j} = mse_profile;
    results.num_iter(j) = numel(mse_profile);
    results.transformations{j} = dqt;
    results.pose{j} = qt;
    results.timestamp{j} = frame.timestamp;
    
    % Update the model
    if strcmpi(modelmode, 'global')
        model = [model frame]; %#ok<AGROW>
    else
        model = frame;
    end
    model.subsample(cloudsize);
end

results.avg_mse = results.avg_mse / (pcs.num_frames-1);

save(fullfile(output_dir, 'results_latest.mat'), 'results');
write_trajectory(results, fullfile(output_dir, 'trajectory.txt'));

clear('icp');


