function [Uz1,Sz1,Vz1]=recsvd_fop(zk,zp,Uz0,Sz0,Vz0,a,nn)
% recsvd_v1:   
%           recursively update singular value decomposition procedure
%           based on the 'future' measurement sample zk, the 'past'
%           measurement sample zp and related initial conditions.
%
% Call: 
%           [Uz1,Sz1,Vz1]=recsvd_fop(zk,zp,Uz0,Sz0,Vz0,a,nn)
%
% Input:    [zk,zp,Uz0,Sz0,Vz0,a,nn]
%       
%           zk   - A s*(l+m)-by-1 vector, which denotes 'future'
%                  measurement sample. (s is the order of parity vector,
%                  see reference.)
%           zp   - A s*(l+m)-by-1 vector, which denotes the 'past'
%                  measurement sample.
%           Uz0  - A s*(l+m)-by-s*(l+m) matrix, which denotes the initial
%                  left singular matrix.
%           Sz0  - A s*(l+m)-by-s*(l+m) matrix, which contains the initial
%                  singular values in descending order.
%           Vz0  - A s*(l+m)-by-s*(l+m) matrix, which denotes the initial
%                  right singular vectors.
%           a    - A scalar denotes the forgetting factor.
%           nn   - A scalar denotes the number of significant singular
%                  values.     
%      
% Output:   [Uz1,Sz1,Vz1]
%       
%           Uz1  - A s*(l+m)-by-s*(l+m) matrix, which denotes the updated
%                  left singular matrix.
%           Sz1  - A s*(l+m)-by-s*(l+m) matrix, which contains the updated
%                  singular values in descending order.
%           Vz1  - A s*(l+m)-by-s*(l+m) matrix, which denotes the updated
%                  right singular vectors.
%         
% Notes: NONE
%
% Required M-Files: NONE
% 
% Reference: A. Naik, S. Yin and S.X. Ding (2009), "Recursive identification
%            algorithms to design fault detection system", 7th IFAC 
%            symposium on fault detection, supervision and safety of
%            technical processes, Juli, Barcelona.
%
% -------------------------------------------------------------------------
% University of Duisburg-Essen (Campus Duisburg)
% Faculty of Engineering
% Institute for Automatic Control and Complex Systems (AKS)
% Bismarckstr. 81
% D-47057 Duisburg, Germany
%
% Tel:    +49 203 379 42 93
% Fax:    +49 203 379 29 28
% -------------------------------------------------------------------------

%
% History:
%       09.April 2010 - File "recsvd_v1.m" created by AKS.
% #########################################################################
% Start "recsvd_v1"

%--------------------------------------------------------------------------
% initialize the algorithm
Uz0=Uz0(:,1:nn);
Sz0=Sz0(1:nn,1:nn);
Vz0=Vz0(:,1:nn);
zk_1=sqrt(1-a)*Uz0'*zk;
zv_1=sqrt(1-a)*Vz0'*zp;
pu=sqrt(1-a)*zk;
qu=zeros(size(zk,1),1);

%--------------------------------------------------------------------------
% update the left singular vector
Uz_1=zeros(size(Uz0));
for i=1:nn-1
    pu=pu-zk_1(i,:)*Uz0(:,i);
    qu=qu+(zv_1(i,:)/Sz0(i,i))*Uz0(:,i);
    Uz_1(:,i)=Uz0(:,i)+(zv_1(i,:)*pu/Sz0(i,i))-zk_1(i,:)*qu;  
end
Uz_1(:,nn)=Uz0(:,nn)-zk_1(nn,:)*qu;

%--------------------------------------------------------------------------
% update the right singular vector
pv=sqrt(1-a)*zp;
qv=zeros(size(zp,1),1);
Vz_1=zeros(size(Vz0));
for j=1:nn-1   
    pv=pv-zv_1(j,:)*Vz0(:,j);
    qv=qv+(zk_1(j,:)/Sz0(j,j))*Vz0(:,j);
    Vz_1(:,j)=Vz0(:,j)+zk_1(j,:)*pv-zv_1(j,:)*qv;    
end
Vz_1(:,nn)=Vz0(:,nn)-zv_1(nn,:)*qv;

%--------------------------------------------------------------------------
% update singular values and normalize singular vectors
for h=1:nn
    Sz_1=a*Sz0(h,h)+(1-a)*Uz0(:,h)'*zk*zp'*Vz0(:,h);
    Sz(h,h)=abs(Sz_1);
    Uz(:,h)=Sz_1*Uz_1(:,h)./norm(Sz_1*Uz_1(:,h));
    Vz(:,h)=Vz_1(:,h)./norm(Vz_1(:,h));    
end
Sz = diag(Sz);
[Sz1,I] = sort(Sz,'descend');
Sz1 = diag(Sz1);
Uz_sorted = zeros(size(Uz));
Vz_sorted = zeros(size(Vz));
for d = 1:nn
    ind = I(d);
    Uz_sorted(:,d) = Uz(:,ind);
    Vz_sorted(:,d) = Vz(:,ind);
end   
Uz1=Uz_sorted;
Vz1=Vz_sorted;

%--------------------------------------------------------------------------
% End "recsvd_v1"
% #########################################################################