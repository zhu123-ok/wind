function experiment=main_lmocso(config)
% MAIN_LMOCSO Local continuous-layout comparison with an independent folder.
% Default: 00.xml, 400 turbines, one seed, 10,000 FE per algorithm.
if nargin<1, config=struct(); end
here=fileparts(mfilename('fullpath')); addpath(here);
if ~isfield(config,'algorithms'), config.algorithms={'NSGA2','CCGDE3','LMOCSO'}; end
if ~isfield(config,'nRuns'), config.nRuns=1; end
if ~isfield(config,'nTurbines'), config.nTurbines=400; end
if ~isfield(config,'options'), config.options=struct(); end
if ~isfield(config.options,'popSize'), config.options.popSize=100; end
if ~isfield(config.options,'maxFE'), config.options.maxFE=10000; end
if ~isfield(config,'outputDirectory')
    config.outputDirectory=fullfile(here,'results_continuous_lmocso');
end
experiment=run_experiments_continuous(config);
end
