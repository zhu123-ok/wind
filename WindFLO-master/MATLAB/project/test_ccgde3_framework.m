function passed = test_ccgde3_framework()
% Regression checks for independent species, contexts, and exact FE budgets.
here = fileparts(mfilename('fullpath'));
model = windflo_model(fullfile(here,'..','..','Scenarios','00.xml'),4);
problem = windflo_prepare_continuous_problem(model,false);
options = struct('popSize',10,'subPopSize',4,'numGroups',2, ...
    'maxFE',8,'verbose',false);
rng(17);
initial = run_algorithm('CCGDE3',problem,options);
options.maxFE = 12;
rng(17);
oneUpdate = run_algorithm('CCGDE3',problem,options);
% Evolving species 1 must not select away or overwrite species 2.
assert(isequal(initial.subpopulations(2),oneUpdate.subpopulations(2)));
assert(oneUpdate.evaluations == 12);

% Budget ends partway through the last offspring batch.
options.maxFE = 43;
rng(17);
output = run_algorithm('CCGDE3',problem,options);
assert(output.evaluations == 43 && output.history.evaluations(end) == 43);
assert(numel(output.subpopulations) == 2);
assert(all(diff(output.history.evaluations) > 0));
for g = 1:2
    species = output.subpopulations(g);
    assert(size(species.keys,1) == 4);
    % Stored fitness must describe the evaluated complete collaboration.
    [fitness,~,layouts] = windflo_evaluate_population(species.keys,problem);
    assert(isequal(fitness,species.fitness));
    assert(isequal(layouts,species.layouts));
end
rng(17);
repeat = run_algorithm('CCGDE3',problem,options);
assert(isequal(output.archive.fitness,repeat.archive.fitness));
assert(isequal(output.subpopulations,repeat.subpopulations));

options.groupCoordinates = true;
options.numGroups = 4;
options.maxFE = 33;
options.regroupPeriod = 1;
rng(17);
paired = run_algorithm('CCGDE3',problem,options);
assert(isequal(paired.groupId(1:2:end),paired.groupId(2:2:end)));
assert(paired.evaluations == 33);

% Shared NSGA-II crossover settings must not override explicit CCGDE3 settings.
options = struct('popSize',10,'maxFE',12,'crossRate',0.9, ...
    'verbose',false,'ccgde3',struct('subPopSize',4,'crossRate',0.5));
configured = run_algorithm('CCGDE3',problem,options);
assert(configured.parameters.crossRate == 0.5);
assert(configured.parameters.regroupPeriod == 0);
assert(strcmp(configured.parameters.framework,'independent-species-v1'));
passed = true;
fprintf('CCGDE3 independent-species regression checks passed.\n');
end
