function feasible = windflo_check_layout(layout, model)
% WINDFLO_CHECK_LAYOUT 检查边界、障碍物和 8R 最小距离约束。
%
% 检查三类硬约束：
%   1) 布局尺寸必须是 N×2；
%   2) 所有点在场区矩形内（边界算可行）；
%   3) 点不在任何障碍物内部（边界算可行）；
%   4) 任意两机间距 >= 8R。
% 只有全部满足才返回 true；否则评价函数直接给 [Inf Inf Inf]。

feasible = size(layout,1) == model.nTurbines && size(layout,2) == 2;
if ~feasible
    return;
end
% 场区边界：0 <= x <= width，0 <= y <= height。
if any(layout(:,1) < 0 | layout(:,1) > model.width | ...
        layout(:,2) < 0 | layout(:,2) > model.height)
    feasible = false;
    return;
end
% 障碍物：严格在矩形内部才算违规，边界上的点合法。
for i = 1:size(model.obstacles,1)
    o = model.obstacles(i,:);
    if any(layout(:,1) > o(1) & layout(:,1) < o(3) & ...
            layout(:,2) > o(2) & layout(:,2) < o(4))
        feasible = false;
        return;
    end
end
% 最小间距：逐对计算欧氏距离，任一对小于 8R 即不可行。
for i = 1:size(layout,1)-1
    d = sqrt(sum((layout(i+1:end,:) - layout(i,:)).^2, 2));
    if any(d < 8 * model.R)
        feasible = false;
        return;
    end
end
end
