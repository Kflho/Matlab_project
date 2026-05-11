% =========================================================================
% 基于 Dw 网格搜索 + Cw 离散随机采样的最优水印设计脚本 (欺骗误差模型版)
% =========================================================================
clear; clc; yalmip('clear');

%% 1. 系统维度定义
nx = 4; nx_RK = 4; nx_hat = 4; nx_w = 4; nx_q = 4; 
nx_a = 4; % 核心修改：欺骗误差状态维度与系统一致
N_total = nx + nx_RK + nx_hat + nx_w + nx_q + nx_a; % 总维度变为 24
ny = 2; 

%% 2. 搜索空间与权重定义
alpha_min = 0.2; alpha_max = 0.9; step_Dw = 0.01; 
Cw_min = -1; Cw_max = 1; Cw_step = 0.1; num_samples = 500;
cw_possible_values = Cw_min : Cw_step : Cw_max;

epsilon_r = 1.0; 
epsilon_a = 1.0; % 性能损失权重

%% 3. 系统矩阵定义
A = [0.9842 0 -0.0407 0; 0 0.9890 0 -0.0326; 0 0 0.9590 0; 0 0 0 0.9672];
B = [0.0826 -0.0010; -0.0005 0.0625; 0 0.0469; 0.0307 0];
C = [0.5 0 0 0; 0 0.5 0 0];
K = [0.6841 -0.009104 -0.2461 0.002638; -0.05136 0.6823 0.0221 -0.2556];
L = [2.0864 0; 0 5.7124; -12.6084 0; 0 -123.0648];
K_KF = [0.4427 0; 0 0.4451; -0.1561 0; 0 -160.7e-4];
Cj = [0.806 0 0 0; 0 0.787 0 0; 0 0 5.556 0; 0 0 0 7.143; 0 0 0 0; 0 0 0 0];
Dj = [0 0; 0 0; 0 0; 0 0; 0.901 0; 0 0.897];

% --- 核心修改：构造欺骗误差攻击空间 ---
Aa = A - L*C; % 观测器误差动力学，天然稳定
Ba = L;       % 传感器篡改量 a(k) 对估计偏差的驱动

Gw = A - L*C - B*K; 
Hw = L;

%% 4. YALMIP 决策变量
P = sdpvar(N_total, N_total, 'symmetric');
gamma_r = sdpvar(1, 1);
gamma_a = sdpvar(1, 1);
options = sdpsettings('solver', 'sedumi', 'verbose', 0);

%% 5. 双重搜索循环
gamma_star = inf;
fprintf('开始搜索最优水印参数 (欺骗误差模型模式)...\n');

for d1 = alpha_min : step_Dw : alpha_max
    for d2 = alpha_min : step_Dw : alpha_max
        Dw_curr = diag([d1, d2]);
        Dq = inv(Dw_curr); 
        
        for s = 1:num_samples
            rand_idx = randi(length(cw_possible_values), ny, nx_w);
            Cw_curr = cw_possible_values(rand_idx);
            
            % 稳定性拦截
            Gq = Gw - Hw * Dq * Cw_curr;
            if max(abs(eig(Gq))) >= 1.0, continue; end 
            
            % --- 修正后的增广矩阵拼接 (6x6 分块) ---
            Cq = -Dq * Cw_curr; Hq = Hw * Dq;
            
            % G_bar: 状态转移
            row1 = [A, -B*K, zeros(nx, nx_hat + nx_w + nx_q + nx_a)];
            row2 = [L*Dq*Dw_curr*C, A-L*C, zeros(nx_RK, nx_hat), L*Dq*Cw_curr, L*Cq, zeros(nx_RK, nx_a)];
            row3 = [K_KF*Dq*Dw_curr*C, -B*K, A-K_KF*C, K_KF*Dq*Cw_curr, K_KF*Cq, zeros(nx_hat, nx_a)];
            row4 = [Hw*C, zeros(nx_w, nx_RK + nx_hat), Gw, zeros(nx_w, nx_q + nx_a)];
            row5 = [Hq*Dw_curr*C, zeros(nx_q, nx_RK + nx_hat), Hq*Cw_curr, Gq, zeros(nx_q, nx_a)];
            row6 = [zeros(nx_a, nx + nx_RK + nx_hat + nx_w + nx_q), Aa]; 
            G_bar = [row1; row2; row3; row4; row5; row6];
            
            % H_bar: 输入驱动 (对应外部传感器攻击信号 a(k))
            H_bar = [zeros(nx, ny); L*Dq; K_KF*Dq; zeros(nx_w, ny); Hq; Ba];
            
            % 输出矩阵
            C_j_bar = [Cj, -Dj*K, zeros(size(Cj,1), nx_hat + nx_w + nx_q + nx_a)];
            C_r_bar = [Dq*Dw_curr*C, zeros(ny, nx_RK), -C, Dq*Cw_curr, Cq, zeros(ny, nx_a)];
            Dr_bar  = Dq; % 残差直传项
            
            % --- 构造 Lemma 3.1 公式 (12) 的完整 H-inf LMI ---
            M11 = -P + (C_j_bar' * C_j_bar) - gamma_r * (C_r_bar' * C_r_bar);
            M12 = G_bar' * P;
            M13 = C_r_bar' * Dr_bar; 
            M22 = -P;
            M23 = P * H_bar;
            M33 = -gamma_a * eye(ny) - gamma_r * (Dr_bar' * Dr_bar);
            
            LMI = [M11, M12, M13; M12', M22, M23; M13', M23', M33];
            
            Constraints = [P >= 1e-6*eye(N_total), gamma_r >= 0, gamma_a >= 0, LMI <= 0];
            
            Objective = epsilon_r * gamma_r + epsilon_a * gamma_a;
            sol = optimize(Constraints, Objective, options);
            
            if sol.problem == 0
                cost = value(Objective);
                if cost < gamma_star
                    gamma_star = cost; best_Cw = Cw_curr; best_Dw = Dw_curr;
                    fprintf('发现最优解! Cost: %.4f (Dw: [%.2f, %.2f])\n', gamma_star, d1, d2);
                end
            end
        end
    end
end

%% 6. 输出结果
if gamma_star == inf
    disp('依然未找到可行解。建议：1. 检查 A-LC 是否真的 Schur 稳定；2. 适当调大采样数。');
else
    disp('========================================');
    fprintf('设计成功！最优综合代价: %.6f\n', gamma_star);
    disp('最优 Dw:'); disp(best_Dw);
    disp('最优 Cw:'); disp(best_Cw);
end