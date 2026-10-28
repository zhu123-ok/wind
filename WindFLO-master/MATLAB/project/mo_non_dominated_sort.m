function frontNo = mo_non_dominated_sort(objectives)
% MO_NON_DOMINATED_SORT 标准快速非支配排序，目标均按最小化处理。
%
% 做法：
%   1) 对 n 个解两两比较，得到支配关系矩阵；
%   2) 被支配计数为 0 的解属于第一层；
%   3) 逐层剥离已分层解，得到 frontNo = 1,2,3,...
%
% 支配定义：p 支配 q 当且仅当 p 在所有目标上不差于 q，
% 且至少有一个目标严格更好。

n = size(objectives,1);
frontNo = inf(n,1);
dominance = false(n,n); % dominance(p,q)=true 表示 p 支配 q
for p = 1:n
    for q = p+1:n
        pDomQ = all(objectives(p,:) <= objectives(q,:)) && ...
            any(objectives(p,:) < objectives(q,:));
        qDomP = all(objectives(q,:) <= objectives(p,:)) && ...
            any(objectives(q,:) < objectives(p,:));
        if pDomQ
            dominance(p,q) = true;
        elseif qDomP
            dominance(q,p) = true;
        end
    end
end

dominatedCount = sum(dominance,1)';   % 每个解被多少解支配
current = find(dominatedCount == 0)';
frontNo(current) = 1;
front = 1;
while ~isempty(current)
    % 移除当前层对这些解的支配贡献，计数归零者进入下一层。
    reduced = sum(dominance(current,:),1)';
    dominatedCount = dominatedCount-reduced;
    dominance(current,:) = false;
    next = find(dominatedCount == 0 & isinf(frontNo))';
    frontNo(next) = front+1;
    front = front+1;
    current = next;
end
end
