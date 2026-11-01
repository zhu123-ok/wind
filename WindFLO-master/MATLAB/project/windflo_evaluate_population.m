function [fitness,details,layouts,selected,cacheHits,stats] = ...
    windflo_evaluate_population(keys,problem)
% WINDFLO_EVALUATE_POPULATION 批量评价种群（第 10 步）。
%
% 修复了缓存命中时错误复用旧修复信息的 Bug（阶段二 5.4.1）。
% 增加了评价次数、修复轮数等统计字段（阶段二 5.4.4）。

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

% 新增统计变量
infeasibleCount = 0;
totalRepairIterations = 0;
totalFallbackCount = 0;

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
    
    % 统计修复信息
    if isfield(repairInfos{i}, 'iterations')
        totalRepairIterations = totalRepairIterations + repairInfos{i}.iterations;
    end
    if isfield(repairInfos{i}, 'fallbackCount')
        totalFallbackCount = totalFallbackCount + repairInfos{i}.fallbackCount;
    end

    if ~ok
        % 修复后仍不可行：直接给最差目标，不再做尾流计算。
        fitness(i,:) = [inf,inf,inf];
        details{i} = struct('feasible',false,'violation',violation, ...
            'repair',repairInfos{i});
        infeasibleCount = infeasibleCount + 1; % 统计不可行数
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
        % ==========================================
        % 【修复Bug 1：全局缓存命中】
        % 目标值复用旧的，但修复信息必须强制替换为当前解自己的！
        % ==========================================
        saved = problem.cache(cacheKey);
        fitness(i,:) = saved.fitness;
        details{i} = saved.detail;
        details{i}.repair = repairInfos{i}; 
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
        
        % ==========================================
        % 【修复Bug 2：批内缓存命中】
        % 同样，把修复信息强制替换回自己的！
        % ==========================================
        details{i}.repair = repairInfos{i}; 
    end
end

% ==========================================
% 【新增：输出统计结构体】
% ==========================================
stats = struct();
stats.nominalFE = n;                          % 理论评价次数（种群数量）
stats.actualObjectiveCalls = length(needEvaluation); % 真实调用评价函数的次数
stats.cacheHits = cacheHits;                  % 缓存命中次数
stats.infeasibleCount = infeasibleCount;      % 不可行解数量
stats.totalRepairIterations = totalRepairIterations; % 累计修复迭代轮数
stats.totalFallbackCount = totalFallbackCount;       % 累计网格兜底次数

% 验证文档 5.4.4 要求的公式：FE = ActualCalls + CacheHits + InfeasibleCount
% 注：如果有些解既命中缓存又是不可行的，公式可微调，但通常上述等式成立。
end
