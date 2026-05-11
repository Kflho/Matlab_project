clc;
%临时路径
addpath('D:\local_data\software_data\programming_data\Matlab_project\Bachelor_thesis_simulation\Main\Script\Create_FDIA')
addpath('D:\local_data\software_data\programming_data\Matlab_project\Bachelor_thesis_simulation\Main\Script\Create_noise')
addpath('D:\local_data\software_data\programming_data\Matlab_project\Bachelor_thesis_simulation\Main\Script\Create_shoukong')
addpath('D:\local_data\software_data\programming_data\Matlab_project\Common')
addpath('D:\local_data\software_data\programming_data\Matlab_project\Bachelor_thesis_simulation\Main\Simulink')
addpath('D:\local_data\software_data\programming_data\Matlab_project\Bachelor_thesis_simulation\Main\Script\Filter_design')
addpath('D:\local_data\software_data\programming_data\Matlab_project\Bachelor_thesis_simulation\Main\Script\POMDP')
%仿真设置
Ts=1;
FDIA_length=550;
start_time_FDIA=250;
start_time_QW=0;
analog_time=start_time_FDIA+FDIA_length;
%创建受控系统
[G,H,C,D,x_eq,u_eq,y_eq]=Create_shoukong;
%创建性能矩阵
Cj=[
    0.806 0 0 0;
    0 0.787 0 0;
    0 0 5.556 0;
    0 0 0 7.143;
    0 0 0 0;
    0 0 0 0
    ];
Dj=[
    0 0;
    0 0;
    0 0;
    0 0;
    0.901 0;
    0 0.897
    ];
%状态观测器极点配置，用于计算RK
%J=[-0.5 -0.4 0.4 0.5];
%L=place(A',C',J)';

% 假设过程噪声和测量噪声的强度
%Q = eye(4) * 0.001; % 较小的 Q 代表对模型信心足
%R = eye(2) * 1.0;   % 较大的 R 会让 L 变小（更信任模型而非测量）

% 求解离散 Kalman 增益
% [L, ~, ~] = dlqe(A, eye(4), C, Q, R);

%计算反馈控制矩阵用于LQR
K=Calculate_LQR(G,H);
%卡尔曼滤波观测矩阵K_KF
K_KF=[
    0.4427         0
         0      0.4451
   -0.1561         0
         0      -0.1607
    ];

%创建FDIA序列
simin_FDIA = Create_FDIA_Kalman_v5(G, C, K_KF, [1 0;0 1], 1.5, FDIA_length,start_time_FDIA,Ts);
%[A_xi, C_xi, xi_0]=Create_FDIA_StateSpace(A,C,K_KF,[1 0;0 1],0.4);

%创建噪声
[Vk,Wk,simin_noise_va]=Create_noise(analog_time);
I_a=eye(length(G));
%P0=diag([10;10;10;10]);
Va=diag([0.003844, 0.004032]); 
%创建水印嵌入器和移除器
%强水印计算
% epsilon_r=1;
% epsilon_a=10;
% [Dwq,Cwq, global_best_cost_q] = Optimize_watermark_PSO_Discrete_v2(G, H, C, K, K_KF, Cj, Dj, epsilon_r, epsilon_a);
%弱水印计算
% epsilon_r=1;
% epsilon_a=0.1;
% [Dwr,Cwr, global_best_cost_r] = Optimize_watermark_PSO_Discrete_v2(G, H, C, K, K_KF, Cj, Dj, epsilon_r, epsilon_a);
%水印嵌入与移除器状态空间矩阵计算

%粗选水印阵
Cwrr0=[1 1 1 1;1 1 1 1];
Dwrr0=[0.9 0;0 0.9];
Cwqq0=[0.5 0.5 0.5 0.5;0.5 0.5 0.5 0.5];
Dwqq0=[0.35 0;0 0.3];
%最优水印阵
Cwq0=[0.2,-0.4,0.3,-1;-0.3,0.1,-0.9,0.1];
Dwq0=[0.35,0;0,0.3];
Cwr0=[0,-0.3,-1,-1;-0.8,0.3,-1,-0.5];
Dwr0=[0.9,0;0,0.9];

% 水印赋值
Gw=G-K_KF*C-H*K;
Hw=K_KF;

Cw=Cwq0;
Dw=Dwq0;
[Gq, Hq, Cq, Dq] = Get_remover_matrices(Gw, Hw, Cw, Dw);


out=Start_simulink('Control_system_v6');

%计算残差和性能损失的模长平方
 r2=Calculate_energy(out.r);
 yj2=Calculate_energy(out.y_j);
 FDIA2=Calculate_energy(simin_FDIA);

%计算性能损失
disp('加水印受攻击性能损失')
Calculate_Signal_Stats(out.y_j,0,100000);
disp('加水印不受攻击性能损失')
Calculate_Signal_Stats(out.y_j,0,99999);
%disp('加水印受攻击性能损失')
%Calculate_Signal_Stats(simin_FDIA,t_started,t_end);
%Calculate_Signal_Stats(out.r,0,t_started);

%画图
Plot_signals_v5(out.r,'r','攻击前后残差对比图',1,{'t/s','r/cm'});
Add_Threshold(1,'|r|_{max}');
%Plot_signals_v4(out.x,'x_','攻击前后液位对比图',3);

% Plot_signals_v4(r2,'r^2_','攻击前后残差模长平方对比图',1);
% Plot_signals_v5(yj2,'yj^2_','攻击前后性能影响参数对比图',1,{'时间/t','|y_j|^2'},{'|y_j|^2_1','|y_j|^2_2'});
% Plot_signals_v4(FDIA2,'FDIA^2_','攻击能量图',1);

% 残差阈值理论计算
% epsilon_r=trace(Dq*Va*(Dq'))+2*5*trace(Dq*Va*(Dq')*Dq*Va*(Dq'))
% epsilon_r0=trace(Va)+2*5*trace(Va*Va)