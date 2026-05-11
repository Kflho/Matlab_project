function [best_Dw, best_Cw] = Optimize_watermark_design_v2(A, B, C, K, L, K_KF, Cj, Dj, epsilon_r, epsilon_a)
% =========================================================================
% 基于增广 H-inf 优化与诊断功能的最优水印设计函数
% 输入: 系统矩阵与权重 epsilon_r, epsilon_a
% 输出: 最优 Dw, Cw
% =========================================================================

yalmip('clear');

%% 1. 动态推断系统维度
nx = size(A, 1);    % 物理状态维度
nu = size(B, 2);    % 执行器输入通道数
ny = size(C, 1);    % 传感器输出通道数

% 根据你的架构，各增广状态维度与系统状态维度一致
nx_RK  = nx; 
nx_hat = nx; 
nx_w   = nx; 
nx_q   = nx; 
nx_a   = nx; 

N_total = nx + nx_RK + nx_hat + nx_w + nx_q + nx_a; 

%% 2. 搜索空间配置
alpha_min = 0.2; alpha_max = 0.9; step_Dw = 0.05; 
Cw_min = -1; Cw_max = 1; Cw_step = 0.1; 
num_samples = 100; % 每个 Dw 点位的随机采样数
cw_vals = Cw_min : Cw_step : Cw_max;

%% 3. 系统稳定性预检与矩阵初始化
fprintf('--- 系统稳定性诊断开始 ---\n');
check_stability(A - L*C, '观测器 (A-LC)');
check_stability(A - K_KF*C, '卡尔曼滤波器 (A-K_KF*C)');

% 修复 Gw 稳定性，确保 LMI 有解
Gw_orig = A - L*C - B*K;
if max(abs(eig(Gw_orig))) >= 1.0
    fprintf('  [!] 原生 Gw 不稳定(谱半径 %.2f)，强制使用稳定对角阵进行优化。\n', max(abs(eig(Gw_orig))));
    Gw = eye(nx_w) * 0.5; % 动态生成稳定的对角阵，适配当前维度
else
    fprintf('  [OK] 原生 Gw 稳定(谱半径 %.2f)。\n', max(abs(eig(Gw_orig))));
    Gw = Gw_orig;
end

Hw = L; % 水印输入映射
Aa = A - L*C; % 欺骗误差动力学
Ba = L; 

%% 4. YALMIP 决策变量与求解器设置
P       = sdpvar(N_total, N_total, 'symmetric');
gamma_r = sdpvar(1, 1);
gamma_a = sdpvar(1, 1);
options = sdpsettings('solver', 'sedumi', 'verbose', 0);

%% 5. 双重搜索循环
gamma_star = inf;
best_Cw = []; best_Dw = [];
total_pass = 0;

fprintf('\n--- 开始网格搜索 (Dw 网格 + Cw 随机) ---\n');

for d1 = alpha_min : step_Dw : alpha_max
    for d2 = alpha_min : step_Dw : alpha_max
        % 动态构建 Dw，适配 ny 通道数
        Dw_curr = diag([d1, d2]); % 注意：这里假设 ny=2。若 ny 变化，需调整网格循环逻辑
        Dq = inv(Dw_curr);
        
        for s = 1:num_samples
            % 随机采样 Cw
            Cw_curr = cw_vals(randi(length(cw_vals), ny, nx_w));
            
            % 稳定性校验: 移除器 Gq = Gw - L*Dq*Cw
            Gq = Gw - L * Dq * Cw_curr;
            if max(abs(eig(Gq))) >= 1.0, continue; end
            
            % --- 增广矩阵拼接 (基于动态维度) ---
            Cq = -Dq * Cw_curr; Hq = L * Dq;
            
            % 动态计算各个零矩阵的尺寸
            row1 = [A, -B*K, zeros(nx, nx_hat + nx_w + nx_q + nx_a)];
            row2 = [L*Dq*Dw_curr*C, A-L*C, zeros(nx_RK, nx_hat), L*Dq*Cw_curr, L*Cq, zeros(nx_RK, nx_a)];
            row3 = [K_KF*Dq*Dw_curr*C, -B*K, A-K_KF*C, K_KF*Dq*Cw_curr, K_KF*Cq, zeros(nx_hat, nx_a)];
            row4 = [Hw*C, zeros(nx_w, nx_RK + nx_hat), Gw, zeros(nx_w, nx_q + nx_a)]; % 已修复为 Hw*C
            row5 = [Hq*Dw_curr*C, zeros(nx_q, nx_RK + nx_hat), Hq*Cw_curr, Gq, zeros(nx_q, nx_a)];
            row6 = [zeros(nx_a, nx + nx_RK + nx_hat + nx_w + nx_q), Aa];
            
            G_bar = [row1; row2; row3; row4; row5; row6];
            
            % 检查增广系统整体稳定性
            if max(abs(eig(G_bar))) >= 1.0, continue; end
            total_pass = total_pass + 1;
            
            % 输入/输出矩阵构造 (动态维度)
            H_bar = [zeros(nx, ny); L*Dq; K_KF*Dq; zeros(nx_w, ny); Hq; Ba];
            
            nj = size(Cj, 1); % 性能指标输出维度
            C_j_bar = [Cj, -Dj*K, zeros(nj, nx_hat + nx_w + nx_q + nx_a)];
            
            C_r_bar = [Dq*Dw_curr*C, zeros(ny, nx_RK), -C, Dq*Cw_curr, Cq, zeros(ny, nx_a)];
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
            
            % --- 执行优化 ---
            Objective = epsilon_r * gamma_r + epsilon_a * gamma_a;
            sol = optimize(Constraints, Objective, options);
            
            if sol.problem == 0
                cost = value(Objective);
                if cost < gamma_star
                    gamma_star = cost;
                    best_Cw = Cw_curr;
                    best_Dw = Dw_curr;
                    fprintf('[发现解] Dw=[%.1f, %.1f], Cost=%.4f, gr=%.4f, ga=%.4f\n', ...
                            d1, d2, cost, value(gamma_r), value(gamma_a));
                end
            end
        end
    end
end

%% 6. 结果输出与最终诊断
if isempty(best_Dw)
    fprintf('\n诊断报告: 在 %d 个稳定性达标的样本中，未找到可行 LMI 解。\n', total_pass);
    fprintf('可能原因: 1. epsilon 权重冲突; 2. 矩阵数值范围跨度过大 (L 矩阵过大)。\n');
else
    fprintf('\n优化完成！最优 Cost: %.6f\n', gamma_star);
end

end

%% --- 辅助诊断函数 ---
function check_stability(Mat, name)
    eg = max(abs(eig(Mat)));
    if eg < 1
        fprintf('  [OK] %s 稳定, 谱半径: %.4f\n', name, eg);
    else
        fprintf('  [!!] %s 不稳定, 谱半径: %.4f\n', name, eg);
    end
end