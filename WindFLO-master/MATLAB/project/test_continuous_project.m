function passed = test_continuous_project()
% TEST_CONTINUOUS_PROJECT 连续版解码、修复、缓存和算法回归测试。

here = fileparts(mfilename('fullpath'));
scenario = fullfile(here,'..','..','Scenarios','00.xml');
model = windflo_model(scenario,20);
problem = windflo_prepare_continuous_problem(model,true);
assert(problem.dimension == 40,'连续问题维度应为 2N。');

% 普通随机布局应能修复为可行解。
rng(7);
values = rand(1,problem.dimension);
[layout,selected,ok,violation,info] = ...
    windflo_decode_continuous(values,problem);
assert(ok && violation <= 1e-8 && length(selected) == model.nTurbines);
assert(windflo_check_layout(layout,model),'随机连续布局修复失败。');
assert(info.minimumDistance >= 8*model.R-1e-6,'最小间距不满足。');

% 极端情况：所有风机从同一坐标出发也应修复成功。
[sameLayout,~,sameOk] = windflo_decode_continuous( ...
    zeros(1,problem.dimension),problem);
assert(sameOk && windflo_check_layout(sameLayout,model), ...
    '重合风机的兜底修复失败。');

% 解码必须是确定的，否则同一个体的适应度会变化。
[repeatLayout,~,repeatOk] = windflo_decode_continuous(values,problem);
assert(repeatOk && isequal(layout,repeatLayout),'连续修复不可复现。');

[f,detail] = windflo_evaluate(layout,model,problem.wakeFreeAEPPerTurbine);
assert(all(isfinite(f)) && detail.feasible,'连续布局目标评价失败。');
assert(detail.AEP > 0 && detail.LCOE > 0);
assert(detail.CVaR95 >= 0 && detail.CVaR95 <= 1);

% 相同连续布局第二次应命中缓存。
population = repmat(values,2,1);
[~,~,~,~,hits] = windflo_evaluate_population(population,problem);
assert(hits >= 1,'连续布局缓存未命中。');

% 小预算同时检查两种算法和统一接口。
options = struct('popSize',8,'maxFE',32,'archiveSize',12, ...
    'numGroups',4,'regroupPeriod',2,'verbose',false);
problem.cache = containers.Map('KeyType','char','ValueType','any');
rng(11); out1 = run_algorithm('CCGDE3',problem,options);
problem.cache = containers.Map('KeyType','char','ValueType','any');
rng(11); out2 = run_algorithm('NSGA2',problem,options);
check_output(out1,model);
check_output(out2,model);

% 同一种子的 NSGA2 结果应完全可复现。
problem.cache = containers.Map('KeyType','char','ValueType','any');
rng(11); repeat = run_algorithm('NSGA2',problem,options);
assert(isequal(out2.archive.fitness,repeat.archive.fitness),'连续版结果不可复现。');

passed = true;
fprintf('连续版回归测试通过：维度=%d，最小间距=%.3f m。\n', ...
    problem.dimension,info.minimumDistance);
end

function check_output(output,model)
assert(~isempty(output.archive) && ~isempty(output.archive.fitness),'档案为空。');
assert(all(isfinite(output.archive.fitness),'all'),'档案目标含 NaN 或 Inf。');
assert(all(mo_non_dominated_sort(output.archive.fitness)==1),'档案含支配解。');
for i = 1:length(output.archive.layouts)
    assert(windflo_check_layout(output.archive.layouts{i},model), ...
        '档案含不可行连续布局。');
end
end

