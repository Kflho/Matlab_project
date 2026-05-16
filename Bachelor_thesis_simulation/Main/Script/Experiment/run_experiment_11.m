function run_experiment_11()
% 实验11：基于帕累托最优的弱/强水印设计（精确计算10个点）
% 遍历 epsilon_r = 0.1:0.1:0.9，多次重启 PSO 以增强收敛性。

    % ---- 创建系统矩阵 ----
    [G, H, C, D] = Create_shoukong;
    A = G;   B = H;
    K = Calculate_LQR(G, H);
    K_KF = [0.4427 0; 0 0.4451; -0.1561 0; 0 -0.1607];
    Cj = [0.806 0 0 0; 0 0.787 0 0; 0 0 5.556 0; 0 0 0 7.143; 0 0 0 0; 0 0 0 0];
    Dj = [0 0; 0 0; 0 0; 0 0; 0.901 0; 0 0.897];

    % ---- PSO 增强参数 ----
    pso_particles = 200;      % 粒子群规模
    pso_iter      = 100;      % 迭代次数
    n_restart     = 1;        % 每个权重重复运行次数，取最优

    % ---- 权重遍历 ----
    eps_r_values = 0.1:0.1:0.9;    % 精确计算 100 个点
    n_weights = length(eps_r_values);
    J_opt = zeros(n_weights, 1);
    Dw_cell = cell(n_weights, 1);
    Cw_cell = cell(n_weights, 1);

    fprintf('===== 实验11：帕累托最优水印设计 =====\n');
    fprintf('遍历 %d 组权重，每点重启 %d 次 (粒子%d, 迭代%d)\n', n_weights, n_restart, pso_particles, pso_iter);
    tic;

    % 使用 parfor 需注意函数内部不能有共享状态，此处可行
    for i = 1:n_weights
        epsilon_r = eps_r_values(i);
        epsilon_a = 1 - epsilon_r;
        best_cost = inf;
        best_Dw = [];
        best_Cw = [];
        for r = 1:n_restart
            [Dw_tmp, Cw_tmp, cost_tmp] = Optimize_watermark_PSO(A, B, C, K, K_KF, Cj, Dj, ...
                                                                 epsilon_r, epsilon_a, ...
                                                                 pso_particles, pso_iter);
            if cost_tmp < best_cost
                best_cost = cost_tmp;
                best_Dw = Dw_tmp;
                best_Cw = Cw_tmp;
            end
        end
        J_opt(i) = best_cost;
        Dw_cell{i} = best_Dw;
        Cw_cell{i} = best_Cw;
        fprintf('[%02d/%02d] ε_r=%.2f, ε_a=%.2f, J*=%.4f\n', i, n_weights, epsilon_r, epsilon_a, best_cost);
    end
    elapsed = toc;
    fprintf('遍历完成，总耗时 %.1f 分钟\n', elapsed/60);

    % ---- 分区域选出最优 ----
    weak_mask = eps_r_values > (1 - eps_r_values);   % ε_r > ε_a
    strong_mask = eps_r_values < (1 - eps_r_values); % ε_r < ε_a

    [weak_min, weak_idx] = min(J_opt(weak_mask));
    weak_all = find(weak_mask);
    weak_best = weak_all(weak_idx);

    [strong_min, strong_idx] = min(J_opt(strong_mask));
    strong_all = find(strong_mask);
    strong_best = strong_all(strong_idx);

    % ---- 输出结果 ----
    fprintf('\n============= 帕累托最优结果 =============\n');
    fprintf('弱水印 (ε_r=%.2f, ε_a=%.2f)  J* = %.4f\n', eps_r_values(weak_best), 1-eps_r_values(weak_best), weak_min);
    fprintf('  Dw = \n'); disp(Dw_cell{weak_best});
    fprintf('  Cw = \n'); disp(Cw_cell{weak_best});

    fprintf('强水印 (ε_r=%.2f, ε_a=%.2f)  J* = %.4f\n', eps_r_values(strong_best), 1-eps_r_values(strong_best), strong_min);
    fprintf('  Dw = \n'); disp(Dw_cell{strong_best});
    fprintf('  Cw = \n'); disp(Cw_cell{strong_best});

    % 保存结果
    save('Optimal_Watermarks_Pareto.mat', 'Dw_cell', 'Cw_cell', 'eps_r_values', 'J_opt', ...
         'weak_best', 'strong_best');
    fprintf('结果已保存至 Optimal_Watermarks_Pareto.mat\n');

    % ========== 绘制帕累托前沿并导出 ==========
    out_dir = fullfile('Figures', '11_Optimal_Watermarks');
    if ~exist(out_dir, 'dir'), mkdir(out_dir); end

    figure('Color','w');
    plot(eps_r_values, J_opt, 'b-o', 'LineWidth', 1.5, 'MarkerSize', 4);
    hold on;
    xline(0.5, '--k', 'LineWidth', 1.2, 'DisplayName', 'ε_r = ε_a (分界)');
    scatter(eps_r_values(weak_best), J_opt(weak_best), 80, 'r', 'filled', ...
        'DisplayName', sprintf('弱水印最优 (ε_r=%.2f)', eps_r_values(weak_best)));
    scatter(eps_r_values(strong_best), J_opt(strong_best), 80, 'g', 'filled', ...
        'DisplayName', sprintf('强水印最优 (ε_r=%.2f)', eps_r_values(strong_best)));
    xlabel('ε_r');
    ylabel('J* = ε_r γ_r + ε_a γ_a');
    title('水印设计帕累托前沿与最优解');
    legend('Location','northwest');
    grid on;
    hold off;

    Run_visualization;
    Export_fig_paper(gcf, fullfile(out_dir, 'pareto_frontier'), 5.5);
    fprintf('帕累托前沿图已保存至 %s\n', out_dir);
end