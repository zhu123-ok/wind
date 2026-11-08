function passed=test_lmocso()
% Mathematical/operator parity and integration contracts, not a benchmark.
here=fileparts(mfilename('fullpath')); oldPath=path;
cleanup=onCleanup(@()path(oldPath)); addpath(here);
upstream=fullfile(here,'third_party','platemo_lmocso');
addpath(upstream,'-end');
for requested=[3 4 8 20 100]
    [v,n]=lmocso_vectors(requested); [reference,expectedN]=UniformPoint(requested,3);
    assert(n==expectedN && isequal(v,reference));
end
% Execute the unmodified upstream operator via lightweight interface stubs.
rng(31); x=rand(5,7); y=rand(5,7); vx=randn(5,7); vy=randn(5,7);
loser=struct('decs',x,'adds',@(unused)vx);
winner=struct('decs',y,'adds',@(unused)vy);
problem=struct('lower',zeros(1,7),'upper',ones(1,7), ...
    'Evaluation',@(keys,velocity)struct('keys',keys,'velocity',velocity));
rng(3); expected=Operator(problem,loser,winner);
rng(3); [actual,velocity]=lmocso_variation(x,y,vx,vy);
assert(max(abs(actual(:)-expected.keys(:)))<1e-14);
assert(isequal(velocity,expected.velocity));
rmpath(upstream);
assert(isequal(lmocso_fitness([0 1 1;1 0 1;1 1 0;1 1 1]),[1;1;1;0]));
assert(all(lmocso_fitness(ones(3,3))==0));
assert(isinf(lmocso_fitness([0 0 0])));
% Four nondominated points, axes and an interior vector; dominated and invalid
% rows must be removed, each occupied vector must retain its minimum APD.
f=[0 2 2;2 0 2;2 2 0;1 1 1;3 3 3;inf inf inf];
v=[eye(3);ones(1,3)/sqrt(3)];
for theta=[0 .2 1]
    expected=apd_oracle(f(1:4,:),v,theta);
    assert(isequal(lmocso_environmental_selection(f,v,theta),expected));
end
assert(isequal(lmocso_environmental_selection(ones(3,3),v,.5),1));
assert(isempty(lmocso_environmental_selection(inf(3,3),v,.5)));
addpath(fullfile(here,'tests','platemo_adapter'),'-begin');
global PLATEMO_AUDIT_KEYS
for budget=[6 7 19 137]
    options=struct('popSize',8,'maxFE',budget,'archiveSize',12,'verbose',false);
    rng(7); PLATEMO_AUDIT_KEYS=[];
    out=run_algorithm('LMOCSO',struct('dimension',9),options); trace=PLATEMO_AUDIT_KEYS;
    assert(out.evaluations==budget && size(trace,1)==budget);
    assert(all(trace(:)>=0 & trace(:)<=1));
    assert(out.history.evaluations(end)==budget && all(diff(out.history.evaluations)>0));
    assert(out.parameters.initialPopSize==6 && all(out.history.populationSize<=6));
    assert(all(mo_non_dominated_sort(out.population.fitness)==1));
    assert(isequal(size(out.population.velocity),size(out.population.keys)));
    expected=[sum(out.population.keys,2),sum((out.population.keys-.5).^2,2),sum((out.population.keys-1).^2,2)];
    assert(isequal(out.population.fitness,expected));
    rng(7); PLATEMO_AUDIT_KEYS=[];
    repeated=run_algorithm('lmo-cso',struct('dimension',9),options);
    assert(isequal(trace,PLATEMO_AUDIT_KEYS) && isequal(out.archive.fitness,repeated.archive.fitness));
end
rmpath(fullfile(here,'tests','platemo_adapter'));
model=windflo_model(fullfile(here,'..','..','Scenarios','00.xml'),20);
problem=windflo_prepare_continuous_problem(model,true);
rng(11); out=run_algorithm('LMOCSO',problem,struct('popSize',8,'maxFE',37,'verbose',false));
assert(out.evaluations==37);
for i=1:numel(out.archive.layouts)
    assert(windflo_check_layout(out.archive.layouts{i},model));
    f=windflo_evaluate(out.archive.layouts{i},model,problem.wakeFreeAEPPerTurbine);
    assert(all(abs(f-out.archive.fitness(i,:))<1e-10*max(1,abs(f))));
end
passed=true;
fprintf('LMOCSO passed: upstream operator/NBI parity, SDE/APD, exact FE, reproducibility, real layout feasibility.\n');
end
function ids=apd_oracle(f,v,theta)
% Scalar dot products provide an independent check of vector association/APD.
f=f-min(f,[],1); assoc=zeros(size(f,1),1); angles=zeros(size(f,1),size(v,1));
gamma=zeros(size(v,1),1);
for i=1:size(v,1)
    other=setdiff(1:size(v,1),i); a=zeros(size(other));
    for k=1:numel(other), a(k)=acos(dot(v(i,:),v(other(k),:))/(norm(v(i,:))*norm(v(other(k),:)))); end
    gamma(i)=min(a);
end
for j=1:size(f,1)
    for i=1:size(v,1), angles(j,i)=acos(dot(f(j,:),v(i,:))/(norm(f(j,:))*norm(v(i,:)))); end
    [~,assoc(j)]=min(angles(j,:));
end
ids=[];
for i=1:size(v,1)
    members=find(assoc==i);
    if isempty(members), continue; end
    scores=zeros(size(members));
    for k=1:numel(members)
        j=members(k); scores(k)=norm(f(j,:))*(1+3*theta*angles(j,i)/gamma(i));
    end
    [~,best]=min(scores); ids(end+1,1)=members(best);
end
end
