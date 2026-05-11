function [best_Dw, best_Cw] = Optimize_watermark_design_v3(A, B, C, K, L, K_KF, Cj, Dj, epsilon_r, epsilon_a)
% =========================================================================
% 基于增广 H-inf 优化与诊断功能的最优水印设计函数 (带进度反馈提速版)
% =========================================================================

yalmip('clear');

%% 1. 动态推断系统维度
nx = size(A, 1);    
nu = size(B, 2);    
ny = size(C, 1);    

nx_RK = nx; nx_hat = nx; nx_w = nx; nx_q = nx; nx_a = nx; 
N_total = nx + nx_RK + nx_hat + nx_w + nx_q + nx_a; 

%% 2. 搜索空间配置
alpha_min = 0.2; alpha_max = 0.9; step_Dw = 0.05; 
Cw_min = -1; Cw_max = 1; Cw_step = 0.1; 
num_samples = 10; % 初期调试建议降为 30-50 提速
cw_vals = Cw_min : Cw_step : Cw_max;

dw_grid = alpha_min : step_Dw : alpha_max;
total_grids = length(dw_grid) * length(dw_grid); % 计算总网格数

%% 3. 系统稳定性预检与矩阵初始化
fprintf('--- 系统稳定性诊断开始 ---\n');
check_stability(A - L*C, '观测器 (A-LC)');
check_stability(A - K_KF*C, '卡尔曼滤波器 (A-K_KF*C)');

Gw_orig = A - L*C - B*K;
if max(abs(eig(Gw_orig))) >= 1.0
    fprintf('  [!] 原生 Gw 不稳定，强制使用稳定对角阵进行优化。\n');
    Gw = eye(nx_w) * 0.5; 
else
    fprintf('  [OK] 原生 Gw 稳定。\n');
    Gw = Gw_orig;
end

Hw = L; Aa = A - L*C; Ba = L; 

%% 4. YALMIP 决策变量与求解器设置
P       = sdpvar(N_total, N_total, 'symmetric');
gamma_r = sdpvar(1, 1);
gamma_a = sdpvar(1, 1);
% 提示：如果你安装了 MOSEK，将 'mosek' 改为 'mosek' 速度会有质的飞跃！
options = sdpsettings('solver', 'mosek', 'verbose', 0, 'cachesolvers', 1);

%% 5. 双重搜索循环
gamma_star = inf;
best_Cw = []; best_Dw = [];
total_pass = 0;
current_grid = 0;

fprintf('\n--- 开始网格搜索 (共 %d 个 Dw 组合) ---\n', total_grids);
global_tic = tic; % 记录总耗时

for d1 = dw_grid
    for d2 = dw_grid
        current_grid = current_grid + 1;
        Dw_curr = diag([d1, d2]); 
        Dq = inv(Dw_curr);
        
        % 打印当前网格点进度，不换行
        fprintf('[%d/%d] 正在搜索 Dw=[%.2f, %.2f]... ', current_grid, total_grids, d1, d2);
        grid_tic = tic; % 记录当前网格耗时
        
        valid_samples_in_grid = 0; % 记录当前网格有多少样本进入了求解器
        
        for s = 1:num_samples
            Cw_curr = cw_vals(randi(length(cw_vals), ny, nx_w));
            
            % 移除器稳定性极速拦截
            Gq = Gw - L * Dq * Cw_curr;
            if max(abs(eig(Gq))) >= 1.0, continue; end
            
            % 拼装矩阵
            Cq = -Dq * Cw_curr; Hq = L * Dq;
            
            row1 = [A, -B*K, zeros(nx, nx_hat + nx_w + nx_q + nx_a)];
            row2 = [L*Dq*Dw_curr*C, A-L*C, zeros(nx_RK, nx_hat), L*Dq*Cw_curr, L*Cq, zeros(nx_RK, nx_a)];
            row3 = [K_KF*Dq*Dw_curr*C, -B*K, A-K_KF*C, K_KF*Dq*Cw_curr, K_KF*Cq, zeros(nx_hat, nx_a)];
            row4 = [Hw*C, zeros(nx_w, nx_RK + nx_hat), Gw, zeros(nx_w, nx_q + nx_a)]; 
            row5 = [Hq*Dw_curr*C, zeros(nx_q, nx_RK + nx_hat), Hq*Cw_curr, Gq, zeros(nx_q, nx_a)];
            row6 = [zeros(nx_a, nx + nx_RK + nx_hat + nx_w + nx_q), Aa];
            G_bar = [row1; row2; row3; row4; row5; row6];
            
            % 增广系统稳定性拦截
            if max(abs(eig(G_bar))) >= 1.0, continue; end
            
            valid_samples_in_grid = valid_samples_in_grid + 1;
            total_pass = total_pass + 1;
            
            H_bar = [zeros(nx, ny); L*Dq; K_KF*Dq; zeros(nx_w, ny); Hq; Ba];
            nj = size(Cj, 1);
            C_j_bar = [Cj, -Dj*K, zeros(nj, nx_hat + nx_w + nx_q + nx_a)];
            C_r_bar = [Dq*Dw_curr*C, zeros(ny, nx_RK), -C, Dq*Cw_curr, Cq, zeros(ny, nx_a)];
            Dr_bar = Dq;

            % 构造 LMI
            M11 = -P + (C_j_bar' * C_j_bar) - gamma_r * (C_r_bar' * C_r_bar);
            M12 = G_bar' * P;
            M13 = C_r_bar' * Dr_bar; 
            M22 = -P;
            M23 = P * H_bar;
            M33 = -gamma_a * eye(ny) - gamma_r * (Dr_bar' * Dr_bar);
            
            LMI = [M11, M12, M13; M12', M22, M23; M13', M23', M33];
            Constraints = [P >= 1e-8*eye(N_total), gamma_r >= 0, gamma_a >= 0, LMI <= 0];
            
            % 求解
            Objective = epsilon_r * gamma_r + epsilon_a * gamma_a;
            sol = optimize(Constraints, Objective, options);
            
            if sol.problem == 0
                cost = value(Objective);
                if cost < gamma_star
                    gamma_star = cost;
                    best_Cw = Cw_curr;
                    best_Dw = Dw_curr;
                    % 发现更优解时，强制换行高亮打印
                    fprintf('\n  >>> [突破] 找到更优解! Cost=%.4f (gr=%.4f, ga=%.4f)\n', ...
                            cost, value(gamma_r), value(gamma_a));
                end
            end
        end
        % 打印该网格点结束信息
        fprintf(' 耗时 %.1fs (测试了 %d 个稳定样本)\n', toc(grid_tic), valid_samples_in_grid);
    end
end

%% 6. 结果输出
fprintf('\n======================================================\n');
fprintf('全部搜索完成！总耗时: %.1f 分钟\n', toc(global_tic)/60);
if isempty(best_Dw)
    fprintf('诊断报告: 在 %d 个稳定性达标的样本中，未找到可行 LMI 解。\n', total_pass);
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