function [layout,feasible,info] = windflo_repair_layout(layout,model,options)
% WINDFLO_REPAIR_LAYOUT 确定性修复场界、障碍物和 8R 最小间距（第 9 步）。
%
% 修复分三级，尽量保留原始坐标信息：
%   1) 投影：越界点拉回场区；障碍物内部点沿最短方向推到障碍物边界；
%   2) 排斥：对间距不足的风机对，沿连线各退一半，最多 maxIterations 轮；
%   3) 兜底：若仍有冲突，按间距 8R*gridFactor 的网格从近到远为冲突风机
%      找可行点；只要网格点足够容纳 N 台风机，就能得到可行布局。
%
% 确定性：相同输入必得相同输出；两个点完全重合时，分离方向由风机编号
% 的哈希角决定，不使用随机数。这样同一布局的缓存键和实验结果可复现。
%
% info 字段：
%   iterations        实际执行的排斥轮数
%   fallbackCount     使用网格兜底的风机数
%   movement          所有风机相对原始坐标的移动距离之和（m）
%   minimumDistance   修复后的最小风机间距（m）
%   boundaryViolation 越界距离之和
%   obstacleViolation 落在障碍物内的风机数
%   totalViolation    上述违规量之和
%   feasible          是否完全满足约束

if nargin < 3, options = struct(); end
maxIterations = get_option(options,'maxIterations',60);
tolerance = get_option(options,'tolerance',1e-6);
gridFactor = get_option(options,'gridFactor',1.05);
minDistance = 8*model.R;
original = layout;                    % 保存原始坐标，用于统计移动量

% ---- 第一级：场界与障碍物投影 ----
layout = project_bounds_and_obstacles(layout,model);

% ---- 第二级：成对排斥 ----
iterations = 0;
for iter = 1:maxIterations
    iterations = iter;
    moved = false;
    for i = 1:size(layout,1)-1
        for j = i+1:size(layout,1)
            delta = layout(i,:)-layout(j,:);
            distance = norm(delta);
            if distance < minDistance-tolerance
                % 完全重合时 norm 为 0，无法从连线得到方向，
                % 用编号哈希生成一个确定性的分离方向。
                if distance < tolerance
                    angle = mod((i*73856093+j*19349663),360)*pi/180;
                    direction = [cos(angle),sin(angle)];
                else
                    direction = delta/distance;
                end
                % 各退一半重叠量，使间距刚好达到 8R（略留 tolerance）。
                shift = 0.5*(minDistance-distance+tolerance);
                layout(i,:) = layout(i,:)+shift*direction;
                layout(j,:) = layout(j,:)-shift*direction;
                moved = true;
            end
        end
    end
    % 推开后可能越界或进入障碍物，每轮都要重新投影。
    layout = project_bounds_and_obstacles(layout,model);
    if ~moved || minimum_distance(layout) >= minDistance-tolerance
        break;
    end
end

% ---- 第三级：仍有冲突时用网格兜底 ----
fallbackCount = 0;
if ~windflo_check_layout(layout,model)
    [layout,fallbackCount] = sequential_fallback(layout,model,minDistance,gridFactor);
end

% ---- 汇总修复统计 ----
feasible = windflo_check_layout(layout,model);
minD = minimum_distance(layout);
boundaryViolation = sum(max(0,-layout(:,1))+max(0,layout(:,1)-model.width)+ ...
    max(0,-layout(:,2))+max(0,layout(:,2)-model.height));
distanceViolation = max(0,minDistance-minD);
obstacleViolation = count_obstacle_points(layout,model);
totalViolation = boundaryViolation+distanceViolation+obstacleViolation;
info = struct('iterations',iterations,'fallbackCount',fallbackCount, ...
    'movement',sum(sqrt(sum((layout-original).^2,2))), ...
    'minimumDistance',minD,'boundaryViolation',boundaryViolation, ...
    'obstacleViolation',obstacleViolation,'totalViolation',totalViolation, ...
    'feasible',feasible);
end

function layout = project_bounds_and_obstacles(layout,model)
% PROJECT_BOUNDS_AND_OBSTACLES 把坐标压回场区，并把障碍物内的点推到最近边界。
% 障碍物是轴对齐矩形，边界上的点视为合法（判断用严格不等号）。
layout(:,1) = min(model.width,max(0,layout(:,1)));
layout(:,2) = min(model.height,max(0,layout(:,2)));
for k = 1:size(model.obstacles,1)
    o = model.obstacles(k,:);        % [xmin ymin xmax ymax]
    for i = 1:size(layout,1)
        p = layout(i,:);
        if p(1) > o(1) && p(1) < o(3) && p(2) > o(2) && p(2) < o(4)
            % 比较到四条边的距离，移到最近的一条边上。
            gaps = [p(1)-o(1),o(3)-p(1),p(2)-o(2),o(4)-p(2)];
            [~,side] = min(gaps);
            if side == 1, p(1) = o(1);
            elseif side == 2, p(1) = o(3);
            elseif side == 3, p(2) = o(2);
            else, p(2) = o(4);
            end
            layout(i,:) = p;
        end
    end
end
end

function [layout,fallbackCount] = sequential_fallback(layout,model,minDistance,gridFactor)
% SEQUENTIAL_FALLBACK 按顺序放置风机：能保留原点就保留，否则从网格中
% 选最近的、与已放置风机不冲突的可行点。
%
% 网格间距 = 8R*gridFactor > 8R，因此网格点之间天然满足间距约束；
% 只要场区能容纳 N 台风机，逐个放置就不会失败。
step = minDistance*gridFactor;
[gx,gy] = meshgrid(0:step:model.width,0:step:model.height);
grid = [gx(:),gy(:)];
% 去掉落在障碍物内部的网格点（边界点合法）。
valid = true(size(grid,1),1);
for k = 1:size(model.obstacles,1)
    o = model.obstacles(k,:);
    valid = valid & ~(grid(:,1) > o(1) & grid(:,1) < o(3) & ...
        grid(:,2) > o(2) & grid(:,2) < o(4));
end
grid = grid(valid,:);
fallbackCount = 0;
placed = zeros(size(layout));
placedCount = 0;
for i = 1:size(layout,1)
    p = layout(i,:);
    oldPoints = placed(1:placedCount,:);
    if is_valid_point(p,oldPoints,model,minDistance)
        placedCount = placedCount+1;
        placed(placedCount,:) = p;
        continue;
    end
    % 冲突：按距离从近到远找第一个可行网格点。
    distance = sum((grid-p).^2,2);
    [~,order] = sort(distance,'ascend');
    found = false;
    for j = 1:length(order)
        candidate = grid(order(j),:);
        if is_valid_point(candidate,oldPoints,model,minDistance)
            placedCount = placedCount+1;
            placed(placedCount,:) = candidate;
            fallbackCount = fallbackCount+1;
            found = true;
            break;
        end
    end
    if ~found
        % 理论上容量足够时不会走到这里；保底仍保留原点。
        placedCount = placedCount+1;
        placed(placedCount,:) = p;
    end
end
layout = placed(1:placedCount,:);
end

function ok = is_valid_point(point,placed,model,minDistance)
% IS_VALID_POINT 判断单个点是否满足场界、障碍物和已放置风机的间距约束。
ok = point(1) >= 0 && point(1) <= model.width && ...
    point(2) >= 0 && point(2) <= model.height;
if ~ok, return; end
for k = 1:size(model.obstacles,1)
    o = model.obstacles(k,:);
    if point(1) > o(1) && point(1) < o(3) && ...
            point(2) > o(2) && point(2) < o(4)
        ok = false;
        return;
    end
end
if ~isempty(placed)
    ok = all(sqrt(sum((placed-point).^2,2)) >= minDistance-1e-8);
end
end

function value = minimum_distance(layout)
% MINIMUM_DISTANCE 计算布局中的最小两两间距；少于 2 台时返回 inf。
if size(layout,1) < 2, value = inf; return; end
value = inf;
for i = 1:size(layout,1)-1
    value = min(value,min(sqrt(sum((layout(i+1:end,:)-layout(i,:)).^2,2))));
end
end

function count = count_obstacle_points(layout,model)
% COUNT_OBSTACLE_POINTS 统计严格落在障碍物内部的风机数。
count = 0;
for k = 1:size(model.obstacles,1)
    o = model.obstacles(k,:);
    count = count+sum(layout(:,1) > o(1) & layout(:,1) < o(3) & ...
        layout(:,2) > o(2) & layout(:,2) < o(4));
end
end

function value = get_option(options,name,defaultValue)
% GET_OPTION 读取可选参数；字段不存在时返回默认值。
if isfield(options,name), value = options.(name); else, value = defaultValue; end
end
