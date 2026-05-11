function [H_s,U,S,V,var_s,phi0]=Att(u,y,s)
[m,~]=size(y);
[l,~]=size(u);
p=s;
f=s;
n=3;
L=length(u)/s;
L=round(L)-1;
y_s=cell(s,L);
u_s=cell(s,L);
for k=1:L
    for j=1:s
        y_s{j,k}=y(:,j+s*(k-1));
        u_s{j,k}=u(:,j+s*(k-1));   
    end
end
y_s=cell2mat(y_s);
u_s=cell2mat(u_s);
L=length(u_s);
Y_p=y_s(:,1:L/2);
Y_f=y_s(:,L/2+1:L);
U_p=u_s(:,1:L/2);
U_f=u_s(:,L/2+1:L);
Z_p=[Y_p;U_p];
Z_f=[Y_f;U_f];
phi0=Z_f*Z_p';
[U,S,V]=svd(phi0);
% U11=U(1:m*f,1:l*f+n);
U12=U(1:m*f,l*f+n+1:end);
% U21=U(m*f+1:end,1:l*f+n);
% U22=U(16:end,l*f+n+1:end);
U2=U(:,l*f+n+1:end);
Gama_s_left=U12';
H_s=null(Gama_s_left);
noise_s=U2'*Z_f;
% var_s=var(noise_s);
var_s=(noise_s*noise_s')/(L/2-1);
var_s=min(mean(abs(var_s)));
% [Uz1,Sz1,Vz1]=recsvd(zk,zp,Uz0,Sz0,Vz0,0.9,s*l+n);
end   

% function [Uz1,Sz1,Vz1]=recsvd(zk,zp,Uz0,Sz0,Vz0,a,nn)
% % initialize the algorithm
% Uz0=Uz0(:,1:nn);
% Sz0=Sz0(1:nn,1:nn);
% Vz0=Vz0(:,1:nn);
% zk_1=sqrt(1-a)*Uz0'*zk;
% zv_1=sqrt(1-a)*Vz0'*zp;
% pu=sqrt(1-a)*zk;
% qu=zeros(size(zk,1),1);
% %--------------------------------------------------------------------------
% % update the left singular vector
% Uz_1=zeros(size(Uz0));
% for i=1:nn-1
%     pu=pu-zk_1(i,:)*Uz0(:,i);
%     qu=qu+(zv_1(i,:)/Sz0(i,i))*Uz0(:,i);
%     Uz_1(:,i)=Uz0(:,i)+(zv_1(i,:)*pu/Sz0(i,i))-zk_1(i,:)*qu;  
% end
% Uz_1(:,nn)=Uz0(:,nn)-zk_1(nn,:)*qu;
% 
% %--------------------------------------------------------------------------
% % update the right singular vector
% pv=sqrt(1-a)*zp;
% qv=zeros(size(zp,1),1);
% Vz_1=zeros(size(Vz0));
% for j=1:nn-1   
%     pv=pv-zv_1(j,:)*Vz0(:,j);
%     qv=qv+(zk_1(j,:)/Sz0(j,j))*Vz0(:,j);
%     Vz_1(:,j)=Vz0(:,j)+zk_1(j,:)*pv-zv_1(j,:)*qv;    
% end
% Vz_1(:,nn)=Vz0(:,nn)-zv_1(nn,:)*qv;
% 
% %--------------------------------------------------------------------------
% % update singular values and normalize singular vectors
% for h=1:nn
%     Sz_1=a*Sz0(h,h)+(1-a)*Uz0(:,h)'*zk*zp'*Vz0(:,h);
%     Sz(h,h)=abs(Sz_1);
%     Uz(:,h)=Sz_1*Uz_1(:,h)./norm(Sz_1*Uz_1(:,h));
%     Vz(:,h)=Vz_1(:,h)./norm(Vz_1(:,h));    
% end
% Sz = diag(Sz);
% [Sz1,I] = sort(Sz,'descend');
% Sz1 = diag(Sz1);
% Uz_sorted = zeros(size(Uz));
% Vz_sorted = zeros(size(Vz));
% for d = 1:nn
%     ind = I(d);
%     Uz_sorted(:,d) = Uz(:,ind);
%     Vz_sorted(:,d) = Vz(:,ind);
% end   
% Uz1=Uz_sorted;
% Vz1=Vz_sorted;
% 
% %--------------------------------------------------------------------------
% end

