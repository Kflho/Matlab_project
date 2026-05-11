function r_s=res_three(u,y,y_false,A,B,C,D,s,Alpha)
% [~,~]=size(C);
[m,r]=size(D);
Z=zeros(m,r);
Gamma_s=cell(s,1);
for i=1:1:s
Gamma_s{i,1}=C*A^(i-1);
end

Gamma_s=cell2mat(Gamma_s);

% Gamma_s_left1=eye(m*s)-Gamma_s*inv(Gamma_s'*Gamma_s)*Gamma_s';
Gamma_s_left2=eye(m*s)-Gamma_s*((Gamma_s'*Gamma_s)\Gamma_s');
Gamma_s_left=(null(Gamma_s'))';
% a=Gamma_s_left2(3,:)*h;
H=cell(s,s);
h=cell(s,1);
for i=1:s
    h{i}=C*A^(i-1)*B;%h(1)=C*B,h(2)=C*A*B
    H{i,i}=D;
end
for j=1:s-1
    for i=1:s-1
        if i+j<s+1 && i<s+1
           H{i+j,i}=h{j};
           H{i,i+j}=Z;
        end
    end
end
H=cell2mat(H);

v_s=Gamma_s_left2(3,:);
% v_s=Gamma_s_left2;

L=length(u)/s;
L=round(L)-1;
y_s=cell(s,L);
u_s=cell(s,L);
for i=1:L
    for j=1:s
        y_s{j,i}=y(:,j+s*(i-1));
        u_s{j,i}=u(:,j+s*(i-1));   
    end
end
y_s=cell2mat(y_s);

% for i=1:length(y_s)
%     y_s(:,i)=y_s(:,i)+0.3*Alpha;      %注入攻击
% end
% for i=1:712
%     y_s(:,i)=y_s(:,i)+Alpha;      %注入攻击
% end
u_s=cell2mat(u_s);
r_s=v_s*y_s-v_s*H*u_s;

% v_s=[-0.3717,0.0606,-0.0423,0.7175,0.1338,0.0038,-0.1150,...
%     -0.1324,0.0034,-0.1152,-0.3999,0.004,-0.1155,0.3260,0.0056];

% QRS=2.747678755748043e-11;
% J_th=9.0509;


% % r_s=r_s(2000:end);
% % t=1:L;
% % r_s=(r_s.^2)/(2*QRS);
% t=1:length(r_s);
% plot(t,r_s,'b','LineWidth',0.5);
% % legend('测试统计量');
% hold on
% % J=zeros(1,length(t));
% % J=J+J_th;
% % plot(t,J,'--k','LineWidth',0.5);
% % legend('测试统计量','阈值')
% end