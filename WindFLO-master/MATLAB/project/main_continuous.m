function experiment = main_continuous()
% MAIN_CONTINUOUS 连续坐标版正式实验入口（流程第 1 步）。
%
% 作用：
%   集中设置实验规模、场景、算法参数和输出目录，然后调用
%   run_experiments_continuous 完成 CCGDE3 与 NSGA2 的对比实验。
%
% 实验设置：
%   场景       Scenarios/00.xml（场区 7000 m x 14000 m，24 个风向）
%   风机       100 台，连续问题维度 2N = 200
%   独立运行   每个算法 5 次，随机种子 1~5
%   种群规模   80
%   评价预算   每次运行 10000 次评价（命中缓存也计入预算）
%   Pareto 档案 最多 100 个非支配解
%
% 输出：
%   experiment 结构体；run_experiments_continuous 还会在
%   results_continuous/ 下生成 experiment.mat、summary.csv、summary.json。
%
% 说明：本入口只用于连续坐标表示；原 main_large_scale 和
% results_large_scale 不会被修改或覆盖。

here = fileparts(mfilename('fullpath'));   % 当前 m 文件所在目录
addpath(here);                             % 保证同目录函数可被调用

config = struct();

% ---- 场景与实验规模 ----
config.scenarioFile = fullfile(here,'..','..','Scenarios','00.xml');
config.nTurbines = 100;                    % 风机台数 N；连续变量数为 2N
config.nRuns = 5;                          % 每个算法的独立重复次数
config.seed = 1;                           % 起始种子；第 r 次用 seed+r-1

% ---- 评价方式 ----
config.useCache = true;                    % 按实际布局缓存评价，减少重复尾流计算
config.useParallel = false;                % 默认串行；开启需 Parallel Computing Toolbox

% ---- 结果目录 ----
config.outputDirectory = fullfile(here,'results_continuous');

% ---- 布局修复参数（第 9 步使用）----
% maxIterations：成对排斥的最大轮数
% gridFactor   ：网格兜底间距 = 8R * gridFactor，略大于最小间距以保证可行
config.repairOptions = struct('maxIterations',60,'gridFactor',1.05);

% ---- 两种算法共享的参数 ----
% numGroups/regroupPeriod/mutationFactor 只被 CCGDE3 使用；
% crossRate 在 CCGDE3 中是二项交叉概率，在 NSGA2 中是 SBX 交叉概率。
config.options = struct( ...
    'popSize',80, ...           % 种群规模
    'maxFE',10000, ...          % 每次运行的评价次数上限
    'archiveSize',100, ...      % 外部 Pareto 档案上限
    'numGroups',10, ...         % CCGDE3 的变量分组数
    'regroupPeriod',10, ...     % CCGDE3 每隔 10 代重新分组
    'mutationFactor',0.5, ...   % CCGDE3 差分缩放因子 F
    'crossRate',0.9, ...        % 交叉概率
    'verbose',true);            % 打印每代进度

experiment = run_experiments_continuous(config);
end
