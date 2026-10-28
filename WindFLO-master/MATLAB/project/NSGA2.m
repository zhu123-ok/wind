function result = NSGA2(problem,options)
% NSGA2 标准多目标遗传算法，作为 CCGDE3 的公平基线（第 6、7B、12 步）。
%
% 与 CCGDE3 共用：初始种群、评价预算、目标函数、环境选择、Pareto 档案
% 和收敛记录；差异只在子代生成：
%   1) 二元锦标赛：先比非支配等级，等级相同比拥挤距离；
%   2) SBX 模拟二进制交叉，分布指数 etaC；
%   3) 多项式变异，分布指数 etaM，变异率默认 1/M。
% 这样两种算法的差异可以主要归因于搜索算子，而不是评价次数或选择策略。
%
% 输入 problem 需包含 dimension（2N）和 model；options 可覆盖 popSize、
% maxFE、crossRate、mutationRate、etaC、etaM、archiveSize 和 verbose。

if nargin < 2, options = struct(); end
popSize = get_option(options,'popSize',80);
maxFE = get_option(options,'maxFE',10000);
crossRate = get_option(options,'crossRate',0.9);
if isfield(problem,'dimension')
    M = problem.dimension;
else
    M = size(problem.candidates,1);
end
mutationRate = get_option(options,'mutationRate',1/M);  % 平均每个个体变异一个变量
etaC = get_option(options,'etaC',20);   % SBX 分布指数，越大子代越靠近父代
etaM = get_option(options,'etaM',20);   % 多项式变异分布指数
archiveSize = get_option(options,'archiveSize',100);
verbose = get_option(options,'verbose',true);

% ---- 第 6 步：初始化并立即评价 ----
pop = rand(popSize,M);
[fitness,details,layouts,selected,hits] = ...
    windflo_evaluate_population(pop,problem);
evaluations = popSize;
cacheHits = hits;
archive = mo_update_archive([],pop,fitness,details,layouts,selected,archiveSize);
history = make_history(maxFE,popSize);
history = record_history(history,evaluations,archive);
generation = 0;

while evaluations < maxFE
    generation = generation+1;

    % ---- 第 7B 步：锦标赛选择 -> SBX 交叉 + 多项式变异 ----
    frontNo = mo_non_dominated_sort(fitness);
    crowding = mo_crowding_distance(fitness,frontNo);
    nOffspring = min(popSize,maxFE-evaluations);
    parentIds = tournament(frontNo,crowding,2*ceil(nOffspring/2));
    parents = pop(parentIds,:);
    offspring = variation(parents,crossRate,mutationRate,etaC,etaM);
    offspring = offspring(1:nOffspring,:);   % 预算末尾可能多产生一对

    [offF,offD,offL,offS,hits] = ...
        windflo_evaluate_population(offspring,problem);
    evaluations = evaluations+nOffspring;
    cacheHits = cacheHits+hits;

    % ---- 第 12 步：父代 + 子代合并后做环境选择 ----
    poolX = [pop;offspring]; poolF = [fitness;offF];
    poolD = [details;offD]; poolL = [layouts;offL]; poolS = [selected;offS];
    keep = mo_environmental_selection(poolF,popSize);
    pop = poolX(keep,:); fitness = poolF(keep,:);
    details = poolD(keep); layouts = poolL(keep); selected = poolS(keep);
    archive = mo_update_archive(archive,pop,fitness,details,layouts,selected,archiveSize);
    history = record_history(history,evaluations,archive);

    if verbose && (generation == 1 || mod(generation,10) == 0)
        fprintf('NSGA-II generation %d, FE=%d, archive=%d\n', ...
            generation,evaluations,size(archive.fitness,1));
    end
end

% 选折中代表解，并裁剪历史到实际记录长度。
id = mo_representative(archive.fitness);
history.evaluations = history.evaluations(1:history.count);
history.archiveSize = history.archiveSize(1:history.count);
history.ideal = history.ideal(1:history.count,:);
history.fronts = history.fronts(1:history.count);
result = struct('name','NSGA2','archive',archive, ...
    'representative',struct('keys',archive.keys(id,:), ...
    'layout',archive.layouts{id},'selected',archive.selected{id}, ...
    'objectives',archive.fitness(id,:),'detail',archive.details{id}), ...
    'history',history,'evaluations',evaluations,'cacheHits',cacheHits, ...
    'generations',generation);
result.best = result.representative;   % 兼容原主程序
end

function ids = tournament(frontNo,crowding,nParents)
% TOURNAMENT 二元锦标赛：等级低者胜；等级相同则拥挤距离大者胜。
n = length(frontNo);
ids = zeros(nParents,1);
for i = 1:nParents
    a = randi(n); b = randi(n);
    if frontNo(a) < frontNo(b) || ...
            (frontNo(a) == frontNo(b) && crowding(a) >= crowding(b))
        ids(i) = a;
    else
        ids(i) = b;
    end
end
end

function offspring = variation(parents,pc,pm,etaC,etaM)
% VARIATION 成对执行 SBX 交叉，再对每个子代做多项式变异，最后压回 [0,1]。
[n,M] = size(parents);
offspring = zeros(n,M);
for i = 1:2:n
    p1 = parents(i,:);
    p2 = parents(min(i+1,n),:);   % 个体数为奇数时最后一个与自身配对
    c1 = p1; c2 = p2;
    if rand < pc
        % SBX：按分布指数 etaC 生成 beta，再做对称的凸组合。
        u = rand(1,M);
        beta = zeros(1,M);
        low = u <= 0.5;
        beta(low) = (2*u(low)).^(1/(etaC+1));
        beta(~low) = (1./(2*(1-u(~low)))).^(1/(etaC+1));
        beta = beta .* (-1).^randi([0,1],1,M);   % 随机正负方向
        c1 = 0.5*((1+beta).*p1+(1-beta).*p2);
        c2 = 0.5*((1-beta).*p1+(1+beta).*p2);
    end
    c1 = polynomial_mutation(c1,pm,etaM);
    c2 = polynomial_mutation(c2,pm,etaM);
    offspring(i,:) = min(1,max(0,c1));       % 连续变量保持在 [0,1]
    if i+1 <= n, offspring(i+1,:) = min(1,max(0,c2)); end
end
end

function x = polynomial_mutation(x,pm,etaM)
% POLYNOMIAL_MUTATION 以概率 pm 逐变量扰动，扰动幅度随 etaM 增大而减小。
mask = rand(size(x)) < pm;
u = rand(size(x));
left = mask & u < 0.5;
right = mask & u >= 0.5;
delta = zeros(size(x));
delta(left) = (2*u(left)+(1-2*u(left)).*(1-x(left)).^(etaM+1)).^(1/(etaM+1))-1;
delta(right) = 1-(2*(1-u(right))+2*(u(right)-0.5).*x(right).^(etaM+1)).^(1/(etaM+1));
x(mask) = x(mask)+delta(mask);
end

function history = make_history(maxFE,popSize)
% MAKE_HISTORY 预分配收敛历史；+5 留给最后一轮不足整代的情况。
n = ceil(maxFE/max(1,popSize))+5;
history = struct('evaluations',zeros(n,1),'archiveSize',zeros(n,1), ...
    'ideal',nan(n,3),'fronts',{cell(n,1)},'count',0);
end

function history = record_history(history,evaluations,archive)
% RECORD_HISTORY 记录当前评价次数、档案规模、理想点和完整前沿。
history.count = history.count+1;
i = history.count;
history.evaluations(i) = evaluations;
history.archiveSize(i) = size(archive.fitness,1);
history.ideal(i,:) = min(archive.fitness,[],1);
history.fronts{i} = archive.fitness;
end

function value = get_option(options,name,defaultValue)
% GET_OPTION 读取可选参数；字段不存在时返回默认值。
if isfield(options,name), value = options.(name); else, value = defaultValue; end
end
