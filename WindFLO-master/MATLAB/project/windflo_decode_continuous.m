function [layout,selected,feasible,violation,repairInfo] = ...
    windflo_decode_continuous(values,problem)
% WINDFLO_DECODE_CONTINUOUS 把 2N 维归一化变量解码成 N×2 实际坐标（第 8 步）。
%
% 映射关系：
%   x_i = values(2i-1) * width
%   y_i = values(2i)   * height
% 因此奇数位控制东西向，偶数位控制南北向。
%
% 输出：
%   layout     N×2 坐标（m），已经过 windflo_repair_layout 修复
%   selected   1..N，连续版没有机位选择，保留该字段以统一接口
%   feasible   修复后是否满足场界、障碍物和 8R 间距
%   violation  修复信息中的总违规量，0 表示完全可行
%   repairInfo 修复统计（迭代次数、移动量、兜底次数、最小间距等）

model = problem.model;
values = values(:)';                  % 统一成行向量
if length(values) ~= problem.dimension
    error('连续变量长度必须等于 2N。');
end

% 算法可能因变异/交叉越界，这里先压回 [0,1]。
values = min(1,max(0,values));
layout = zeros(model.nTurbines,2);
layout(:,1) = values(1:2:end)'*model.width;    % 所有奇数位 -> x
layout(:,2) = values(2:2:end)'*model.height;   % 所有偶数位 -> y

% 连续坐标很难天然满足 8R 间距，必须修复后才能评价。
[layout,feasible,repairInfo] = windflo_repair_layout( ...
    layout,model,problem.repairOptions);
selected = (1:model.nTurbines)';      % 连续版每台风机都参与，不选机位
violation = repairInfo.totalViolation;
end
