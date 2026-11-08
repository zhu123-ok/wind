function ids=lmocso_environmental_selection(f,v,theta)
% PlatEMO LMOCSO: first nondominated layer, one minimum-APD point per ray.
% Shared WindFLO repair represents infeasibility by nonfinite objectives.
valid=find(all(isfinite(f),2));
if isempty(valid), ids=zeros(0,1); return; end
valid=valid(mo_non_dominated_sort(f(valid,:))==1);
f=f(valid,:); f=f-min(f,[],1);
v=v./sqrt(sum(v.^2,2));
cosine=max(-1,min(1,v*v')); cosine(1:size(v,1)+1:end)=0;
gamma=max(min(acos(cosine),[],2),eps);
norms=sqrt(sum(f.^2,2));
cosine=(f./max(norms,eps))*v';
angle=acos(max(-1,min(1,cosine)));
% An exact ideal point has no direction. Retain it deterministically on ray 1.
angle(norms==0,:)=0;
[~,associate]=min(angle,[],2);
next=zeros(size(v,1),1);
for i=unique(associate)'
    current=find(associate==i);
    apd=(1+size(f,2)*theta*angle(current,i)/gamma(i)).*norms(current);
    [~,best]=min(apd); next(i)=valid(current(best));
end
ids=next(next~=0);
end
