function [best_Dw, best_Cw, global_best_cost] = Optimize_watermark_PSO(A, B, C, K, K_KF, Cj, Dj, epsilon_r, epsilon_a, num_particles, max_iter)
% ...
% 新增输入参数（可选）：
%   num_particles : 粒子群规模，默认 300
%   max_iter      : 最大迭代次数，默认 300

    if nargin < 10, max_iter = 300; end
    if nargin < 9, num_particles = 300; end
% =========================================================================
% 基于粒子群算法 (PSO) 的最优水印设计 (连续优化版)
% 适配 20 维单卡尔曼滤波器 (KF) 架构
% =========================================================================

yalmip('clear');

%% 1. 系统维度与 PSO 变量映射
nx = size(A, 1);    
ny = size(C, 1);    
nx_w = nx; 

% 粒子维度：Dw对角线2个 + Cw矩阵 ny*nx_w (2*4=8) 个 = 10 维
dim = ny + (ny * nx_w); 

%% 2. PSO 算法核心参数设置
% num_particles = 10;       % 粒子群规模
% max_iter = 10;            % 最大迭代次数

% 定义搜索边界
LB = [0.001, 0.001, -1 * ones(1, ny * nx_w)]; 
UB = [0.2, 0.2,  1 * ones(1, ny * nx_w)]; 

% 速度边界 
V_max = 0.2 * (UB - LB);
V_min = -V_max;

% 学习因子与惯性权重
w_start = 0.9; w_end = 0.4; 
c1 = 1.5; 
c2 = 1.5; 

%% 3. 初始化粒子群 (连续空间，不做离散化)
Positions = zeros(num_particles, dim);
Velocities = zeros(num_particles, dim);
for i = 1:dim
    Positions(:, i) = LB(i) + (UB(i) - LB(i)) * rand(num_particles, 1);
    Velocities(:, i) = V_min(i) + (V_max(i) - V_min(i)) * rand(num_particles, 1);
end

% 初始化最优记录
pBest_Positions = Positions;
pBest_Scores = inf(num_particles, 1);
gBest_Position = zeros(1, dim);
gBest_Score = inf;

options = sdpsettings('solver', 'mosek', 'verbose', 0, 'cachesolvers', 1);
% 【防卡死代码】：限制 MOSEK 内部只使用 1 个线程
options.mosek.MSK_IPAR_NUM_THREADS = 1;

%% 4. PSO 主循环
fprintf('\n======================================================\n');
fprintf('启动连续 PSO 优化 (无网格离散)\n');
global_tic = tic;

for iter = 1:max_iter
    iter_tic = tic;
    valid_lmi_count = 0; 
    
    w = w_start - (w_start - w_end) * (iter / max_iter);
    
    % =========================================================
    % 开启并行计算 (火力全开)
    % =========================================================
    costs_this_iter = zeros(num_particles, 1);
    
    % parfor 会调用电脑所有 CPU 核心同时算这批粒子
    parfor i = 1:num_particles
        costs_this_iter(i) = evaluate_Fitness(Positions(i, :), A, B, C, K, K_KF, Cj, Dj, epsilon_r, epsilon_a, options);
    end
    
    % =========================================================
    % 串行更新最优记录 (统计结果)
    % =========================================================
    for i = 1:num_particles
        cost = costs_this_iter(i);
        
        if cost < 1e5
            valid_lmi_count = valid_lmi_count + 1;
        end
        
        % 更新个体最优
        if cost < pBest_Scores(i)
            pBest_Scores(i) = cost;
            pBest_Positions(i, :) = Positions(i, :);
        end
        
        % 更新全局最优
        if cost < gBest_Score
            gBest_Score = cost;
            gBest_Position = Positions(i, :);
            fprintf('  >>> [突破] 第%d代发现新全局最优: Cost = %.4f\n', iter, gBest_Score);
            
            % 1. 实时解析出当前矩阵
            temp_Dw = diag([gBest_Position(1), gBest_Position(2)]);
            temp_Cw = reshape(gBest_Position(3:end), size(C, 1), size(A, 1));
            
            % 2. 打印到命令行（保留四位小数）
            fprintf('  当前暂存 Dw =\n');
            print_matrix_4d(temp_Dw);
            fprintf('  当前暂存 Cw =\n');
            print_matrix_4d(temp_Cw);
            
            % 3. 强行写入硬盘
            temp_filename = sprintf('Temp_Best_Watermark_ea_%g.mat', epsilon_a);
            save(temp_filename, 'temp_Dw', 'temp_Cw', 'gBest_Score');
        end
    end
    
    % --- 更新速度和位置 (连续空间，无离散化) ---
    for i = 1:num_particles
        r1 = rand(1, dim);
        r2 = rand(1, dim);
        
        Velocities(i, :) = w * Velocities(i, :) ...
            + c1 * r1 .* (pBest_Positions(i, :) - Positions(i, :)) ...
            + c2 * r2 .* (gBest_Position - Positions(i, :));
        
        Velocities(i, :) = max(min(Velocities(i, :), V_max), V_min);
        Positions(i, :) = Positions(i, :) + Velocities(i, :);
        Positions(i, :) = max(min(Positions(i, :), UB), LB);
    end
    
    fprintf('[Iter %02d/%02d] 耗时 %.1fs | 当前最优: %.4f | 有效解: %d/%d\n', ...
            iter, max_iter, toc(iter_tic), gBest_Score, valid_lmi_count, num_particles);
end

%% 5. 结果还原与输出
global_best_cost = gBest_Score;
best_Dw = diag([gBest_Position(1), gBest_Position(2)]);
best_Cw = reshape(gBest_Position(3:end), size(C, 1), size(A, 1));

fprintf('\n======================================================\n');
fprintf('连续 PSO 优化完成！总耗时: %.1f 分钟\n', toc(global_tic)/60);
if gBest_Score == inf
    fprintf('诊断报告: 寻优失败，未找到任何可行解。\n');
else
    fprintf('全局最优 Cost: %.4f\n', gBest_Score);
    fprintf('最优 Dw =\n');
    print_matrix_4d(best_Dw);
    fprintf('最优 Cw =\n');
    print_matrix_4d(best_Cw);
end

end

% =========================================================================
% 内部辅助函数：按四位小数打印矩阵
% =========================================================================
function print_matrix_4d(M)
    [rows, cols] = size(M);
    for r = 1:rows
        for c = 1:cols
            fprintf('  %.4f', M(r,c));
        end
        fprintf('\n');
    end
end

% =========================================================================
% 内部函数：适应度计算 (LMI 求解核心保持不变)
% =========================================================================
function cost = evaluate_Fitness(particle, A, B, C, K, K_KF, Cj, Dj, epsilon_r, epsilon_a, options)
% 【加入这行救命代码】：每次进函数前，清空 YALMIP 在当前并行核心里的符号缓存！
    yalmip('clear');

    ny = size(C, 1); nx_w = size(A, 1);
    d1 = particle(1); d2 = particle(2);
    Cw_curr = reshape(particle(3:end), ny, nx_w);
    
    Dw_curr = diag([d1, d2]);
    Dq = diag([1/d1, 1/d2]); 
    
    Hw = K_KF; 
    Gw = A - K_KF*C - B*K; 
    if max(abs(eig(Gw))) >= 1.0; Gw = eye(nx_w) * 0.5; end
    
    Gq = Gw - K_KF * Dq * Cw_curr;
    if max(abs(eig(Gq))) >= 1.0
        cost = 1e6; return; 
    end
    
    nx = size(A, 1); nx_hat = nx; nx_q = nx; nx_a = nx; 
    Aa = A - K_KF*C; Ba = K_KF;
    Cq = -Dq * Cw_curr; Hq = K_KF * Dq;
    
    row1 = [A, -B*K, zeros(nx, nx_w + nx_q + nx_a)];
    row2 = [K_KF*Dq*Dw_curr*C, A - B*K - K_KF*C, K_KF*Dq*Cw_curr, K_KF*Cq, zeros(nx_hat, nx_a)];
    row3 = [Hw*C, zeros(nx_w, nx_hat), Gw, zeros(nx_w, nx_q + nx_a)]; 
    row4 = [Hq*Dw_curr*C, zeros(nx_q, nx_hat), Hq*Cw_curr, Gq, zeros(nx_q, nx_a)];
    row5 = [zeros(nx_a, nx + nx_hat + nx_w + nx_q), Aa];
    G_bar = [row1; row2; row3; row4; row5];
    
    if max(abs(eig(G_bar))) >= 1.0
        cost = 1e6; return; 
    end
    
    N_total = nx + nx_hat + nx_w + nx_q + nx_a;
    P = sdpvar(N_total, N_total, 'symmetric');
    gamma_r = sdpvar(1, 1);
    gamma_a = sdpvar(1, 1);
    
    H_bar = [zeros(nx, ny); K_KF*Dq; zeros(nx_w, ny); Hq; Ba];
    nj = size(Cj, 1);
    C_j_bar = [Cj, -Dj*K, zeros(nj, nx_w + nx_q + nx_a)];
    C_r_bar = [Dq*Dw_curr*C, -C, Dq*Cw_curr, Cq, zeros(ny, nx_a)];
    Dr_bar = Dq;

    M11 = -P + (C_j_bar' * C_j_bar) - gamma_r * (C_r_bar' * C_r_bar);
    M12 = G_bar' * P;
    M13 = C_r_bar' * Dr_bar; 
    M22 = -P;
    M23 = P * H_bar;
    M33 = -gamma_a * eye(ny) - gamma_r * (Dr_bar' * Dr_bar);
    
    LMI = [M11, M12, M13; M12', M22, M23; M13', M23', M33];
    Constraints = [P >= 1e-8*eye(N_total), gamma_r >= 0, gamma_a >= 0, LMI <= 0];
    Objective = epsilon_r * gamma_r + epsilon_a * gamma_a;
    
    sol = optimize(Constraints, Objective, options);
    
    if sol.problem == 0
        cost = value(Objective);
    else
        cost = 1e6; 
    end
end