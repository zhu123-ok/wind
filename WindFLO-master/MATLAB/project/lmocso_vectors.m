function [v,n]=lmocso_vectors(n)
% Three-objective NBI branch of PlatEMO UniformPoint (see third_party).
m=3; h1=1;
while nchoosek(h1+m,m-1)<=n, h1=h1+1; end
v=layer(h1,m);
if h1<m
    h2=0;
    while nchoosek(h1+m-1,m-1)+nchoosek(h2+m,m-1)<=n, h2=h2+1; end
    if h2>0, v=[v;layer(h2,m)/2+1/(2*m)]; end
end
v=max(v,1e-6); n=size(v,1);
end
function v=layer(h,m)
v=nchoosek(1:h+m-1,m-1)-repmat(0:m-2,nchoosek(h+m-1,m-1),1)-1;
v=([v,zeros(size(v,1),1)+h]-[zeros(size(v,1),1),v])/h;
end
