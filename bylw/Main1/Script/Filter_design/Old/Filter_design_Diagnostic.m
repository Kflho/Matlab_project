% =========================================================================
% 最优水印设计脚本 (单层搜索 Cw + Dw 固定 + Gw 稳定性修复)
% =========================================================================
clear; clc; yalmip('clear');

%% 1. 系统维度定义
nx = 4; nx_RK = 4; nx_hat = 4; nx_w = 4; nx_q = 4; nx_a = 4; 
N_total = 24; ny = 2; 

%% 2. 搜索参数与权重配置
% 固定 Dw (0.5 I) 以排除干扰
Dw_curr = diag([0.5, 0.5]); 
Dq = inv(Dw_curr); 

% Cw 离散采样约束 (针对 L 增益巨大的情况，缩小采样范围)
Cw_min = -1;   % 缩小范围以保证稳定性
Cw_max = 1;    
Cw_step = 0.0001;   
num_samples = 500000; 
cw_vals = Cw_min : Cw_step : Cw_max;

epsilon_r = 1.0; 
epsilon_a = 0; % 性能损失权重

%% 3. 系统矩阵定义 (填入你的实际数据)
A = [0.9842 0 -0.0407 0; 0 0.9890 0 -0.0326; 0 0 0.9590 0; 0 0 0 0.9672];
B = [0.0826 -0.0010; -0.0005 0.0625; 0 0.0469; 0.0307 0];
C = [0.5 0 0 0; 0 0.5 0 0];
K = [0.6841 -0.009104 -0.2461 0.002638; -0.05136 0.6823 0.0221 -0.2556];
L =[
 0.01946	0
0	0.02337
-0.003634	0
0	-0.004337
];
K_KF = [0.4427 0; 0 0.4451; -0.1561 0; 0 -160.7e-4];
Cj = [0.806 0 0 0; 0 0.787 0 0; 0 0 5.556 0; 0 0 0 7.143; 0 0 0 0; 0 0 0 0];
Dj = [0 0; 0 0; 0 0; 0 0; 0.901 0; 0 0.897];

% --- 核心修改：修复 Gw 稳定性 ---
% 强制 Gw 为稳定极点阵，解决 1.4946 的发散问题
Gw = diag([0.5, 0.5, 0.4, 0.4]); 
Hw = L; % 此时 Hw 仅作为输入映射

% --- 攻击空间：欺骗误差模型 ---
Aa = A - L*C; % 已验证稳定
Ba = L; 

%% 4. YALMIP 决策变量与配置
P       = sdpvar(N_total, N_total, 'symmetric');
gamma_r = sdpvar(1, 1);
gamma_a = sdpvar(1, 1);
options = sdpsettings('solver', 'sedumi', 'verbose', 0);

%% 5. 搜索循环
gamma_star = inf;
best_Cw = [];
pass_count = 0; % 稳定性通过计数器

fprintf('开始诊断式搜索...\n');

for s = 1:num_samples
    % 随机离散采样 Cw
    Cw_curr = cw_vals(randi(length(cw_vals), ny, nx_w));
    
    % --- 移除器稳定性校验 (Gq = Gw - L*Dq*Cw) ---
    Gq = Gw - L * Dq * Cw_curr; 
    if max(abs(eig(Gq))) >= 1.0, continue; end % 若不稳定则静默跳过
    
    pass_count = pass_count + 1;
    
    % --- 增广矩阵拼装 ---
    Cq = -Dq * Cw_curr; Hq = L * Dq;
    
    row1 = [A, -B*K, zeros(4,16)];
    row2 = [L*Dq*Dw_curr*C, A-L*C, zeros(4,4), L*Dq*Cw_curr, L*Cq, zeros(4,4)];
    row3 = [K_KF*Dq*Dw_curr*C, -B*K, A-K_KF*C, K_KF*Dq*Cw_curr, K_KF*Cq, zeros(4,4)];
    row4 = [L*C, zeros(4,8), Gw, zeros(4,8)];
    row5 = [Hq*Dw_curr*C, zeros(4,8), Hq*Cw_curr, Gq, zeros(4,4)];
    row6 = [zeros(4,20), Aa];
    G_bar = [row1; row2; row3; row4; row5; row6];
    
    % H_bar 对应输入 a(k)
    H_bar = [zeros(4,2); L*Dq; K_KF*Dq; zeros(4,2); Hq; Ba];
    C_j_bar = [Cj, -Dj*K, zeros(6,16)];
    C_r_bar = [Dq*Dw_curr*C, zeros(2,4), -C, Dq*Cw_curr, Cq, zeros(2,4)];
    Dr_bar = Dq;

    % --- 构造 Lemma 3.1 完整 LMI ---
    M11 = -P + (C_j_bar' * C_j_bar) - gamma_r * (C_r_bar' * C_r_bar);
    M12 = G_bar' * P;
    M13 = C_r_bar' * Dr_bar; 
    M22 = -P;
    M23 = P * H_bar;
    M33 = -gamma_a * eye(ny) - gamma_r * (Dr_bar' * Dr_bar);
    
    LMI = [M11, M12, M13; M12', M22, M23; M13', M23', M33];
    Constraints = [P >= 1e-8*eye(N_total), gamma_r >= 0, gamma_a >= 0, LMI <= 0];
    
    % --- 求解 ---
    Objective = epsilon_r * gamma_r + epsilon_a * gamma_a;
    sol = optimize(Constraints, Objective, options);
    
    if sol.problem == 0
        cost = value(Objective);
        if cost < gamma_star
            gamma_star = cost;
            best_Cw = Cw_curr;
            fprintf('[发现可行解] 样本 %d: Cost = %.4f | gr = %.4f | ga = %.4f\n', ...
                    s, cost, value(gamma_r), value(gamma_a));
        end
    end
end

%% 6. 最终反馈
fprintf('\n--- 搜索诊断报告 ---\n');
fprintf('总采样样本数: %d\n', num_samples);
fprintf('通过稳定性拦截并进入 LMI 求解的样本数: %d\n', pass_count);

if gamma_star == inf
    fprintf('诊断结论: 所有进入求解器的样本均判定为 Infeasible。\n');
    fprintf('建议建议: 尝试进一步缩小 Cw 范围，或降低 epsilon_a 的权重。\n');
else
    disp('最优 C_w:'); disp(best_Cw);
end