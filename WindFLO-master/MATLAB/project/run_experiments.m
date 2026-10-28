function experiment = run_experiments(config)
% RUN_EXPERIMENTS 使用相同评价预算多次独立比较 CCGDE3 和 NSGA-II。
% 结果保存为 MAT、CSV 和 JSON，方便后续画图和统计分析。

config = fill_defaults(config);
here = fileparts(mfilename('fullpath'));
if ~isfield(config,'scenarioFile')
    config.scenarioFile = fullfile(here,'..','..','Scenarios','00.xml');
end
model = windflo_model(config.scenarioFile,config.nTurbines);
candidates = windflo_make_candidates(model,config.candidateCount);
baseProblem = windflo_prepare_problem(model,candidates,false);
algorithms = {'CCGDE3','NSGA2'};
recordTemplate = struct('algorithm','','run',0,'seed',0,'timeSeconds',0, ...
    'output',[],'HV',nan,'IGD',nan,'Spacing',nan,'convergenceHV',[]);
records = repmat(recordTemplate,length(algorithms)*config.nRuns,1);
recordIndex = 0;
frontParts = cell(length(algorithms)*config.nRuns,1);

for a = 1:length(algorithms)
    for r = 1:config.nRuns
        seed = config.seed+r-1;
        rng(seed,'twister');
        problem = baseProblem;
        problem.useCache = config.useCache;
        problem.useParallel = config.useParallel;
        if config.useCache
            problem.cache = containers.Map('KeyType','char','ValueType','any');
        end
        fprintf('\n%s run %d/%d, seed=%d\n',algorithms{a},r,config.nRuns,seed);
        t = tic;
        output = run_algorithm(algorithms{a},problem,config.options);
        elapsed = toc(t);
        rec = struct('algorithm',algorithms{a},'run',r,'seed',seed, ...
            'timeSeconds',elapsed,'output',output,'HV',nan,'IGD',nan, ...
            'Spacing',nan,'convergenceHV',[]);
        recordIndex = recordIndex+1;
        records(recordIndex) = rec;
        frontParts{recordIndex} = output.archive.fitness;
    end
end
allFronts = vertcat(frontParts{:});

% 所有算法、所有运行的非支配解共同组成经验参考前沿。
frontNo = mo_non_dominated_sort(allFronts);
referenceFront = allFronts(frontNo == 1,:);
lower = min(allFronts,[],1);
upper = max(allFronts,[],1);
for i = 1:length(records)
    m = mo_metrics(records(i).output.archive.fitness,referenceFront,lower,upper);
    records(i).HV = m.HV;
    records(i).IGD = m.IGD;
    records(i).Spacing = m.Spacing;
    h = records(i).output.history;
    records(i).convergenceHV = zeros(length(h.fronts),1);
    for j = 1:length(h.fronts)
        hm = mo_metrics(h.fronts{j},referenceFront,lower,upper);
        records(i).convergenceHV(j) = hm.HV;
    end
end

summary = summarize(records,algorithms);
experiment = struct('config',config,'model',model,'candidates',candidates, ...
    'records',records,'referenceFront',referenceFront,'summary',summary);

if ~exist(config.outputDirectory,'dir'), mkdir(config.outputDirectory); end
save(fullfile(config.outputDirectory,'experiment.mat'),'experiment','-v7.3');
writetable(struct2table(summary),fullfile(config.outputDirectory,'summary.csv'));
write_json_summary(experiment,fullfile(config.outputDirectory,'summary.json'));
disp(struct2table(summary));
end

function summary = summarize(records,algorithms)
template = struct('algorithm','','HV_mean',0,'HV_std',0,'IGD_mean',0, ...
    'IGD_std',0,'Spacing_mean',0,'Spacing_std',0,'time_mean_s',0, ...
    'archive_mean',0);
summary = repmat(template,length(algorithms),1);
for a = 1:length(algorithms)
    ids = strcmp({records.algorithm},algorithms{a});
    hv = [records(ids).HV]; igd = [records(ids).IGD];
    spacing = [records(ids).Spacing]; times = [records(ids).timeSeconds];
    outputs = {records(ids).output};
    archiveSizes = cellfun(@(x)size(x.archive.fitness,1),outputs);
    summary(a) = struct('algorithm',algorithms{a}, ...
        'HV_mean',mean(hv),'HV_std',std(hv), ...
        'IGD_mean',mean(igd),'IGD_std',std(igd), ...
        'Spacing_mean',mean(spacing),'Spacing_std',std(spacing), ...
        'time_mean_s',mean(times),'archive_mean',mean(archiveSizes));
end
end

function write_json_summary(experiment,fileName)
runTemplate = struct('algorithm','','run',0,'seed',0,'timeSeconds',0, ...
    'HV',0,'IGD',0,'Spacing',0,'objectives',[],'layouts',{{}}, ...
    'convergenceFE',[],'convergenceHV',[]);
runs = repmat(runTemplate,length(experiment.records),1);
s = struct('config',experiment.config,'summary',experiment.summary, ...
    'referenceFront',experiment.referenceFront,'runs',runs);
for i = 1:length(experiment.records)
    r = experiment.records(i);
    s.runs(i) = struct('algorithm',r.algorithm,'run',r.run,'seed',r.seed, ...
        'timeSeconds',r.timeSeconds,'HV',r.HV,'IGD',r.IGD, ...
        'Spacing',r.Spacing,'objectives',r.output.archive.fitness, ...
        'layouts',{r.output.archive.layouts}, ...
        'convergenceFE',r.output.history.evaluations, ...
        'convergenceHV',r.convergenceHV);
end
fid = fopen(fileName,'w');
if fid < 0, error('无法写入 %s',fileName); end
clean = onCleanup(@()fclose(fid));
fwrite(fid,jsonencode(s),'char');
end

function config = fill_defaults(config)
if nargin == 0 || isempty(config), config = struct(); end
config = set_default(config,'nTurbines',100);
config = set_default(config,'candidateCount',1200);
config = set_default(config,'nRuns',5);
config = set_default(config,'seed',1);
config = set_default(config,'useCache',true);
config = set_default(config,'useParallel',false);
config = set_default(config,'outputDirectory',fullfile(pwd,'results_large_scale'));
if ~isfield(config,'options'), config.options = struct(); end
config.options = set_default(config.options,'popSize',80);
config.options = set_default(config.options,'maxFE',10000);
config.options = set_default(config.options,'archiveSize',100);
config.options = set_default(config.options,'verbose',true);
end

function s = set_default(s,name,value)
if ~isfield(s,name), s.(name) = value; end
end
