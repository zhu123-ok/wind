function model = windflo_model(scenarioFile, nTurbines)
% WINDFLO_MODEL 读取 WindFLO XML 场景，整理成项目统一的 model 结构（第 2 步）。
%
% 输入：
%   scenarioFile 场景 XML 路径（本项目为 Scenarios/00.xml）
%   nTurbines    本次安装的风机台数 N，缺省为 8
%
% 输出 model 的主要字段：
%   width/height  场区宽高（m）
%   obstacles     M×4 障碍物矩形 [xmin ymin xmax ymax]（m）
%   wind          c/k/omega/theta：每个风向的 Weibull 尺度、形状、频率和方向角
%   R/CT/kw/...   风机、尾流和功率曲线参数
%   cost          成本参数（示例值，可在外部整体替换）
%
% 说明：XML 只提供场区、障碍物和风况；风机、尾流、成本参数在这里补全，
% 后续解码、修复和评价都只依赖这个自包含的 model。

if nargin < 2
    nTurbines = 8;
end
if ~exist(scenarioFile, 'file')
    error('找不到场景文件：%s', scenarioFile);
end

% 用 Java DOM 解析 XML；后续按标签名取节点。
doc = xmlread(scenarioFile);
model = struct();
model.scenarioFile = scenarioFile;
model.nTurbines = nTurbines;

% ---- 风机与尾流参数 ----
model.R = 38.5;             % 风轮半径（m）；8R = 308 m 为最小间距
model.CT = 0.8;             % 推力系数，进入单尾流亏损公式
model.kw = 0.075;           % 尾流扩张系数，尾流半径 R + kw*x
model.PRated = 1500;        % 额定功率（kW）
model.vCin = 3.5;           % 切入风速（m/s）
model.vRated = 14;          % 额定风速（m/s）
model.vCout = 20;           % 切出风速（m/s）
model.lambda = 140.86;      % 线性功率曲线 P = lambda*v + eta（kW）
model.eta = -500;           % 线性功率曲线截距（kW）
model.hoursPerYear = 8760;  % 年小时数，用于把功率换算成 AEP

% ---- 场区尺寸 ----
% 若 XML 缺少标签或数值非法，则回退到默认值。
model.width = read_number(doc, 'Width', 7000);
model.height = read_number(doc, 'Height', 14000);

% ---- 风况：每个 <angle> 节点对应一个风向 ----
angleNodes = doc.getElementsByTagName('angle');
nAngles = angleNodes.getLength();
model.wind.c = zeros(nAngles, 1);      % Weibull 尺度参数 c（m/s）
model.wind.k = zeros(nAngles, 1);      % Weibull 形状参数 k
model.wind.omega = zeros(nAngles, 1);  % 风向频率权重（未归一化）
model.wind.theta = zeros(nAngles, 1);  % 风向角（度）
for i = 1:nAngles
    node = angleNodes.item(i-1);       % Java 节点索引从 0 开始
    model.wind.c(i) = str2double(char(node.getAttribute('c')));
    model.wind.k(i) = str2double(char(node.getAttribute('k')));
    model.wind.omega(i) = str2double(char(node.getAttribute('omega')));
    model.wind.theta(i) = str2double(char(node.getAttribute('theta')));
end

% ---- 障碍物：轴对齐矩形 ----
obstacleNodes = doc.getElementsByTagName('obstacle');
nObstacles = obstacleNodes.getLength();
model.obstacles = zeros(nObstacles, 4);
for i = 1:nObstacles
    node = obstacleNodes.item(i-1);
    model.obstacles(i, :) = [str2double(char(node.getAttribute('xmin'))), ...
        str2double(char(node.getAttribute('ymin'))), ...
        str2double(char(node.getAttribute('xmax'))), ...
        str2double(char(node.getAttribute('ymax')))];
end

% ---- 成本参数（示例值）----
% 这些数值只影响 LCOE 的相对比较；换成真实报价时整体替换 model.cost 即可。
model.cost = struct( ...
    'capexPerTurbine', 750000, ...   % 单台风机初始投资（元）
    'fixedCost', 0, ...              % 与台数无关的固定投资（元）
    'omPerTurbineYear', 20000, ...   % 单台年运维成本（元/年）
    'cablePerMeter', 500, ...        % 单位长度电缆成本（元/m）
    'lifeYears', 20, ...             % 项目寿命（年）
    'discountRate', 0.03, ...        % 折现率
    'decommissionRate', 0.10);       % 退役成本占初始投资比例
end

function value = read_number(doc, tagName, defaultValue)
% READ_NUMBER 读取 XML 中某个标签的数值；缺失或非法时返回默认值。
nodes = doc.getElementsByTagName(tagName);
if nodes.getLength() == 0
    value = defaultValue;
    return;
end
value = str2double(char(nodes.item(0).getTextContent()));
if isnan(value)
    value = defaultValue;
end
end
