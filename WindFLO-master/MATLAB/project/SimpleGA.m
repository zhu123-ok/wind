function result = SimpleGA(model,candidates,options)
% SIMPLEGA 旧接口兼容函数。
% 原来的加权和GA不属于规范多目标算法，现统一转到NSGA-II。
warning('SimpleGA 已弃用，当前调用将转到 NSGA-II。');
if nargin < 3, options = struct(); end
problem = windflo_prepare_problem(model,candidates,true);
result = NSGA2(problem,options);
end
