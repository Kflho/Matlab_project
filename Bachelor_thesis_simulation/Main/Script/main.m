clc;
close all;
rng(2026); 
%临时路径
addpath('D:\local_data\software_data\programming_data\Matlab_project\Bachelor_thesis_simulation\Function\Create_FDIA')
addpath('D:\local_data\software_data\programming_data\Matlab_project\Bachelor_thesis_simulation\Function\Create_noise')
addpath('D:\local_data\software_data\programming_data\Matlab_project\Bachelor_thesis_simulation\Function\Create_shoukong')
addpath('D:\local_data\software_data\programming_data\Matlab_project\Bachelor_thesis_simulation\Function\Filter_design')
addpath('D:\local_data\software_data\programming_data\Matlab_project\Bachelor_thesis_simulation\Function\POMDP')
addpath('D:\local_data\software_data\programming_data\Matlab_project\Common')
addpath('D:\local_data\software_data\programming_data\Matlab_project\Bachelor_thesis_simulation\Main\Simulink')
%仿真设置
Ts=1;
FDIA_length=550;%攻击长度
start_time_FDIA=250;%攻击开始时间
start_time_QW=1000;%水印嵌入时间
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

%计算反馈控制矩阵用于LQR
K=Calculate_LQR(G,H);

%卡尔曼滤波观测矩阵K_KF
K_KF=[
    0.4427         0
         0      0.4451
   -0.1561         0
         0      -0.1607
    ];

%创建水印
% 写在 main.m 最前面
watermarks(1).name = '粗选弱';
watermarks(1).Cw = [1 1 1 1;1 1 1 1];
watermarks(1).Dw = [0.9 0;0 0.9];

watermarks(2).name = '粗选强';
watermarks(2).Cw = [0.5 0.5 0.5 0.5;0.5 0.5 0.5 0.5];
watermarks(2).Dw = [0.5 0;0 0.5];

watermarks(3).name = '最优弱';
watermarks(3).Cw = [0,-0.3,-1,-1;-0.8,0.3,-1,-0.5];
watermarks(3).Dw = [0.9,0;0,0.9];

watermarks(4).name = '最优强';
watermarks(4).Cw = [0.2,-0.4,0.3,-1;-0.3,0.1,-0.9,0.1];
watermarks(4).Dw = [0.35,0;0,0.3];
% ... 继续添加

% 水印赋值
Gw=G-K_KF*C-H*K;
Hw=K_KF;
active = 4;  % ← 每次只改这一个数字
Cw = watermarks(active).Cw;
Dw = watermarks(active).Dw;

[Gq, Hq, Cq, Dq] = Get_remover_matrices(Gw, Hw, Cw, Dw);
disp(['当前水印：', watermarks(active).name]);



%创建FDIA序列
d_target = [5.5; 5.5];
sign_vec = [1; 1];     % 两个通道都正向偏移
ramp_len = 250;         % 斜坡时长
simin_FDIA = Create_FDIA_MinEnergy_LP_fixedsign_par(G, C, K_KF, FDIA_length, d_target, sign_vec, start_time_FDIA, Ts, ramp_len);
% simin_FDIA = Create_FDIA_Kalman_v5(G, C, K_KF, [1 0;0 1], 1.5, FDIA_length,start_time_FDIA,Ts);
%[A_xi, C_xi, xi_0]=Create_FDIA_StateSpace(A,C,K_KF,[1 0;0 1],0.4);

%创建噪声
[Vk,Wk,simin_noise_va]=Create_noise(analog_time);
I_a=eye(length(G));
%P0=diag([10;10;10;10]);
Va=diag([0.003844, 0.004032]); 



%运行仿真
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

% 计算残差阈值
% epsilon_r=trace(Dq*Va*(Dq'))+2*5*trace(Dq*Va*(Dq')*Dq*Va*(Dq'))
% epsilon_r0=trace(Va)+2*5*trace(Va*Va)

%画图
Plot_signals_v5(out.r,'r','攻击前后残差对比图',1,{'t/s','r/cm'});
Add_Threshold(1,'|r|_{max}');
Plot_signals_v5(out.x,'x','攻击前后液位对比图',3,{'t/s','x/cm'});

Plot_signals_v5(r2,'r^2','攻击前后残差模长平方对比图',1,{'t/s','|r|^2/cm^2'},{'|r|^2'});
% Plot_signals_v5(yj2,'yj^2_','攻击前后性能影响参数对比图',1,{'时间/t','|y_j|^2'},{'|y_j|^2_1','|y_j|^2_2'});
% Plot_signals_v4(FDIA2,'FDIA^2_','攻击能量图',1);

