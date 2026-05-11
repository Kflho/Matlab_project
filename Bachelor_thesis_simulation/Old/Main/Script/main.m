clc;
%临时路径
addpath('D:\local_data\software_data\programming_data\matlabproject\bylw\Main\Script\Create_FDIA')
addpath('D:\local_data\software_data\programming_data\matlabproject\bylw\Main\Script\Create_noise')
addpath('D:\local_data\software_data\programming_data\matlabproject\bylw\Main\Script\Create_shoukong')
addpath('D:\local_data\software_data\programming_data\matlabproject\Common')
addpath('D:\local_data\software_data\programming_data\matlabproject\bylw\Main\Simulink')
addpath('D:\local_data\software_data\programming_data\matlabproject\bylw\Main\Script\Filter_design')
addpath('D:\local_data\software_data\programming_data\matlabproject\bylw\Main\Script\POMDP')
%仿真设置
Ts=1;
start_time=250;
%创建受控系统
[A,B,C,D,x_eq,u_eq,y_eq]=Create_shoukong;
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
Q = eye(4) * 0.001; % 较小的 Q 代表对模型信心足
R = eye(2) * 1.0;   % 较大的 R 会让 L 变小（更信任模型而非测量）

% 求解离散 Kalman 增益
[L, ~, ~] = dlqe(A, eye(4), C, Q, R);

%计算反馈控制矩阵用于LQR
K=Calculate_LQR(A,B);
%卡尔曼滤波观测矩阵K_KF
K_KF=[
    0.4427         0
         0      0.4451
   -0.1561         0
         0      -0.1607
    ];

%创建FDIA序列
%simin_FDIA=Create_FDIA(A,C);
simin_FDIA = Create_FDIA_Kalman_v5(A, C, K_KF, [1 0;0 1], 1.5, 1000,start_time,Ts);
%[A_xi, C_xi, xi_0]=Create_FDIA_StateSpace(A,C,K_KF,[1 0;0 1],0.4);

%创建噪声
[Vk,Wk,simin_noise_va]=Create_noise;
I_a=eye(length(A));
%P0=diag([10;10;10;10]);

%计算残差和性能损失
% r2=Calculate_Residual_Norm_Sq(out.r);
% yj2=Calculate_Residual_Norm_Sq(out.y_j);
% FDIA2=Calculate_Residual_Norm_Sq(simin_FDIA);
%性能损失计算起止时间
t_started=250;
t_end=800;
Calculate_Signal_Stats(out.y_j,t_started,t_end);
Calculate_Signal_Stats(simin_FDIA,t_started,t_end);
Calculate_Signal_Stats(out.r,0,t_started);
Calculate_Signal_Stats(out.r,0,t_started);
%强水印计算
epsilon_r=1;
epsilon_a=10;
[Dwq,Cwq]=Optimize_watermark_design_v4(A,B,C,K,K_KF,Cj,Dj,epsilon_r,epsilon_a);
%弱水印计算
epsilon_r=1;
epsilon_a=0.1;
[Dwr,Cwr]=Optimize_watermark_design_v4(A,B,C,K,K_KF,Cj,Dj,epsilon_r,epsilon_a);

%Plot_signals_v4(out.r,'r_','攻击前后残差对比图',1);
%Plot_signals_v4(out.x,'x_','攻击前后液位对比图',3);

%Plot_signals_v4(r2,'r^2_','攻击前后残差模长平方对比图',1);
% Plot_signals_v4(yj2,'yj^2_','攻击前后性能损失模长平方对比图',1);
% Plot_signals_v4(FDIA2,'FDIA^2_','攻击能量图',1);
