function distance = mo_crowding_distance(objectives,frontNo)
% MO_CROWDING_DISTANCE 计算同一非支配层内的拥挤距离。
%
% 对每个目标单独排序，把相邻解的目标差按该目标的范围归一化后累加。
% 每个目标的边界解（最小值和最大值）距离设为 inf，保证它们优先保留；
% 层内只有 1~2 个解时也全部设为 inf。

n = size(objectives,1);
nObj = size(objectives,2);
distance = zeros(n,1);
fronts = unique(frontNo(isfinite(frontNo)))';
for f = fronts
    ids = find(frontNo == f);
    if length(ids) <= 2
        distance(ids) = inf;
        continue;
    end
    for j = 1:nObj
        [values,order] = sort(objectives(ids,j));
        sortedIds = ids(order);
        distance(sortedIds([1,end])) = inf;
        range = values(end)-values(1);
        if range <= eps, continue; end   % 该目标在层内全相同，跳过
        for k = 2:length(ids)-1
            distance(sortedIds(k)) = distance(sortedIds(k)) + ...
                (values(k+1)-values(k-1))/range;
        end
    end
end
end
