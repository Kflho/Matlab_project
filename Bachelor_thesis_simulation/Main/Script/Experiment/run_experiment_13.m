function run_experiment_13(point_num)
% 实验13：POMDP 性能损失期望曲线
% 任务1：固定 TrueAtkFreq=0.005，p_min 变化 (20个点)
% 任务2：固定 p_min=0.05，TrueAtkFreq 变化 (20个点)

    %% ========== 公共设置 ==========
    % 启动并行池（如果有 Parallel Toolbox）
    if isempty(gcp('nocreate'))
        try
            parpool('local');
        catch
            disp('无法启动并行池，将使用串行计算。');
        end
    end

    % 添加路径（根据实际修改）
    addpath('D:\local_data\software_data\programming_data\Matlab_project\Common\Visualization');

    % 输出文件夹
    out_dir = fullfile('Figures', '13_POMDP_curves');
    if ~exist(out_dir, 'dir'), mkdir(out_dir); end

    %% ========== 任务1：p_min 变化 ==========
    TrueAtkFreq = 0.005;
    p_min_vals = linspace(0.005, 0.2, point_num);   % 20个点，可根据需求调整范围
    n_pts = length(p_min_vals);

    fprintf('===== 任务1：TrueAtkFreq=%.3f，扫描 p_min =====\n', TrueAtkFreq);
    costs_task1 = zeros(n_pts, 4);   % 每行对应一种 p_min 下的四种策略损失

    tic;
    % 使用 parfor 加速
    parfor i = 1:n_pts
        avg_costs = POMDP_function(p_min_vals(i), TrueAtkFreq);
        costs_task1(i, :) = avg_costs;
        fprintf('p_min=%.4f 完成，损失 [%.2f, %.2f, %.2f, %.2f]\n', ...
                p_min_vals(i), avg_costs(1), avg_costs(2), avg_costs(3), avg_costs(4));
    end
    fprintf('任务1完成，耗时 %.1f 分钟\n', toc/60);

    % 绘制图1
    figure('Color','w');
    plot(p_min_vals, costs_task1(:,1), 's-', 'LineWidth',1.5, 'DisplayName','不加水印');
    hold on;
    plot(p_min_vals, costs_task1(:,2), 'o-', 'LineWidth',1.5, 'DisplayName','持续弱水印');
    plot(p_min_vals, costs_task1(:,3), 'd-', 'LineWidth',1.5, 'DisplayName','持续强水印');
    plot(p_min_vals, costs_task1(:,4), '^-', 'LineWidth',1.5, 'DisplayName','POMDP 切换方案');
    hold off;
    xlabel('攻击频率估计下界 p_min','Interpreter','latex');
    ylabel('长期平均性能损失 (cm^2)','Interpreter','latex');
    title('不同p_min下各方案长期平均性能损失 (攻击频率固定ambda=0.005)','Interpreter','latex');
    legend('Location','best'); grid on;
    Run_visualization;
    Export_fig_paper(gcf, fullfile(out_dir, 'task1_p_min'), 5.5);

    %% ========== 任务2：TrueAtkFreq 变化 ==========
    p_min_fixed = 0.05;
    freq_vals = linspace(0.001, 0.02, point_num);   % 20个点，范围可调
    n_pts2 = length(freq_vals);

    fprintf('\n===== 任务2：p_min=%.2f，扫描 TrueAtkFreq =====\n', p_min_fixed);
    costs_task2 = zeros(n_pts2, 4);

    tic;
    parfor i = 1:n_pts2
        avg_costs = POMDP_function(p_min_fixed, freq_vals(i));
        costs_task2(i, :) = avg_costs;
        fprintf('TrueAtkFreq=%.4f 完成，损失 [%.2f, %.2f, %.2f, %.2f]\n', ...
                freq_vals(i), avg_costs(1), avg_costs(2), avg_costs(3), avg_costs(4));
    end
    fprintf('任务2完成，耗时 %.1f 分钟\n', toc/60);

    % 绘制图2
    figure('Color','w');
    plot(freq_vals, costs_task2(:,1), 's-', 'LineWidth',1.5, 'DisplayName','不加水印');
    hold on;
    plot(freq_vals, costs_task2(:,2), 'o-', 'LineWidth',1.5, 'DisplayName','持续弱水印');
    plot(freq_vals, costs_task2(:,3), 'd-', 'LineWidth',1.5, 'DisplayName','持续强水印');
    plot(freq_vals, costs_task2(:,4), '^-', 'LineWidth',1.5, 'DisplayName','POMDP 切换方案');
    hold off;
    xlabel('真实攻击频率 (lambda)','Interpreter','latex');
    ylabel('长期平均性能损失 (cm^2)','Interpreter','latex');
    title('不同攻击频率下各方案长期平均性能损失 (p_min=0.05)','Interpreter','latex');
    legend('Location','best'); grid on;
    Run_visualization;
    Export_fig_paper(gcf, fullfile(out_dir, 'task2_TrueAtkFreq'), 5.5);
end