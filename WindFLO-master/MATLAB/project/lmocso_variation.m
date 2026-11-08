function [x,velocity]=lmocso_variation(loser,winner,loserVelocity,winnerVelocity)
% PlatEMO LMOCSO Operator: accelerated CSO, then mutate BOTH competitors.
% Variables are normalized to [0,1]; velocities stay attached to encodings.
[n,d]=size(loser);
r1=repmat(rand(n,1),1,d); r2=repmat(rand(n,1),1,d);
v=r1.*loserVelocity+r2.*(winner-loser);
x=[loser+v+r1.*(v-loserVelocity);winner];
velocity=[v;winnerVelocity];
site=rand(2*n,d)<1/d; mu=rand(2*n,d);
x=min(1,max(0,x));
t=site & mu<=0.5;
x(t)=x(t)+(2*mu(t)+(1-2*mu(t)).*(1-x(t)).^21).^(1/21)-1;
t=site & mu>0.5;
x(t)=x(t)+1-(2*(1-mu(t))+2*(mu(t)-0.5).*x(t).^21).^(1/21);
end
