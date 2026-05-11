% =========================================================================
% 基于 Dw 网格搜索 + Cw 离散随机采样的最优水印设计脚本
% =========================================================================
clear; clc; yalmip('clear');

%% 1. 系统维度定义
nx = 4; 
nx_RK = 4;
nx_hat = 4; 
nx_w = 4; % 因为 Cw 是 2x4，所以水印状态维度设为 4
nx_q = 4; 
nx_a = 9; % 攻击发生器维度
N_total = nx + nx_RK + nx_hat + nx_w + nx_q + nx_a; 
ny = 2; % 传感器通道数

%% 2. 离散化搜索空间约束
% (1) Dw 网格约束 (遵循工程推导: 0.2~0.9)
alpha_min = 0.2; alpha_max = 0.9; step_Dw = 0.01;

% (2) Cw 离散化约束 (用于离散随机采样)
Cw_min = -10;   % 最小值
Cw_max = 10;    % 最大值
Cw_step = 0.1;   % 网格大小 (步长)
num_samples = 1000; % 随机采样的总次数

% 根据约束生成离散可选值集合
cw_possible_values = Cw_min : Cw_step : Cw_max;
%% 2.5 优化目标函数权重定义 (补充部分)
% 这两个参数决定了防守策略的侧重点：
% epsilon_r 越大，越看重“发现攻击的能力”；
% epsilon_a 越大，越看重“系统运行的平稳性”。
epsilon_r = 1.0; 
epsilon_a = 50.0; % 这是一个参考值，建议根据性能需求进行调整
%% 3. 系统已知矩阵 (此处请填入具体数值)
%被控对象状态空间
A=[    
    0.9842         0   -0.0407         0;
         0    0.9890         0   -0.0326;
         0         0    0.9590         0;
         0         0         0    0.9672
         ];
B=[    
    0.0826   -0.0010;
   -0.0005    0.0625;
         0    0.0469;
    0.0307         0
    ];
C=[
    0.5 0 0 0;
    0 0.5 0 0
    ];
D=[
    0 0;
    0 0
    ];
%LQR
K=[
    0.6841	-0.009104	-0.2461	0.002638;
    -0.05136	0.6823	0.0221	-0.2556
    ];
%R-k
L=[
    2.0864	0;
    0	5.7124;
    -12.6084	0;
    0	-123.0648
    ];
%KF
K_KF=[
    0.4427         0
         0      0.4451
   -0.1561         0
         0      -0.1607
    ];
%性能矩阵
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
%攻击生成
Aa=[
        0	0	1	0	0	0	0	0	0;
        0	0	0	1	0	0	0	0	0;
        0	0	0	0	1	0	0	0	0;
        0	0	0	0	0	1	0	0	0;
        0	0	0	0	0	0	1	0	0;
        0	0	0	0	0	0	0	1	0;
        1	0	0	0	0	0	0	0	0;
        0	1	0	0	0	0	0	0	-0.0099;
        0	0	0	0	0	0	0	0	0.9890
];
Ca=[
    1	0	0	0	0	0	0	0	0;
    0	1	0	0	0	0	0	0	0
];

% 水印发生器动态核心 (需匹配 nx_w=4)
Gw = A-L*C-B*K; % 示例稳定阵
Hw = L; % 示例

%% 4. YALMIP 决策变量 (仅保留 P, gamma)
P       = sdpvar(N_total, N_total, 'symmetric');
gamma_r = sdpvar(1, 1);
gamma_a = sdpvar(1, 1);
options = sdpsettings('solver', 'sedumi', 'verbose', 0);

%% 5. 双重搜索循环
gamma_star = inf;
best_Cw = []; best_Dw = [];

fprintf('开始离散化搜索 (Dw网格 + Cw离散随机)...\n');

% 外层：Dw 网格搜索
for d1 = alpha_min : step_Dw : alpha_max
    for d2 = alpha_min : step_Dw : alpha_max
        Dw_curr = diag([d1, d2]);
        Dq = inv(Dw_curr); %
        
        % 内层：Cw 离散化随机采样
        for s = 1:num_samples
            % 从离散集合中随机选取索引填充 2x4 矩阵
            rand_idx = randi(length(cw_possible_values), ny, nx_w);
            Cw_curr = cw_possible_values(rand_idx);
            
            % --- 稳定性校验 ---
            Gq = Gw - Hw * Dq * Cw_curr;
            if max(abs(eig(Gq))) >= 1.0
                continue; % 拦截不稳定解
            end
            
            % --- 增广矩阵拼装 (使用最新推导的 G_bar) ---
            Cq = -Dq * Cw_curr;
            Hq = Hw * Dq;
            
            row1 = [A, -B*K, zeros(nx, nx_hat + nx_w + nx_q + nx_a)];
            row2 = [L*Dq*Dw_curr*C, A-L*C, zeros(nx_RK, nx_hat), L*Dq*Cw_curr, L*Cq, L*Dq*Ca];
            row3 = [K_KF*Dq*Dw_curr*C, -B*K, A-K_KF*C, K_KF*Dq*Cw_curr, K_KF*Cq, K_KF*Dq*Ca];
            row4 = [Hw*C, zeros(nx_w, nx_RK + nx_hat), Gw, zeros(nx_w, nx_q + nx_a)];
            row5 = [Hq*Dw_curr*C, zeros(nx_q, nx_RK + nx_hat), Hq*Cw_curr, Gq, Hq*Ca];
            row6 = [zeros(nx_a, nx + nx_RK + nx_hat + nx_w + nx_q), Aa];
            
            G_bar   = [row1; row2; row3; row4; row5; row6];
            C_j_bar = [Cj, -Dj*K, zeros(size(Cj,1), nx_hat + nx_w + nx_q + nx_a)];
            C_r_bar = [C, zeros(size(C,1), nx_RK), -C, Dq*Cw_curr, -Dq*Cw_curr, Dq*Ca];
            
            % --- 凸优化求解 (LMI) ---
            Constraints = [P >= 0, gamma_r >= 0, gamma_a >= 0];
            M11 = -P + (C_j_bar' * C_j_bar) - gamma_r * (C_r_bar' * C_r_bar);
            M12 = G_bar' * P;
            M21 = P * G_bar;
            M22 = -P;
            Constraints = [Constraints, [M11, M12; M21, M22] <= 0];
            
            Objective = epsilon_r * gamma_r + epsilon_a * gamma_a;
            sol = optimize(Constraints, Objective, options);
            
            % --- 最优解更新 ---
            if sol.problem == 0
                cost = value(Objective);
                if cost < gamma_star
                    gamma_star = cost;
                    best_Cw = Cw_curr;
                    best_Dw = Dw_curr;
                    fprintf('发现更优解! Cost: %.4f (Dw: [%.1f, %.1f])\n', gamma_star, d1, d2);
                end
            end
        end
    end
end

%% 6. 输出最优结果
if gamma_star == inf
    disp('未找到可行解。请检查系统矩阵或调整搜索范围。');
else
    disp('========================================');
    fprintf('设计完成！最优综合代价: %.6f\n', gamma_star);
    disp('最优 Dw:'); disp(best_Dw);
    disp('最优 Cw:'); disp(best_Cw);
end