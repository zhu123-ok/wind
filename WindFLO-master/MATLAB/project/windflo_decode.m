function [layout, selected, feasible, violation] = windflo_decode(keys, problem, model)
% WINDFLO_DECODE 把 [0,1] 随机键解码为固定数量的风机坐标。
% 按键值从高到低贪心选点，冲突图保证距离不小于 8R。

% 兼容旧调用 windflo_decode(keys,candidates,model)。
if nargin == 3
    problem = windflo_prepare_problem(model, problem, false);
end
candidates = problem.candidates;
model = problem.model;

keys = keys(:);
if length(keys) ~= size(candidates, 1)
    error('keys 长度必须等于候选点数量 M。');
end
[~, order] = sort(keys, 'descend');
selected = zeros(model.nTurbines, 1);
nSelected = 0;
blocked = false(size(candidates,1),1);
for t = 1:length(order)
    id = order(t);
    if ~blocked(id)
        nSelected = nSelected + 1;
        selected(nSelected) = id;
        blocked(problem.conflictList{id}) = true;
        blocked(id) = true;
        if nSelected == model.nTurbines
            break;
        end
    end
end

selected = selected(1:nSelected);
layout = candidates(selected, :);
feasible = nSelected == model.nTurbines;
violation = model.nTurbines - nSelected;
end
