function problem = windflo_prepare_problem(model, candidates, useCache)
% WINDFLO_PREPARE_PROBLEM 预计算冲突关系和无尾流功率。
% 这些数据由所有算法共用，避免在每次评价中重复计算。

if nargin < 3
    useCache = true;
end
M = size(candidates, 1);
minDistance = 8 * model.R;

% conflict(i,j)=true 表示候选点 i 和 j 不能同时安装风机。
rows = cell(M,1);
cols = cell(M,1);
for i = 1:M-1
    delta = candidates(i+1:end,:) - candidates(i,:);
    bad = find(sum(delta.^2,2) < minDistance^2) + i;
    rows{i} = [repmat(i,length(bad),1); bad];
    cols{i} = [bad; repmat(i,length(bad),1)];
end
rows = vertcat(rows{:});
cols = vertcat(cols{:});
problem = struct();
problem.model = model;
problem.representation = 'discrete';
problem.dimension = M;
problem.candidates = candidates;
problem.conflict = sparse(rows, cols, true, M, M);
problem.conflictList = cell(M,1);
for i = 1:M
    problem.conflictList{i} = find(problem.conflict(:,i));
end
problem.minDistance = minDistance;

omega = model.wind.omega(:);
problem.windProbability = omega / sum(omega);
problem.wakeFreePower = windflo_expected_power( ...
    model.wind.c(:)', model.wind.k(:)', model);
problem.wakeFreeAEPPerTurbine = model.hoursPerYear * ...
    sum(problem.windProbability' .* problem.wakeFreePower);

problem.useCache = useCache;
problem.useParallel = false; % 有并行工具箱时可由实验配置打开
if useCache
    problem.cache = containers.Map('KeyType','char','ValueType','any');
else
    problem.cache = [];
end
end
