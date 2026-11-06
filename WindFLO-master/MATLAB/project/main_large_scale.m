function experiment = main_large_scale()
% MAIN_LARGE_SCALE 正式的大规模三目标算法对比入口。
% 风机台数读取场景 NTurbines，默认1200维随机键，每种算法5次独立运行。

here = fileparts(mfilename('fullpath'));
addpath(here);
config = struct();
config.scenarioFile = fullfile(here,'..','..','Scenarios','00.xml');
config.nTurbines = [];                     % Read NTurbines from the scenario XML.
config.candidateCount = 1200;
config.nRuns = 5;        % 最终论文建议增加到20或30次
config.seed = 1;
config.useCache = true;
config.useParallel = false; % 有 Parallel Computing Toolbox 时可改为 true
config.outputDirectory = fullfile(here,'results_large_scale_species_v1');
config.options = struct('popSize',100,'maxFE',10000, ...
    'archiveSize',100,'numGroups',2,'regroupPeriod',0,'verbose',true);
config.options.ccgde3 = struct('subPopSize',40,'numGroups',2, ...
    'mutationFactor',0.5,'crossRate',0.5,'regroupPeriod',0);

experiment = run_experiments(config);
end
