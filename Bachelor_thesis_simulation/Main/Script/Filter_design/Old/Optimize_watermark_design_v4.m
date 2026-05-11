function [best_Dw, best_Cw] = Optimize_watermark_design_v4(A, B, C, K, K_KF, Cj, Dj, epsilon_r, epsilon_a)
% =========================================================================
% 基于增广 H-inf 优化最优水印设计 (20维单 KF 极速版 + MOSEK)
% 注意：彻底删除了 RK 观测器及其增益 L，全面使用 K_KF
% =========================================================================

yalmip('clear');

%% 1. 动态推断系统维度 (降维至 20 维)
nx = size(A, 1);    
nu = size(B, 2);    
ny = size(C, 1);    

% 剔除 nx_RK，直接使用 nx_hat 作为唯一的观测器和残差生成器
nx_hat = nx; nx_w = nx; nx_q = nx; nx_a = nx; 
N_total = nx + nx_hat + nx_w + nx_q + nx_a; % 5个模块，总维度 20

%% 2. 搜索空间配置
alpha_min = 0.2; alpha_max = 0.9; step_Dw = 0.05; 
Cw_min = -1; Cw_max = 1; Cw_step = 0.1; 
num_samples = 50; % MOSEK很快，50~100均可轻松驾驭
cw_vals = Cw_min : Cw_step : Cw_max;

dw_grid = alpha_min : step_Dw : alpha_max;
total_grids = length(dw_grid) * length(dw_grid); 

%% 3. 系统稳定性预检与矩阵初始化 (全面适配 KF)
fprintf('--- 20维单卡尔曼架构 稳定性诊断 ---\n');
check_stability(A - K_KF*C, '卡尔曼滤波器 (A-K_KF*C)');

% 【核心修改】水印生成器参数现在匹配 KF
Hw = K_KF; 
Gw_orig = A - K_KF*C - B*K; 
if max(abs(eig(Gw_orig))) >= 1.0
    fprintf('  [!] 原生 Gw 不稳定，强制使用稳定对角阵进行优化。\n');
    Gw = eye(nx_w) * 0.5; 
else
    fprintf('  [OK] 原生 Gw 稳定。\n');
    Gw = Gw_orig;
end

% 【核心修改】攻击者为了隐蔽，其误差动力学模仿 KF
Aa = A - K_KF*C; 
Ba = K_KF; 

%% 4. YALMIP 决策变量与求解器设置
P       = sdpvar(N_total, N_total, 'symmetric');
gamma_r = sdpvar(1, 1);
gamma_a = sdpvar(1, 1);

% 确认启用 mosek
options = sdpsettings('solver', 'mosek', 'verbose', 0, 'cachesolvers', 1);

%% 5. 双重搜索循环
gamma_star = inf;
best_Cw = []; best_Dw = [];
total_pass = 0;
current_grid = 0;

fprintf('\n--- 开始极速网格搜索 (共 %d 个 Dw 组合) ---\n', total_grids);
global_tic = tic; 

for d1 = dw_grid
    for d2 = dw_grid
        current_grid = current_grid + 1;
        Dw_curr = diag([d1, d2]); 
        Dq = inv(Dw_curr);
        
        fprintf('[%d/%d] 搜索 Dw=[%.2f, %.2f]... ', current_grid, total_grids, d1, d2);
        grid_tic = tic; 
        valid_samples_in_grid = 0; 
        
        for s = 1:num_samples
            Cw_curr = cw_vals(randi(length(cw_vals), ny, nx_w));
            
            % 移除器稳定性极速拦截 (换成 K_KF)
            Gq = Gw - K_KF * Dq * Cw_curr;
            if max(abs(eig(Gq))) >= 1.0, continue; end
            
            % --- 拼装 20 维增广矩阵 (严格按 5x5 分块数学推导) ---
            Cq = -Dq * Cw_curr; Hq = K_KF * Dq;
            
            % ① 物理系统 x (闭环控制 u = -K*x_hat)
            row1 = [A, -B*K, zeros(nx, nx_w + nx_q + nx_a)];
            
            % ② 卡尔曼滤波器 x_hat (融合了状态估计与残差基准)
            row2 = [K_KF*Dq*Dw_curr*C, A - B*K - K_KF*C, K_KF*Dq*Cw_curr, K_KF*Cq, zeros(nx_hat, nx_a)];
            
            % ③ 水印生成器 x_w
            row3 = [Hw*C, zeros(nx_w, nx_hat), Gw, zeros(nx_w, nx_q + nx_a)]; 
            
            % ④ 水印移除器 x_q
            row4 = [Hq*Dw_curr*C, zeros(nx_q, nx_hat), Hq*Cw_curr, Gq, zeros(nx_q, nx_a)];
            
            % ⑤ 欺骗攻击误差 x_a
            row5 = [zeros(nx_a, nx + nx_hat + nx_w + nx_q), Aa];
            
            G_bar = [row1; row2; row3; row4; row5];
            
            if max(abs(eig(G_bar))) >= 1.0, continue; end
            
            valid_samples_in_grid = valid_samples_in_grid + 1;
            total_pass = total_pass + 1;
            
            % --- 输入与输出矩阵 (降维适配) ---
            H_bar = [zeros(nx, ny); K_KF*Dq; zeros(nx_w, ny); Hq; Ba];
            
            nj = size(Cj, 1);
            C_j_bar = [Cj, -Dj*K, zeros(nj, nx_w + nx_q + nx_a)];
            C_r_bar = [Dq*Dw_curr*C, -C, Dq*Cw_curr, Cq, zeros(ny, nx_a)];
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
            
            % 目标函数求解
            Objective = epsilon_r * gamma_r + epsilon_a * gamma_a;
            sol = optimize(Constraints, Objective, options);
            
            if sol.problem == 0
                cost = value(Objective);
                if cost < gamma_star
                    gamma_star = cost;
                    best_Cw = Cw_curr;
                    best_Dw = Dw_curr;
                    fprintf('\n  >>> [突破] 找到更优解! Cost=%.4f (gr=%.4f, ga=%.4f)\n', ...
                            cost, value(gamma_r), value(gamma_a));
                end
            end
        end
        fprintf(' 耗时 %.2fs (测试了 %d 个稳定样本)\n', toc(grid_tic), valid_samples_in_grid);
    end
end

%% 6. 结果输出
fprintf('\n======================================================\n');
fprintf('全部搜索完成！总耗时: %.2f 秒\n', toc(global_tic));
if isempty(best_Dw)
    fprintf('诊断报告: 在 %d 个稳定性达标的样本中，未找到可行解。\n', total_pass);
else
    fprintf('最优 Cost: %.6f\n', gamma_star);
    disp('最优 Dw ='); disp(best_Dw);
    disp('最优 Cw ='); disp(best_Cw);
end
end

function check_stability(Mat, name)
    eg = max(abs(eig(Mat)));
    if eg < 1
        fprintf('  [OK] %s 稳定, 谱半径: %.4f\n', name, eg);
    else
        fprintf('  [!!] %s 不稳定, 谱半径: %.4f\n', name, eg);
    end
end