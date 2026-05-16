%仿真设置
Ts=1;
FDIA_length=750;        %攻击长度
start_time_FDIA=250;    %攻击开始时间
start_time_QW=2000;      %水印嵌入时间
analog_time=start_time_FDIA+FDIA_length;
%图片设置

%创建受控系统
[G,H,C,D,x_eq,u_eq,y_eq]=Create_shoukong;
H_ext = [H, eye(4)];
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


% 计算
 [best_Dw, best_Cw, global_best_cost] = Optimize_watermark_PSO(G, H, C, K, K_KF, Cj, Dj, 1, 99, 100, 100);
 % 水印赋值
Gw=G-K_KF*C-H*K;
Hw=K_KF;
active = 3;  % ← 每次只改这一个数字
Cw = best_Cw;
Dw = best_Dw;

[Gq, Hq, Cq, Dq] = Get_remover_matrices(Gw, Hw, Cw, Dw);