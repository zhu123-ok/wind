function [fitness,details,layouts,selected,hits]=windflo_evaluate_population(keys,~)
% Test-only deterministic evaluator; never add this folder in experiments.
global PLATEMO_AUDIT_KEYS
PLATEMO_AUDIT_KEYS=[PLATEMO_AUDIT_KEYS;keys];
n=size(keys,1);
fitness=[sum(keys,2),sum((keys-.5).^2,2),sum((keys-1).^2,2)];
details=cell(n,1); layouts=cell(n,1); selected=cell(n,1);
for i=1:n
    details{i}=struct('feasible',true,'violation',0);
    layouts{i}=[(1:size(keys,2))',keys(i,:)'];
    selected{i}=(1:size(keys,2))';
end
hits=0;
end
