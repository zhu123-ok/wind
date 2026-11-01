% 测试缓存有效性的脚本
clear; clc;

% 1. 加载模型（注意路径，如果都在同一个文件夹，直接写 '00.xml'）
scenarioFile = '00.xml';
fprintf('正在加载模型...\n');
model = windflo_model(scenarioFile, 100);
problem = windflo_prepare_continuous_problem(model, false, struct());

% 生成 50 个测试解（模拟算法跑了一代产生的种群）
n = 50; 
keys = rand(n, problem.dimension);
keys(2:10, :) = repmat(keys(1, :), 9, 1); % 故意制造9个一模一样的解

% 2. 测试【关闭缓存】
fprintf('\n正在测试无缓存模式...\n');
problem.useCache = false;
tic;
[~, ~, ~, ~, ~, stats_nocache] = windflo_evaluate_population(keys, problem);
time_nocache = toc;

% 3. 测试【开启缓存】
fprintf('\n正在测试开启缓存模式...\n');
problem.useCache = true;
problem.cache = containers.Map('KeyType','char','ValueType','any');
tic;
[~, ~, ~, ~, ~, stats_cache] = windflo_evaluate_population(keys, problem);
time_cache = toc;

% 4. 打印结果
fprintf('\n\n================ 缓存有效性对比 ================\n');
fprintf('无缓存耗时: %.4f 秒, 实际调用评价函数: %d 次\n', time_nocache, stats_nocache.actualObjectiveCalls);
fprintf('有缓存耗时: %.4f 秒, 实际调用评价函数: %d 次\n', time_cache, stats_cache.actualObjectiveCalls);
fprintf('缓存拦截了 %d 次冗余计算，整体提速了 %.2f%%\n', ...
    stats_nocache.actualObjectiveCalls - stats_cache.actualObjectiveCalls, ...
    (time_nocache - time_cache) / time_nocache * 100);
fprintf('================================================\n');
