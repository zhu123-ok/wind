function metrics = mo_metrics(front,referenceFront,lower,upper)
% MO_METRICS 计算 HV、IGD 和 Spacing（第 13 步）。
%
% 先按全部实验的目标范围 [lower,upper] 把解归一化到 [0,1]，
% 消除 AEP、LCOE、CVaR 量纲不同带来的影响；参考点取 (1.1,1.1,1.1)。
%
% 输入：
%   front          一次运行的档案目标值（n×3，最小化）
%   referenceFront 全部运行合并得到的经验参考前沿（m×3）
%   lower/upper    归一化下界/上界（1×3）
%
% 输出：
%   HV      超体积，越大越好（同时反映收敛和分布）
%   IGD     参考前沿到该前沿的平均最近距离，越小越好
%   Spacing 该前沿最近邻距离的标准差，越小说明分布越均匀

range = max(upper-lower,eps);         % 防止某个目标在所有解上相等
front = (front-lower)./range;
referenceFront = (referenceFront-lower)./range;
front = min(1,max(0,front));          % 归一化后压回 [0,1]
referenceFront = min(1,max(0,referenceFront));
metrics.HV = hypervolume3(front,[1.1,1.1,1.1]);
% IGD：对参考前沿的每个点，找它到该前沿的最近距离，再取平均。
metrics.IGD = mean(nearest_distance(referenceFront,front));
% Spacing：前沿内部每个解的最近邻距离（排除自身）的标准差。
d = nearest_distance(front,front,true);
if length(d) <= 1
    metrics.Spacing = 0;
else
    metrics.Spacing = std(d,1);
end
end

function d = nearest_distance(A,B,ignoreSelf)
% NEAREST_DISTANCE A 中每个点到 B 的最近欧氏距离。
% ignoreSelf=true 时要求 A、B 是同一组解，并排除点自身。
if nargin < 3, ignoreSelf = false; end
d = inf(size(A,1),1);
for i = 1:size(A,1)
    delta = B-A(i,:);
    values = sqrt(sum(delta.^2,2));
    if ignoreSelf && size(A,1) == size(B,1)
        values(i) = inf;
    end
    d(i) = min(values);
end
end

function hv = hypervolume3(points,ref)
% HYPERVOLUME3 三目标最小化问题的精确超体积（按 x 方向切片）。
%
% 只考虑严格被参考点支配的点；非支配点才可能贡献体积。
% 对每个 x 切片，计算 (y,z) 平面的二维面积，再乘以 x 方向宽度。
points = points(all(points < ref,2),:);
if isempty(points), hv = 0; return; end
front = mo_non_dominated_sort(points);
points = points(front == 1,:);
xs = unique(points(:,1));
xs = sort(xs);
xBound = [xs;ref(1)];
hv = 0;
for i = 1:length(xs)
    % 在 [xs(i), xs(i+1)) 这一层，x <= xs(i) 的解支配该切片。
    active = points(points(:,1) <= xs(i),2:3);
    hv = hv+(xBound(i+1)-xs(i))*area2(active,ref(2:3));
end
end

function area = area2(points,ref)
% AREA2 二维最小化问题的面积（按 y 方向切片）。
points = points(all(points < ref,2),:);
if isempty(points), area = 0; return; end
ys = unique(points(:,1));
ys = sort(ys);
yBound = [ys;ref(1)];
area = 0;
for i = 1:length(ys)
    % 在该 y 切片中，只需保留 z 最小的解。
    active = points(points(:,1) <= ys(i),2);
    bestZ = min(active);
    area = area+(yBound(i+1)-ys(i))*(ref(2)-bestZ);
end
end
