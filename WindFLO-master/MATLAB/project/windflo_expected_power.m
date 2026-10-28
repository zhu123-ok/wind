function power = windflo_expected_power(c, k, model)
% WINDFLO_EXPECTED_POWER 计算 Weibull 风速下的期望功率。
%
% 把风速轴按 0.25 m/s 离散，用 Weibull 累积分布之差作为该区间的概率，
% 再乘以区间中点对应的功率，累加得到期望功率。
%
% 功率曲线：
%   切入 ~ 额定：P = lambda*v + eta（线性段，负值截为 0）
%   额定 ~ 切出：P = PRated
%   其余风速：  P = 0
%
% c、k 可以是相同尺寸的矩阵，便于一次计算“风机×风向”的期望功率；
% k 为标量时会自动扩展到 c 的尺寸。

if ~isequal(size(c), size(k))
    if isscalar(k)
        k = repmat(k, size(c));
    else
        error('c 和 k 的尺寸必须相同。');
    end
end
if any(c(:) <= 0)
    error('Weibull 尺度参数必须大于 0。');
end

% 0.25 m/s 的积分步长；mid 是每个区间的中点风速。
edges = 0:0.25:model.vCout;
mid = (edges(1:end-1) + edges(2:end)) / 2;
turbinePower = zeros(size(mid));
% 线性功率段：只保留切入到额定之间的风速。
id = mid >= model.vCin & mid <= model.vRated;
turbinePower(id) = max(0, model.lambda*mid(id) + model.eta);
% 额定功率段：额定到切出之间保持满发。
id = mid > model.vRated & mid < model.vCout;
turbinePower(id) = model.PRated;

power = zeros(size(c));
% Weibull 累积分布 F(v) = 1 - exp(-(v/c)^k)；
% 区间概率 = F(上界) - F(下界)。
for v = 1:length(mid)
    f1 = 1 - exp(-(edges(v) ./ c).^k);
    f2 = 1 - exp(-(edges(v+1) ./ c).^k);
    power = power + turbinePower(v) .* (f2 - f1);
end
end
