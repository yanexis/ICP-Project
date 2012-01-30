function experiments()

    global DATA_PATH DROPBOX_PATH

    function results = do_one(method, frameskip, modelmode)
        fn = [method '_' num2str(frameskip) '_' modelmode];
        results = do_registration(dataset, fullfile(output_dir, fn), cs{:},...% posor{:},...
                    'MaxFrames', 500, ...
                    'ModelMode', modelmode, ...
                    'GICPArgs', {'Method', method, 'MaxIterations', 100},...
                    'FrameSkip', frameskip);
    end


    dataset = fullfile(DATA_PATH, 'rgbd_dataset_freiburg1_xyz');
    output_dir = fullfile(DROPBOX_PATH, 'results');
    cs = {'MaxCloudSize', 1e4};
    posor = {'StartPosition', [0.1170 -1.1503 1.4005], 'StartOrientation', [-0.5709 0.6523 -0.3566 0.3486]};

    do_one('icp', 1, 'global');
end