function key = windflo_layout_key(layout)
% WINDFLO_LAYOUT_KEY 用无序坐标集生成布局缓存键（第 10 步缓存使用）。
%
% 布局对风机编号是置换不变的：同一组坐标无论怎么编号都是同一个布局。
% 因此先生成键：
%   1) 坐标四舍五入到 1e-6 m，去掉浮点尾差；
%   2) 按 x、y 排序，消除编号顺序；
%   3) 拼成字符串，作为 containers.Map 的键。
% 空布局单独返回 'empty'，避免生成空字符串键。

if isempty(layout)
    key = 'empty';
    return;
end
ordered = sortrows(round(layout*1e6)/1e6,[1,2]);
key = sprintf('%.6f_',ordered');
end
