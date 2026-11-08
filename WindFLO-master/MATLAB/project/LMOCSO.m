function result=LMOCSO(problem,options)
% LMOCSO WindFLO adapter of Tian et al., IEEE Trans. Cybernetics 2020.
% Copyright (c) 2026 BIMK Group (upstream algorithm); acknowledge PlatEMO
% and the original paper in publications. See third_party/platemo_lmocso.
if nargin<2, options=struct(); end
d=problem.dimension; requested=opt(options,'popSize',100);
budget=opt(options,'maxFE',10000); capacity=opt(options,'archiveSize',100);
verbose=opt(options,'verbose',true);
validateattributes(d,{'numeric'},{'scalar','integer','positive','finite'});
validateattributes(requested,{'numeric'},{'scalar','integer','>=',3,'finite'});
validateattributes(budget,{'numeric'},{'scalar','integer','positive','finite'});
validateattributes(capacity,{'numeric'},{'scalar','integer','positive','finite'});
if (isfield(problem,'lower') && any(problem.lower~=0)) || ...
        (isfield(problem,'upper') && any(problem.upper~=1))
    error('LMOCSO:Bounds','LMOCSO requires normalized [0,1] variables.');
end
[vectors,n]=lmocso_vectors(requested);
assert(budget>=n,'LMOCSO:Budget','Budget must cover the adjusted initial population (%d).',n);
evaluations=0; cacheHits=0; generation=0; archive=[];
history=struct('evaluations',[],'archiveSize',[],'ideal',zeros(0,3), ...
    'fronts',{{}},'populationSize',[],'count',0);
population=evaluate(rand(n,d),zeros(n,d));
population=select(population); publish();
while evaluations<budget
    generation=generation+1;
    fitness=lmocso_fitness(population.fitness); count=size(population.keys,1);
    if count>=2, rank=randperm(count,2*floor(count/2)); else, rank=[1,1]; end
    loser=rank(1:end/2); winner=rank(end/2+1:end);
    change=fitness(loser)>=fitness(winner);
    temp=winner(change); winner(change)=loser(change); loser(change)=temp;
    [x,velocity]=lmocso_variation(population.keys(loser,:),population.keys(winner,:), ...
        population.velocity(loser,:),population.velocity(winner,:));
    offspring=evaluate(x,velocity);
    names=fieldnames(population); pool=population;
    for k=1:numel(names), pool.(names{k})=[population.(names{k});offspring.(names{k})]; end
    population=select(pool); publish();
    if verbose && (generation==1 || mod(generation,10)==0 || evaluations==budget)
        fprintf('LMOCSO generation %d, FE=%d/%d, population=%d, archive=%d\n', ...
            generation,evaluations,budget,size(population.keys,1),size(archive.fitness,1));
    end
end
id=mo_representative(archive.fitness);
result=struct('name','LMOCSO','archive',archive,'population',population, ...
    'representative',struct('keys',archive.keys(id,:),'layout',archive.layouts{id}, ...
        'selected',archive.selected{id},'objectives',archive.fitness(id,:), ...
        'detail',archive.details{id}),'history',history,'evaluations',evaluations, ...
    'cacheHits',cacheHits,'generations',generation);
result.best=result.representative;
result.parameters=struct('framework','platemo-lmocso-adapter-v1', ...
    'sourceCommit','e2d58cb4850acf1af5c48dffb669e86e9a89da9e', ...
    'requestedPopSize',requested,'initialPopSize',n,'referenceVectors',vectors, ...
    'thetaExponent',2,'mutationEta',20);
    function p=evaluate(x,velocity)
        count=min(size(x,1),budget-evaluations);
        x=min(1,max(0,x(1:count,:))); velocity=velocity(1:count,:);
        [f,details,layouts,selected,hits]=windflo_evaluate_population(x,problem);
        assert(size(f,2)==3,'LMOCSO:Objectives','The adapter requires three objectives.');
        evaluations=evaluations+count; cacheHits=cacheHits+hits;
        p=struct('keys',x,'fitness',f,'velocity',velocity, ...
            'details',{details},'layouts',{layouts},'selected',{selected});
    end
    function p=select(p)
        ids=lmocso_environmental_selection(p.fitness,vectors,(evaluations/budget)^2);
        if isempty(ids), error('LMOCSO:NoFeasibleSolution','No finite solutions after layout repair.'); end
        fields=fieldnames(p);
        for j=1:numel(fields), p.(fields{j})=p.(fields{j})(ids,:); end
    end
    function publish()
        archive=mo_update_archive(archive,population.keys,population.fitness, ...
            population.details,population.layouts,population.selected,capacity);
        k=history.count+1; history.count=k;
        history.evaluations(k,1)=evaluations;
        history.archiveSize(k,1)=size(archive.fitness,1);
        history.ideal(k,:)=min(archive.fitness,[],1);
        history.fronts{k,1}=archive.fitness;
        history.populationSize(k,1)=size(population.keys,1);
        if isfield(options,'progressFcn'), options.progressFcn(archive,history,evaluations,cacheHits); end
    end
end
function value=opt(s,name,default)
if isfield(s,name), value=s.(name); else, value=default; end
end
