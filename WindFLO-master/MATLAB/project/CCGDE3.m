function result = CCGDE3(problem,options)
% CCGDE3 协同进化广义差分进化（三目标），连续实验的主算法（第 6、7A、12 步）。
%
% 算法框架：
%   1) 随机初始化 popSize 个 2N 维个体，立即评价并建立初始档案；
%   2) 把决策变量分成 numGroups 组，每隔 regroupPeriod 代重新随机分组；
%   3) 依次进化每一组：其余组固定为“协同上下文”，上下文个体从当前
%      种群的非支配解中随机抽取，本组用 DE/rand/1/bin 产生新值；
%   4) 子代评价后做 GDE3 预选择，再用非支配排序 + 拥挤距离截断；
%   5) 每代把种群并入外部 Pareto 档案，直到评价预算用完。
%
% 连续版的特殊处理：
%   分组以风机为单位，同一台风机的 x、y 必须落在同一组。否则坐标对
%   被拆到不同组，协同上下文会把 x 和 y 拼成没有几何意义的组合。
%
% 输入 problem 需包含 dimension（2N）、model 等字段；options 可覆盖
% popSize、maxFE、numGroups、regroupPeriod、mutationFactor、crossRate、
% archiveSize 和 verbose。

if nargin < 2, options = struct(); end
popSize = get_option(options,'popSize',80);
maxFE = get_option(options,'maxFE',10000);
F = get_option(options,'mutationFactor',0.5);   % 差分缩放因子
CR = get_option(options,'crossRate',0.9);       % 二项交叉概率
numGroups = get_option(options,'numGroups',2);
regroupPeriod = get_option(options,'regroupPeriod',10);
archiveSize = get_option(options,'archiveSize',100);
verbose = get_option(options,'verbose',true);

% 离散版维度是候选点数，连续版维度是 2N。
if isfield(problem,'dimension')
    M = problem.dimension;
else
    M = size(problem.candidates,1);
end
% 分组数必须能覆盖所有变量；连续版还要求不超过风机数，
% 否则无法保证同一台机的 x、y 同组。
if numGroups < 1 || numGroups > M
    error('numGroups 必须在 1 到决策维度之间。');
end
if isfield(problem,'representation') && ...
        strcmpi(problem.representation,'continuous') && ...
        numGroups > problem.model.nTurbines
    error('连续版 numGroups 不能超过风机数量。');
end
if popSize < 4, error('CCGDE3 的 popSize 至少为 4。'); end

% ---- 第 6 步：初始化并立即评价 ----
pop = rand(popSize,M);                          % 均匀分布在 [0,1]^M
[fitness,details,layouts,selected,hits] = ...
    windflo_evaluate_population(pop,problem);
evaluations = popSize;                          % 已消耗的评价次数
cacheHits = hits;
archive = mo_update_archive([],pop,fitness,details,layouts,selected,archiveSize);
history = make_history(maxFE,popSize);
history = record_history(history,evaluations,archive);
generation = 0;

while evaluations < maxFE
    generation = generation+1;
    % 第 1 代必分组；之后每 regroupPeriod 代重新分组。
    if generation == 1 || mod(generation-1,regroupPeriod) == 0
        groupId = make_groups(problem,M,numGroups);
    end

    for g = 1:numGroups
        if evaluations >= maxFE, break; end
        vars = find(groupId == g);      % 本组要进化的变量下标
        other = find(groupId ~= g);     % 其余变量：保持上下文值
        frontNo = mo_non_dominated_sort(fitness);
        nd = find(frontNo == 1);        % 当前非支配解，作为上下文供体
        if isempty(nd), nd = (1:popSize)'; end

        % 最后一代可能不足 popSize 个，按剩余预算截断。
        nOffspring = min(popSize,maxFE-evaluations);
        trial = pop(1:nOffspring,:);    % 以父代为底稿

        % 第 7A 步之一：其他组由随机非支配个体提供协同上下文。
        context = nd(randi(length(nd),nOffspring,1));
        trial(:,other) = pop(context,other);

        % 第 7A 步之二：本组执行 DE/rand/1/bin。
        for i = 1:nOffspring
            pool = randperm(popSize);
            pool(pool == i) = [];       % 去掉自身，保证三个基向量互异
            a = pop(pool(1),vars);
            b = pop(pool(2),vars);
            c = pop(pool(3),vars);
            mutant = min(1,max(0,a+F*(b-c)));   % 变异并压回 [0,1]
            mask = rand(1,length(vars)) < CR;   % 二项交叉掩码
            mask(randi(length(vars))) = true;   % 至少保留一个变异分量
            trial(i,vars(mask)) = mutant(mask);
        end

        % 评价子代；命中缓存的部分不重复做尾流计算。
        [trialF,trialD,trialL,trialS,hits] = ...
            windflo_evaluate_population(trial,problem);
        evaluations = evaluations+nOffspring;
        cacheHits = cacheHits+hits;

        % ---- 第 12 步：GDE3 预选择 + 环境选择 ----
        % GDE3：父支配子留父；子支配父留子；互不支配时父子都进候选池。
        [poolX,poolF,poolD,poolL,poolS] = gde3_preselection( ...
            pop,fitness,details,layouts,selected, ...
            trial,trialF,trialD,trialL,trialS,nOffspring);
        keep = mo_environmental_selection(poolF,popSize);  % 截断回 popSize
        pop = poolX(keep,:); fitness = poolF(keep,:);
        details = poolD(keep); layouts = poolL(keep); selected = poolS(keep);
        % 把改进解并入档案；档案内部会去重并只保留非支配解。
        archive = mo_update_archive(archive,pop,fitness,details,layouts,selected,archiveSize);
        history = record_history(history,evaluations,archive);
    end
    if verbose && (generation == 1 || mod(generation,5) == 0)
        fprintf('CCGDE3 generation %d, FE=%d, archive=%d\n', ...
            generation,evaluations,size(archive.fitness,1));
    end
end

% 选一个离归一化理想点最近的解，仅用于展示“折中代表解”。
id = mo_representative(archive.fitness);
result = pack_result('CCGDE3',archive,id,history,evaluations,cacheHits,generation);
result.groups = numGroups;
end

function groupId = make_groups(problem,M,numGroups)
% MAKE_GROUPS 随机分组：连续版按风机分组，离散版按候选变量分组。
groupId = zeros(1,M);
isContinuous = isfield(problem,'representation') && ...
    strcmpi(problem.representation,'continuous');
if isContinuous
    % 连续版：先随机打乱风机顺序，再轮流分配组号；
    % 同一台机的 2i-1 和 2i 两个变量写入同一个组。
    nTurbines = problem.model.nTurbines;
    order = randperm(nTurbines);
    for i = 1:nTurbines
        turbine = order(i);
        g = mod(i-1,numGroups)+1;
        groupId(2*turbine-1) = g;
        groupId(2*turbine) = g;
    end
else
    % 离散版：每个候选点是一个变量，直接轮流分配。
    order = randperm(M);
    for i = 1:M
        groupId(order(i)) = mod(i-1,numGroups)+1;
    end
end
end

function [X,F,D,L,S] = gde3_preselection(parent,parentF,parentD,parentL,parentS, ...
    child,childF,childD,childL,childS,nChild)
% GDE3_PRESELECTION 父子一对一比较，生成候选池。
%
% 规则：
%   父支配子 -> 只留父
%   子支配父 -> 只留子
%   互不支配 -> 父、子都留（交给环境选择按拥挤距离截断）
% 若子代数量少于父代（预算末尾），多出的父代直接保留。
X = zeros(0,size(parent,2)); F = zeros(0,size(parentF,2));
D = {}; L = {}; S = {};
for i = 1:size(parent,1)
    if i > nChild
        take_parent();
        continue;
    end
    pDomC = all(parentF(i,:) <= childF(i,:)) && any(parentF(i,:) < childF(i,:));
    cDomP = all(childF(i,:) <= parentF(i,:)) && any(childF(i,:) < parentF(i,:));
    if pDomC
        take_parent();
    elseif cDomP
        take_child();
    else
        take_parent();
        take_child();
    end
end

    % 嵌套函数直接读写上面的候选池和当前下标 i。
    function take_parent()
        X(end+1,:) = parent(i,:); F(end+1,:) = parentF(i,:);
        D{end+1,1} = parentD{i}; L{end+1,1} = parentL{i}; S{end+1,1} = parentS{i};
    end
    function take_child()
        X(end+1,:) = child(i,:); F(end+1,:) = childF(i,:);
        D{end+1,1} = childD{i}; L{end+1,1} = childL{i}; S{end+1,1} = childS{i};
    end
end

function history = make_history(maxFE,popSize)
% MAKE_HISTORY 预分配收敛历史；+10 留给最后一轮不足整代和分组记录。
n = ceil(maxFE/max(1,popSize))+10;
history = struct('evaluations',zeros(n,1),'archiveSize',zeros(n,1), ...
    'ideal',nan(n,3),'fronts',{cell(n,1)},'count',0);
end

function history = record_history(history,evaluations,archive)
% RECORD_HISTORY 记录当前评价次数、档案规模、理想点和完整前沿。
% 前沿快照用于实验结束后重算 HV 收敛曲线。
history.count = history.count+1;
i = history.count;
history.evaluations(i) = evaluations;
history.archiveSize(i) = size(archive.fitness,1);
history.ideal(i,:) = min(archive.fitness,[],1);
history.fronts{i} = archive.fitness;
end

function result = pack_result(name,archive,id,history,evaluations,cacheHits,generation)
% PACK_RESULT 裁剪历史并组装统一的结果结构。
history.evaluations = history.evaluations(1:history.count);
history.archiveSize = history.archiveSize(1:history.count);
history.ideal = history.ideal(1:history.count,:);
history.fronts = history.fronts(1:history.count);
result = struct();
result.name = name;
result.archive = archive;
result.representative = struct('keys',archive.keys(id,:), ...
    'layout',archive.layouts{id},'selected',archive.selected{id}, ...
    'objectives',archive.fitness(id,:),'detail',archive.details{id});
result.best = result.representative;  % 兼容原主程序；实际是折中代表解
result.history = history;
result.evaluations = evaluations;
result.cacheHits = cacheHits;
result.generations = generation;
end

function value = get_option(options,name,defaultValue)
% GET_OPTION 读取可选参数；字段不存在时返回默认值。
if isfield(options,name), value = options.(name); else, value = defaultValue; end
end
