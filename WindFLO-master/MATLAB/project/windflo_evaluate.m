function [objectives, detail] = windflo_evaluate(layout, model, wakeFreeAEP)
% WINDFLO_EVALUATE 单个布局的三目标评价（第 11 步）。
%
% 三个目标全部按最小化处理：
%   f1 = -AEP       年发电量（kWh），取负号把“越大越好”变成最小化
%   f2 = LCOE       平准化度电成本（元/kWh），越小越好
%   f3 = CVaR95     最差 5% 机组的平均尾流损失，越小说明损失越均匀
%
% 尾流计算（每个风向独立）：
%   1) 把坐标差投影到顺风/横风方向；
%   2) 顺风距离 > 0 且横风距离 <= R + kw*x 的风机受上游影响；
%   3) 单次亏损 = (1-sqrt(1-CT)) / (1+kw*x/R)^2；
%   4) 多台上游的亏损按平方和开方叠加（Katic 风格）；
%   5) 风机的有效来流 c_i = c * (1 - 总亏损)，再算期望功率。
%
% 输入：
%   layout      N×2 实际坐标（m）
%   model       windflo_model 的输出
%   wakeFreeAEP 可选；无尾流时单机年发电量，用于 CVaR 的损失基准，
%               省略时现场重算。

detail = empty_detail();
if ~windflo_check_layout(layout, model)
    objectives = [inf, inf, inf];
    detail.violation = 1;
    return;
end

n = size(layout,1);
nDir = length(model.wind.c);
omega = model.wind.omega(:);
omega = omega / sum(omega);              % 风向概率
theta = model.wind.theta(:) * pi / 180;  % 角度转弧度

% dx(i,j)、dy(i,j) 表示风机 i 相对风机 j 的坐标差。
dx = layout(:,1) - layout(:,1)';
dy = layout(:,2) - layout(:,2)';
deficitAll = zeros(n,nDir);              % 每台风机在每个风向下的总亏损

for d = 1:nDir
    % 把相对位置投影到该风向的顺风、横风轴。
    downwind = dx*cos(theta(d)) + dy*sin(theta(d));
    crosswind = abs(-dx*sin(theta(d)) + dy*cos(theta(d)));
    % 尾流区随顺风距离线性扩张。
    wakeRadius = model.R + model.kw*downwind;
    wake = downwind > 0 & crosswind <= wakeRadius;
    % 单次尾流亏损；上游越远，恢复越多。
    oneLoss = (1-sqrt(1-model.CT)) ./ ...
        (1 + model.kw*max(downwind,0)/model.R).^2;
    oneLoss(~wake) = 0;
    % 多台上游的亏损按平方和开方叠加。
    deficitAll(:,d) = sqrt(sum(oneLoss.^2,2));
end

% 总亏损达到 1 说明模型已失效（有效风速 <= 0），视为不可行。
if any(deficitAll(:) >= 1)
    objectives = [inf, inf, inf];
    detail.violation = 2;
    return;
end

% 各风机在各风向下的有效 Weibull 尺度参数；形状参数 k 保持不变。
c = repmat(model.wind.c(:)',n,1) .* (1-deficitAll);
k = repmat(model.wind.k(:)',n,1);
power = windflo_expected_power(c,k,model);
aepByTurbine = model.hoursPerYear * sum(power.*omega',2);
aep = sum(aepByTurbine);

% 无尾流基准：用于把“每台机的损失”归一化成比例。
if nargin < 3 || isempty(wakeFreeAEP)
    wakeFreePower = windflo_expected_power( ...
        model.wind.c(:)',model.wind.k(:)',model);
    wakeFreeAEP = model.hoursPerYear*sum(omega'.*wakeFreePower);
end
lossRatio = max(0,1-aepByTurbine/max(wakeFreeAEP,eps));
cvar95 = upper_cvar(lossRatio,0.95);
lcoe = windflo_lcoe(layout,aep,model);

objectives = [-aep,lcoe,cvar95];
detail.feasible = true;
detail.violation = 0;
detail.AEP = aep;
detail.LCOE = lcoe;
detail.CVaR95 = cvar95;
detail.wakeLoss = lossRatio;
detail.energyByTurbine = aepByTurbine;
detail.wakeDeficit = deficitAll;
end

function value = upper_cvar(losses,alpha)
% UPPER_CVAR 离散样本的上尾 CVaR（条件风险价值）。
%
% alpha=0.95 表示只看最差 5% 的机组。若尾部质量不是整数个样本，
% 对分位点处的样本按小数比例线性计入，避免结果随样本数突变。
losses = sort(losses(:),'descend');
tailMass = (1-alpha)*length(losses);   % 尾部包含的“样本个数”
whole = floor(tailMass);
fraction = tailMass-whole;
if whole == 0
    value = losses(1);                 % 样本太少，退化为最差个体
elseif whole >= length(losses)
    value = mean(losses);
else
    total = sum(losses(1:whole)) + fraction*losses(whole+1);
    value = total/tailMass;
end
end

function lcoe = windflo_lcoe(layout,aep,model)
% WINDFLO_LCOE 平准化度电成本：总现值成本 / 总现值发电量。
cost = model.cost;
% 年金现值因子：把每年运维成本折算到建设期。
pvFactor = sum(1./(1+cost.discountRate).^(1:cost.lifeYears));
capex = cost.capexPerTurbine*size(layout,1) + cost.fixedCost;
% 用最小生成树长度近似场内集电电缆总长。
cableCapex = cost.cablePerMeter*mst_length(layout);
annualOM = cost.omPerTurbineYear*size(layout,1);
% 退役成本发生在寿命末，按末年折现。
decommission = cost.decommissionRate*capex / ...
    (1+cost.discountRate)^cost.lifeYears;
pvCost = capex + cableCapex + pvFactor*annualOM + decommission;
lcoe = pvCost/max(aep*pvFactor,eps);
end

function total = mst_length(points)
% MST_LENGTH 用 Prim 算法求风机间最小生成树长度，作为电缆长度估计。
n = size(points,1);
if n <= 1, total = 0; return; end
dx = points(:,1)-points(:,1)';
dy = points(:,2)-points(:,2)';
D = sqrt(dx.^2+dy.^2);
used = false(n,1);       % 已加入树的点
used(1) = true;
best = inf(n,1);         % 每个未用点到树的最短边
best = min(best,D(:,1));
best(1) = inf;
total = 0;
for t = 2:n
    [edge,id] = min(best);
    if ~isfinite(edge), error('最小生成树计算失败。'); end
    total = total+edge;
    used(id) = true;
    best(id) = inf;
    newDistance = D(:,id);
    update = ~used & newDistance < best;
    best(update) = newDistance(update);
end
end

function detail = empty_detail()
% EMPTY_DETAIL 评价失败时的默认细节结构。
detail = struct('feasible',false,'violation',inf,'AEP',0,'LCOE',inf, ...
    'CVaR95',inf,'wakeLoss',[],'energyByTurbine',[],'wakeDeficit',[]);
end
