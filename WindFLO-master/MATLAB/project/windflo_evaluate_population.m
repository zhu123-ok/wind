function [fitness,details,layouts,selected,cacheHits] = ...
    windflo_evaluate_population(keys,problem)
% WINDFLO_EVALUATE_POPULATION 批量评价种群（第 10 步）。
%
% 职责：把“解码 -> 修复 -> 查缓存 -> 真正评价 -> 回填结果”串起来，
% 同时兼容离散随机键和连续坐标两种表示。
%
% 输入 keys：
%   连续版  n×2N 的 [0,1] 坐标
%   离散版  n×M 的候选点编号
%
% 输出：
%   fitness    n×3 目标 [-AEP, LCOE, CVaR95]；不可行个体为 [Inf Inf Inf]
%   details    每个个体的评价细节，repair 字段记录修复统计
%   layouts    修复后的实际坐标（N×2）
%   selected   参与评价的机位/风机编号
%   cacheHits  本次命中的缓存数（包括批内重复）
%
% 缓存键：
%   连续版  由实际坐标生成的布局键（坐标保留 1e-6 m 后排序），
%           因此不同的变量编码只要解出同一布局也能命中；
%   离散版  排序后的候选点编号串。
%
% 缓存分两层：
%   1) problem.cache：跨代共享的全局缓存；
%   2) pending：本批内已出现、但尚未评价的重复布局，用 alias 指向首个，
%      等首个评价完成后统一回填，避免同一批内重复计算。

n = size(keys,1);
fitness = zeros(n,3);
details = cell(n,1);
layouts = cell(n,1);
selected = cell(n,1);
cacheHits = 0;
cacheKeys = cell(n,1);
repairInfos = cell(n,1);
needEvaluation = zeros(n,1);    % 需要真正评价的个体下标
needCount = 0;
alias = zeros(n,1);             % 批内重复：指向同批中已登记的首个个体
pending = containers.Map('KeyType','char','ValueType','double');

% 先统一解码并查缓存，收集所有未命中的布局，再集中评价。
for i = 1:n
    isContinuous = isfield(problem,'representation') && ...
        strcmpi(problem.representation,'continuous');
    if isContinuous
        [layout,ids,ok,violation,repairInfo] = ...
            windflo_decode_continuous(keys(i,:),problem);
        repairInfos{i} = repairInfo;
    else
        [layout,ids,ok,violation] = windflo_decode(keys(i,:),problem);
        repairInfos{i} = struct();
    end
    layouts{i} = layout;
    selected{i} = ids;
    if ~ok
        % 修复后仍不可行：直接给最差目标，不再做尾流计算。
        fitness(i,:) = [inf,inf,inf];
        details{i} = struct('feasible',false,'violation',violation, ...
            'repair',repairInfos{i});
        continue;
    end

    % 连续版用实际坐标做键；离散版用排序后的机位编号做键。
    if isContinuous
        cacheKey = windflo_layout_key(layout);
    else
        cacheKey = sprintf('%d_',sort(ids));
    end
    cacheKeys{i} = cacheKey;
    if problem.useCache && isKey(problem.cache,cacheKey)
        % 全局缓存命中：直接复用目标值和评价细节。
        saved = problem.cache(cacheKey);
        fitness(i,:) = saved.fitness;
        details{i} = saved.detail;
        cacheHits = cacheHits+1;
    elseif problem.useCache && isKey(pending,cacheKey)
        % 本批内重复：先记下别名，等首个评价完再回填。
        alias(i) = pending(cacheKey);
        cacheHits = cacheHits+1;
    else
        needCount = needCount+1;
        needEvaluation(needCount) = i;
        if problem.useCache, pending(cacheKey) = i; end
    end
end
needEvaluation = needEvaluation(1:needCount);

% 只有未命中的布局才进入真正的尾流评价。
useParallel = isfield(problem,'useParallel') && problem.useParallel && ...
    license('test','Distrib_Computing_Toolbox');
newFitness = cell(length(needEvaluation),1);
newDetails = cell(length(needEvaluation),1);
if useParallel
    layoutsToEvaluate = layouts(needEvaluation);
    evalModel = problem.model;
    wakeFreeAEP = problem.wakeFreeAEPPerTurbine;
    parfor k = 1:length(needEvaluation)
        [newFitness{k},newDetails{k}] = windflo_evaluate( ...
            layoutsToEvaluate{k},evalModel,wakeFreeAEP);
    end
else
    for k = 1:length(needEvaluation)
        i = needEvaluation(k);
        [newFitness{k},newDetails{k}] = windflo_evaluate(layouts{i}, ...
            problem.model,problem.wakeFreeAEPPerTurbine);
    end
end

% 回填新评价结果，并写入全局缓存。
for k = 1:length(needEvaluation)
    i = needEvaluation(k);
    fitness(i,:) = newFitness{k};
    details{i} = newDetails{k};
    details{i}.repair = repairInfos{i};   % 附带修复统计
    if problem.useCache
        problem.cache(cacheKeys{i}) = struct('fitness',fitness(i,:), ...
            'detail',details{i});
    end
end

% 批内重复个体复用首个个体的结果。
for i = 1:n
    if alias(i) > 0
        fitness(i,:) = fitness(alias(i),:);
        details{i} = details{alias(i)};
    end
end
end
