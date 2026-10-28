function [ids,frontNo,crowding] = mo_environmental_selection(objectives,nKeep)
% MO_ENVIRONMENTAL_SELECTION (μ+λ) 环境选择（第 12 步）。
%
% 规则：
%   1) 按非支配等级从低到高整层接收；
%   2) 若某一层放不下，只在这一层内按拥挤距离从大到小取所需数量，
%      让保留解在前沿上尽量分散。
%
% 输入 objectives 为父代 + 子代的合并目标（全部最小化），nKeep 为保留数。
% 输出 ids 为被保留个体在合并池中的行号。
frontNo = mo_non_dominated_sort(objectives);
crowding = mo_crowding_distance(objectives,frontNo);
ids = zeros(nKeep,1);
filled = 0;
front = 1;
while filled < nKeep
    members = find(frontNo == front);
    if isempty(members), break; end       % 池子比 nKeep 小
    if filled+length(members) <= nKeep
        % 整层都能放下，全部接收。
        ids(filled+1:filled+length(members)) = members;
        filled = filled+length(members);
    else
        % 只接收该层中拥挤距离最大的 need 个。
        [~,order] = sort(crowding(members),'descend');
        need = nKeep-filled;
        ids(filled+1:nKeep) = members(order(1:need));
        filled = nKeep;
    end
    front = front+1;
end
ids = ids(1:filled);
end
