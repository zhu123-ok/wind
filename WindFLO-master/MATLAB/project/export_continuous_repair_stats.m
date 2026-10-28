function repairData = export_continuous_repair_stats(resultDirectory)
% EXPORT_CONTINUOUS_REPAIR_STATS 导出连续版最终档案的修复统计（第 15 步）。
%
% 这是可选的后处理脚本，主入口 main_continuous 不会自动调用。
%
% 输入：
%   resultDirectory  results_continuous 目录（缺省为脚本旁的该目录）
%
% 输出：
%   repairData 结构体，同时写入 repair_summary.json，包含：
%     items    每个算法、每次运行、档案中每个解的修复记录
%     summary  按算法汇总：兜底使用率、平均移动量、平均迭代次数等
%
% 用途：判断连续表示下约束修复的强度——移动量过大或兜底率过高，
% 说明搜索几乎依靠修复器才能得到可行布局。

here = fileparts(mfilename('fullpath'));
if nargin < 1 || isempty(resultDirectory)
    resultDirectory = fullfile(here,'results_continuous');
end
matFile = fullfile(resultDirectory,'experiment.mat');
if ~exist(matFile,'file')
    error('找不到实验文件：%s',matFile);
end

loaded = load(matFile,'experiment');
records = loaded.experiment.records;
% 预先建立空的结构体数组，字段与最终 JSON 对齐。
items = struct('algorithm',{},'run',{},'seed',{},'archiveIndex',{}, ...
    'iterations',{},'fallbackCount',{},'totalMovement',{}, ...
    'minimumDistance',{},'feasible',{});

for i = 1:length(records)
    details = records(i).output.archive.details;
    for j = 1:length(details)
        repair = details{j}.repair;
        one = struct();
        one.algorithm = records(i).algorithm;
        one.run = records(i).run;
        one.seed = records(i).seed;
        one.archiveIndex = j;
        one.iterations = read_field(repair,'iterations',0);
        one.fallbackCount = read_field(repair,'fallbackCount',0);
        % 修复器内部字段名是 movement；对外用 totalMovement 更直观。
        one.totalMovement = read_field(repair,'movement',0);
        one.minimumDistance = read_field(repair,'minimumDistance',nan);
        one.feasible = read_field(repair,'feasible',false);
        items(end+1) = one; %#ok<AGROW>
    end
end

algorithms = {'CCGDE3','NSGA2'};
summary = repmat(struct('algorithm','','layoutCount',0, ...
    'fallbackUseRate',0,'fallbackCountMean',0,'movementMean',0, ...
    'movementStd',0,'iterationsMean',0,'minimumDistanceMin',0, ...
    'feasibleRate',0),length(algorithms),1);
for a = 1:length(algorithms)
    ids = strcmp({items.algorithm},algorithms{a});
    x = items(ids);
    fallback = [x.fallbackCount];
    movement = [x.totalMovement];
    iterations = [x.iterations];
    distances = [x.minimumDistance];
    feasible = [x.feasible];
    summary(a) = struct('algorithm',algorithms{a},'layoutCount',length(x), ...
        'fallbackUseRate',mean(fallback > 0), ...   % 至少用过一次兜底的比例
        'fallbackCountMean',mean(fallback), ...
        'movementMean',mean(movement),'movementStd',std(movement), ...
        'iterationsMean',mean(iterations), ...
        'minimumDistanceMin',min(distances), ...
        'feasibleRate',mean(feasible));
end

repairData = struct('source',matFile,'items',items,'summary',summary);
fileName = fullfile(resultDirectory,'repair_summary.json');
fid = fopen(fileName,'w');
if fid < 0
    error('无法写入 %s',fileName);
end
clean = onCleanup(@()fclose(fid));   % 异常时也能关闭文件
fwrite(fid,jsonencode(repairData),'char');
fprintf('修复统计已写入：%s\n',fileName);
disp(struct2table(summary));
end

function value = read_field(s,name,defaultValue)
% READ_FIELD 安全读取字段；旧结果缺少 repair 字段时返回默认值。
if isstruct(s) && isfield(s,name)
    value = s.(name);
else
    value = defaultValue;
end
end
