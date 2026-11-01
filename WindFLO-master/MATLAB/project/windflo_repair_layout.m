function [layout,feasible,info] = windflo_repair_layout(layout,model,options,movableMask)
% WINDFLO_REPAIR_LAYOUT 确定性修复场界、障碍物和 8R 最小间距（第 9 步）。
%
% 修复分三级，尽量保留原始坐标信息：
%   1) 投影：越界点拉回场区；障碍物内部点沿最短方向推到障碍物边界；
%   2) 排斥：对间距不足的风机对，沿连线各退一半，最多 maxIterations 轮；
%   3) 兜底：若仍有冲突，按间距 8R*gridFactor 的网格从近到远为冲突风机
%      找可行点；只要网格点足够容纳 N 台风机，就能得到可行布局。
%
% 增加了 movableMask 支持（适配 CCGDE3 分组协同进化）：
%   movableMask 为逻辑数组，true 表示该风机允许移动，false 表示固定不动。
%   如果未传入 movableMask，则默认所有风机都可移动。

if nargin < 3, options = struct(); end
if nargin < 4 || isempty(movableMask)
    movableMask = true(size(layout,1),1);
end

maxIterations = get_option(options,'maxIterations',60);
tolerance = get_option(options,'tolerance',1e-6);
gridFactor = get_option(options,'gridFactor',1.05);
minDistance = 8*model.R;
original = layout;                    % 保存原始坐标，用于统计移动量

% ---- 第一级：场界与障碍物投影 ----
layout = project_bounds_and_obstacles(layout,model,movableMask);

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
                % 如果两个风机都不能动，跳过不处理（保留违规，让评价器罚分）
                if ~movableMask(i) && ~movableMask(j)
                    continue;
                end
                
                % 完全重合时 norm 为 0，无法从连线得到方向，
                % 用编号哈希生成一个确定性的分离方向。
                if distance < tolerance
                    angle = mod((i*73856093+j*19349663),360)*pi/180;
                    direction = [cos(angle),sin(angle)];
                else
                    direction = delta/distance;
                end
                
                overlap = minDistance - distance + tolerance;
                
                % 根据 movableMask 分配推开量
                if movableMask(i) && movableMask(j)
                    % 都能动，各退一半
                    shift = 0.5 * overlap;
                    layout(i,:) = layout(i,:) + shift * direction;
                    layout(j,:) = layout(j,:) - shift * direction;
                elseif movableMask(i) && ~movableMask(j)
                    % 只有 i 能动，i 承担全部推开量
                    layout(i,:) = layout(i,:) + overlap * direction;
                elseif ~movableMask(i) && movableMask(j)
                    % 只有 j 能动，j 承担全部推开量
                    layout(j,:) = layout(j,:) - overlap * direction;
                end
                moved = true;
            end
        end
    end
    % 推开后可能越界或进入障碍物，每轮都要重新投影（只处理可移动的）
    layout = project_bounds_and_obstacles(layout,model,movableMask);
    if ~moved || minimum_distance(layout) >= minDistance-tolerance
        break;
    end
end

% ---- 第三级：仍有冲突时用网格兜底 ----
fallbackCount = 0;
if ~windflo_check_layout(layout,model)
    [layout,fallbackCount] = sequential_fallback(layout,model,minDistance,gridFactor,movableMask);
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

function layout = project_bounds_and_obstacles(layout,model,movableMask)
% PROJECT_BOUNDS_AND_OBSTACLES 把坐标压回场区，并把障碍物内的点推到最近边界。
% 仅对 movableMask 为 true 的风机进行移动。
movableIdx = find(movableMask);

% 处理边界
layout(movableIdx,1) = min(model.width,max(0,layout(movableIdx,1)));
layout(movableIdx,2) = min(model.height,max(0,layout(movableIdx,2)));

% 处理障碍物
for k = 1:size(model.obstacles,1)
    o = model.obstacles(k,:);        % [xmin ymin xmax ymax]
    for idx = 1:length(movableIdx)
        i = movableIdx(idx);
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

function [layout,fallbackCount] = sequential_fallback(layout,model,minDistance,gridFactor,movableMask)
% SEQUENTIAL_FALLBACK 按顺序放置风机：能保留原点就保留，否则从网格中
% 选最近的、与已放置风机不冲突的可行点。
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
    
    % 如果当前点合法，直接保留
    if is_valid_point(p,oldPoints,model,minDistance)
        placedCount = placedCount+1;
        placed(placedCount,:) = p;
        continue;
    end
    
    % 如果当前点冲突，但它是“固定点”（不允许移动），强制保留原位
    if ~movableMask(i)
        placedCount = placedCount+1;
        placed(placedCount,:) = p;
        continue;
    end
    
    % 冲突且可移动：按距离从近到远找第一个可行网格点。
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
