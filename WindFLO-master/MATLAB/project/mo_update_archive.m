function archive = mo_update_archive(old,keys,fitness,details,layouts,selected,maxSize)
% MO_UPDATE_ARCHIVE 维护外部 Pareto 档案（第 12 步）。
%
% 处理顺序：
%   1) 合并旧档案和新种群；
%   2) 丢掉含 Inf/NaN 的不可行个体；
%   3) 按实际布局坐标去重：同一布局只保留第一次出现的解；
%   4) 快速非支配排序，只保留第一层（非支配解）；
%   5) 超过 maxSize 时按拥挤距离截断，保持前沿分布。
%
% 连续版和离散版共用：去重键由 windflo_layout_key 根据实际坐标生成，
% 因此不同的变量编码只要解出同一布局，也会被识别为重复。
if isempty(old)
    allKeys = keys; allFitness = fitness; allDetails = details;
    allLayouts = layouts; allSelected = selected;
else
    allKeys = [old.keys;keys];
    allFitness = [old.fitness;fitness];
    allDetails = [old.details;details];
    allLayouts = [old.layouts;layouts];
    allSelected = [old.selected;selected];
end

% 不可行个体的目标为 Inf，直接剔除，档案中只保留可评价解。
valid = all(isfinite(allFitness),2);
allKeys = allKeys(valid,:); allFitness = allFitness(valid,:);
allDetails = allDetails(valid); allLayouts = allLayouts(valid);
allSelected = allSelected(valid);
if isempty(allFitness)
    archive = [];
    return;
end

% 按实际坐标去重；unique 的 'stable' 保留首次出现的顺序。
layoutKeys = cell(length(allLayouts),1);
for i = 1:length(allLayouts)
    layoutKeys{i} = windflo_layout_key(allLayouts{i});
end
[~,uniqueIds] = unique(layoutKeys,'stable');
allKeys = allKeys(uniqueIds,:); allFitness = allFitness(uniqueIds,:);
allDetails = allDetails(uniqueIds); allLayouts = allLayouts(uniqueIds);
allSelected = allSelected(uniqueIds);

% 只保留非支配层；超过上限时用拥挤距离保留分布最均匀的解。
frontNo = mo_non_dominated_sort(allFitness);
ids = find(frontNo == 1);
if length(ids) > maxSize
    distance = mo_crowding_distance(allFitness(ids,:),ones(length(ids),1));
    [~,order] = sort(distance,'descend');
    ids = ids(order(1:maxSize));
end
archive = struct('keys',allKeys(ids,:),'fitness',allFitness(ids,:), ...
    'details',{allDetails(ids)},'layouts',{allLayouts(ids)}, ...
    'selected',{allSelected(ids)});
end
