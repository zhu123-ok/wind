function experiment = main_continuous()
% MAIN_CONTINUOUS 连续坐标版正式实验入口（流程第 1 步）。
%
% 作用：
%   集中设置实验规模、场景、算法参数和输出目录，然后调用
%   run_experiments_continuous 完成 CCGDE3 与 NSGA2 的对比实验。
%
% 实验设置：
%   场景       Scenarios/00.xml（场区 7000 m x 14000 m，24 个风向）
%   风机       读取场景 NTurbines，00.xml 为 400 台，连续问题维度为 800
%   独立运行   每个算法 1 次，随机种子 1
%   种群规模   NSGA-II 100；CCGDE3 每组 40
%   评价预算   每次运行 10000 次评价（命中缓存也计入预算）
%   Pareto 档案 最多 100 个非支配解
%
% 输出：
%   experiment 结构体；run_experiments_continuous 还会在
%   results_continuous_00_10k_species_v1/ 下生成 experiment.mat、summary.csv、summary.json。
%

here = fileparts(mfilename('fullpath'));   % 当前 m 文件所在目录
addpath(here);                             % 保证同目录函数可被调用

config = struct();

% ---- 场景与实验规模 ----
config.scenarioFile = fullfile(here,'..','..','Scenarios','00.xml');
config.nTurbines = [];                     % Read NTurbines from the scenario XML.
config.nRuns = 1;                          % 每个算法的独立重复次数
config.checkpointFE = [880 4080 10000];
config.seed = 1;                           % 起始种子；第 r 次用 seed+r-1

% ---- 评价方式 ----
config.useCache = true;                    % 按实际布局缓存评价，减少重复尾流计算
config.useParallel = false;                % 默认串行；开启需 Parallel Computing Toolbox

% ---- 结果目录 ----
config.outputDirectory = fullfile(here,'results_continuous_00_10k_species_v1');

% ---- 布局修复参数（第 9 步使用）----
% maxIterations：成对排斥的最大轮数
% gridFactor   ：网格兜底间距 = 8R * gridFactor，略大于最小间距以保证可行
config.repairOptions = struct('maxIterations',60,'gridFactor',1.05);

% ---- 两种算法共享的参数 ----
% numGroups/regroupPeriod/mutationFactor 只被 CCGDE3 使用；
% 顶层 crossRate 用于 NSGA2；CCGDE3 参数由下方 ccgde3 结构单独指定。
config.options = struct( ...
    'popSize',100, ...           % 种群规模
    'maxFE',10000, ...          % 每次运行的评价次数上限
    'archiveSize',100, ...      % 外部 Pareto 档案上限
    'numGroups',2, ...         % CCGDE3 的变量分组数
    'regroupPeriod',0, ...     % 0 表示固定初始随机分组
    'mutationFactor',0.5, ...   % CCGDE3 差分缩放因子 F
    'crossRate',0.9, ...        % 交叉概率
    'verbose',true);            % 打印每代进度

config.options.ccgde3 = struct('subPopSize',40,'numGroups',2, ...
    'mutationFactor',0.5,'crossRate',0.5,'regroupPeriod',0);

experiment = run_experiments_continuous(config);
end
