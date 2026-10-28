function outputs = main_compare()
% MAIN_COMPARE 快速演示程序，正式大规模实验请运行 main_large_scale。

here = fileparts(mfilename('fullpath'));
scenarioFile = fullfile(here, '..', '..', 'Scenarios', '00.xml');
addpath(here);

% 演示规模故意较小，便于几分钟内检查完整调用链。
nTurbines = 20;
candidateCount = 1200;
model = windflo_model(scenarioFile, nTurbines);
candidates = windflo_make_candidates(model, candidateCount);
problem = windflo_prepare_problem(model,candidates,true);

options = struct('popSize',20,'maxFE',400,'archiveSize',30,'verbose',false);
fprintf('\n===== 输入结构 =====\n');
fprintf('场景文件: %s\n', model.scenarioFile);
fprintf('场区: %.1f m × %.1f m，风机数 N = %d\n', ...
    model.width, model.height, model.nTurbines);
fprintf('候选点矩阵 candidates: %d × %d\n', size(candidates,1), size(candidates,2));
fprintf('目标向量: [-AEP, LCOE, CVaR95]（全部按最小化处理）\n');
fprintf('约束: 边界、障碍物、任意两点距离 >= 8R = %.1f m\n', 8*model.R);

% 两种算法经过同一个入口调用，因此比较时只改变算法名称。
fprintf('\n===== 调用关系 =====\n');
fprintf('main_compare -> run_algorithm(''CCGDE3'') -> CCGDE3\n');
fprintf('main_compare -> run_algorithm(''NSGA2'') -> NSGA2\n');
fprintf('两种算法都调用 windflo_decode -> windflo_evaluate\n');

outputs = struct();
% 固定随机种子，方便重复实验；两种算法从相同随机起点开始。
rng(1);
outputs.CCGDE3 = run_algorithm('CCGDE3',problem,options);
rng(1);
problem.cache = containers.Map('KeyType','char','ValueType','any');
outputs.NSGA2 = run_algorithm('NSGA2',problem,options);

fprintf('\n===== 输出结构 =====\n');
print_result(outputs.CCGDE3);
print_result(outputs.NSGA2);
fprintf('result.best.layout 是 N×2 风机坐标；result.best.objectives 是 1×3 目标；\n');
fprintf('result.archive 保存非支配解，result.history 保存每代标量记录。\n');
end

function print_result(result)
f = result.best.objectives;
fprintf('%s: evaluations = %d, archiveSize = %d\n', result.name, ...
    result.evaluations, size(result.archive.fitness,1));
fprintf('  -AEP = %.4g, LCOE = %.6g, CVaR95 = %.6g\n', f(1), f(2), f(3));
fprintf('  best.layout size = %d × %d, feasible = %d\n', ...
    size(result.best.layout,1), size(result.best.layout,2), result.best.detail.feasible);
end
