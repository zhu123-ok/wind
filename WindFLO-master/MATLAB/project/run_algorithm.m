function result = run_algorithm(name, problem, varargin)
% RUN_ALGORITHM 多目标算法的统一入口。
%
% 推荐接口：run_algorithm(name, problem, options)
% 兼容接口：run_algorithm(name, model, candidates, options)
%
% 按算法名称分派到 CCGDE3 或 NSGA2，使实验脚本不必关心具体实现。

if nargin >= 4
    % 旧接口：第二个参数是 model，第三个是候选点集合。
    model = problem;
    candidates = varargin{1};
    options = varargin{2};
    problem = windflo_prepare_problem(model,candidates,true);
elseif nargin == 3
    options = varargin{1};
else
    options = struct();
end
switch lower(name)
    case {'ccgde3', 'ccg-de3'}
        result = CCGDE3(problem,options);
    case {'nsga2', 'nsga-ii'}
        result = NSGA2(problem,options);
    otherwise
        error('未知算法：%s。可用算法为 CCGDE3 或 NSGA2。',name);
end
end
