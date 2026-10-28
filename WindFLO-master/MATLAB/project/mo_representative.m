function id = mo_representative(objectives)
% MO_REPRESENTATIVE 选择离归一化理想点最近的折中解，仅用于展示。
%
% 先把档案中每个目标按该目标的最小/最大值归一化，再选离原点最近的解，
% 即各目标之间比较均衡的那个解。该选择不影响算法运行和档案内容。

lower = min(objectives,[],1);
upper = max(objectives,[],1);
normal = (objectives-lower)./max(upper-lower,eps);
[~,id] = min(sqrt(sum(normal.^2,2)));
end
