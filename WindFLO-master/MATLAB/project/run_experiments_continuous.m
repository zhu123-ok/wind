function experiment = run_experiments_continuous(config)
% RUN_EXPERIMENTS_CONTINUOUS 连续坐标实验的总调度（第 5、13、14 步）。
%
% 流程：
%   1) 读取场景，建立连续问题模板（只建一次，不启用缓存）；
%   2) CCGDE3、NSGA2 各独立运行 nRuns 次：每次设置种子、新建缓存、
%      计时并保存算法输出；
%   3) 合并全部运行的档案，取非支配第一层作为“经验参考前沿”；
%   4) 在统一归一化尺度上计算每次运行的 HV/IGD/Spacing，
%      并沿收敛历史逐点计算 HV，得到 HV 收敛曲线；
%   5) 按算法汇总均值/标准差/平均用时/平均档案规模，
%      保存 experiment.mat、summary.csv、summary.json。
%
% 公平性：两个算法使用同一场景、同一评价预算、同一组随机种子（1~5），
% 并且启用缓存时每次运行都新建缓存，避免前一次运行的结果影响后一次。
%
% 输出 experiment 的主要字段：
%   config/model/problemInfo  实验设置与问题信息
%   records                   每次运行的详细结果和指标
%   referenceFront            全部运行合并后的经验参考前沿
%   summary                   按算法汇总的表格

config = fill_defaults(config);
here = fileparts(mfilename('fullpath'));
if ~isfield(config,'scenarioFile')
    config.scenarioFile = fullfile(here,'..','..','Scenarios','00.xml');
end

% 模型和问题模板只构建一次；每次运行只替换缓存对象。
model = windflo_model(config.scenarioFile,config.nTurbines);
baseProblem = windflo_prepare_continuous_problem( ...
    model,false,config.repairOptions);

algorithms = {'CCGDE3','NSGA2'};
% 每次运行的记录模板；output 保存算法返回的完整结构（档案、历史等）。
recordTemplate = struct('algorithm','','run',0,'seed',0,'timeSeconds',0, ...
    'output',[],'HV',nan,'IGD',nan,'Spacing',nan,'convergenceHV',[]);
records = repmat(recordTemplate,length(algorithms)*config.nRuns,1);
frontParts = cell(length(records),1);   % 暂存每次运行的档案目标值
recordIndex = 0;

% ---- 第 5 步：按算法、按种子依次运行 ----
for a = 1:length(algorithms)
    for r = 1:config.nRuns
        seed = config.seed+r-1;         % 本次运行的随机种子
        rng(seed,'twister');            % 固定随机数流，保证可复现
        problem = baseProblem;          % 值拷贝问题模板
        problem.useCache = config.useCache;
        problem.useParallel = config.useParallel;
        if config.useCache
            % 每次运行新建缓存，保证运行之间相互独立。
            problem.cache = containers.Map('KeyType','char','ValueType','any');
        end
        fprintf('\n%s continuous run %d/%d, seed=%d\n', ...
            algorithms{a},r,config.nRuns,seed);
        timer = tic;
        output = run_algorithm(algorithms{a},problem,config.options);
        elapsed = toc(timer);           % 墙钟时间（秒），含评价与选择开销
        recordIndex = recordIndex+1;
        records(recordIndex) = struct('algorithm',algorithms{a}, ...
            'run',r,'seed',seed,'timeSeconds',elapsed,'output',output, ...
            'HV',nan,'IGD',nan,'Spacing',nan,'convergenceHV',[]);
        frontParts{recordIndex} = output.archive.fitness;
    end
end

% ---- 第 13 步：构造经验参考前沿并计算指标 ----
% 把所有运行的档案合并，非支配第一层即“经验参考前沿”。
% 注意：它不是解析的真实前沿，IGD 是相对于这组实验最好解的指标。
allFronts = vertcat(frontParts{:});
frontNo = mo_non_dominated_sort(allFronts);
referenceFront = allFronts(frontNo == 1,:);
% 用全部解的目标范围做归一化，保证不同运行、不同指标可比。
lower = min(allFronts,[],1);
upper = max(allFronts,[],1);
for i = 1:length(records)
    metric = mo_metrics(records(i).output.archive.fitness, ...
        referenceFront,lower,upper);
    records(i).HV = metric.HV;
    records(i).IGD = metric.IGD;
    records(i).Spacing = metric.Spacing;
    % 逐点重算 HV，形成与评价次数对应的收敛曲线。
    history = records(i).output.history;
    records(i).convergenceHV = zeros(length(history.fronts),1);
    for j = 1:length(history.fronts)
        one = mo_metrics(history.fronts{j},referenceFront,lower,upper);
        records(i).convergenceHV(j) = one.HV;
    end
end

% ---- 第 14 步：汇总并保存 ----
summary = summarize(records,algorithms);
problemInfo = struct('representation','continuous', ...
    'dimension',baseProblem.dimension,'minDistance',baseProblem.minDistance, ...
    'repairOptions',baseProblem.repairOptions);
experiment = struct('config',config,'model',model,'problemInfo',problemInfo, ...
    'records',records,'referenceFront',referenceFront,'summary',summary);

if ~exist(config.outputDirectory,'dir'), mkdir(config.outputDirectory); end
save(fullfile(config.outputDirectory,'experiment.mat'),'experiment','-v7.3');
writetable(struct2table(summary),fullfile(config.outputDirectory,'summary.csv'));
write_json_summary(experiment,fullfile(config.outputDirectory,'summary.json'));
disp(struct2table(summary));
end

function summary = summarize(records,algorithms)
% SUMMARIZE 按算法汇总指标：均值、标准差、平均用时和平均档案规模。
template = struct('algorithm','','HV_mean',0,'HV_std',0,'IGD_mean',0, ...
    'IGD_std',0,'Spacing_mean',0,'Spacing_std',0,'time_mean_s',0, ...
    'archive_mean',0);
summary = repmat(template,length(algorithms),1);
for a = 1:length(algorithms)
    ids = strcmp({records.algorithm},algorithms{a});   % 该算法的所有运行
    hv = [records(ids).HV]; igd = [records(ids).IGD];
    spacing = [records(ids).Spacing]; times = [records(ids).timeSeconds];
    outputs = {records(ids).output};
    sizes = cellfun(@(x)size(x.archive.fitness,1),outputs);
    summary(a) = struct('algorithm',algorithms{a}, ...
        'HV_mean',mean(hv),'HV_std',std(hv), ...
        'IGD_mean',mean(igd),'IGD_std',std(igd), ...
        'Spacing_mean',mean(spacing),'Spacing_std',std(spacing), ...
        'time_mean_s',mean(times),'archive_mean',mean(sizes));
end
end

function write_json_summary(experiment,fileName)
% WRITE_JSON_SUMMARY 把实验压缩成便于外部绘图/检查的 JSON。
% MAT 里保留完整档案和细节；JSON 只保留配置、指标、目标值、布局和收敛曲线。
runTemplate = struct('algorithm','','run',0,'seed',0,'timeSeconds',0, ...
    'HV',0,'IGD',0,'Spacing',0,'evaluations',0,'cacheHits',0, ...
    'objectives',[],'layouts',{{}},'convergenceFE',[],'convergenceHV',[]);
runs = repmat(runTemplate,length(experiment.records),1);
s = struct('config',experiment.config,'problemInfo',experiment.problemInfo, ...
    'summary',experiment.summary,'referenceFront',experiment.referenceFront, ...
    'runs',runs);
for i = 1:length(experiment.records)
    r = experiment.records(i);
    s.runs(i) = struct('algorithm',r.algorithm,'run',r.run,'seed',r.seed, ...
        'timeSeconds',r.timeSeconds,'HV',r.HV,'IGD',r.IGD, ...
        'Spacing',r.Spacing,'evaluations',r.output.evaluations, ...
        'cacheHits',r.output.cacheHits, ...
        'objectives',r.output.archive.fitness, ...
        'layouts',{r.output.archive.layouts}, ...
        'convergenceFE',r.output.history.evaluations, ...
        'convergenceHV',r.convergenceHV);
end
fid = fopen(fileName,'w');
if fid < 0, error('无法写入 %s',fileName); end
clean = onCleanup(@()fclose(fid));   % 函数退出时自动关闭文件
fwrite(fid,jsonencode(s),'char');
end

function config = fill_defaults(config)
% FILL_DEFAULTS 为缺省字段补默认值，使函数可以独立调用。
if nargin == 0 || isempty(config), config = struct(); end
config = set_default(config,'nTurbines',100);
config = set_default(config,'nRuns',5);
config = set_default(config,'seed',1);
config = set_default(config,'useCache',true);
config = set_default(config,'useParallel',false);
config = set_default(config,'outputDirectory',fullfile(pwd,'results_continuous'));
if ~isfield(config,'repairOptions'), config.repairOptions = struct(); end
if ~isfield(config,'options'), config.options = struct(); end
config.options = set_default(config.options,'popSize',80);
config.options = set_default(config.options,'maxFE',10000);
config.options = set_default(config.options,'archiveSize',100);
config.options = set_default(config.options,'numGroups',10);
config.options = set_default(config.options,'regroupPeriod',10);
config.options = set_default(config.options,'verbose',true);
end

function s = set_default(s,name,value)
% SET_DEFAULT 若结构体缺少字段 name，则补上默认值。
if ~isfield(s,name), s.(name) = value; end
end
