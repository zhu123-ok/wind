function passed = test_project()
% TEST_PROJECT 回归测试：候选点、约束、评价、缓存和两种算法。
here = fileparts(mfilename('fullpath'));
scenario = fullfile(here,'..','..','Scenarios','00.xml');

model = windflo_model(scenario,20);
candidates = windflo_make_candidates(model,1200);
assert(size(candidates,1) == 1200,'候选点数量不准确。');
problem = windflo_prepare_problem(model,candidates,true);
assert(nnz(problem.conflict) > 0,'密集候选点没有产生冲突边。');

rng(7);
[layout,selected,ok,violation] = windflo_decode(rand(1,1200),problem);
assert(ok && violation == 0 && length(selected) == 20,'随机键解码失败。');
assert(windflo_check_layout(layout,model),'解码布局不满足约束。');
[f,detail] = windflo_evaluate(layout,model,problem.wakeFreeAEPPerTurbine);
assert(all(isfinite(f)) && detail.feasible,'三目标评价出现异常。');
assert(detail.AEP > 0 && detail.LCOE > 0,'AEP或LCOE不是正数。');
assert(detail.CVaR95 >= 0 && detail.CVaR95 <= 1,'CVaR95越界。');

% 相同布局第二次评价应命中缓存。
keys = repmat(rand(1,1200),2,1);
[~,~,~,~,hits] = windflo_evaluate_population(keys,problem);
assert(hits >= 1,'重复布局没有命中缓存。');

% 安全距离边界：等于8R可行，小于8R不可行。
smallModel = windflo_model(scenario,2);
assert(windflo_check_layout([0,0;8*smallModel.R,0],smallModel));
assert(~windflo_check_layout([0,0;8*smallModel.R-0.01,0],smallModel));

% 小评价预算只用于确认两种算法调用链完整。
options = struct('popSize',8,'maxFE',32,'archiveSize',12,'verbose',false);
rng(11); out1 = run_algorithm('CCGDE3',problem,options);
problem.cache = containers.Map('KeyType','char','ValueType','any');
rng(11); out2 = run_algorithm('NSGA2',problem,options);
check_output(out1,model);
check_output(out2,model);

% 同一种子应得到相同的初始随机过程和最终目标集。
problem.cache = containers.Map('KeyType','char','ValueType','any');
rng(11); repeat = run_algorithm('NSGA2',problem,options);
assert(isequal(out2.archive.fitness,repeat.archive.fitness),'结果不可复现。');

allF = [out1.archive.fitness;out2.archive.fitness];
ref = allF(mo_non_dominated_sort(allF)==1,:);
m = mo_metrics(out1.archive.fitness,ref,min(allF,[],1),max(allF,[],1));
assert(all(isfinite([m.HV,m.IGD,m.Spacing])),'性能指标出现NaN或Inf。');
passed = true;
fprintf('全部回归测试通过。候选点=%d，冲突边=%d。\n', ...
    size(candidates,1),nnz(problem.conflict)/2);
end

function check_output(output,model)
assert(~isempty(output.archive) && ~isempty(output.archive.fitness),'档案为空。');
assert(all(mo_non_dominated_sort(output.archive.fitness)==1),'档案含支配解。');
for i = 1:length(output.archive.layouts)
    assert(windflo_check_layout(output.archive.layouts{i},model),'档案含不可行布局。');
end
end
