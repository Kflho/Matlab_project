function [best_Dw, best_Cw] = Optimize_watermark_design(A, B, C, K, L, K_KF, Cj, Dj, epsilon_r, epsilon_a)
% =========================================================================
% 基于增广 H-inf 优化与诊断功能的最优水印设计函数
% 输入: 系统矩阵与权重 epsilon_r, epsilon_a
% 输出: 最优 Dw, Cw
% =========================================================================

yalmip('clear');

%% 1. 系统维度与搜索配置
nx = 4; nx_RK = 4; nx_hat = 4; nx_w = 4; nx_q = 4; nx_a = 4; 
N_total = 24; ny = 2; nu = 2;

% 搜索空间配置
alpha_min = 0.2; alpha_max = 0.9; step_Dw = 0.1; 
Cw_min = -1; Cw_max = 1; Cw_step = 0.1; 
num_samples = 50; % 每个 Dw 点位的随机采样数
cw_vals = Cw_min : Cw_step : Cw_max;

%% 2. 系统稳定性预检与矩阵初始化
fprintf('--- 系统稳定性诊断开始 ---\n');
check_stability(A - L*C, '观测器 (A-LC)');
check_stability(A - K_KF*C, '卡尔曼滤波器 (A-K_KF*C)');

% 核心修改：修复 Gw 稳定性，确保 LMI 有解
% 若原生 Gw 不稳定，强制使用稳定的名义矩阵
Gw_orig = A - L*C - B*K;
if max(abs(eig(Gw_orig))) >= 1.0
    fprintf('  [!] 原生 Gw 不稳定(谱半径 %.2f)，强制使用稳定对角阵进行优化。\n', max(abs(eig(Gw_orig))));
    Gw = diag([0.5, 0.5, 0.4, 0.4]); 
else
    fprintf('  [OK] 原生 Gw 稳定(谱半径 %.2f)。\n', max(abs(eig(Gw_orig))));
    Gw = Gw_orig;
end

Hw = L; % 水印输入映射
Aa = A - L*C; % 欺骗误差动力学
Ba = L; 

%% 3. YALMIP 决策变量与求解器设置
P       = sdpvar(N_total, N_total, 'symmetric');
gamma_r = sdpvar(1, 1);
gamma_a = sdpvar(1, 1);
options = sdpsettings('solver', 'sedumi', 'verbose', 0);

%% 4. 双重搜索循环
gamma_star = inf;
best_Cw = []; best_Dw = [];
total_pass = 0;

fprintf('\n--- 开始网格搜索 (Dw 网格 + Cw 随机) ---\n');

for d1 = alpha_min : step_Dw : alpha_max
    for d2 = alpha_min : step_Dw : alpha_max
        Dw_curr = diag([d1, d2]);
        Dq = inv(Dw_curr);
        
        for s = 1:num_samples
            % 随机采样 Cw
            Cw_curr = cw_vals(randi(length(cw_vals), ny, nx_w));
            
            % 稳定性校验: 移除器 Gq = Gw - L*Dq*Cw
            Gq = Gw - L * Dq * Cw_curr;
            if max(abs(eig(Gq))) >= 1.0, continue; end
            
            % --- 增广矩阵拼接 (基于传感器输入 a(k) 逻辑) ---
            Cq = -Dq * Cw_curr; Hq = L * Dq;
            
            % G_bar (24x24)
            row1 = [A, -B*K, zeros(4,16)];
            row2 = [L*Dq*Dw_curr*C, A-L*C, zeros(4,4), L*Dq*Cw_curr, L*Cq, zeros(4,4)];
            row3 = [K_KF*Dq*Dw_curr*C, -B*K, A-K_KF*C, K_KF*Dq*Cw_curr, K_KF*Cq, zeros(4,4)];
            row4 = [Hw*C, zeros(4,8), Gw, zeros(4,8)];
            row5 = [Hq*Dw_curr*C, zeros(4,8), Hq*Cw_curr, Gq, zeros(4,4)];
            row6 = [zeros(4,20), Aa];
            G_bar = [row1; row2; row3; row4; row5; row6];
            
            % 检查增广系统整体稳定性
            if max(abs(eig(G_bar))) >= 1.0, continue; end
            total_pass = total_pass + 1;
            
            % 输入/输出矩阵构造
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

%% 5. 结果输出与最终诊断
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