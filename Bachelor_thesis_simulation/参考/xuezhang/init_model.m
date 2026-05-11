%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Matlab 3-Tank System Example
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
close all;
clear all;
clc;

%--------------------------------------------------------------------------
% system parameters:
%--------------------------------------------------------------------------
A     = 154;      %cm^2
Sn    = 0.5;      %cm^2
Sl    = 0.5;      %cm^2        Querschnittsfl�che Leck
Hmax  = 62;       %cm
Q1max = 100;      %cm^3/sec
Q2max = 100;      %cm^3/sec
az1   = 0.46;     %1
az2   = 0.60;     %1
az3   = 0.45;     %1
g     = 981;      %cm/s^2


Q1rel=1;          %1          Skalierung Zufluss Tank 1 [0..1] 
Q2rel=1;          %1          Skalierung Zufluss Tank 2 [0..1] 


% Entkopplung sparameter:
a01=0.05;         %Pole PT1 Glied
a02=0.05;         %Pole PT1 Glied

l1=a01;           %Verst�rkung Untersystem1 != 1
l2=a02;           %Verst�rkung Untersystem2 != 1

%F�hrungsgr��en

h10=45;           %cm  
h20=15;           %cm

% PI-Regler f�r entkoppeltes System
% with p=0 and damping=1
p=0;
k=0.0125;
v=k;                        %Verst�rkung =1



%--------------------------------------------------------------------------
% nonlinear system:
%--------------------------------------------------------------------------
syms f1 f2 f3 h1 h2 h3 Q1 Q2 t1 t2 t3 t4 t5 t6

f1=1/A*(Q1-az1*Sn*sqrt(2*g*(h1-h3))-t1*sqrt(2*g*h1)-t4*az1*Sn*sqrt(2*g*(h1-h3)));
f2=1/A*(Q2+az3*Sn*sqrt(2*g*(h3-h2))-az2*Sn*sqrt(2*g*h2)-t2*sqrt(2*g*h2)+t6*az3*Sn*sqrt(2*g*(h3-h2))-t5*az2*Sn*sqrt(2*g*h2));
f3=1/A*(az1*Sn*sqrt(2*g*(h1-h3))-az3*Sn*sqrt(2*g*(h3-h2))-t3*sqrt(2*g*h3)+t4*az1*Sn*sqrt(2*g*(h1-h3))-t6*az3*Sn*sqrt(2*g*(h3-h2)));

f4_c = 1/A*(az1*Sn*sqrt(2*g*(h1-h3))-az3*Sn*sqrt(2*g*(h3-h2)));


%--------------------------------------------------------------------------
% linearization
%--------------------------------------------------------------------------
a11=diff(f1,h1);a12=diff(f1,h2);a13=diff(f1,h3);
a21=diff(f2,h1);a22=diff(f2,h2);a23=diff(f2,h3);
a31=diff(f3,h1);a32=diff(f3,h2);a33=diff(f3,h3);

a31_c=diff(f4_c,h1);a32_c=diff(f4_c,h2);a33_c=diff(f4_c,h3);


b11=diff(f1,Q1);b12=diff(f1,Q2);
b21=diff(f2,Q1);b22=diff(f2,Q2);
b31=diff(f3,Q1);b32=diff(f3,Q2);

h1=45;        %cm  it must be: x10>x30>x20 for idle state
h2=15;        %cm
h3=30;        %cm

t1=0;t2=0;t3=0;t4=0;t5=0;t6=0;


%--------------------------------------------------------------------------
% nominal model
%--------------------------------------------------------------------------
%disp('nominal model:')
An=[eval(a11),eval(a12),eval(a13);
    eval(a21),eval(a22),eval(a23);
    eval(a31),eval(a32),eval(a33)];
Bn=[eval(b11),eval(b12);
    eval(b21),eval(b22);
    eval(b31),eval(b32)];
Cn=eye(3);
Dn=zeros(3,2);

%--------------------------------------------------------------------------
% faulty model
%--------------------------------------------------------------------------
%disp('faulty model:')
syms t1 t2 t3 t4 t5 t6
A1 = [eval(diff(a11,t1)),0,0;0,0,0;0,0,0];
A2 = [0,0,0;0,eval(diff(a22,t2)),0;0,0,0];
A3 = [0,0,0;0,0,0;0,0,eval(diff(a33,t3))];
A4 = [eval(diff(a11,t4)),0,eval(diff(a13,t4));0,0,0;eval(diff(a31,t4)),0,eval(diff(a33,t4))];
A5 = [0,0,0;0,eval(diff(a22,t5)),0;0,0,0];
A6 = [0,0,0;0,eval(diff(a22,t6)),eval(diff(a23,t6));0,eval(diff(a32,t6)),eval(diff(a33,t6))];

Ef = [zeros(3,3),Bn];            % influence of actuator faults
Ff = [eye(3),zeros(3,2)];        % influence of sensor faults
Ed = zeros(3,2);                 % disturbance on states
Fd = [1,0;0,1;0,0];              % disturbance on sensors

sys=ss(An,Bn,Cn,Dn);

%--------------------------------------------------------------------------
% discretization and the noise
%--------------------------------------------------------------------------
m_ts = 2; 
sysd=c2d(sys,m_ts,'zoh');

Ef_d = [zeros(3,3),sysd.b];
Ff_d = [eye(3),zeros(3,2)];
Ed_d = zeros(3,3);
Fd_d = eye(3);

if m_ts == 1
    m_var1 = 0.0019;
    m_var2 = 0.0079;
    m_var3 = 0.0040;
    m_steps = 1e4;
elseif m_ts == 2
    m_var1 = 0.0026;
    m_var2 = 0.0093;
    m_var3 = 0.0019;
        % m_var1 = 0;
        % m_var2 = 0;
        % m_var3 = 0;
    m_steps = 2e4;
elseif m_ts == 5
    m_var1 = 0.2027;
    m_var2 = 0.4394;
    m_var3 = 0.0051;
    m_steps = 5e4;
end


%--------------------------------------------------------------------------
% on-line parameters
%--------------------------------------------------------------------------
% m_steps = 50000;
m_steps = 30000;



%--------------------------------------------------------------------------
% fault-free configuration
%--------------------------------------------------------------------------

F_sensor1_time = 0;        % sec
F_sensor1_offset = 0;      % 5 cm
F_sensor2_time = 0;        % sec
F_sensor2_offset = 0;      % 5 cm
F_sensor3_time = 0;        % sec
F_sensor3_offset = 0;      % 5 cm

F_plugg13_time = 0;        % sec
F_plugg13_gain = 0;        % 5 %
F_plugg32_time = 0;        % sec
F_plugg32_gain = 0;        % 10 %
F_plugg20_time = 0;        % sec
F_plugg20_gain = 0;        % 15 %

F_leak1_time = 0;          % sec
F_leak1_gain = 0;          % 5 %
F_leak2_time = 0;          % sec
F_leak2_gain = 0;          % 10 %
F_leak3_time = 0;          % sec
F_leak3_gain = 0;          % 15 %

F_pump1_time = 0;          % sec
F_pump1_gain = 100;        % 90 %
F_pump2_time = 0;          % sec
F_pump2_gain = 100;         % 80 %

%--------------------------------------------------------------------------
% Attacker-Matrix
%--------------------------------------------------------------------------

H_s=[0.352325574028282	0.160060274005077	0.151373007149584
0.0882596087112155	0.0940745133847350	0.106273628955316
0.380334272542366	-0.182430873669178	-0.0944929265344096
0.404079710473133	0.0867432971061024	0.0776216465603635
0.149160697726677	0.0135741600459739	0.0183937389851999
0.132542405293369	0.150879310898846	0.267726726211206
0.353769521611094	0.280469880238090	0.160049230311442
0.0921842793917100	0.264586634371091	0.107394699693645
0.374636850834566	-0.795433204994596	-0.126014360791152
0.443600110229398	0.174955632267430	-0.0482296254278068
0.212996257805141	0.125940841845161	-0.172422008239359
-0.0646057868651256	-0.271886839980743	0.890919594176926];
% H_s=[0.35	0.16	0.15
% 0.088	0.09	0.106
% 0.38	-0.18	-0.09
% 0.40	0.086	0.077
% 0.14	0.0135	0.018
% 0.13	0.15	0.267
% 0.35	0.280	0.160
% 0.09	0.26	0.107
% 0.37	-0.79	-0.12
% 0.44	0.17	-0.048
% 0.21	0.13	-0.17
% -0.06	-0.27	0.89];
var_s=3.9197e-06;
Fi_s=(H_s'*var_s^(-1)*H_s)\(H_s'*var_s^(-1));
Lambda=Fi_s'*Fi_s;
A_s=H_s'*H_s;
B_s=H_s'*Lambda*H_s;
[V,D]=eig(A_s,B_s);
v1=V(:,1);v2=V(:,2);v3=V(:,3);
v_example=[1;1;1];
sgama=v_example;
% sgama=v1+v2+v3;
Alpha=H_s*sgama/norm(H_s*sgama);
M_a=10;
Alpha=M_a*Alpha;
s=length(Alpha)/3;
Alpha_1=zeros(4,1);
Alpha_2=zeros(4,1);
Alpha_3=zeros(4,1);
for i=1:s
Alpha_1(i,1)=Alpha(1+(i-1)*3);
Alpha_2(i,1)=Alpha(2+(i-1)*3);
Alpha_3(i,1)=Alpha(3+(i-1)*3);
end
Alpha_1(5,1)=Alpha(1);
Alpha_2(5,1)=Alpha(2);
Alpha_3(5,1)=Alpha(3);
alpha_1=[0;Alpha_1];
alpha_2=[0;Alpha_2];
alpha_3=[0;Alpha_3];


t_alpha6=0:2:10;
% t_alpha5=2:2:10;









%%%测试理想等价空间
dalpha=[-0.99;0;0;0.008;0;-0.008;-0.00014;0;0.0002;0;0;0];
s=length(dalpha)/3;
dalpha_1=zeros(5,1);
dalpha_2=zeros(5,1);
dalpha_3=zeros(5,1);
for i=1:s
dalpha_1(i,1)=dalpha(1+(i-1)*3);
dalpha_2(i,1)=dalpha(2+(i-1)*3);
dalpha_3(i,1)=dalpha(3+(i-1)*3);
end
dalpha_1(5,1)=dalpha(1);
dalpha_2(5,1)=dalpha(2);
dalpha_3(5,1)=dalpha(3);

Dalpha_1=[0;dalpha_1];
Dalpha_2=[0;dalpha_2];
Dalpha_3=[0;dalpha_3];
