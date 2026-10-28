function candidates = windflo_make_candidates(model, targetCount)
% WINDFLO_MAKE_CANDIDATES 生成指定数量的均匀候选点。
% 候选网格比 8R 更密，让最小距离约束真正参与优化。

if nargin < 2
    targetCount = 1200;
end
targetCount = max(100, round(targetCount));

% 根据场区长宽比决定横纵网格数量。
ratio = model.width / model.height;
nx = max(2, ceil(sqrt(targetCount * ratio)));
ny = max(2, ceil(targetCount / nx));

% 障碍物会删掉部分点，所以逐渐加密直到数量足够。
while true
    x = linspace(0, model.width, nx);
    y = linspace(0, model.height, ny);
    [xx, yy] = meshgrid(x, y);
    allPoints = remove_bad_points([xx(:), yy(:)], model);
    if size(allPoints, 1) >= targetCount
        break;
    end
    nx = nx + 1;
    ny = ny + 1;
end

% 均匀抽取为准确的 targetCount 个。
ids = round(linspace(1, size(allPoints,1), targetCount));
candidates = unique(allPoints(ids,:), 'rows', 'stable');
if size(candidates,1) < targetCount
    [~, unused] = setdiff(allPoints, candidates, 'rows', 'stable');
    need = targetCount - size(candidates,1);
    candidates = [candidates; allPoints(unused(1:need),:)];
end

if size(candidates, 1) < model.nTurbines
    error('候选点数 M 必须不少于风机数 N。');
end
end

function points = remove_bad_points(points, model)
inside = points(:,1) < 0 | points(:,1) > model.width | ...
    points(:,2) < 0 | points(:,2) > model.height;
for i = 1:size(model.obstacles, 1)
    o = model.obstacles(i, :);
    inside = inside | (points(:,1) > o(1) & points(:,1) < o(3) & ...
        points(:,2) > o(2) & points(:,2) < o(4));
end
points(inside, :) = [];
end
