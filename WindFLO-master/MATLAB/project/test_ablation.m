% 修复器消融实验脚本 (真实场景版)
clear; clc;

% ==========================================
% 1. 加载真实的模型参数（直接借用你们项目的底层函数）
% ==========================================
here = fileparts(mfilename('fullpath'));
scenarioFile = fullfile(here, '..', '..', 'Scenarios', '00.xml');
nTurbines = 100;

fprintf('正在加载场景数据...\n');
model = windflo_model(scenarioFile, nTurbines);
% 获取默认修复参数，和 main_continuous 保持一致
repairOptions = struct('maxIterations', 60, 'gridFactor', 1.05);

% ==========================================
% 2. 生成测试数据（故意让前 15 台挤在一起）
% ==========================================
numTests = 30; % 测试 30 次
layouts = cell(numTests, 1);
for i = 1:numTests
    % 在场区范围内随机生成 100 台风机
    layouts{i} = rand(nTurbines, 2) .* [model.width, model.height];
    % 故意让前 15 台风机集中在一个点上，逼迫修复器工作
    layouts{i}(1:15, :) = repmat([model.width/2, model.height/2], 15, 1) + randn(15, 2)*10; 
end

% ==========================================
% 3. 开始消融实验
% ==========================================
modes = {'无修复', '仅连续修复(禁用兜底)', '完整修复(默认)'};
results = struct();

for m = 1:3
    fprintf('\n====== 正在测试模式: %s ======\n', modes{m});
    feasible_count = 0;
    total_movement = 0;
    total_time = 0;
    
    for i = 1:numTests
        tic;
        
        if m == 1 
            % 模式1：无修复，直接检查
            layout = layouts{i};
            feasible = windflo_check_layout(layout, model);
            info = struct('movement', 0);
            
        elseif m == 2 
            % 模式2：仅连续修复（将 gridFactor 设为极大值，物理上禁止走到网格兜底）
            opt = repairOptions;
            opt.gridFactor = 1e6; 
            [layout, feasible, info] = windflo_repair_layout(layouts{i}, model, opt);
            
        else 
            % 模式3：完整修复（使用默认设置，包含网格兜底）
            opt = repairOptions;
            [layout, feasible, info] = windflo_repair_layout(layouts{i}, model, opt);
        end
        
        total_time = total_time + toc;
        if feasible
            feasible_count = feasible_count + 1; 
        end
        total_movement = total_movement + info.movement;
    end
    
    results(m).name = modes{m};
    results(m).feasible_ratio = feasible_count / numTests * 100;
    results(m).avg_movement = total_movement / numTests;
    results(m).avg_time = total_time / numTests;
end

% ==========================================
% 4. 打印结果表格
% ==========================================
fprintf('\n================ 消融实验结果 (基于 00.xml 真实场景) ================\n');
fprintf('模式\t\t\t\t可行解比例\t平均移动距离(m)\t平均耗时(s)\n');
for m = 1:3
    fprintf('%-20s\t%.2f%%\t\t%.2f\t\t%.4f\n', ...
        results(m).name, results(m).feasible_ratio, results(m).avg_movement, results(m).avg_time);
end
