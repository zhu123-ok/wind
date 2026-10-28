function problem = windflo_prepare_continuous_problem(model,useCache,repairOptions)
% WINDFLO_PREPARE_CONTINUOUS_PROBLEM 构建 2N 维连续坐标问题（第 3~4 步）。
%
% 决策变量：
%   values = [x1,y1,x2,y2,...,xN,yN]，每个分量都在 [0,1]。
%   解码时 x_i = values(2i-1)*width，y_i = values(2i)*height。
%
% 预计算（避免在每次评价中重复计算）：
%   windProbability        每个风向的概率，由 omega 归一化得到
%   wakeFreePower          无尾流时各风向的单机期望功率
%   wakeFreeAEPPerTurbine  无尾流时单机年发电量，作为 CVaR95 的损失基准
%
% 约束参数：
%   minDistance = 8R = 308 m（R=38.5 m）
%
% 输入：
%   model           windflo_model 生成的模型
%   useCache        是否启用布局评价缓存
%   repairOptions   修复器参数（maxIterations、gridFactor 等）

if nargin < 2, useCache = true; end
if nargin < 3, repairOptions = struct(); end

% 修复器的默认参数；调用方只需覆盖关心的字段。
repairOptions = set_default(repairOptions,'maxIterations',60);
repairOptions = set_default(repairOptions,'tolerance',1e-6);
repairOptions = set_default(repairOptions,'gridFactor',1.05);

omega = model.wind.omega(:);             % 列向量，便于归一化
problem = struct();
problem.model = model;                   % 解码、修复和评价共享同一模型
problem.representation = 'continuous';   % 标记表示方式，供算法和评价分派
problem.dimension = 2*model.nTurbines;   % 每台风机占 2 个变量
problem.lower = zeros(1,problem.dimension);
problem.upper = ones(1,problem.dimension);
problem.minDistance = 8*model.R;         % 最小叶轮间距约束
problem.repairOptions = repairOptions;

% ---- 风况基线 ----
% omega 是频率权重，归一化后才是概率。
problem.windProbability = omega/sum(omega);
% 无尾流时，单机在各风向下的期望功率（行向量，长度 nDir）。
problem.wakeFreePower = windflo_expected_power( ...
    model.wind.c(:)',model.wind.k(:)',model);
% 无尾流时单机年发电量：8760 * Σ_d p_d * P_free(d)。
problem.wakeFreeAEPPerTurbine = model.hoursPerYear* ...
    sum(problem.windProbability'.*problem.wakeFreePower);

% ---- 缓存 ----
% 键是实际布局坐标串，值是 struct('fitness',...,'detail',...)。
problem.useCache = useCache;
problem.useParallel = false;
if useCache
    problem.cache = containers.Map('KeyType','char','ValueType','any');
else
    problem.cache = [];
end
end

function s = set_default(s,name,value)
% SET_DEFAULT 若结构体缺少字段 name，则补上默认值。
if ~isfield(s,name), s.(name) = value; end
end
