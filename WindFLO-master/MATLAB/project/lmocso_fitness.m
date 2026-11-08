function fitness=lmocso_fitness(f)
% PlatEMO LMOCSO shift-based density: larger values win competitions.
% Constant objectives carry zero distance (upstream division-by-zero guard).
n=size(f,1);
f=(f-min(f,[],1))./max(max(f,[],1)-min(f,[],1),eps);
fitness=inf(n,1);
for i=1:n
    distance=sqrt(sum((max(f,f(i,:))-f(i,:)).^2,2));
    distance(i)=inf; fitness(i)=min(distance);
end
end
