function result = CCGDE3(problem,options)
% CCGDE3 Independent species with cooperative context evaluation.
% Each species owns its group components and its evaluated full solutions.
% Context donors are frozen from each species' first front at cycle start.
% popSize is the comparison population size; subPopSize defaults to 40%
% of popSize (at least four). Paper defaults are 100 and 40, two groups,
% F=CR=0.5, and fixed random variable grouping.
% groupCoordinates=true binds wind turbine x/y pairs as an optional adaptation.
if nargin < 2, options = struct(); end
popSize = get_option(options,'popSize',100);
subPopSize = get_option(options,'subPopSize',max(4,round(0.4*popSize)));
maxFE = get_option(options,'maxFE',10000);
F = get_option(options,'mutationFactor',0.5);
CR = get_option(options,'crossRate',0.5);
numGroups = get_option(options,'numGroups',2);
regroupPeriod = get_option(options,'regroupPeriod',0);
groupCoordinates = get_option(options,'groupCoordinates',false);
archiveSize = get_option(options,'archiveSize',100);
verbose = get_option(options,'verbose',true);
if isfield(problem,'dimension')
    M = problem.dimension;
else
    M = size(problem.candidates,1);
end
validateattributes(subPopSize,{'numeric'},{'scalar','integer','>=',4});
validateattributes(numGroups,{'numeric'},{'scalar','integer','>=',1,'<=',M});
validateattributes(maxFE,{'numeric'},{'scalar','integer','>=',numGroups*subPopSize});
validateattributes(regroupPeriod,{'numeric'},{'scalar','integer','nonnegative'});
validateattributes(F,{'numeric'},{'scalar','real','finite','nonnegative'});
validateattributes(CR,{'numeric'},{'scalar','real','>=',0,'<=',1});
if groupCoordinates && numGroups > problem.model.nTurbines
    error('CCGDE3:Groups','Paired coordinate groups cannot exceed turbine count.');
end
groupId = make_groups(problem,M,numGroups,groupCoordinates);
initial = rand(subPopSize,M);
template = struct('keys',initial,'fitness',[],'details',{{}},'layouts',{{}},'selected',{{}});
species = repmat(template,numGroups,1);
archive = [];
evaluations = 0;
cacheHits = 0;
% Initially, all other species donate random native components.
donors = repmat({initial},numGroups,1);
for g = 1:numGroups
    keys = collaborate(initial,g,donors,groupId);
    [fitness,details,layouts,selected,hits] = windflo_evaluate_population(keys,problem);
    species(g) = struct('keys',keys,'fitness',fitness,'details',{details}, ...
        'layouts',{layouts},'selected',{selected});
    evaluations = evaluations+subPopSize;
    cacheHits = cacheHits+hits;
    archive = mo_update_archive(archive,keys,fitness,details,layouts,selected,archiveSize);
end
if isempty(archive)
    error('CCGDE3:NoFeasibleSolution','No feasible evaluated solution during species initialization.');
end
history = make_history(maxFE,subPopSize);
history = record_history(history,evaluations,archive);
generation = 0;
while evaluations < maxFE
    generation = generation+1;
    if regroupPeriod > 0 && generation > 1 && mod(generation-1,regroupPeriod) == 0
        groupId = make_groups(problem,M,numGroups,groupCoordinates);
    end
    % Each donor pool belongs to a distinct species from the previous cycle.
    for g = 1:numGroups
        frontNo = mo_non_dominated_sort(species(g).fitness);
        donors{g} = species(g).keys(frontNo == 1,:);
    end
    for g = 1:numGroups
        if evaluations >= maxFE, break; end
        parent = species(g);
        vars = find(groupId == g);
        nOffspring = min(subPopSize,maxFE-evaluations);
        trial = parent.keys(1:nOffspring,:);
        for i = 1:nOffspring
            pool = randperm(subPopSize);
            pool(pool == i) = [];
            mutant = parent.keys(pool(1),vars) + ...
                F*(parent.keys(pool(2),vars)-parent.keys(pool(3),vars));
            mutant = min(1,max(0,mutant));
            mask = rand(1,length(vars)) < CR;
            mask(randi(length(vars))) = true;
            trial(i,vars(mask)) = mutant(mask);
        end
        trial = collaborate(trial,g,donors,groupId);
        [trialF,trialD,trialL,trialS,hits] = windflo_evaluate_population(trial,problem);
        evaluations = evaluations+nOffspring;
        cacheHits = cacheHits+hits;
        [poolX,poolF,poolD,poolL,poolS] = gde3_preselection( ...
            parent.keys,parent.fitness,parent.details,parent.layouts,parent.selected, ...
            trial,trialF,trialD,trialL,trialS,nOffspring);
        keep = gde3_selection(poolF,subPopSize);
        species(g) = struct('keys',poolX(keep,:),'fitness',poolF(keep,:), ...
            'details',{poolD(keep)},'layouts',{poolL(keep)},'selected',{poolS(keep)});
        archive = mo_update_archive(archive,species(g).keys,species(g).fitness, ...
            species(g).details,species(g).layouts,species(g).selected,archiveSize);
        history = record_history(history,evaluations,archive);
        if isfield(options,'progressFcn')
            options.progressFcn(archive,history,evaluations,cacheHits);
        end
    end
    if verbose && (generation == 1 || mod(generation,5) == 0)
        fprintf('CCGDE3 cycle %d, FE=%d, species=%d, archive=%d\n', ...
            generation,evaluations,numGroups,size(archive.fitness,1));
    end
end
id = mo_representative(archive.fitness);
result = pack_result('CCGDE3',archive,id,history,evaluations,cacheHits,generation);
result.groups = numGroups;
result.subpopulations = species;
result.groupId = groupId;
result.parameters = struct('framework','independent-species-v1', ...
    'subPopSize',subPopSize,'numGroups',numGroups,'mutationFactor',F, ...
    'crossRate',CR,'regroupPeriod',regroupPeriod,'groupCoordinates',groupCoordinates);
end

function keys = collaborate(keys,activeGroup,donors,groupId)
% Native active-group components survive unchanged.
for g = 1:numel(donors)
    if g == activeGroup, continue; end
    rows = randi(size(donors{g},1),size(keys,1),1);
    keys(:,groupId == g) = donors{g}(rows,groupId == g);
end
end

function ids = gde3_selection(fitness,nKeep)
% Keep complete fronts, then prune the last front with recomputed distances.
frontNo = mo_non_dominated_sort(fitness);
ids = zeros(0,1);
for f = 1:max(frontNo)
    members = find(frontNo == f);
    need = nKeep-numel(ids);
    if numel(members) <= need
        ids = [ids;members];
    else
        while numel(members) > need
            distance = mo_crowding_distance(fitness(members,:),ones(numel(members),1));
            [~,worst] = min(distance);
            members(worst) = [];
        end
        ids = [ids;members];
    end
    if numel(ids) == nKeep, break; end
end
end

function groupId = make_groups(problem,M,numGroups,groupCoordinates)
% MAKE_GROUPS 随机分组：连续版按风机分组，离散版按候选变量分组。
groupId = zeros(1,M);
isContinuous = isfield(problem,'representation') && ...
    strcmpi(problem.representation,'continuous');
if isContinuous && groupCoordinates
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
%   子不劣于父（含等值） -> 只留子
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
    cDomP = all(childF(i,:) <= parentF(i,:));
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
