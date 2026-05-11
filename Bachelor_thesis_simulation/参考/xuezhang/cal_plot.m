function J=cal_plot(u,y,r_s,N)
f1=figure(1);
t_y=2:2:2*length(y);
plot(t_y,y);
grid minor
legend('液位一','液位二','液位三')
xlabel('t/s');
ylabel('h/cm');
set(f1,'Color','w');
f2=figure(2);
t_u=2:2:2*length(u);
plot(t_u,u);
legend('输入信号1','输入信号2')
xlabel('t/s');
ylabel('Q/(cm^3/s)');
set(f2,'Color','w');
f3=figure(3);
t_r=8:8:8*length(r_s);
plot(t_r,r_s,'b','LineWidth',0.5);
legend('r_s');
xlabel('t/s');
ylabel('残差');
set(f3,'Color','w');
f4=figure(4);
Xigema_r=1.4644e-06;%1.3643e-06/0.0056%1.4593e-06/0.0056
% J_th=3.841/2; %0.05
J_th=10.83/2;

% J_th=8.641/2;

L_rs=round(length(r_s)/N);
[m,~]=size(r_s);
J=zeros(m,L_rs-1);
for i=1:L_rs-1
    for j=1:N
        J(:,i)=J(:,i)+(r_s(:,(i-1)*N+j));
    end
    % J(:,i)=sqrt(J(:,i)/N);

end
mean_r_s=mean(r_s(1:600));
J=(J-mean_r_s*N).^2/(2*N*Xigema_r);


% J=(r_s-mean_r_s).^2/2;
% J_th=max(J);

% J=(J-0.0302*N).^2/(2*N*Xigema_r);
% J=(J-0.0056*N).^2/(2*N*Xigema_r);
% J=(J).^2/(2*N*Xigema_r);
t_J=N*(8:8:8*length(J));

plot(t_J,J,'b','LineWidth',0.5);

hold on
Z=zeros(1,length(J));
J_th=Z+J_th;
plot(t_J,J_th,'--k','LineWidth',0.5);
xlabel('t/s');
ylabel('T^2检验统计量');
legend('检验统计量','阈值')
set(f4,'Color','w');
f5=figure(5);
subplot(2,2,1)
plot(t_y,y);
legend('水箱一','水箱二','水箱三')
xlabel('t/s');
ylabel('h/cm');
title('图（a）:系统状态');
subplot(2,2,2)
plot(t_u,u);
legend('输入信号1','输入信号2')
xlabel('t/s');
ylabel('Q/(cm^3/s)');
title('图（b）:输入信号');
subplot(2,2,3)
t_r=8:8:8*length(r_s);
plot(t_r,r_s,'b','LineWidth',0.5);
legend('r_s');
xlabel('t/s');
ylabel('残差');
title('图（c）:残差');
subplot(2,2,4)
t_J=32:32:32*length(J);
plot(t_J,J,'b','LineWidth',0.5)
hold on
plot(t_J,J_th,'--k','LineWidth',0.5);
xlabel('t/s');
ylabel('T^2检验统计量');
legend('检验统计量','阈值')
title('图（d）:检验统计量')
set(f5,'Color','w');
end


% plot(t,r_s,'b','LineWidth',0.5);
% % legend('测试统计量');
% hold on
% J=zeros(1,length(t));
% J=J+J_th;
% plot(t,J,'--k','LineWidth',0.5);
% legend('测试统计量','阈值')
% xlabel('k');
% ylabel('GLR');
% set(h,'Color','w');